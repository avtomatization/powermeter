import Foundation
import IOKit
import IOKit.ps

private enum IOPS {
    static let batteryType = "InternalBattery"
    static let acPower = "AC Power"
}

enum PowerUnavailableReason: Equatable, Sendable {
    case noIOPSData
    case noPowerSources
    case zeroCurrent
    case batteryNotFound

    var l10nKey: String {
        switch self {
        case .noIOPSData: return "errors.no_iops"
        case .noPowerSources: return "errors.no_sources"
        case .zeroCurrent: return "errors.zero_current"
        case .batteryNotFound: return "errors.battery_not_found"
        }
    }
}

enum BatteryFlow: Equatable, Sendable {
    case charging
    case onACIdle
    case discharging

    var l10nKey: String {
        switch self {
        case .charging: return "battery.charging"
        case .onACIdle: return "battery.ac"
        case .discharging: return "battery.discharging"
        }
    }
}

enum PowerSample: Sendable {
    case watts(Double, flow: BatteryFlow)
    case unavailable(PowerUnavailableReason)
}

enum PowerSampler {
    private static let voltageCacheLock = NSLock()
    private static var voltageCachedMv: Double?
    private static var voltageCachedAt: CFAbsoluteTime = 0
    /// Короткий TTL только для запасного пути без напряжения в IOPS.
    private static let voltageCacheTTL: CFAbsoluteTime = 1

    /// Сырые данные `AppleSmartBattery`: SystemPower ближе к тому, что показывают сторонние виджеты.
    private struct RegistrySample {
        var millivolts: Double
        var milliamps: Double
        var systemPowerWatts: Double?
    }

    static func sample() -> PowerSample {
        let registrySample = readAppleSmartBatterySample()

        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unavailable(.noIOPSData)
        }

        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unavailable(.noPowerSources)
        }

        for src in list {
            guard
                let desc = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            let type = desc[kIOPSTypeKey as String] as? String
            guard type == IOPS.batteryType else { continue }

            let voltageMv: Double?
            let currentMa: Double?

            if let r = registrySample, r.millivolts > 0 {
                voltageMv = r.millivolts
                currentMa = r.milliamps
            } else {
                voltageMv = {
                    if let v = double(forKeys: [kIOPSVoltageKey as String, "Voltage"], in: desc), v > 0 {
                        return v
                    }
                    return registryBatteryVoltageMillivoltsCached()
                }()
                /// InstantAmperage в IOPS чаще «мгновенный», чем усреднённый Current.
                currentMa = double(forKeys: [
                    "InstantAmperage",
                    "Current",
                    kIOPSCurrentKey as String,
                    "Amperage"
                ], in: desc)
            }

            guard let vMv = voltageMv, vMv > 0 else { continue }
            guard let currentMa else { continue }

            let volts = vMv / 1000.0
            let amps = currentMa / 1000.0
            let watts = SMCPowerReader.systemTotalPowerWatts() ?? registrySample?.systemPowerWatts ?? abs(volts * amps)

            let state = desc[kIOPSPowerSourceStateKey as String] as? String
            let charging = bool(forKey: kIOPSIsChargingKey as String, in: desc)
                || bool(forKey: "Is Charging", in: desc)
            let flow = batteryFlow(state: state, charging: charging, amps: amps)

            if watts < 0.05 {
                return .unavailable(.zeroCurrent)
            }

            return .watts(watts, flow: flow)
        }

        return .unavailable(.batteryNotFound)
    }

    private static func readAppleSmartBatterySample() -> RegistrySample? {
        guard let match = IOServiceMatching("AppleSmartBattery") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, match)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard
            let vMv = doubleProperty(
                service,
                keys: ["AppleRawBatteryVoltage", "Voltage"]
            ), vMv > 0
        else { return nil }

        guard
            let iMa = doubleProperty(
                service,
                keys: ["InstantAmperage", "Amperage"]
            )
        else { return nil }

        let batteryData = IORegistryEntryCreateCFProperty(
            service,
            "BatteryData" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any]
        let systemPower = batteryData.flatMap { double(forKeys: ["SystemPower"], in: $0) }

        return RegistrySample(millivolts: vMv, milliamps: iMa, systemPowerWatts: systemPower)
    }

    private static func doubleProperty(_ service: io_registry_entry_t, keys: [String]) -> Double? {
        for key in keys {
            guard
                let cf = IORegistryEntryCreateCFProperty(
                    service,
                    key as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue()
            else { continue }
            if let v = normalizeNumeric(cf) { return v }
        }
        return nil
    }

    private static func batteryFlow(state: String?, charging: Bool, amps: Double) -> BatteryFlow {
        if charging {
            return .charging
        }
        if state == IOPS.acPower, abs(amps) < 0.01 {
            return .onACIdle
        }
        return .discharging
    }

    /// IORegistry для напряжения тяжёлый; кэш снижает риск подвисаний при частом опросе.
    private static func registryBatteryVoltageMillivoltsCached() -> Double? {
        voltageCacheLock.lock()
        let now = CFAbsoluteTimeGetCurrent()
        if let v = voltageCachedMv, now - voltageCachedAt < voltageCacheTTL {
            voltageCacheLock.unlock()
            return v
        }
        voltageCacheLock.unlock()

        let fresh = registryBatteryVoltageMillivolts()

        voltageCacheLock.lock()
        if let fresh {
            voltageCachedMv = fresh
            voltageCachedAt = CFAbsoluteTimeGetCurrent()
            voltageCacheLock.unlock()
            return fresh
        }
        let stale = voltageCachedMv
        voltageCacheLock.unlock()
        return stale
    }

    private static func registryBatteryVoltageMillivolts() -> Double? {
        guard let match = IOServiceMatching("AppleSmartBattery") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, match)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        for key in ["AppleRawBatteryVoltage", "Voltage"] {
            guard
                let cf = IORegistryEntryCreateCFProperty(
                    service,
                    key as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue()
            else { continue }
            if let v = cf as? Int, v > 0 { return Double(v) }
            if let v = cf as? Int32, v > 0 { return Double(v) }
            if let n = cf as? NSNumber, n.doubleValue > 0 { return n.doubleValue }
        }
        return nil
    }

    private static func bool(forKey key: String, in desc: [String: Any]) -> Bool {
        if let b = desc[key] as? Bool { return b }
        if let i = desc[key] as? Int { return i != 0 }
        if let n = desc[key] as? NSNumber { return n.intValue != 0 }
        return false
    }

    private static func double(forKeys keys: [String], in desc: [String: Any]) -> Double? {
        for key in keys {
            guard let raw = desc[key] else { continue }
            if let v = normalizeNumeric(raw) { return v }
        }
        return nil
    }

    private static func normalizeNumeric(_ value: Any) -> Double? {
        switch value {
        case let v as Int:
            return Double(v)
        case let v as Int32:
            return Double(v)
        case let v as Int64:
            return Double(v)
        case let v as Double:
            return v
        case let v as UInt64 where v > UInt64(Int64.max):
            return Double(Int64(bitPattern: v))
        case let v as NSNumber:
            let typeChar = String(cString: v.objCType)
            if typeChar.contains("Q"), v.uint64Value > UInt64(Int64.max) {
                return Double(Int64(bitPattern: v.uint64Value))
            }
            return v.doubleValue
        default:
            return nil
        }
    }
}

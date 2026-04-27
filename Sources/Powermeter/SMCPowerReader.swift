import Foundation
import IOKit

enum SMCPowerReader {
    private static let lock = NSLock()
    private static var client: SMCClient?
    private static var lastLoggedSource: String?

    static func systemTotalPowerWatts() -> Double? {
        lock.lock()
        defer { lock.unlock() }

        if client == nil {
            client = SMCClient()
        }

        for key in ["PSTR", "PDTR", "PDMR"] {
            guard let sample = client?.readWatts(key: key), sample > 0 else { continue }
            logSourceOnce("smc:\(key)")
            return sample
        }
        logSourceOnce("smc:nil")
        return nil
    }

    private static func logSourceOnce(_ source: String) {
        guard lastLoggedSource != source else { return }
        lastLoggedSource = source
        PowermeterLog.log("power source \(source)")
    }
}

private final class SMCClient {
    private typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    private struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCParamStruct {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private let connection: io_connect_t

    init?() {
        var iterator: io_iterator_t = 0
        let matchingDictionary = IOServiceMatching("AppleSMC")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        let device = IOIteratorNext(iterator)
        guard device != 0 else { return nil }
        defer { IOObjectRelease(device) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(device, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            return nil
        }
        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    func readWatts(key: String) -> Double? {
        guard let sample = read(key: key) else { return nil }
        guard sample.type == "flt " else { return nil }
        return Self.plausibleFloat(bytes: sample.bytes)
    }

    private func read(key: String) -> (type: String, bytes: [UInt8])? {
        let code = Self.fourCharCode(key)

        var infoInput = SMCParamStruct()
        infoInput.key = code
        infoInput.data8 = 9
        guard let infoOutput = callDriver(input: infoInput), infoOutput.result == 0 else {
            return nil
        }

        var readInput = SMCParamStruct()
        readInput.key = code
        readInput.keyInfo.dataSize = infoOutput.keyInfo.dataSize
        readInput.data8 = 5
        guard let readOutput = callDriver(input: readInput), readOutput.result == 0 else {
            return nil
        }

        let size = min(Int(infoOutput.keyInfo.dataSize), 32)
        let bytes = withUnsafeBytes(of: readOutput.bytes) { buffer in
            Array(buffer.prefix(size))
        }
        return (Self.string(fromFourCharCode: infoOutput.keyInfo.dataType), bytes)
    }

    private func callDriver(input: SMCParamStruct) -> SMCParamStruct? {
        var input = input
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection,
            2,
            &input,
            MemoryLayout<SMCParamStruct>.stride,
            &output,
            &outputSize
        )
        guard result == kIOReturnSuccess else { return nil }
        return output
    }

    private static func decodeWatts(type: String, bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }

        switch type {
        case "sp78":
            return plausibleFixed(bytes: bytes, signed: true, fractionBits: 8)
        case "spa5":
            return plausibleFixed(bytes: bytes, signed: true, fractionBits: 5)
        case "sp96":
            return plausibleFixed(bytes: bytes, signed: true, fractionBits: 6)
        case "fp88":
            return plausibleFixed(bytes: bytes, signed: false, fractionBits: 8)
        case "fpa6":
            return plausibleFixed(bytes: bytes, signed: false, fractionBits: 6)
        case "flt ", "flt":
            return plausibleFloat(bytes: bytes)
        default:
            return plausibleFixed(bytes: bytes, signed: type.hasPrefix("s"), fractionBits: 8)
        }
    }

    private static func plausibleFixed(bytes: [UInt8], signed: Bool, fractionBits: Int) -> Double? {
        let big = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        let little = UInt16(bytes[1]) << 8 | UInt16(bytes[0])
        let divisor = Double(1 << fractionBits)

        let candidates: [Double]
        if signed {
            candidates = [Double(Int16(bitPattern: big)) / divisor, Double(Int16(bitPattern: little)) / divisor]
        } else {
            candidates = [Double(big) / divisor, Double(little) / divisor]
        }

        return candidates
            .filter { $0 > 0.05 && $0 < 300 }
            .max()
    }

    private static func plausibleFloat(bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let big = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        let little = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
        return [Float32(bitPattern: big), Float32(bitPattern: little)]
            .map(Double.init)
            .filter { $0 > 0.05 && $0 < 300 }
            .first
    }

    private static func fourCharCode(_ string: String) -> UInt32 {
        string.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private static func string(fromFourCharCode code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

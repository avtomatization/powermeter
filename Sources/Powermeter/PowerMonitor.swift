import Combine
import Foundation
import SwiftUI

@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var displayWatts: String = ""
    @Published private(set) var detail: String = ""

    private var smoothed: Double?
    private var tickTimer: DispatchSourceTimer?
    private var settingsCancellable: AnyCancellable?

    private var sampleGeneration: UInt64 = 0

    private var sampleInFlight = false
    private var resampleWhenDone = false

    private var sampleTask: Task<Void, Never>?

    private weak var settings: AppSettings?

    private let sampleWaitSeconds: TimeInterval = 2.5

    /// Тики не на main — не пересекаемся с отрисовкой MenuBarExtra и системной строкой меню.
    private static let tickQueue = DispatchQueue(label: "powermeter.menuBarTick", qos: .utility)

    func start(settings: AppSettings) {
        PowermeterLog.clearSession()
        PowermeterLog.log("PowerMonitor.start")
        self.settings = settings
        settingsCancellable?.cancel()
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                PowermeterLog.log("settings changed -> restartTimer")
                self?.restartTimer()
            }
        }
        restartTimer()
    }

    func stop() {
        tickTimer?.cancel()
        tickTimer = nil
        sampleTask?.cancel()
        sampleTask = nil
        sampleGeneration &+= 1
        sampleInFlight = false
        resampleWhenDone = false
        settingsCancellable?.cancel()
        settingsCancellable = nil
    }

    private func restartTimer() {
        tickTimer?.cancel()
        tickTimer = nil
        sampleTask?.cancel()
        sampleTask = nil
        sampleGeneration &+= 1
        sampleInFlight = false
        resampleWhenDone = false

        guard let settings else { return }
        let interval = settings.refreshInterval.seconds
        PowermeterLog.log("restartTimer interval=\(interval)s gen=\(sampleGeneration) precision=\(settings.precision.rawValue)")

        let timer = DispatchSource.makeTimerSource(queue: Self.tickQueue)
        // Меньший leeway — ближе к равномерному опросу, как у «быстрых» индикаторов.
        let leewayMs = max(5, min(80, Int(interval * 1000 * 0.08)))
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(leewayMs))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.scheduleTick()
            }
        }
        timer.resume()
        tickTimer = timer

        scheduleTick()
    }

    private func scheduleTick() {
        guard settings != nil else { return }
        beginSample()
    }

    private func beginSample() {
        guard settings != nil else { return }
        if sampleInFlight {
            resampleWhenDone = true
            PowermeterLog.log("beginSample coalesced (already inFlight)")
            return
        }

        sampleInFlight = true
        sampleGeneration &+= 1
        let token = sampleGeneration
        PowermeterLog.log("beginSample token=\(token) maxWait=\(sampleWaitSeconds)s")

        sampleTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await Self.runSample(maxWait: self.sampleWaitSeconds)
            let label = Self.outcomeLabel(outcome)
            await MainActor.run { [weak self] in
                guard let self else { return }

                self.sampleInFlight = false

                let again = self.resampleWhenDone
                self.resampleWhenDone = false

                let genNow = self.sampleGeneration
                let match = token == genNow
                PowermeterLog.log("sample finished token=\(token) genNow=\(genNow) match=\(match) first=\(label) again=\(again)")

                guard match else {
                    if again {
                        PowermeterLog.log("stale token -> scheduleTick (again)")
                        self.scheduleTick()
                    }
                    return
                }

                guard let settings = self.settings else {
                    if again {
                        self.scheduleTick()
                    }
                    return
                }

                switch outcome {
                case let .sample(s):
                    self.apply(
                        sample: s,
                        alpha: settings.precision.smoothingAlpha,
                        digits: settings.precision.fractionDigits,
                        lang: settings.language
                    )
                case .timedOut:
                    let msg = L10n.string("errors.sample_timeout", language: settings.language)
                    self.detail = msg
                    PowermeterLog.log("UI: timeout detail set")
                }

                if again {
                    PowermeterLog.log("chained scheduleTick after completion")
                    self.scheduleTick()
                }
            }
        }
    }

    private enum SampleOutcome: Sendable {
        case sample(PowerSample)
        case timedOut
    }

    private nonisolated static func runSample(maxWait: TimeInterval) async -> SampleOutcome {
        await withTaskGroup(of: SampleOutcome.self) { group in
            group.addTask(priority: .background) {
                await Task.yield()
                let s = PowerSampler.sample()
                return .sample(s)
            }
            group.addTask {
                let ns = UInt64(maxWait * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                return .timedOut
            }
            let first = await group.next()!
            PowermeterLog.log("runSample race winner: \(Self.outcomeLabel(first))")
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func outcomeLabel(_ o: SampleOutcome) -> String {
        switch o {
        case let .sample(.watts(w, f)):
            return "watts(\(w)W flow=\(String(describing: f)))"
        case let .sample(.unavailable(e)):
            return "unavailable(\(String(describing: e)))"
        case .timedOut:
            return "TIMEOUT"
        }
    }

    private func apply(
        sample: PowerSample,
        alpha: Double,
        digits: Int,
        lang: AppLanguage
    ) {
        switch sample {
        case let .watts(w, flow):
            if let prev = smoothed {
                smoothed = prev + alpha * (w - prev)
            } else {
                smoothed = w
            }
            guard let s = smoothed else { return }
            let fmt = NumberFormatter()
            fmt.minimumFractionDigits = digits
            fmt.maximumFractionDigits = digits
            fmt.locale = lang.locale
            let num = fmt.string(from: NSNumber(value: s)) ?? String(format: "%.\(digits)f", s)
            let unit = L10n.string("unit.watts", language: lang)
            publishDisplay(
                display: "\(num) \(unit)",
                detail: L10n.string(flow.l10nKey, language: lang)
            )

        case let .unavailable(reason):
            smoothed = nil
            publishDisplay(
                display: L10n.string("display.no_value", language: lang),
                detail: L10n.string(reason.l10nKey, language: lang)
            )
        }
    }

    private func publishDisplay(display: String, detail: String) {
        displayWatts = display
        self.detail = detail
        PowermeterLog.log("publishDisplay display=\"\(display)\" detail.len=\(detail.count)")
    }
}

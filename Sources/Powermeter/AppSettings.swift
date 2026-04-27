import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case chineseSimplified = "zh-Hans"
    case french = "fr"
    case spanish = "es"
    case german = "de"

    var id: String { rawValue }

    /// Имя папки `.lproj` (для `zh-Hans` совпадает с идентификатором).
    var bundleFolderName: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var localizationKey: String {
        switch self {
        case .english: return "language.en"
        case .russian: return "language.ru"
        case .chineseSimplified: return "language.zh_hans"
        case .french: return "language.fr"
        case .spanish: return "language.es"
        case .german: return "language.de"
        }
    }

    static func resolveDefault() -> AppLanguage {
        let code = Locale.preferredLanguages.first ?? "en"
        if code.hasPrefix("ru") { return .russian }
        if code.hasPrefix("zh") { return .chineseSimplified }
        if code.hasPrefix("fr") { return .french }
        if code.hasPrefix("es") { return .spanish }
        if code.hasPrefix("de") { return .german }
        return .english
    }
}

enum RefreshInterval: String, CaseIterable, Identifiable {
    case s1
    case s2
    case s5
    case s10

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .s1: return 1
        case .s2: return 2
        case .s5: return 5
        case .s10: return 10
        }
    }

    var localizationKey: String { "settings.interval.\(rawValue)" }

    /// Миграция старых значений из UserDefaults (русские подписи).
    static func migrating(from stored: String) -> RefreshInterval? {
        if let v = RefreshInterval(rawValue: stored) { return v }
        switch stored {
        case "s0_25", "s0_5", "0,25 с", "0.25 s", "0,5 с", "0.5 s": return .s1
        case "1 с": return .s1
        case "2 с": return .s2
        case "5 с": return .s5
        case "10 с": return .s10
        default: return nil
        }
    }
}

enum MeasurementPrecision: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var localizationKey: String { "settings.precision.\(rawValue)" }

    /// Сглаживание EMA: больше α — быстрее реакция.
    var smoothingAlpha: Double {
        switch self {
        case .low: return 0.12
        case .medium: return 0.55
        /// Без сглаживания: иначе цифра «залипает» рядом с другими индикаторами и кажется зависшей.
        case .high: return 1.0
        }
    }

    var fractionDigits: Int {
        switch self {
        case .low: return 0
        case .medium: return 2
        case .high: return 3
        }
    }

    static func migrating(from stored: String) -> MeasurementPrecision? {
        if let v = MeasurementPrecision(rawValue: stored) { return v }
        switch stored {
        case "Низкая": return .low
        case "Средняя": return .medium
        case "Высокая": return .high
        default: return nil
        }
    }
}

final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let language = "appLanguage"
        static let refresh = "refreshInterval"
        static let precision = "measurementPrecision"
        static let liveRefreshMigration = "liveRefreshMigrationV1"
        static let realIntervalMigration = "realIntervalMigrationV2"
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Keys.refresh) }
    }

    @Published var precision: MeasurementPrecision {
        didSet { defaults.set(precision.rawValue, forKey: Keys.precision) }
    }

    init() {
        if let raw = defaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            language = AppLanguage.resolveDefault()
        }

        if let s = defaults.string(forKey: Keys.refresh),
           let r = RefreshInterval.migrating(from: s) {
            refreshInterval = r
        } else {
            refreshInterval = .s1
        }

        if let s = defaults.string(forKey: Keys.precision),
           let p = MeasurementPrecision.migrating(from: s) {
            precision = p
        } else {
            precision = .high
        }

        if !defaults.bool(forKey: Keys.liveRefreshMigration) {
            refreshInterval = .s1
            precision = .high
            defaults.set(true, forKey: Keys.liveRefreshMigration)
        }

        if !defaults.bool(forKey: Keys.realIntervalMigration) {
            if defaults.string(forKey: Keys.refresh) == "s0_25"
                || defaults.string(forKey: Keys.refresh) == "s0_5" {
                refreshInterval = .s1
            }
            defaults.set(true, forKey: Keys.realIntervalMigration)
        }
    }
}

import SwiftUI

/// Метка в трее живёт в отдельном поддереве с собственным `@StateObject` монитора.
/// Если держать `PowerMonitor` в `App`, каждый тик ватт пересобирает `MenuBarExtra` и **сбрасывает** открытые подменю.
struct MenuBarTrayContainer: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var monitor = PowerMonitor()

    var body: some View {
        MenuBarTrayLabel(monitor: monitor, settings: settings)
            .task {
                monitor.start(settings: settings)
            }
    }
}

/// Содержимое выпадающего меню зависит **только** от настроек, чтобы тики `PowerMonitor`
/// не пересобирали иерархию меню и не сбрасывали подменю (точность / язык) при наведении.
struct MenuBarDropdownContent: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Group {
            Text(L10n.string("menu.help_detail", language: settings.language))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Menu(L10n.string("menu.settings", language: settings.language)) {
                Menu(L10n.string("menu.language", language: settings.language)) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            settings.language = lang
                        } label: {
                            HStack {
                                Text(L10n.string(lang.localizationKey, language: settings.language))
                                if settings.language == lang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Menu(L10n.string("menu.refresh_interval", language: settings.language)) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Button {
                            settings.refreshInterval = interval
                        } label: {
                            HStack {
                                Text(L10n.string(interval.localizationKey, language: settings.language))
                                if settings.refreshInterval == interval {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Menu(L10n.string("menu.precision", language: settings.language)) {
                    ForEach(MeasurementPrecision.allCases) { prec in
                        Button {
                            settings.precision = prec
                        } label: {
                            HStack {
                                Text(L10n.string(prec.localizationKey, language: settings.language))
                                if settings.precision == prec {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Toggle(isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                )) {
                    Text(L10n.string("menu.launch_at_login", language: settings.language))
                }
            }

            Divider()

            Button(L10n.string("menu.quit", language: settings.language)) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .environment(\.locale, settings.language.locale)
    }
}

/// Только строка меню: высокочастотные обновления изолированы здесь.
struct MenuBarTrayLabel: View {
    @ObservedObject var monitor: PowerMonitor
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
            Text(
                monitor.displayWatts.isEmpty
                    ? L10n.string("display.no_value", language: settings.language)
                    : monitor.displayWatts
            )
            .monospacedDigit()
        }
        .accessibilityLabel(L10n.string("a11y.power", language: settings.language))
        .help(monitor.detail)
    }
}

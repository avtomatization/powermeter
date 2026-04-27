import Foundation

enum L10n {
    static func string(_ key: String, language: AppLanguage) -> String {
        let module = PowermeterResourceBundle.shared
        guard
            let path = module.path(forResource: language.bundleFolderName, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(
                key,
                tableName: nil,
                bundle: module,
                value: key,
                comment: ""
            )
        }
        return NSLocalizedString(
            key,
            tableName: nil,
            bundle: bundle,
            value: key,
            comment: ""
        )
    }
}

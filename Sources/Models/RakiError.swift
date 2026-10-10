import Foundation

enum RakiError: LocalizedError {
    case network(String)
    case checksum
    case unzip
    case exists(String)
    case notFound
    case permission
    case invalidCatalog
    case invalidName
    case invalidDestination
    case unsupportedPlist
    case other(String)

    var errorDescription: String? {
        switch self {
        case .network(let m): return L("error.network", m)
        case .checksum: return L("error.checksum")
        case .unzip: return L("error.unzip")
        case .exists(let n): return L("error.exists", n)
        case .notFound: return L("error.not_found")
        case .permission: return L("error.permission")
        case .invalidCatalog: return L("error.invalid_catalog")
        case .invalidName: return L("error.invalid_name")
        case .invalidDestination: return L("error.invalid_destination")
        case .unsupportedPlist: return L("error.unsupported_plist")
        case .other(let m): return L("error.other", m)
        }
    }

    static func wrap(_ error: Error) -> RakiError {
        if let e = error as? RakiError { return e }
        if error is DecodingError { return .invalidCatalog }
        if let e = error as? URLError { return .network(e.localizedDescription) }
        if let e = error as? CocoaError {
            switch e.code {
            case .fileNoSuchFile, .fileReadNoSuchFile: return .notFound
            case .fileReadNoPermission, .fileWriteNoPermission: return .permission
            case .fileWriteFileExists: return .exists(e.localizedDescription)
            default: break
            }
        }
        if let e = error as? POSIXError, e.code == .EACCES || e.code == .EPERM { return .permission }
        return .other(error.localizedDescription)
    }
}

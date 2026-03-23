import Foundation

enum DataLayerError: LocalizedError {
    case notConfigured(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let target):
            return "\(target) is not configured yet."
        case .notImplemented(let target):
            return "\(target) is not implemented yet."
        }
    }
}

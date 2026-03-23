import Foundation

struct GetRoutePolylineUseCase {
    let repository: DirectionsRepository

    func callAsFunction(originLat: Double, originLng: Double, destLat: Double, destLng: Double) async throws -> RoutePolyline {
        try await repository.getRoute(originLat: originLat, originLng: originLng, destLat: destLat, destLng: destLng)
    }
}

extension UserMode {
    var driverServiceType: ServiceType? {
        switch self {
        case .partnerTaxi: return .taxi
        case .partnerDaeri: return .daeri
        case .general, .partnerStore: return nil
        }
    }
}

enum DomainError: LocalizedError {
    case invalidMode
    case notFound(String)
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .invalidMode:
            return "Invalid mode."
        case .notFound(let value):
            return "Not found: \(value)"
        case .unauthenticated:
            return "User is not authenticated."
        }
    }
}

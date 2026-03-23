import Foundation

struct SearchPlacesUseCase {
    let repository: PlaceRepository

    func callAsFunction(
        query: String,
        page: Int = 1,
        size: Int = 15,
        centerLng: Double? = nil,
        centerLat: Double? = nil,
        radiusM: Int? = nil
    ) async throws -> [Place] {
        try await repository.searchPlaces(
            query: query,
            page: page,
            size: size,
            centerLng: centerLng,
            centerLat: centerLat,
            radiusM: radiusM
        )
    }
}

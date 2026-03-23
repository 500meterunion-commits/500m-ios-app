import Foundation

private struct KakaoKeywordResponse: Decodable {
    let documents: [KakaoPlaceDTO]
}

private struct KakaoPlaceDTO: Decodable {
    let id: String
    let placeName: String
    let addressName: String
    let roadAddressName: String
    let placeURL: String
    let x: String
    let y: String

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
        case placeURL = "place_url"
        case x
        case y
    }
}

final class PlaceRepositoryLive: PlaceRepository {
    private let environment: AppEnvironment

    init(environment: AppEnvironment = .shared) {
        self.environment = environment
    }

    func searchPlaces(
        query: String,
        page: Int,
        size: Int,
        centerLng: Double?,
        centerLat: Double?,
        radiusM: Int?
    ) async throws -> [Place] {
        var components = URLComponents(string: "https://dapi.kakao.com/v2/local/search/keyword.json")!
        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        if let centerLng { queryItems.append(URLQueryItem(name: "x", value: "\(centerLng)")) }
        if let centerLat { queryItems.append(URLQueryItem(name: "y", value: "\(centerLat)")) }
        if let radiusM { queryItems.append(URLQueryItem(name: "radius", value: "\(radiusM)")) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("KakaoAK \(environment.kakaoRestAPIKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(KakaoKeywordResponse.self, from: data)
        return response.documents.map {
            Place(
                id: $0.id,
                name: $0.placeName,
                address: $0.roadAddressName.isEmpty ? $0.addressName : $0.roadAddressName,
                placeURL: $0.placeURL,
                longitude: Double($0.x),
                latitude: Double($0.y)
            )
        }
    }
}

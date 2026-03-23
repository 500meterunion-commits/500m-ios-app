import Foundation

private struct KakaoDirectionsResponse: Decodable {
    let routes: [KakaoRoute]
}

private struct KakaoRoute: Decodable {
    let summary: KakaoRouteSummary?
    let sections: [KakaoSection]
}

private struct KakaoRouteSummary: Decodable {
    let distance: Int?
    let duration: Int?
}

private struct KakaoSection: Decodable {
    let roads: [KakaoRoad]
}

private struct KakaoRoad: Decodable {
    let vertexes: [Double]
}

final class DirectionsRepositoryLive: DirectionsRepository {
    private let environment: AppEnvironment

    init(environment: AppEnvironment = .shared) {
        self.environment = environment
    }

    func getRoute(originLat: Double, originLng: Double, destLat: Double, destLng: Double) async throws -> RoutePolyline {
        var components = URLComponents(string: "https://apis-navi.kakaomobility.com/v1/directions")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: "\(originLng),\(originLat)"),
            URLQueryItem(name: "destination", value: "\(destLng),\(destLat)"),
            URLQueryItem(name: "priority", value: "RECOMMEND"),
            URLQueryItem(name: "summary", value: "false")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("KakaoAK \(environment.kakaoRestAPIKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(KakaoDirectionsResponse.self, from: data)
        guard let route = response.routes.first else {
            return RoutePolyline(points: [], distanceM: 0, durationSec: 0)
        }

        let points = route.sections
            .flatMap(\.roads)
            .flatMap(\.vertexes)
            .chunked(into: 2)
            .compactMap { chunk -> LatLng? in
                guard chunk.count == 2 else { return nil }
                return LatLng(lat: chunk[1], lng: chunk[0])
            }

        return RoutePolyline(
            points: points,
            distanceM: route.summary?.distance ?? 0,
            durationSec: route.summary?.duration ?? 0
        )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

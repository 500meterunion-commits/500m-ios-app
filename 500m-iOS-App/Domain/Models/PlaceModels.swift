import Foundation

struct Place: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let address: String
    let placeURL: String
    let longitude: Double?
    let latitude: Double?
}

import Foundation

private enum GeohashConstants {
    static let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")
}

final class GeohashEncoderLive: GeohashEncoder {
    func encodePrefix(lat: Double, lng: Double, length: Int = 7) -> String {
        var latitudeRange = (-90.0, 90.0)
        var longitudeRange = (-180.0, 180.0)
        var hash = ""
        var bit = 0
        var characterValue = 0
        var isEvenBit = true

        while hash.count < length {
            if isEvenBit {
                let midpoint = (longitudeRange.0 + longitudeRange.1) / 2
                if lng >= midpoint {
                    characterValue = (characterValue << 1) | 1
                    longitudeRange.0 = midpoint
                } else {
                    characterValue <<= 1
                    longitudeRange.1 = midpoint
                }
            } else {
                let midpoint = (latitudeRange.0 + latitudeRange.1) / 2
                if lat >= midpoint {
                    characterValue = (characterValue << 1) | 1
                    latitudeRange.0 = midpoint
                } else {
                    characterValue <<= 1
                    latitudeRange.1 = midpoint
                }
            }

            isEvenBit.toggle()
            bit += 1

            if bit == 5 {
                hash.append(GeohashConstants.alphabet[characterValue])
                bit = 0
                characterValue = 0
            }
        }

        return hash
    }
}

final class CellCalculatorLive: CellCalculator {
    private let geohashEncoder: GeohashEncoder

    init(geohashEncoder: GeohashEncoder = GeohashEncoderLive()) {
        self.geohashEncoder = geohashEncoder
    }

    func nearbyCells(lat: Double, lng: Double, radiusM: Double) -> Set<String> {
        let precision = 7
        let cellHeight = 153.0
        let cellWidth = max(153.0 * cos(lat * .pi / 180), 20.0)

        let latSteps = Int(ceil(radiusM / cellHeight)) + 1
        let lngSteps = Int(ceil(radiusM / cellWidth)) + 1

        var result = Set<String>()
        for dy in (-latSteps)...latSteps {
            for dx in (-lngSteps)...lngSteps {
                let pointLat = lat + metersToLatitude(Double(dy) * cellHeight)
                let pointLng = lng + metersToLongitude(Double(dx) * cellWidth, at: lat)
                result.insert(geohashEncoder.encodePrefix(lat: pointLat, lng: pointLng, length: precision))
            }
        }

        return result
    }

    private func metersToLatitude(_ meters: Double) -> Double {
        meters / 111_320.0
    }

    private func metersToLongitude(_ meters: Double, at latitude: Double) -> Double {
        let metersPerDegree = max(111_320.0 * cos(latitude * .pi / 180), 0.1)
        return meters / metersPerDegree
    }
}

import FirebaseFirestore
import Foundation

enum FirestoreMappers {
    static func timestampMillis(_ value: Any?) -> Int64 {
        if let timestamp = value as? Timestamp {
            return Int64(timestamp.dateValue().timeIntervalSince1970 * 1000)
        }
        if let date = value as? Date {
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        if let number = value as? NSNumber {
            return number.int64Value
        }
        return 0
    }

    static func userProfile(from data: [String: Any], id: String) -> UserProfile {
        UserProfile(
            id: id,
            displayName: data["displayName"] as? String,
            marketId: data["marketId"] as? String,
            mode: UserMode(rawValue: data["mode"] as? String ?? "") ?? .general,
            taxiAccess: ApprovalStatus(rawValue: data["taxiAccess"] as? String ?? "") ?? .none,
            daeriAccess: ApprovalStatus(rawValue: data["daeriAccess"] as? String ?? "") ?? .none,
            storeAccess: ApprovalStatus(rawValue: data["storeAccess"] as? String ?? "") ?? .none,
            taxiPartnerId: data["taxiPartnerId"] as? String,
            daeriPartnerId: data["daeriPartnerId"] as? String,
            storePartnerId: data["storePartnerId"] as? String,
            userProfileURL: data["userProfileUrl"] as? String ?? data["userProfileURL"] as? String,
            agreedNormalTerms: data["agreedNormalTerms"] as? [String: Bool],
            agreedPartnerTerms: data["agreedPartnerTerms"] as? [String: Bool]
        )
    }

    static func userProfileData(_ profile: UserProfile) -> [String: Any] {
        [
            "uid": profile.id,
            "displayName": profile.displayName as Any,
            "marketId": profile.marketId as Any,
            "mode": profile.mode.rawValue,
            "taxiAccess": profile.taxiAccess.rawValue,
            "daeriAccess": profile.daeriAccess.rawValue,
            "storeAccess": profile.storeAccess.rawValue,
            "taxiPartnerId": profile.taxiPartnerId as Any,
            "daeriPartnerId": profile.daeriPartnerId as Any,
            "storePartnerId": profile.storePartnerId as Any,
            "userProfileUrl": profile.userProfileURL as Any,
            "agreedNormalTerms": profile.agreedNormalTerms as Any,
            "agreedPartnerTerms": profile.agreedPartnerTerms as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    static func matchRequest(from data: [String: Any], id: String) -> MatchRequest {
        MatchRequest(
            requestId: id,
            marketId: data["marketId"] as? String ?? "",
            serviceType: ServiceType(rawValue: data["serviceType"] as? String ?? "") ?? .taxi,
            userId: data["userId"] as? String ?? "",
            driverId: data["driverId"] as? String ?? "",
            pickupLat: data["pickupLat"] as? Double ?? 0,
            pickupLng: data["pickupLng"] as? Double ?? 0,
            createdAt: timestampMillis(data["createdAt"]),
            status: MatchRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
            memo: data["memo"] as? String
        )
    }

    static func taxiDriver(from data: [String: Any], id: String) -> TaxiDriver {
        TaxiDriver(
            driverId: id,
            marketId: data["marketId"] as? String,
            name: data["name"] as? String,
            birthDate: data["birthDate"] as? String,
            phoneMasked: data["phoneMasked"] as? String,
            photoURL: data["photoUrl"] as? String,
            carNumber: data["carNumber"] as? String,
            memo: data["memo"] as? String,
            insuranceShared: data["insuranceShared"] as? Bool
        )
    }

    static func daeriDriver(from data: [String: Any], id: String) -> DaeriDriver {
        DaeriDriver(
            driverId: id,
            marketId: data["marketId"] as? String,
            name: data["name"] as? String,
            birthDate: data["birthDate"] as? String,
            phoneMasked: data["phoneMasked"] as? String,
            photoURL: data["photoUrl"] as? String,
            insuranceSubscribed: data["insuranceSubscribed"] as? Bool,
            memo: data["memo"] as? String,
            insuranceShared: data["insuranceShared"] as? Bool
        )
    }

    static func store(from data: [String: Any], id: String) -> Store {
        Store(
            storeId: id,
            marketId: data["marketId"] as? String,
            storeName: data["storeName"] as? String,
            kakaoStoreRegId: data["kakaoStoreRegId"] as? String,
            ownerBirthDate: data["ownerBirthDate"] as? String,
            ownerName: data["ownerName"] as? String,
            ownerPhone: data["ownerPhone"] as? String ?? data["ownerContact"] as? String,
            promoImageURL: data["promoImageUrl"] as? String,
            promoText: data["promoText"] as? String,
            insuranceShared: data["insuranceShared"] as? Bool,
            category: data["category"] as? String,
            lat: data["lat"] as? Double,
            lng: data["lng"] as? Double
        )
    }

    static func partnerApplication(from data: [String: Any], id: String) -> PartnerApplication {
        let payload = (data["payload"] as? [String: Any])?.reduce(into: [String: String]()) { partial, entry in
            partial[entry.key] = String(describing: entry.value)
        } ?? [:]

        return PartnerApplication(
            applicationId: id,
            uid: data["uid"] as? String ?? "",
            mode: UserMode(rawValue: data["mode"] as? String ?? "") ?? .general,
            marketId: data["marketId"] as? String ?? "",
            status: PartnerApplicationStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
            partnerId: data["partnerId"] as? String,
            payload: payload,
            attachments: data["attachments"] as? [String] ?? [],
            createdAt: timestampMillis(data["createdAt"]),
            updatedAt: timestampMillis(data["updatedAt"]),
            reviewedAt: timestampMillis(data["reviewedAt"]),
            reviewedBy: data["reviewedBy"] as? String,
            rejectReason: data["rejectReason"] as? String
        )
    }

    static func userHistoryItem(from data: [String: Any], id: String) -> UserHistoryItem {
        UserHistoryItem(
            requestId: id,
            service: ServiceType(rawValue: data["service"] as? String ?? "") ?? .taxi,
            status: MatchRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
            marketId: data["marketId"] as? String ?? "",
            createdAtMs: timestampMillis(data["createdAtMs"] ?? data["createdAt"]),
            expireAtMs: timestampMillis(data["expireAtMs"] ?? data["expireAt"]),
            providerId: data["providerId"] as? String,
            providerName: data["providerName"] as? String,
            providerProfileImageURL: data["providerProfileImageUrl"] as? String,
            pickupLat: data["pickupLat"] as? Double,
            pickupLng: data["pickupLng"] as? Double
        )
    }
}

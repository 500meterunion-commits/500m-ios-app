import FirebaseFirestore
import FirebaseStorage
import Foundation

final class PartnerRepositoryLive: PartnerRepository {
    private let firestore: Firestore
    private let storage: Storage

    init(
        firestore: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage()
    ) {
        self.firestore = firestore
        self.storage = storage
    }

    func getTaxiDriver(driverId: String) async throws -> TaxiDriver? {
        let snapshot = try await FirebaseAsync.getDocument(firestore.collection("taxiDrivers").document(driverId))
        guard let data = snapshot.data() else { return nil }
        return FirestoreMappers.taxiDriver(from: data, id: driverId)
    }

    func getDaeriDriver(driverId: String) async throws -> DaeriDriver? {
        let snapshot = try await FirebaseAsync.getDocument(firestore.collection("daeriDrivers").document(driverId))
        guard let data = snapshot.data() else { return nil }
        return FirestoreMappers.daeriDriver(from: data, id: driverId)
    }

    func getStore(storeId: String) async throws -> Store? {
        let snapshot = try await FirebaseAsync.getDocument(firestore.collection("stores").document(storeId))
        guard let data = snapshot.data() else { return nil }
        return FirestoreMappers.store(from: data, id: storeId)
    }

    func upsertTaxiDriver(_ driver: TaxiDriver) async throws {
        try await FirebaseAsync.setData(
            firestore.collection("taxiDrivers").document(driver.id),
            data: [
                "driverId": driver.id,
                "marketId": driver.marketId as Any,
                "name": driver.name as Any,
                "birthDate": driver.birthDate as Any,
                "phoneMasked": driver.phoneMasked as Any,
                "photoUrl": driver.photoURL as Any,
                "carNumber": driver.carNumber as Any,
                "memo": driver.memo as Any,
                "insuranceShared": driver.insuranceShared as Any
            ],
            merge: true
        )
    }

    func upsertDaeriDriver(_ driver: DaeriDriver) async throws {
        try await FirebaseAsync.setData(
            firestore.collection("daeriDrivers").document(driver.id),
            data: [
                "driverId": driver.id,
                "marketId": driver.marketId as Any,
                "name": driver.name as Any,
                "birthDate": driver.birthDate as Any,
                "phoneMasked": driver.phoneMasked as Any,
                "photoUrl": driver.photoURL as Any,
                "insuranceSubscribed": driver.insuranceSubscribed as Any,
                "memo": driver.memo as Any,
                "insuranceShared": driver.insuranceShared as Any
            ],
            merge: true
        )
    }

    func upsertStore(_ store: Store) async throws {
        try await FirebaseAsync.setData(
            firestore.collection("stores").document(store.id),
            data: [
                "storeId": store.id,
                "marketId": store.marketId as Any,
                "storeName": store.storeName as Any,
                "kakaoStoreRegId": store.kakaoStoreRegId as Any,
                "ownerBirthDate": store.ownerBirthDate as Any,
                "ownerName": store.ownerName as Any,
                "ownerPhone": store.ownerPhone as Any,
                "promoImageUrl": store.promoImageURL as Any,
                "promoText": store.promoText as Any,
                "insuranceShared": store.insuranceShared as Any,
                "category": store.category as Any,
                "lat": store.lat as Any,
                "lng": store.lng as Any
            ],
            merge: true
        )
    }

    func uploadStorePromoImage(storeId: String, imageData: Data) async throws -> String {
        try await uploadJPEG(path: "store_promos/\(storeId).jpg", data: imageData)
    }

    func uploadTaxiDriverPhoto(driverId: String, imageData: Data) async throws -> String {
        try await uploadJPEG(path: "partner_photos/taxi/\(driverId).jpg", data: imageData)
    }

    func uploadDaeriDriverPhoto(driverId: String, imageData: Data) async throws -> String {
        try await uploadJPEG(path: "partner_photos/daeri/\(driverId).jpg", data: imageData)
    }

    private func uploadJPEG(path: String, data: Data) async throws -> String {
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        return try await FirebaseAsync.downloadURL(afterUploading: data, to: ref, metadata: metadata).absoluteString
    }
}

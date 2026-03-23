import Combine
import Foundation

struct ObserveUserHistoryUseCase {
    let repository: UserHistoryRepository

    func callAsFunction(uid: String, service: ServiceType?) -> AnyPublisher<[UserHistoryItem], Never> {
        repository.observeHistory(uid: uid, service: service)
    }
}

struct UploadPartnerDocumentUseCase {
    let repository: PartnerApplicationRepository

    func callAsFunction(uid: String, data: Data, ext: String) async throws -> String {
        try await repository.uploadPartnerDocument(uid: uid, data: data, ext: ext)
    }
}

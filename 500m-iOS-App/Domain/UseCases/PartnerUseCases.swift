import Foundation

enum PartnerSwitchDecision: Equatable {
    case openApply(UserMode)
    case showPending(UserMode)
    case showRejected(UserMode, String?)
    case switchToPartner(UserMode)
}

struct GetPartnerInfoUseCase {
    let repository: PartnerRepository

    func callAsFunction(partnerId: String, mode: UserMode) async throws -> PartnerInfo? {
        switch mode {
        case .partnerTaxi:
            return try await repository.getTaxiDriver(driverId: partnerId).map(PartnerInfo.taxi)
        case .partnerDaeri:
            return try await repository.getDaeriDriver(driverId: partnerId).map(PartnerInfo.daeri)
        case .partnerStore:
            return try await repository.getStore(storeId: partnerId).map(PartnerInfo.store)
        case .general:
            return nil
        }
    }
}

struct SubmitPartnerApplicationUseCase {
    let applicationRepository: PartnerApplicationRepository
    let authRepository: AuthRepository

    func callAsFunction(mode: UserMode, marketId: String, payload: [String: String], attachments: [String]) async throws {
        guard mode != .general else { throw DomainError.invalidMode }
        let uid = try await authRepository.requireUID()
        let appID = "\(uid)_\(mode.rawValue)"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let existing = try await applicationRepository.getApplication(applicationId: appID)

        let application = PartnerApplication(
            applicationId: appID,
            uid: uid,
            mode: mode,
            marketId: marketId,
            status: .pending,
            partnerId: existing?.partnerId,
            payload: payload,
            attachments: attachments,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            reviewedAt: existing?.reviewedAt ?? 0,
            reviewedBy: existing?.reviewedBy,
            rejectReason: existing?.rejectReason
        )
        try await applicationRepository.upsertApplication(application)
    }
}

struct DecidePartnerSwitchUseCase {
    let userRepository: UserRepository
    let applicationRepository: PartnerApplicationRepository

    func callAsFunction(uid: String, mode: UserMode) async throws -> PartnerSwitchDecision {
        guard let profile = try await userRepository.getUserProfile(uid: uid) else {
            return .openApply(mode)
        }

        let access: ApprovalStatus
        let partnerID: String?
        switch mode {
        case .partnerTaxi:
            access = profile.taxiAccess
            partnerID = profile.taxiPartnerId
        case .partnerDaeri:
            access = profile.daeriAccess
            partnerID = profile.daeriPartnerId
        case .partnerStore:
            access = profile.storeAccess
            partnerID = profile.storePartnerId
        case .general:
            return .switchToPartner(.general)
        }

        if let partnerID, !partnerID.isEmpty {
            return .switchToPartner(mode)
        }

        switch access {
        case .approved:
            return .switchToPartner(mode)
        case .pending:
            return .showPending(mode)
        case .rejected:
            let app = try await applicationRepository.getApplication(applicationId: "\(uid)_\(mode.rawValue)")
            return .showRejected(mode, app?.rejectReason)
        case .none:
            return .openApply(mode)
        }
    }
}

import Foundation

extension UserMode {
    var titleForApply: String {
        switch self {
        case .partnerTaxi: return "택시 파트너 신청"
        case .partnerDaeri: return "대리 파트너 신청"
        case .partnerStore: return "자영업 파트너 신청"
        case .general: return "파트너 신청"
        }
    }
}

extension MatchRequestStatus {
    var koreanText: String {
        switch self {
        case .pending: return "요청 중"
        case .accepted: return "매칭 완료"
        case .inProgress: return "운행 중"
        case .completed: return "운행 완료"
        case .rejected: return "거절됨"
        case .canceled: return "취소됨"
        case .expired: return "만료됨"
        }
    }
}

extension PartnerApplicationStatus {
    var koreanText: String {
        switch self {
        case .pending: return "승인 대기"
        case .approved: return "승인 완료"
        case .rejected: return "승인 거절"
        case .canceled: return "취소됨"
        }
    }
}

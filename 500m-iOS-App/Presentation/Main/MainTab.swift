import Foundation

enum MainTab: String, CaseIterable, Hashable {
    case store
    case taxi
    case daeri
    case mypage

    var title: String {
        switch self {
        case .store: return "우리동네"
        case .taxi: return "택시부르기"
        case .daeri: return "대리부르기"
        case .mypage: return "마이페이지"
        }
    }

    var systemImage: String {
        switch self {
        case .store: return "storefront"
        case .taxi: return "car.fill"
        case .daeri: return "steeringwheel"
        case .mypage: return "person.crop.circle"
        }
    }

    var assetName: String {
        switch self {
        case .store: return "tab_store"
        case .taxi: return "tab_taxi"
        case .daeri: return "tab_daeri"
        case .mypage: return "tab_my"
        }
    }
}

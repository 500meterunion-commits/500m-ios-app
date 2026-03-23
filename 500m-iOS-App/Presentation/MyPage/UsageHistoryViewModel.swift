import Combine
import FirebaseAuth
import Foundation

@MainActor
final class UsageHistoryViewModel: ObservableObject {
    @Published var selectedService: ServiceType = .taxi
    @Published private(set) var history: [UserHistoryItem] = []

    private var container: AppContainer?
    private var cancellables = Set<AnyCancellable>()
    private var historyCancellable: AnyCancellable?

    init(container: AppContainer? = nil) {
        self.container = container
        bindSelection()
    }

    func configure(container: AppContainer) {
        if self.container == nil {
            self.container = container
        }
        bindHistory(service: selectedService)
    }

    private func bindSelection() {
        $selectedService
            .sink { [weak self] service in
                self?.bindHistory(service: service)
            }
            .store(in: &cancellables)
    }

    private func bindHistory(service: ServiceType) {
        guard let container else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            history = []
            return
        }

        historyCancellable = container.observeUserHistory(uid: uid, service: service)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.history = items.sorted { $0.createdAtMs > $1.createdAtMs }
            }
    }
}

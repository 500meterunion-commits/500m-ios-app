import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading(String)
        case success
        case failure(String)
    }

    @Published private(set) var state: State = .idle

    private var container: AppContainer?

    init(container: AppContainer? = nil) {
        self.container = container
    }

    func configure(container: AppContainer) {
        if self.container == nil {
            self.container = container
        }
    }

    func signInWithGoogle() {
        Task {
            state = .loading("Google 로그인 중")
            do {
                guard let container = self.container else {
                    throw DomainError.unauthenticated
                }
                _ = try await container.signInWithGoogle()
                state = .success
            } catch {
                state = .failure(error.localizedDescription)
            }
        }
    }

    func signInWithKakao() {
        Task {
            state = .loading("Kakao 로그인 중")
            do {
                guard let container = self.container else {
                    throw DomainError.unauthenticated
                }
                _ = try await container.signInWithKakao()
                state = .success
            } catch {
                state = .failure(error.localizedDescription)
            }
        }
    }

    func clearError() {
        if case .failure = state {
            state = .idle
        }
    }
}

import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AppSessionStore: ObservableObject {
    private static let minimumSplashDuration: TimeInterval = 3.0

    enum Phase: Equatable {
        case launching
        case signedOut
        case needsTerms(UserProfile)
        case signedIn(UserProfile)
    }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var isBusy = false
    @Published var alertMessage: String?

    let container: AppContainer

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var profileCancellable: AnyCancellable?
    private let launchStartedAt = Date()

    init(container: AppContainer) {
        self.container = container
        bindProfileCache()
        bindAuthState()
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func refreshProfile() {
        Task {
            await reloadCurrentUser()
        }
    }

    func applyNormalTerms(service: Bool, location: Bool) {
        Task {
            await updateNormalTerms(service: service, location: location)
        }
    }

    func signOutToLogin() {
        Task {
            do {
                try await container.signOut()
            } catch {
                alertMessage = error.localizedDescription
            }
            await transition(to: .signedOut)
        }
    }

    private func bindAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor [weak self] in
                await self?.reloadCurrentUser()
            }
        }

        Task {
            await reloadCurrentUser()
        }
    }

    private func bindProfileCache() {
        profileCancellable = container.observeCachedUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard
                    let self,
                    let profile,
                    Auth.auth().currentUser != nil
                else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let nextPhase: Phase = self.hasRequiredTerms(profile) ? .signedIn(profile) : .needsTerms(profile)
                    await self.transition(to: nextPhase)
                }
            }
    }

    private func reloadCurrentUser() async {
        guard let user = Auth.auth().currentUser else {
            await transition(to: .signedOut)
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let profile = try await container.syncAndGetUserProfile(
                uid: user.uid,
                displayName: user.displayName,
                photoURL: user.photoURL?.absoluteString
            )
            let nextPhase: Phase = hasRequiredTerms(profile) ? .signedIn(profile) : .needsTerms(profile)
            await transition(to: nextPhase)
        } catch {
            alertMessage = error.localizedDescription
            await transition(to: .signedOut)
        }
    }

    private func updateNormalTerms(service: Bool, location: Bool) async {
        guard case let .needsTerms(profile) = phase else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            let updated = try await container.updateUserProfile(
                uid: profile.id,
                patch: UserProfilePatch(
                    agreedNormalTerms: [
                        "terms_service": service,
                        "terms_location": location,
                    ]
                )
            )
            phase = .signedIn(updated)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func hasRequiredTerms(_ profile: UserProfile) -> Bool {
        profile.agreedNormalTerms?["terms_service"] == true &&
        profile.agreedNormalTerms?["terms_location"] == true
    }

    private func transition(to nextPhase: Phase) async {
        if case .launching = phase {
            let elapsed = Date().timeIntervalSince(launchStartedAt)
            let remaining = max(0, Self.minimumSplashDuration - elapsed)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
        }
        phase = nextPhase
    }
}

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: AppSessionStore

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                SplashView()
            case .signedOut:
                LoginView()
            case let .needsTerms(profile):
                TermsAgreementView(profile: profile)
            case let .signedIn(profile):
                MainShellView(profile: profile)
            }
        }
        .alert("안내", isPresented: Binding(
            get: { session.alertMessage != nil },
            set: { newValue in
                if !newValue { session.alertMessage = nil }
            }
        ), actions: {
            Button("확인") { session.alertMessage = nil }
        }, message: {
            Text(session.alertMessage ?? "")
        })
    }
}

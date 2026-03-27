import FirebaseCore
import SwiftUI

@main
struct _00m_iOS_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container: AppContainer
    @StateObject private var session: AppSessionStore
    @StateObject private var deepLinkCenter = AppDeepLinkCenter.shared

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let container = AppContainer()
        _container = StateObject(wrappedValue: container)
        _session = StateObject(wrappedValue: AppSessionStore(container: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(session)
                .environmentObject(deepLinkCenter)
        }
    }
}

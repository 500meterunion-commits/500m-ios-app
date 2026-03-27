import SwiftUI

struct ContentView: View {
    var body: some View {
        AppRootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppContainer())
        .environmentObject(AppSessionStore(container: AppContainer()))
        .environmentObject(AppDeepLinkCenter.shared)
}

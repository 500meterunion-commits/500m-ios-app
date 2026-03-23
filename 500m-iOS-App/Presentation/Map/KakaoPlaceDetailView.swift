import SwiftUI
import WebKit

struct KakaoPlaceDetailView: View {
    let placeId: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            KakaoPlaceWebView(placeId: placeId)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("가게 정보")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct KakaoPlaceWebView: UIViewRepresentable {
    let placeId: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: "https://place.map.kakao.com/\(placeId)") else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

import SwiftUI

struct SplashView: View {
    private let brandRed = Color(red: 0.97, green: 0.25, blue: 0.26)
    private let textGray = Color(red: 0.65, green: 0.70, blue: 0.78)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: max(170, proxy.size.height * 0.30))

                    VStack(spacing: 22) {
                        Image("ic_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 130, height: 130)

                        Text("500미터")
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(brandRed)
                    }

                    Spacer()

                    Text("주변 모든 것을 연결하다")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(textGray)
                        .padding(.bottom, max(92, proxy.size.height * 0.12))
                }
            }
        }
    }
}

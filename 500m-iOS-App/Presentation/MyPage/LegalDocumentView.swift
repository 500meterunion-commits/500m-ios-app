import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let content: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TermsTextView(
                text: content,
                textColor: UIColor(Color(red: 0.43, green: 0.47, blue: 0.53)),
                font: .systemFont(ofSize: 15, weight: .regular),
                lineSpacing: 7
            )
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 8)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color.white)
    }
}

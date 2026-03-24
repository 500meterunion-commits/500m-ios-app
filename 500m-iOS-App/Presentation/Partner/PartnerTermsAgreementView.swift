import SwiftUI

private enum PartnerTermType {
    case required
}

private struct PartnerTermItem: Identifiable, Hashable {
    let id: String
    let type: PartnerTermType
    let title: String
    let content: String
}

private struct PartnerTermDetailView: View {
    let title: String
    let content: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

                HStack {
                    Button(action: onClose) {
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
    }
}

struct PartnerTermsAgreementView: View {
    let onBack: () -> Void
    let onAgree: (_ checkedMap: [String: Bool]) -> Void

    @State private var checkedMap: [String: Bool] = [
        "terms_service": false,
        "terms_location": false,
    ]
    @State private var selectedTerm: PartnerTermItem?

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    agreementCard
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 140)
            }

            bottomButton
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea())
        .fullScreenCover(item: $selectedTerm) { term in
            PartnerTermDetailView(
                title: term.title,
                content: term.content,
                onClose: { selectedTerm = nil }
            )
        }
    }

    private var header: some View {
        ZStack {
            Text("약관 동의")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

            HStack {
                Button(action: onBack) {
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

    private var agreementCard: some View {
        VStack(spacing: 0) {
            partnerRow(
                title: "전체 동의",
                checked: isAllChecked,
                onCheck: toggleAll,
                onOpen: nil
            )

            Rectangle()
                .fill(Color(red: 0.94, green: 0.95, blue: 0.97))
                .frame(height: 1)
                .padding(.horizontal, 18)

            ForEach(Self.terms) { item in
                partnerRow(
                    title: "[필수] \(item.title)",
                    checked: checkedMap[item.id] == true,
                    onCheck: { checkedMap[item.id] = !(checkedMap[item.id] ?? false) },
                    onOpen: { selectedTerm = item }
                )
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }

    private func partnerRow(
        title: String,
        checked: Bool,
        onCheck: @escaping () -> Void,
        onOpen: (() -> Void)?
    ) -> some View {
        HStack(spacing: 16) {
            Button(action: onCheck) {
                ZStack {
                    Circle()
                        .stroke(checked ? brandRed : Color(red: 0.84, green: 0.88, blue: 0.92), lineWidth: 2)
                        .background((checked ? brandRed : Color.clear).clipShape(Circle()))
                        .frame(width: 34, height: 34)

                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                onOpen?()
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
                    Spacer()
                    if onOpen != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.8, green: 0.84, blue: 0.89))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(height: 92)
    }

    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                onAgree(checkedMap)
            } label: {
                Text("동의하고 시작하기")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(brandRed.opacity(requiredTermsSatisfied ? 1 : 0.35))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!requiredTermsSatisfied)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }

    private var isAllChecked: Bool {
        Self.terms.allSatisfy { checkedMap[$0.id] == true }
    }

    private var requiredTermsSatisfied: Bool {
        isAllChecked
    }

    private func toggleAll() {
        let newValue = !isAllChecked
        Self.terms.forEach { checkedMap[$0.id] = newValue }
    }

    private static let terms: [PartnerTermItem] = [
        .init(
            id: "terms_service",
            type: .required,
            title: "마케팅 정보 수신 및 활용 동의",
            content: TermsContent.partnerMarketing
        ),
        .init(
            id: "terms_location",
            type: .required,
            title: "개인정보 제3자 제공 동의",
            content: TermsContent.partnerThirdParty
        ),
    ]
}

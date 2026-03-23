import SwiftUI

private enum NormalTermType {
    case required
    case optional
}

private struct NormalTermItem: Identifiable, Hashable {
    let id: String
    let type: NormalTermType
    let title: String
    let content: String
}

private struct TermDetailScreen: View {
    let term: NormalTermItem
    let brandRed: Color
    let lineGray: Color
    let textDark: Color
    let textGray: Color
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(textDark)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(term.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(textDark)

                    Spacer()

                    Color.clear
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 14)

                Divider()
                    .overlay(lineGray)

                TermsTextView(
                    text: term.content,
                    textColor: UIColor(textGray),
                    font: .systemFont(ofSize: 15, weight: .regular),
                    lineSpacing: 7
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(lineGray)

                    Button(action: onConfirm) {
                        Text("확인")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(brandRed)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white)
                }
                .background(Color.white)
            }
        }
    }
}

struct TermsAgreementView: View {
    let profile: UserProfile

    @EnvironmentObject private var session: AppSessionStore
    @State private var checkedMap: [String: Bool] = Dictionary(
        uniqueKeysWithValues: Self.normalTerms.map { ($0.id, false) }
    )
    @State private var selectedTerm: NormalTermItem?

    private let brandRed = Color(red: 0.91, green: 0.29, blue: 0.29)
    private let lineGray = Color(red: 0.91, green: 0.93, blue: 0.95)
    private let textDark = Color(red: 0.12, green: 0.16, blue: 0.22)
    private let textGray = Color(red: 0.48, green: 0.53, blue: 0.58)
    private let uncheckedGray = Color(red: 0.81, green: 0.85, blue: 0.89)

    private var requiredIDs: [String] {
        Self.normalTerms.filter { $0.type == .required }.map(\.id)
    }

    private var allRequiredChecked: Bool {
        requiredIDs.allSatisfy { checkedMap[$0] == true }
    }

    private var allChecked: Bool {
        Self.normalTerms.allSatisfy { checkedMap[$0.id] == true }
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 22)

                        termsRow(
                            title: "전체 동의",
                            checked: allChecked,
                            isPrimary: true,
                            showChevron: false,
                            titleColor: textDark,
                            onToggle: toggleAll
                        )

                        Spacer()
                            .frame(height: 18)

                        Divider()
                            .overlay(lineGray)

                        Spacer()
                            .frame(height: 6)

                        ForEach(Self.normalTerms) { item in
                            termsRow(
                                title: prefixedTitle(for: item),
                                checked: checkedMap[item.id] == true,
                                isPrimary: false,
                                showChevron: true,
                                titleColor: item.type == .optional && checkedMap[item.id] != true ? textGray : textDark,
                                onToggle: { toggleItem(item.id) },
                                onOpenDetail: { selectedTerm = item }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomCTA
        }
        .fullScreenCover(item: $selectedTerm) { term in
            TermDetailScreen(
                term: term,
                brandRed: brandRed,
                lineGray: lineGray,
                textDark: textDark,
                textGray: textGray,
                onClose: { selectedTerm = nil },
                onConfirm: {
                    checkedMap[term.id] = true
                    selectedTerm = nil
                }
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                session.signOutToLogin()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(textDark)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("약관 동의")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(textDark)

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(lineGray)

            Button {
                session.applyNormalTerms(
                    service: checkedMap["terms_service"] == true,
                    location: checkedMap["terms_location"] == true
                )
            } label: {
                Text("동의하고 시작하기")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(allRequiredChecked ? brandRed : brandRed.opacity(0.35))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!allRequiredChecked || session.isBusy)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func termsRow(
        title: String,
        checked: Bool,
        isPrimary: Bool,
        showChevron: Bool,
        titleColor: Color,
        onToggle: @escaping () -> Void,
        onOpenDetail: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 0) {
            checkCircle(checked: checked, onTap: onToggle)

            Spacer()
                .frame(width: 12)

            Button(action: onOpenDetail ?? onToggle) {
                rowLabel(
                    title: title,
                    isPrimary: isPrimary,
                    showChevron: showChevron,
                    titleColor: titleColor
                )
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 62)
        .padding(.vertical, 10)
    }

    private func rowLabel(
        title: String,
        isPrimary: Bool,
        showChevron: Bool,
        titleColor: Color
    ) -> some View {
                HStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: isPrimary ? 20 : 16, weight: isPrimary ? .bold : .medium))
                        .foregroundStyle(titleColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(red: 0.72, green: 0.76, blue: 0.80))
                            .frame(width: 28, height: 28)
                    }
                }
    }

    private func checkCircle(checked: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(checked ? brandRed : .clear)
                    .overlay {
                        Circle()
                            .stroke(checked ? brandRed : uncheckedGray, lineWidth: 2)
                    }

                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func toggleAll() {
        let newValue = !allChecked
        Self.normalTerms.forEach { checkedMap[$0.id] = newValue }
    }

    private func toggleItem(_ id: String) {
        checkedMap[id] = !(checkedMap[id] == true)
    }
    private func prefixedTitle(for item: NormalTermItem) -> String {
        (item.type == .required ? "[필수] " : "[선택] ") + item.title
    }

    private static var normalTerms: [NormalTermItem] {
        [
            NormalTermItem(
                id: "terms_service",
                type: .required,
                title: "500미터 서비스 이용약관",
                content: TermsContent.service
            ),
            NormalTermItem(
                id: "terms_location",
                type: .required,
                title: "위치기반서비스 이용약관",
                content: TermsContent.location
            ),
            NormalTermItem(
                id: "terms_privacy",
                type: .optional,
                title: "개인정보 수집 및 이용 동의",
                content: TermsContent.privacy
            )
        ]
    }
}

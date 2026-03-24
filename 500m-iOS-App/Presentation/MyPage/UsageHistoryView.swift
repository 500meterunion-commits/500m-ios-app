import SwiftUI

struct UsageHistoryView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UsageHistoryViewModel()

    private let brandOrange = Color(red: 0.91, green: 0.36, blue: 0.16)

    var body: some View {
        VStack(spacing: 0) {
            header
            tabStrip

            if viewModel.history.isEmpty {
                Spacer()
                Text("이용 내역이 없습니다.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(red: 0.67, green: 0.73, blue: 0.79))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.history) { item in
                            historyCard(item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .background(Color(red: 0.97, green: 0.98, blue: 0.99))
            }
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.configure(container: container)
        }
    }

    private var header: some View {
        ZStack {
            Text("이용 내역")
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

    private var tabStrip: some View {
        HStack(spacing: 0) {
            historyTab(title: "택시", service: .taxi)
            historyTab(title: "대리기사", service: .daeri)
        }
        .background(Color.white)
    }

    private func historyTab(title: String, service: ServiceType) -> some View {
        let selected = viewModel.selectedService == service

        return Button {
            viewModel.selectedService = service
        } label: {
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 18, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? brandOrange : Color(red: 0.39, green: 0.45, blue: 0.54))

                Rectangle()
                    .fill(selected ? brandOrange : .clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
        .buttonStyle(.plain)
    }

    private func historyCard(_ item: UserHistoryItem) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: item.providerProfileImageURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.58, green: 0.66, blue: 0.72))
            }
            .frame(width: 58, height: 58)
            .background(Color(red: 0.95, green: 0.96, blue: 0.98))
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(item.providerName?.nilIfBlank ?? "기사님")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))

                HStack(spacing: 10) {
                    Text(item.status.koreanText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.54))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.95, green: 0.96, blue: 0.98), in: RoundedRectangle(cornerRadius: 8))

                    Text(historyDate(item.createdAtMs))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.54))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }

    private func historyDate(_ ms: Int64) -> String {
        guard ms > 0 else { return "-" }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
            .formatted(.dateTime.year().month().day().hour().minute())
    }
}

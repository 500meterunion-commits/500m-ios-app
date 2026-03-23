import SwiftUI

struct UsageHistoryView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = UsageHistoryViewModel()

    var body: some View {
        List {
            Picker("서비스", selection: $viewModel.selectedService) {
                Text("택시").tag(ServiceType.taxi)
                Text("대리").tag(ServiceType.daeri)
            }
            .pickerStyle(.segmented)

            if viewModel.history.isEmpty {
                Text("이용 내역이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.history) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.providerName?.nilIfBlank ?? "파트너")
                            .font(.headline)
                        Text(item.status.koreanText)
                            .font(.subheadline)
                        Text(Date(timeIntervalSince1970: TimeInterval(item.createdAtMs) / 1000).formatted(date: .numeric, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("이용 내역")
        .task {
            viewModel.configure(container: container)
        }
    }
}

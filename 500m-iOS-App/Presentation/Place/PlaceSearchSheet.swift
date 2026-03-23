import SwiftUI

struct PlaceSearchSheet: View {
    let onSelect: (Place) -> Void

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlaceSearchViewModel()

    init(onSelect: @escaping (Place) -> Void) {
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("가게명/주소 검색", text: $viewModel.query)
                    Picker("지역", selection: $viewModel.marketID) {
                        Text("부산").tag("busan")
                        Text("울산").tag("ulsan")
                    }
                    Picker("카테고리", selection: $viewModel.category) {
                        Text("LIFE").tag("LIFE")
                        Text("FOOD").tag("FOOD")
                        Text("URGENT").tag("URGENT")
                    }

                    Button(viewModel.isLoading ? "검색중..." : "검색") {
                        viewModel.search()
                    }
                    .disabled(viewModel.isLoading)
                }

                Section("결과") {
                    ForEach(viewModel.results) { place in
                        Button {
                            onSelect(place)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(place.name)
                                    .font(.headline)
                                Text(place.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("장소 검색")
            .task {
                viewModel.configure(container: container)
            }
            .alert("검색 오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue { viewModel.errorMessage = nil }
                }
            ), actions: {
                Button("확인") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
    }
}

import Foundation

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var marketID = "busan"
    @Published var category = "LIFE"
    @Published private(set) var isLoading = false
    @Published private(set) var results: [Place] = []
    @Published var errorMessage: String?

    private var container: AppContainer?

    init(container: AppContainer? = nil) {
        self.container = container
    }

    func configure(container: AppContainer) {
        if self.container == nil {
            self.container = container
        }
    }

    func search() {
        Task {
            await performSearch()
        }
    }

    private func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }
        guard let container else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            results = try await container.searchPlaces(query: query, page: 1, size: 15)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

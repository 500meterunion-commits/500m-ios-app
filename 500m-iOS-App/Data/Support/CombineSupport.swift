import Combine
import Foundation

enum CombineSupport {
    static func combineLatest<T>(_ publishers: [AnyPublisher<[T], Never>]) -> AnyPublisher<[[T]], Never> {
        guard let first = publishers.first else {
            return Just([]).eraseToAnyPublisher()
        }

        return publishers.dropFirst().reduce(first.map { [$0] }.eraseToAnyPublisher()) { partial, next in
            partial
                .combineLatest(next)
                .map { accumulated, value in
                    accumulated + [value]
                }
                .eraseToAnyPublisher()
        }
    }
}

import Combine
import FirebaseDatabase
import Foundation

enum RealtimeDatabaseAsync {
    static func getValue(_ reference: DatabaseReference) async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DataSnapshot, Error>) in
            reference.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    static func updateChildren(_ reference: DatabaseReference, values: [String: Any?]) async throws {
        let sanitized = values.reduce(into: [AnyHashable: Any]()) { partial, entry in
            partial[entry.key] = entry.value ?? NSNull()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.updateChildValues(sanitized) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension DatabaseReference {
    func valuePublisher<T>(_ transform: @escaping (DataSnapshot) -> T?) -> AnyPublisher<T, Never> {
        let subject = PassthroughSubject<T, Never>()

        let listener = DatabaseHandleHolder(reference: self, subject: subject, transform: transform)
        let handle = observe(.value) { snapshot in
            if let value = transform(snapshot) {
                subject.send(value)
            }
        }
        listener.handle = handle

        return subject
            .handleEvents(receiveCancel: {
                listener.cancel()
            })
            .eraseToAnyPublisher()
    }
}

private final class DatabaseHandleHolder<T> {
    let reference: DatabaseReference
    let subject: PassthroughSubject<T, Never>
    let transform: (DataSnapshot) -> T?
    var handle: DatabaseHandle?

    init(
        reference: DatabaseReference,
        subject: PassthroughSubject<T, Never>,
        transform: @escaping (DataSnapshot) -> T?
    ) {
        self.reference = reference
        self.subject = subject
        self.transform = transform
    }

    func cancel() {
        if let handle {
            reference.removeObserver(withHandle: handle)
        }
    }
}

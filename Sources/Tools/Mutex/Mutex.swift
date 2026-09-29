import Foundation

internal struct Mutex<Value>: @unchecked Sendable {

    private let storage: MutexStorage<Value>

    internal init(value: Value) {
        self.storage = MutexStorage(value: value)
    }

    internal borrowing func withLock<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        storage.lock()

        defer {
            storage.unlock()
        }

        return try body(&storage.value)
    }
}

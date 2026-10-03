public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryEncoder: Sendable {

    // MARK: - Instance Properties

    // The options and the user info are kept under one lock, which takes one allocation and one locking per call.
    private let optionsLock: OSAllocatedUnfairLock<DictionaryEncodingOptions>

    public var dateEncodingStrategy: DictionaryDateEncodingStrategy {
        get { optionsLock.withLock(\.dateEncodingStrategy) }
        set { optionsLock.withLock { $0.dateEncodingStrategy = newValue } }
    }

    public var dataEncodingStrategy: DictionaryDataEncodingStrategy {
        get { optionsLock.withLock(\.dataEncodingStrategy) }
        set { optionsLock.withLock { $0.dataEncodingStrategy = newValue } }
    }

    public var nonConformingFloatEncodingStrategy: DictionaryNonConformingFloatEncodingStrategy {
        get { optionsLock.withLock(\.nonConformingFloatEncodingStrategy) }
        set { optionsLock.withLock { $0.nonConformingFloatEncodingStrategy = newValue } }
    }

    public var nilEncodingStrategy: DictionaryNilEncodingStrategy {
        get { optionsLock.withLock(\.nilEncodingStrategy) }
        set { optionsLock.withLock { $0.nilEncodingStrategy = newValue } }
    }

    public var keyEncodingStrategy: DictionaryKeyEncodingStrategy {
        get { optionsLock.withLock(\.keyEncodingStrategy) }
        set { optionsLock.withLock { $0.keyEncodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { optionsLock.withLock(\.userInfo) }
        set { optionsLock.withLock { $0.userInfo = newValue } }
    }

    // MARK: - Initializers

    public init(
        dateEncodingStrategy: DictionaryDateEncodingStrategy = .deferredToDate,
        dataEncodingStrategy: DictionaryDataEncodingStrategy = .base64,
        nonConformingFloatEncodingStrategy: DictionaryNonConformingFloatEncodingStrategy = .throw,
        nilEncodingStrategy: DictionaryNilEncodingStrategy = .useNil,
        keyEncodingStrategy: DictionaryKeyEncodingStrategy = .useDefaultKeys,
        userInfo: [CodingUserInfoKey: Sendable] = [:]
    ) {
        let options = DictionaryEncodingOptions(
            dateEncodingStrategy: dateEncodingStrategy,
            dataEncodingStrategy: dataEncodingStrategy,
            nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy,
            nilEncodingStrategy: nilEncodingStrategy,
            keyEncodingStrategy: keyEncodingStrategy,
            userInfo: userInfo
        )

        self.optionsLock = OSAllocatedUnfairLock(initialState: options)
    }

    // MARK: - Instance Methods

    private func encodeRootValue<T>(
        _ value: T,
        encoding: (_ encoder: Encoder) throws -> Void
    ) throws -> [String: Sendable] {
        let options = optionsLock.withLock(\.self)

        let encoder = DictionaryValueEncoder(
            context: DictionaryEncodingContext(options: options),
            parent: nil,
            key: .empty
        )

        do {
            try encoding(encoder)
        } catch {
            // The encoders of nested containers refer back to the encoders of their containers until taken.
            encoder.discard()
            throw error
        }

        guard let dictionary = encoder.takeValue() as? [String: Sendable] else {
            throw EncodingError.invalidRootValue(value)
        }

        return dictionary
    }

    public func encode<T: Encodable>(_ value: T) throws -> [String: Sendable] {
        try encodeRootValue(value) { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode<T: EncodableWithConfiguration>(
        _ value: T,
        configuration: T.EncodingConfiguration
    ) throws -> [String: Sendable] {
        try encodeRootValue(value) { encoder in
            try value.encode(to: encoder, configuration: configuration)
        }
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension EncodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func invalidRootValue(_ value: Any) -> any Error {
        let context = Context(codingPath: [], debugDescription: "Root component cannot be encoded in Dictionary")

        return Self.invalidValue(value, context)
    }
}

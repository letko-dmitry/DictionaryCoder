public import Foundation

public final class DictionaryEncoder: Sendable {

    // MARK: - Instance Properties

    // The options and the user info are kept under one lock, which takes one allocation and one locking per call.
    private let optionsMutex: Mutex<DictionaryEncodingOptions>

    public var dateEncodingStrategy: DictionaryDateEncodingStrategy {
        get { optionsMutex.withLock { $0.dateEncodingStrategy } }
        set { optionsMutex.withLock { $0.dateEncodingStrategy = newValue } }
    }

    public var dataEncodingStrategy: DictionaryDataEncodingStrategy {
        get { optionsMutex.withLock { $0.dataEncodingStrategy } }
        set { optionsMutex.withLock { $0.dataEncodingStrategy = newValue } }
    }

    public var decimalEncodingStrategy: DictionaryDecimalEncodingStrategy {
        get { optionsMutex.withLock { $0.decimalEncodingStrategy } }
        set { optionsMutex.withLock { $0.decimalEncodingStrategy = newValue } }
    }

    public var nonConformingFloatEncodingStrategy: DictionaryNonConformingFloatEncodingStrategy {
        get { optionsMutex.withLock { $0.nonConformingFloatEncodingStrategy } }
        set { optionsMutex.withLock { $0.nonConformingFloatEncodingStrategy = newValue } }
    }

    public var nilEncodingStrategy: DictionaryNilEncodingStrategy {
        get { optionsMutex.withLock { $0.nilEncodingStrategy } }
        set { optionsMutex.withLock { $0.nilEncodingStrategy = newValue } }
    }

    public var keyEncodingStrategy: DictionaryKeyEncodingStrategy {
        get { optionsMutex.withLock { $0.keyEncodingStrategy } }
        set { optionsMutex.withLock { $0.keyEncodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { optionsMutex.withLock { $0.userInfo } }
        set { optionsMutex.withLock { $0.userInfo = newValue } }
    }

    // MARK: - Initializers

    public init(
        dateEncodingStrategy: DictionaryDateEncodingStrategy = .deferredToDate,
        dataEncodingStrategy: DictionaryDataEncodingStrategy = .base64,
        decimalEncodingStrategy: DictionaryDecimalEncodingStrategy = .deferredToDecimal,
        nonConformingFloatEncodingStrategy: DictionaryNonConformingFloatEncodingStrategy = .throw,
        nilEncodingStrategy: DictionaryNilEncodingStrategy = .useNil,
        keyEncodingStrategy: DictionaryKeyEncodingStrategy = .useDefaultKeys,
        userInfo: [CodingUserInfoKey: Sendable] = [:]
    ) {
        let options = DictionaryEncodingOptions(
            dateEncodingStrategy: dateEncodingStrategy,
            dataEncodingStrategy: dataEncodingStrategy,
            decimalEncodingStrategy: decimalEncodingStrategy,
            nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy,
            nilEncodingStrategy: nilEncodingStrategy,
            keyEncodingStrategy: keyEncodingStrategy,
            userInfo: userInfo
        )

        self.optionsMutex = Mutex(value: options)
    }

    // MARK: - Instance Methods

    private func encodeRootValue<T>(
        _ value: T,
        encoding: (_ encoder: Encoder) throws -> Void
    ) throws -> [String: Sendable] {
        let options = optionsMutex.withLock { $0 }

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

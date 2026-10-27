public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryEncoder: Sendable {

    // MARK: - Instance Properties

    // The context of the current options and user info, which every call shares under one lock,
    // so that a call takes a reference to it rather than a copy of the options and an allocation.
    private let contextLock: OSAllocatedUnfairLock<DictionaryEncodingContext>

    public var dateEncodingStrategy: DictionaryDateEncodingStrategy {
        get { contextLock.withLock(\.options.dateEncodingStrategy) }
        set { updateOptions { $0.dateEncodingStrategy = newValue } }
    }

    public var dataEncodingStrategy: DictionaryDataEncodingStrategy {
        get { contextLock.withLock(\.options.dataEncodingStrategy) }
        set { updateOptions { $0.dataEncodingStrategy = newValue } }
    }

    public var decimalEncodingStrategy: DictionaryDecimalEncodingStrategy {
        get { contextLock.withLock(\.options.decimalEncodingStrategy) }
        set { updateOptions { $0.decimalEncodingStrategy = newValue } }
    }

    public var nonConformingFloatEncodingStrategy: DictionaryNonConformingFloatEncodingStrategy {
        get { contextLock.withLock(\.options.nonConformingFloatEncodingStrategy) }
        set { updateOptions { $0.nonConformingFloatEncodingStrategy = newValue } }
    }

    public var nilEncodingStrategy: DictionaryNilEncodingStrategy {
        get { contextLock.withLock(\.options.nilEncodingStrategy) }
        set { updateOptions { $0.nilEncodingStrategy = newValue } }
    }

    public var keyEncodingStrategy: DictionaryKeyEncodingStrategy {
        get { contextLock.withLock(\.options.keyEncodingStrategy) }
        set { updateOptions { $0.keyEncodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { contextLock.withLock(\.options.userInfo) }
        set { updateOptions { $0.userInfo = newValue } }
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

        self.contextLock = OSAllocatedUnfairLock(initialState: DictionaryEncodingContext(options: options))
    }

    // MARK: - Instance Methods

    private func updateOptions(_ update: @Sendable (_ options: inout DictionaryEncodingOptions) -> Void) {
        contextLock.withLock { context in
            var options = context.options

            update(&options)

            context = DictionaryEncodingContext(options: options)
        }
    }

    private func encodeRootValue<T>(
        _ value: T,
        encoding: (_ encoder: Encoder) throws -> Void
    ) throws -> [String: Sendable] {
        let encoder = DictionaryValueEncoder(
            context: contextLock.withLock(\.self),
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

public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryEncoder: Sendable {

    // MARK: - Instance Properties

    private let optionsLock: OSAllocatedUnfairLock<DictionaryEncodingOptions>
    private let userInfoLock: OSAllocatedUnfairLock<[CodingUserInfoKey: Sendable]>

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
        get { userInfoLock.withLock(\.self) }
        set { userInfoLock.withLock { $0 = newValue } }
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
            keyEncodingStrategy: keyEncodingStrategy
        )

        self.optionsLock = OSAllocatedUnfairLock(initialState: options)
        self.userInfoLock = OSAllocatedUnfairLock(initialState: userInfo)
    }

    // MARK: - Instance Methods

    public func encode<T: Encodable>(_ value: T) throws -> [String: Sendable] {
        let options = optionsLock.withLock(\.self)

        let encoder = DictionarySingleValueEncodingContainer(
            context: DictionaryComponentEncoder(options: options, userInfo: userInfo),
            codingPathNode: .root
        )

        try value.encode(to: encoder)

        guard let dictionary = encoder.resolveValue() as? [String: Sendable] else {
            let errorContext = EncodingError.Context(
                codingPath: [],
                debugDescription: "Root component cannot be encoded in Dictionary"
            )

            throw EncodingError.invalidValue(value, errorContext)
        }

        return dictionary
    }

    public func encode<T: EncodableWithConfiguration>(
        _ value: T,
        configuration: T.EncodingConfiguration
    ) throws -> [String: Sendable] {
        let options = optionsLock.withLock(\.self)

        let encoder = DictionarySingleValueEncodingContainer(
            context: DictionaryComponentEncoder(options: options, userInfo: userInfo),
            codingPathNode: .root
        )

        try value.encode(to: encoder, configuration: configuration)

        guard let dictionary = encoder.resolveValue() as? [String: Sendable] else {
            let errorContext = EncodingError.Context(
                codingPath: [],
                debugDescription: "Root component cannot be encoded in Dictionary"
            )

            throw EncodingError.invalidValue(value, errorContext)
        }

        return dictionary
    }
}

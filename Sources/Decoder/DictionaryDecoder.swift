public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryDecoder: Sendable {

    // MARK: - Instance Properties

    // The options and the user info are kept under one lock, which takes one allocation and one locking per call.
    private let optionsLock: OSAllocatedUnfairLock<DictionaryDecodingOptions>

    public var dateDecodingStrategy: DictionaryDateDecodingStrategy {
        get { optionsLock.withLock(\.dateDecodingStrategy) }
        set { optionsLock.withLock { $0.dateDecodingStrategy = newValue } }
    }

    public var dataDecodingStrategy: DictionaryDataDecodingStrategy {
        get { optionsLock.withLock(\.dataDecodingStrategy) }
        set { optionsLock.withLock { $0.dataDecodingStrategy = newValue } }
    }

    public var nonConformingFloatDecodingStrategy: DictionaryNonConformingFloatDecodingStrategy {
        get { optionsLock.withLock(\.nonConformingFloatDecodingStrategy) }
        set { optionsLock.withLock { $0.nonConformingFloatDecodingStrategy = newValue } }
    }

    public var keyDecodingStrategy: DictionaryKeyDecodingStrategy {
        get { optionsLock.withLock(\.keyDecodingStrategy) }
        set { optionsLock.withLock { $0.keyDecodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { optionsLock.withLock(\.userInfo) }
        set { optionsLock.withLock { $0.userInfo = newValue } }
    }

    // MARK: - Initializers

    public init(
        dateDecodingStrategy: DictionaryDateDecodingStrategy = .deferredToDate,
        dataDecodingStrategy: DictionaryDataDecodingStrategy = .base64,
        nonConformingFloatDecodingStrategy: DictionaryNonConformingFloatDecodingStrategy = .throw,
        keyDecodingStrategy: DictionaryKeyDecodingStrategy = .useDefaultKeys,
        userInfo: [CodingUserInfoKey: Sendable] = [:]
    ) {
        let options = DictionaryDecodingOptions(
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
            keyDecodingStrategy: keyDecodingStrategy,
            userInfo: userInfo
        )

        self.optionsLock = OSAllocatedUnfairLock(initialState: options)
    }

    // MARK: - Instance Methods

    private func rootDecoder(for dictionary: [String: Any]) -> DictionaryValueDecoder {
        let options = optionsLock.withLock(\.self)

        return DictionaryValueDecoder(
            component: dictionary,
            context: DictionaryDecodingContext(options: options),
            parent: nil,
            key: .empty
        )
    }

    public func decode<T: Decodable>(
        _ type: T.Type = T.self,
        from dictionary: [String: Any]
    ) throws -> T {
        try T(from: rootDecoder(for: dictionary))
    }

    public func decode<T: Decodable>(from dictionary: [String: Any]) throws -> T {
        try decode(T.self, from: dictionary)
    }

    public func decode<T: DecodableWithConfiguration>(
        _ type: T.Type = T.self,
        from dictionary: [String: Any],
        configuration: T.DecodingConfiguration
    ) throws -> T {
        try T(from: rootDecoder(for: dictionary), configuration: configuration)
    }
}

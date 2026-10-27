public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryDecoder: Sendable {

    // MARK: - Instance Properties

    // The context of the current options and user info, which every call shares under one lock,
    // so that a call takes a reference to it rather than a copy of the options and an allocation.
    private let contextLock: OSAllocatedUnfairLock<DictionaryDecodingContext>

    public var dateDecodingStrategy: DictionaryDateDecodingStrategy {
        get { contextLock.withLock(\.options.dateDecodingStrategy) }
        set { updateOptions { $0.dateDecodingStrategy = newValue } }
    }

    public var dataDecodingStrategy: DictionaryDataDecodingStrategy {
        get { contextLock.withLock(\.options.dataDecodingStrategy) }
        set { updateOptions { $0.dataDecodingStrategy = newValue } }
    }

    public var decimalDecodingStrategy: DictionaryDecimalDecodingStrategy {
        get { contextLock.withLock(\.options.decimalDecodingStrategy) }
        set { updateOptions { $0.decimalDecodingStrategy = newValue } }
    }

    public var nonConformingFloatDecodingStrategy: DictionaryNonConformingFloatDecodingStrategy {
        get { contextLock.withLock(\.options.nonConformingFloatDecodingStrategy) }
        set { updateOptions { $0.nonConformingFloatDecodingStrategy = newValue } }
    }

    public var keyDecodingStrategy: DictionaryKeyDecodingStrategy {
        get { contextLock.withLock(\.options.keyDecodingStrategy) }
        set { updateOptions { $0.keyDecodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { contextLock.withLock(\.options.userInfo) }
        set { updateOptions { $0.userInfo = newValue } }
    }

    // MARK: - Initializers

    public init(
        dateDecodingStrategy: DictionaryDateDecodingStrategy = .deferredToDate,
        dataDecodingStrategy: DictionaryDataDecodingStrategy = .base64,
        decimalDecodingStrategy: DictionaryDecimalDecodingStrategy = .deferredToDecimal,
        nonConformingFloatDecodingStrategy: DictionaryNonConformingFloatDecodingStrategy = .throw,
        keyDecodingStrategy: DictionaryKeyDecodingStrategy = .useDefaultKeys,
        userInfo: [CodingUserInfoKey: Sendable] = [:]
    ) {
        let options = DictionaryDecodingOptions(
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            decimalDecodingStrategy: decimalDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
            keyDecodingStrategy: keyDecodingStrategy,
            userInfo: userInfo
        )

        self.contextLock = OSAllocatedUnfairLock(initialState: DictionaryDecodingContext(options: options))
    }

    // MARK: - Instance Methods

    private func updateOptions(_ update: @Sendable (_ options: inout DictionaryDecodingOptions) -> Void) {
        contextLock.withLock { context in
            var options = context.options

            update(&options)

            context = DictionaryDecodingContext(options: options)
        }
    }

    private func rootDecoder(for dictionary: [String: Any]) -> DictionaryValueDecoder {
        DictionaryValueDecoder(
            component: dictionary,
            context: contextLock.withLock(\.self),
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

    @inline(always)
    @export(implementation)
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

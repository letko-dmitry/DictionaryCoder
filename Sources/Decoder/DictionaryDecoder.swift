public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryDecoder: Sendable {

    // MARK: - Nested Types

    private struct State {

        // MARK: - Instance Properties

        /// The context of the current options and user info, which every call shares,
        /// so that a call takes a reference to it rather than a copy of the options and an allocation.
        var context: DictionaryDecodingContext

        /// The decoder of the last root value, kept for the next call along with the decoders of nested values
        /// that it keeps, so that a call allocates no decoders.
        var reusableDecoder: DictionaryValueDecoder?
    }

    // MARK: - Instance Properties

    // Unchecked, as a decoder is used by one call at a time, which takes it out of the state.
    private let stateLock: OSAllocatedUnfairLock<State>

    public var dateDecodingStrategy: DictionaryDateDecodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.dateDecodingStrategy) }
        set { updateOptions { $0.dateDecodingStrategy = newValue } }
    }

    public var dataDecodingStrategy: DictionaryDataDecodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.dataDecodingStrategy) }
        set { updateOptions { $0.dataDecodingStrategy = newValue } }
    }

    public var decimalDecodingStrategy: DictionaryDecimalDecodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.decimalDecodingStrategy) }
        set { updateOptions { $0.decimalDecodingStrategy = newValue } }
    }

    public var nonConformingFloatDecodingStrategy: DictionaryNonConformingFloatDecodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.nonConformingFloatDecodingStrategy) }
        set { updateOptions { $0.nonConformingFloatDecodingStrategy = newValue } }
    }

    public var keyDecodingStrategy: DictionaryKeyDecodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.keyDecodingStrategy) }
        set { updateOptions { $0.keyDecodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { stateLock.withLockUnchecked(\.context.options.userInfo) }
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

        self.stateLock = OSAllocatedUnfairLock(
            uncheckedState: State(context: DictionaryDecodingContext(options: options), reusableDecoder: nil)
        )
    }

    // MARK: - Instance Methods

    private func updateOptions(_ update: (_ options: inout DictionaryDecodingOptions) -> Void) {
        stateLock.withLockUnchecked { state in
            var options = state.context.options

            update(&options)

            state.context = DictionaryDecodingContext(options: options)
            state.reusableDecoder = nil
        }
    }

    private func decodeRootValue<T>(
        from dictionary: [String: Any],
        decoding: (_ decoder: DictionaryValueDecoder) throws -> T
    ) throws -> T {
        // The context is taken only for a new decoder, as a kept one refers to it already.
        let (reusableDecoder, context) = stateLock.withLockUnchecked { state in
            let reusableDecoder = state.reusableDecoder.take()

            return (reusableDecoder, reusableDecoder == nil ? state.context : nil)
        }

        let decoder: DictionaryValueDecoder

        // Moved out of the binding, which would refer to the decoder to the end of the call and keep it from reuse.
        if let reusableDecoder = consume reusableDecoder {
            reusableDecoder.component = dictionary
            decoder = reusableDecoder
        } else {
            decoder = DictionaryValueDecoder(
                component: dictionary,
                context: unsafe context.unsafelyUnwrapped,
                parent: nil,
                key: .empty
            )
        }

        let value = try decoding(decoder)

        keepForReuse(consume decoder)

        return value
    }

    private func keepForReuse(_ decoder: consuming DictionaryValueDecoder) {
        // A decoder that anything else still refers to, such as a stored container, is left to it.
        guard isKnownUniquelyReferenced(&decoder) else {
            return
        }

        decoder.dropComponents()

        stateLock.withLockUnchecked { [decoder] state in
            // A decoder of options changed since is dropped, as is one of a call that ran at the same time.
            if state.reusableDecoder == nil, decoder.context === state.context {
                state.reusableDecoder = decoder
            }
        }
    }

    public func decode<T: Decodable>(
        _ type: T.Type = T.self,
        from dictionary: [String: Any]
    ) throws -> T {
        try decodeRootValue(from: dictionary) { decoder in
            try T(from: decoder)
        }
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
        try decodeRootValue(from: dictionary) { decoder in
            try T(from: decoder, configuration: configuration)
        }
    }
}

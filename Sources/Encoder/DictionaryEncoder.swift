public import Foundation

import struct os.OSAllocatedUnfairLock

public final class DictionaryEncoder: Sendable {

    // MARK: - Nested Types

    private struct State {

        // MARK: - Instance Properties

        /// The context of the current options and user info, which every call shares,
        /// so that a call takes a reference to it rather than a copy of the options and an allocation.
        var context: DictionaryEncodingContext

        /// The encoder of the last root value, kept for the next call along with the encoders of nested values
        /// that it keeps, so that a call allocates no encoders.
        var reusableEncoder: DictionaryValueEncoder?
    }

    // MARK: - Instance Properties

    // Unchecked, as an encoder is used by one call at a time, which takes it out of the state.
    private let stateLock: OSAllocatedUnfairLock<State>

    public var dateEncodingStrategy: DictionaryDateEncodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.dateEncodingStrategy) }
        set { updateOptions { $0.dateEncodingStrategy = newValue } }
    }

    public var dataEncodingStrategy: DictionaryDataEncodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.dataEncodingStrategy) }
        set { updateOptions { $0.dataEncodingStrategy = newValue } }
    }

    public var decimalEncodingStrategy: DictionaryDecimalEncodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.decimalEncodingStrategy) }
        set { updateOptions { $0.decimalEncodingStrategy = newValue } }
    }

    public var nonConformingFloatEncodingStrategy: DictionaryNonConformingFloatEncodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.nonConformingFloatEncodingStrategy) }
        set { updateOptions { $0.nonConformingFloatEncodingStrategy = newValue } }
    }

    public var nilEncodingStrategy: DictionaryNilEncodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.nilEncodingStrategy) }
        set { updateOptions { $0.nilEncodingStrategy = newValue } }
    }

    public var keyEncodingStrategy: DictionaryKeyEncodingStrategy {
        get { stateLock.withLockUnchecked(\.context.options.keyEncodingStrategy) }
        set { updateOptions { $0.keyEncodingStrategy = newValue } }
    }

    public var userInfo: [CodingUserInfoKey: Sendable] {
        get { stateLock.withLockUnchecked(\.context.options.userInfo) }
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

        self.stateLock = OSAllocatedUnfairLock(
            uncheckedState: State(context: DictionaryEncodingContext(options: options), reusableEncoder: nil)
        )
    }

    // MARK: - Instance Methods

    private func updateOptions(_ update: (_ options: inout DictionaryEncodingOptions) -> Void) {
        stateLock.withLockUnchecked { state in
            var options = state.context.options

            update(&options)

            state.context = DictionaryEncodingContext(options: options)
            state.reusableEncoder = nil
        }
    }

    private func encodeRootValue<T>(
        _ value: T,
        encoding: (_ encoder: Encoder) throws -> Void
    ) throws -> [String: Sendable] {
        let (reusableEncoder, context) = stateLock.withLockUnchecked { state in
            (state.reusableEncoder.take(), state.context)
        }

        let encoder = reusableEncoder ?? DictionaryValueEncoder(context: context, parent: nil, key: .empty)

        do {
            try encoding(encoder)
        } catch {
            // The encoders of nested containers refer back to the encoders of their containers until taken.
            encoder.discard()
            throw error
        }

        let encodedValue = encoder.takeValue()

        keepForReuse(consume encoder)

        guard let dictionary = encodedValue as? [String: Sendable] else {
            throw EncodingError.invalidRootValue(value)
        }

        return dictionary
    }

    private func keepForReuse(_ encoder: consuming DictionaryValueEncoder) {
        // An encoder that anything else still refers to, such as a stored container, is left to it.
        guard isKnownUniquelyReferenced(&encoder) else {
            return
        }

        stateLock.withLockUnchecked { [encoder] state in
            // An encoder of options changed since is dropped, as is one of a call that ran at the same time.
            if state.reusableEncoder == nil, encoder.context === state.context {
                state.reusableEncoder = encoder
            }
        }
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

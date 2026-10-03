/// The encoder of a value, which holds the container that the value is encoded in,
/// and is the single value container of the value as well.
///
/// Every nested value is encoded with an encoder of its own, which is a node of the coding path too.
/// Once a nested value is encoded, its encoder is kept for the next nested value of the container,
/// unless anything else still refers to it, such as a stored container, so that encoding a nested value
/// allocates nothing but the containers of its own value.
internal final class DictionaryValueEncoder: CodingPathNode, Encoder, SingleValueEncodingContainer {

    // MARK: - Nested Types

    /// What the value is encoded in.
    internal enum Storage {

        // MARK: - Enumeration Cases

        case none
        case singleValue
        case keyedContainer
        case unkeyedContainer
    }

    /// Everything about the encoded value that changes.
    internal struct State {

        // MARK: - Instance Properties

        internal var storage = Storage.none
        internal var singleValue: Any?

        /// The values of the keyed container, which the container adds to directly.
        internal var keyedValues = DictionaryKeyedEncodingStorage()

        /// The values of the unkeyed container, which the container adds to directly.
        internal var unkeyedValues = DictionaryUnkeyedEncodingStorage()

        /// Whether a container was replaced with one of another kind, which leaves the replaced container
        /// adding to a storage that is not taken.
        internal var hasReplacedContainer = false

        /// The type of the keys of the keyed container.
        internal var keyType: ObjectIdentifier?

        /// The capacity for the next keyed container with keys of the same type: as many values as the last two
        /// held at least, so that containers of fewer values than the others do not take more memory than they need.
        internal var keyedCapacityHint: (keyType: ObjectIdentifier?, count: Int, capacity: Int) = (nil, 0, 0)

        /// The type of the last nested value that was encoded with an encoder of its own.
        internal var nestedValueType: ObjectIdentifier?

        /// The encoder of the last nested value, kept for the next one.
        internal var reusableEncoder: DictionaryValueEncoder?
    }

    // MARK: - Type Properties

    // Keyed containers of the same type of keys mostly hold as many values, as do the encoders of structures,
    // except for dictionaries, so the capacity hint is limited to keep large dictionaries
    // from wasting memory in small ones.
    private static let maximumKeyedCapacityHint = 16

    // MARK: - Instance Properties

    @exclusivity(unchecked)
    private var uncheckedState = State()

    internal let context: DictionaryEncodingContext

    // Accessed without the exclusivity checks that every access to a stored property of a class makes,
    // as no access lasts while anything else runs, such as the encoding of a nested value.
    internal var state: State {
        _read { yield unsafe uncheckedState }
        _modify { yield unsafe &uncheckedState }
    }

    internal var codingPath: [CodingKey] {
        path
    }

    // Converted when read rather than for every call, which reads it rarely.
    internal var userInfo: [CodingUserInfoKey: Any] {
        context.options.userInfo
    }

    // MARK: - Initializers

    internal init(context: DictionaryEncodingContext, parent: CodingPathNode?, key: CodingPathKey) {
        self.context = context

        super.init(parent: parent, key: key)
    }

    // MARK: - Instance Methods

    /// Makes the value encoded in a storage of the given kind, replacing whatever the value is encoded in.
    @inline(always)
    private func setStorage(_ storage: Storage) {
        if state.storage != .none {
            discard()

            state.hasReplacedContainer = true
        }

        state.storage = storage
    }

    @inline(always)
    private func makeNestedEncoder(at key: CodingPathKey) -> DictionaryValueEncoder {
        guard let encoder = state.reusableEncoder.take() else {
            return DictionaryValueEncoder(context: context, parent: self, key: key)
        }

        encoder.parent = self
        encoder.key = key

        return encoder
    }

    @inline(always)
    private func keepForReuse(_ encoder: inout DictionaryValueEncoder) {
        // An encoder that anything else still refers to, such as a stored container, is left to it.
        guard isKnownUniquelyReferenced(&encoder) else {
            return
        }

        // A kept encoder does not refer back, so that the encoders do not retain each other.
        encoder.parent = nil

        state.reusableEncoder = encoder
    }

    @inline(always)
    private func storeSingleValue<T>(_ value: @autoclosure () throws -> Any?, of originalValue: T) throws {
        guard state.storage == .none else {
            throw EncodingError.valueAlreadyEncoded(originalValue, at: self)
        }

        let value = try value()

        state.singleValue = consume value
        state.storage = .singleValue
    }

    // MARK: -

    /// Takes the encoded value, which leaves the encoder empty for another value.
    internal func takeValue() -> Any? {
        if state.hasReplacedContainer {
            defer {
                discard()
            }

            return takeStoredValue()
        }

        return takeStoredValue()
    }

    @inline(always)
    private func takeStoredValue() -> Any? {
        let storage = state.storage

        state.storage = .none

        switch storage {
        case .none:
            return nil

        case .singleValue:
            return state.singleValue.take()

        case .keyedContainer:
            let values = state.keyedValues.take()
            let hint = state.keyedCapacityHint
            let lastCount = hint.keyType == state.keyType ? hint.count : values.count

            state.keyedCapacityHint = (
                state.keyType,
                values.count,
                min(values.count, lastCount, Self.maximumKeyedCapacityHint)
            )

            return values

        case .unkeyedContainer:
            return state.unkeyedValues.take()
        }
    }

    /// Drops the encoded value along with the encoders of nested containers, which refer back to this encoder.
    internal func discard() {
        state.storage = .none
        state.singleValue = nil
        state.hasReplacedContainer = false

        state.keyedValues.discard()
        state.unkeyedValues.discard()
    }

    /// Encodes a nested value with an encoder of its own, the one kept from the last nested value if there is one.
    @inline(always)
    internal func encodeNestedValue(
        at key: CodingPathKey,
        encoding: (_ encoder: DictionaryValueEncoder) throws -> Void
    ) throws -> Any? {
        var encoder = makeNestedEncoder(at: key)

        do {
            try encoding(encoder)
        } catch {
            encoder.discard()
            throw error
        }

        let value = encoder.takeValue()

        keepForReuse(&encoder)

        return value
    }

    /// The encoder of a nested container or a super encoder for the key, which the keyed container keeps
    /// until its value is taken. A nested container of the same kind for the key is shared, as in `JSONEncoder`.
    internal func nestedEncoder<Key: CodingKey>(
        forKey key: Key,
        as kind: DictionaryNestedEncoderKind
    ) -> DictionaryValueEncoder {
        let encodedKey = encodeKey(key)

        if let encoder = state.keyedValues.nestedEncoder(forKey: encodedKey, as: kind) {
            return encoder
        }

        let encoder = DictionaryValueEncoder(context: context, parent: self, key: .key(key))

        state.keyedValues.store(encoder, as: kind, forKey: encodedKey)

        return encoder
    }

    /// The encoder of a nested container or a super encoder for the next element, which the unkeyed container keeps
    /// until its value is taken.
    internal func nestedEncoderForNextElement() -> DictionaryValueEncoder {
        let encoder = DictionaryValueEncoder(context: context, parent: self, key: .index(state.unkeyedValues.count))

        state.unkeyedValues.append(encoder)

        return encoder
    }

    @inline(always)
    internal func encodeKey<Key: CodingKey>(_ key: Key) -> String {
        switch context.options.keyEncodingStrategy {
        case .useDefaultKeys:
            key.stringValue

        case let .custom(closure):
            closure(position(at: .key(key)).path).stringValue
        }
    }

    // MARK: - Encoder

    internal func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
        if state.storage != .keyedContainer {
            setStorage(.keyedContainer)

            let keyType = ObjectIdentifier(keyType)

            if state.keyedCapacityHint.keyType == keyType {
                state.keyedValues.reserveCapacity(state.keyedCapacityHint.capacity)
            }

            state.keyType = keyType
        }

        return KeyedEncodingContainer(DictionaryKeyedEncodingContainer<Key>(encoder: self))
    }

    internal func unkeyedContainer() -> UnkeyedEncodingContainer {
        if state.storage != .unkeyedContainer {
            setStorage(.unkeyedContainer)
        }

        return DictionaryUnkeyedEncodingContainer(encoder: self)
    }

    internal func singleValueContainer() -> SingleValueEncodingContainer {
        self
    }

    // MARK: - SingleValueEncodingContainer

    internal func encodeNil() throws {
        try storeSingleValue(context.encodedNil, of: Any?.none)
    }

    internal func encode(_ value: Bool) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: Int) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: Int8) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: Int16) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: Int32) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: Int64) throws {
        try storeSingleValue(value, of: value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: UInt) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: UInt8) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: UInt16) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: UInt32) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: UInt64) throws {
        try storeSingleValue(value, of: value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode(_ value: Double) throws {
        try storeSingleValue(encodeFloatingPoint(value, at: position(at: .empty)), of: value)
    }

    internal func encode(_ value: Float) throws {
        try storeSingleValue(encodeFloatingPoint(value, at: position(at: .empty)), of: value)
    }

    internal func encode(_ value: String) throws {
        try storeSingleValue(value, of: value)
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        try storeSingleValue(encode(value, at: .empty), of: value)
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension EncodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func valueAlreadyEncoded<T>(_ value: T, at node: CodingPathNode) -> any Error {
        let context = Context(
            codingPath: node.path,
            debugDescription: "Single value container already has encoded value"
        )

        return Self.invalidValue(value, context)
    }
}

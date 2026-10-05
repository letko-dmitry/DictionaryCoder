/// The decoder of a value, which is its single value container as well.
///
/// Every nested value is decoded with a decoder of its own, which is a node of the coding path too,
/// that the containers of the value refer to. Once a nested value is decoded, its decoder is kept
/// for the next nested value of the container, unless anything else still refers to it, such as a stored container,
/// so that decoding a nested value allocates nothing but the containers of its own value.
internal final class DictionaryValueDecoder: CodingPathNode, Decoder, SingleValueDecodingContainer {

    // MARK: - Nested Types

    /// Everything about the decoding of the value that changes.
    internal struct State {

        // MARK: - Instance Properties

        /// The components of the unkeyed containers of the value, which are looked up once for all of them.
        internal var unkeyedComponents: DictionaryUnkeyedComponents?

        /// The type of the last nested value that was decoded with a decoder of its own.
        internal var nestedValueType: ObjectIdentifier?

        /// The decoder of the last nested value, kept for the next one.
        internal var reusableDecoder: DictionaryValueDecoder?
    }

    // MARK: - Instance Properties

    @exclusivity(unchecked)
    private var uncheckedComponent: Any?

    @exclusivity(unchecked)
    private var uncheckedState = State()

    internal let context: DictionaryDecodingContext

    // Both are accessed without the exclusivity checks that every access to a stored property of a class makes,
    // as no access lasts while anything else runs. They are kept apart, as the component is read
    // while the state changes, such as when a nested value of the component is decoded.
    internal var component: Any? {
        _read { yield uncheckedComponent }
        _modify { yield &uncheckedComponent }
    }

    internal var state: State {
        _read { yield uncheckedState }
        _modify { yield &uncheckedState }
    }

    internal var position: CodingPosition {
        position(at: .empty)
    }

    internal var codingPath: [CodingKey] {
        path
    }

    // Converted when read rather than for every call, which reads it rarely.
    internal var userInfo: [CodingUserInfoKey: Any] {
        context.options.userInfo
    }

    // MARK: - Initializers

    internal init(
        component: consuming Any?,
        context: DictionaryDecodingContext,
        parent: CodingPathNode?,
        key: CodingPathKey
    ) {
        self.uncheckedComponent = component
        self.context = context

        super.init(parent: parent, key: key)
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func makeNestedDecoder(from component: consuming Any?, at key: CodingPathKey) -> DictionaryValueDecoder {
        guard let decoder = state.reusableDecoder.take() else {
            return DictionaryValueDecoder(component: component, context: context, parent: self, key: key)
        }

        decoder.parent = self
        decoder.key = key
        decoder.component = consume component

        return decoder
    }

    @inline(__always)
    private func keepForReuse(_ decoder: inout DictionaryValueDecoder) {
        // A decoder that anything else still refers to, such as a stored container, is left to it.
        guard isKnownUniquelyReferenced(&decoder) else {
            return
        }

        // A kept decoder does not refer back, so that the decoders do not retain each other.
        decoder.parent = nil

        state.reusableDecoder = decoder
    }

    // MARK: -

    /// Decodes a nested value with a decoder of its own, the one kept from the last nested value if there is one.
    @inline(__always)
    internal func decodeNestedValue<T>(
        from component: consuming Any?,
        at key: CodingPathKey,
        decoding: (_ decoder: DictionaryValueDecoder) throws -> T
    ) throws -> T {
        var decoder = makeNestedDecoder(from: component, at: key)
        let value = try decoding(decoder)

        keepForReuse(&decoder)

        return value
    }

    /// The decoder of a nested container or a super decoder, which is not reused, as the caller keeps it.
    internal func nestedDecoder(from component: Any?, at key: CodingPathKey) -> DictionaryValueDecoder {
        DictionaryValueDecoder(component: component, context: context, parent: self, key: key)
    }

    // MARK: - Decoder

    internal func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let components = DictionaryKeyedComponents(component) else {
            throw DecodingError.keyedContainerTypeMismatch(at: self, component: component)
        }

        return KeyedDecodingContainer(DictionaryKeyedDecodingContainer<Key>(decoder: self, components: components))
    }

    internal func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let components = DictionaryUnkeyedComponents(component) else {
            throw DecodingError.unkeyedContainerTypeMismatch(at: self, component: component)
        }

        state.unkeyedComponents = components

        return DictionaryUnkeyedDecodingContainer(decoder: self, count: components.count)
    }

    internal func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }

    // MARK: - SingleValueDecodingContainer

    internal func decodeNil() -> Bool {
        decodeNil(from: component)
    }

    internal func decode(_ type: Bool.Type) throws -> Bool {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int.Type) throws -> Int {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int8.Type) throws -> Int8 {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int16.Type) throws -> Int16 {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int32.Type) throws -> Int32 {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int64.Type) throws -> Int64 {
        try decodePrimitive(type, from: component, at: position)
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type) throws -> Int128 {
        try decodeWideInteger(type, from: component, at: position)
    }

    internal func decode(_ type: UInt.Type) throws -> UInt {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodePrimitive(type, from: component, at: position)
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type) throws -> UInt128 {
        try decodeWideInteger(type, from: component, at: position)
    }

    internal func decode(_ type: Double.Type) throws -> Double {
        try decodeFloatingPoint(type, from: component, at: position)
    }

    internal func decode(_ type: Float.Type) throws -> Float {
        try decodeFloatingPoint(type, from: component, at: position)
    }

    internal func decode(_ type: String.Type) throws -> String {
        try decodePrimitive(type, from: component, at: position)
    }

    internal func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decode(type, from: component, at: .empty)
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension DecodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func keyedContainerTypeMismatch(at node: CodingPathNode, component: Any?) -> any Error {
        let debugDescription: String

        switch component {
        case let value?:
            debugDescription = "Expected to decode \([String: Any].self) but found \(type(of: value)) instead."

        case nil:
            debugDescription = "Cannot get keyed decoding container -- found null value instead."
        }

        let context = Context(codingPath: node.path, debugDescription: debugDescription)

        return Self.typeMismatch([String: Any].self, context)
    }

    @inline(never)
    fileprivate static func unkeyedContainerTypeMismatch(at node: CodingPathNode, component: Any?) -> any Error {
        let debugDescription: String

        switch component {
        case let value?:
            debugDescription = "Expected to decode \([Any].self) but found \(type(of: value)) instead."

        case nil:
            debugDescription = "Cannot get unkeyed decoding container -- found null value instead."
        }

        let context = Context(codingPath: node.path, debugDescription: debugDescription)

        return Self.typeMismatch([Any].self, context)
    }
}

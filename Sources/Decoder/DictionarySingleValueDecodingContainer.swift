/// The decoder of a value, which is its single value container as well.
///
/// Every nested value is decoded with a decoder of its own, so the decoder is the node of the coding path
/// of its value too, which the containers of the value point at.
internal final class DictionarySingleValueDecodingContainer:
    CodingPathNode,
    Decoder,
    SingleValueDecodingContainer {

    // MARK: - Instance Properties

    internal let component: Any?
    internal let context: DictionaryComponentDecoder

    internal var codingPath: [CodingKey] {
        path
    }

    internal var userInfo: [CodingUserInfoKey: Any] {
        context.userInfo
    }

    internal var position: CodingPosition {
        CodingPosition(node: self, key: .empty)
    }

    // MARK: - Initializers

    internal init(
        component: Any?,
        context: DictionaryComponentDecoder,
        parent: CodingPathNode?,
        key: CodingPathKey
    ) {
        self.component = component
        self.context = context

        super.init(parent: parent, key: key)
    }

    internal convenience init(component: Any?, context: DictionaryComponentDecoder, position: CodingPosition) {
        self.init(component: component, context: context, parent: position.node, key: position.key)
    }

    // MARK: - Instance Methods

    internal func decodeNil() -> Bool {
        context.decodeNilComponent(from: component)
    }

    internal func decode(_ type: Bool.Type) throws -> Bool {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int.Type) throws -> Int {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int8.Type) throws -> Int8 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int16.Type) throws -> Int16 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int32.Type) throws -> Int32 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: Int64.Type) throws -> Int64 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type) throws -> Int128 {
        try context.decodeWideInteger(type, from: component, at: position)
    }

    internal func decode(_ type: UInt.Type) throws -> UInt {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt8.Type) throws -> UInt8 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt16.Type) throws -> UInt16 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt32.Type) throws -> UInt32 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode(_ type: UInt64.Type) throws -> UInt64 {
        try context.decodePrimitive(type, from: component, at: position)
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type) throws -> UInt128 {
        try context.decodeWideInteger(type, from: component, at: position)
    }

    internal func decode(_ type: Double.Type) throws -> Double {
        try context.decodeFloatingPoint(type, from: component, at: position)
    }

    internal func decode(_ type: Float.Type) throws -> Float {
        try context.decodeFloatingPoint(type, from: component, at: position)
    }

    internal func decode(_ type: String.Type) throws -> String {
        try context.decodePrimitive(type, from: component, at: position)
    }

    internal func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try context.decode(type, from: component, at: position)
    }

    // MARK: - Decoder

    internal func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let components = DictionaryKeyedComponents(component) else {
            throw DecodingError.keyedContainerTypeMismatch(at: codingPath, component: component)
        }

        return KeyedDecodingContainer(DictionaryKeyedDecodingContainer<Key>(decoder: self, components: components))
    }

    internal func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let components = DictionaryUnkeyedComponents(component) else {
            throw DecodingError.unkeyedContainerTypeMismatch(at: codingPath, component: component)
        }

        return DictionaryUnkeyedDecodingContainer(decoder: self, components: components)
    }

    internal func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension DecodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func keyedContainerTypeMismatch(
        at codingPath: [CodingKey],
        component: Any?
    ) -> any Error {
        let debugDescription: String

        switch component {
        case let value?:
            debugDescription = "Expected to decode \([String: Any].self) but found \(type(of: value)) instead."

        case nil:
            debugDescription = "Cannot get keyed decoding container -- found null value instead."
        }

        let context = Context(codingPath: codingPath, debugDescription: debugDescription)

        return Self.typeMismatch([String: Any].self, context)
    }

    @inline(never)
    fileprivate static func unkeyedContainerTypeMismatch(
        at codingPath: [CodingKey],
        component: Any?
    ) -> any Error {
        let debugDescription: String

        switch component {
        case let value?:
            debugDescription = "Expected to decode \([Any].self) but found \(type(of: value)) instead."

        case nil:
            debugDescription = "Cannot get unkeyed decoding container -- found null value instead."
        }

        let context = Context(codingPath: codingPath, debugDescription: debugDescription)

        return Self.typeMismatch([Any].self, context)
    }
}

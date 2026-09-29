import Foundation

internal final class DictionarySingleValueDecodingContainer:
    Decoder,
    SingleValueDecodingContainer {

    // MARK: - Instance Properties

    internal let component: Any?
    internal let context: DictionaryComponentDecoder
    internal let codingPathNode: CodingPathNode

    internal var codingPath: [CodingKey] {
        codingPathNode.path
    }

    internal var userInfo: [CodingUserInfoKey: Any] {
        context.userInfo
    }

    // MARK: - Initializers

    internal init(
        component: Any?,
        context: DictionaryComponentDecoder,
        codingPathNode: CodingPathNode
    ) {
        self.component = component
        self.context = context
        self.codingPathNode = codingPathNode
    }

    // MARK: - Instance Methods

    internal func decodeNil() -> Bool {
        context.decodeNilComponent(from: component)
    }

    internal func decode(_ type: Bool.Type) throws -> Bool {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Int.Type) throws -> Int {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Int8.Type) throws -> Int8 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Int16.Type) throws -> Int16 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Int32.Type) throws -> Int32 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Int64.Type) throws -> Int64 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type) throws -> Int128 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: UInt.Type) throws -> UInt {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: UInt8.Type) throws -> UInt8 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: UInt16.Type) throws -> UInt16 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: UInt32.Type) throws -> UInt32 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: UInt64.Type) throws -> UInt64 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type) throws -> UInt128 {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Double.Type) throws -> Double {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: Float.Type) throws -> Float {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode(_ type: String.Type) throws -> String {
        try context.decodeComponentValue(from: component, at: codingPathNode)
    }

    internal func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try context.decodeComponentValue(of: type, from: component, at: codingPathNode)
    }

    // MARK: - Decoder

    internal func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let components = DictionaryKeyedComponents(component) else {
            throw DecodingError.keyedContainerTypeMismatch(at: codingPath, component: component)
        }

        let container = DictionaryKeyedDecodingContainer<Key>(
            components: components,
            context: context,
            codingPathNode: codingPathNode
        )

        return KeyedDecodingContainer(container)
    }

    internal func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let components = component as? [Any?] else {
            throw DecodingError.unkeyedContainerTypeMismatch(at: codingPath, component: component)
        }

        return DictionaryUnkeyedDecodingContainer(
            components: components,
            context: context,
            codingPathNode: codingPathNode
        )
    }

    internal func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }
}

extension DecodingError {

    // MARK: - Type Methods

    fileprivate static func keyedContainerTypeMismatch(
        at codingPath: [CodingKey],
        component: Any?
    ) -> Self {
        let debugDescription: String

        switch component {
        case let value?:
            debugDescription = "Expected to decode \([String: Any].self) but found \(type(of: value)) instead."

        case nil:
            debugDescription = "Cannot get keyed decoding container -- found null value instead."
        }

        return .typeMismatch([String: Any].self, Context(codingPath: codingPath, debugDescription: debugDescription))
    }

    fileprivate static func unkeyedContainerTypeMismatch(
        at codingPath: [CodingKey],
        component: Any?
    ) -> Self {
        let debugDescription: String

        switch component {
        case let value?:
            debugDescription = "Expected to decode \([Any].self) but found \(type(of: value)) instead."

        case nil:
            debugDescription = "Cannot get unkeyed decoding container -- found null value instead."
        }

        return .typeMismatch([Any].self, Context(codingPath: codingPath, debugDescription: debugDescription))
    }
}

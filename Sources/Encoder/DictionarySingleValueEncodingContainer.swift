import Foundation

internal final class DictionarySingleValueEncodingContainer:
    Encoder,
    SingleValueEncodingContainer,
    DictionaryComponentContainer {

    // MARK: - Instance Properties

    private var component: DictionaryComponent?

    internal let context: DictionaryComponentEncoder
    internal let codingPathNode: CodingPathNode

    internal var codingPath: [CodingKey] {
        codingPathNode.path
    }

    internal var userInfo: [CodingUserInfoKey: Any] {
        context.userInfo
    }

    // MARK: - Initializers

    internal init(
        context: DictionaryComponentEncoder,
        codingPathNode: CodingPathNode
    ) {
        self.context = context
        self.codingPathNode = codingPathNode
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func collectComponent(_ component: consuming DictionaryComponent, for value: Any?) throws {
        guard self.component == nil else {
            let errorContext = EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Single value container already has encoded value"
            )

            throw EncodingError.invalidValue(value as Any, errorContext)
        }

        self.component = component
    }

    // MARK: - SingleValueEncodingContainer

    internal func encodeNil() throws {
        try collectComponent(context.encodeNilComponent(at: codingPathNode), for: nil)
    }

    internal func encode(_ value: Bool) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Int) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Int8) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Int16) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Int32) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Int64) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: UInt) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: UInt8) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: UInt16) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: UInt32) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: UInt64) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Double) throws {
        try collectComponent(try context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: Float) throws {
        try collectComponent(try context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode(_ value: String) throws {
        try collectComponent(context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        try collectComponent(try context.encodeComponentValue(value, at: codingPathNode), for: value)
    }

    // MARK: - Encoder

    internal func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
        if case let .container(container as DictionaryAnyKeyedEncodingContainer) = component {
            return KeyedEncodingContainer(
                DictionaryKeyedEncodingContainer<Key>(container: container)
            )
        }

        let container = DictionaryAnyKeyedEncodingContainer(
            context: context,
            codingPathNode: codingPathNode
        )

        component = .container(container)

        return KeyedEncodingContainer(
            DictionaryKeyedEncodingContainer<Key>(container: container)
        )
    }

    internal func unkeyedContainer() -> UnkeyedEncodingContainer {
        if case let .container(container as DictionaryUnkeyedEncodingContainer) = component {
            return container
        }

        let container = DictionaryUnkeyedEncodingContainer(
            context: context,
            codingPathNode: codingPathNode
        )

        component = .container(container)

        return container
    }

    internal func singleValueContainer() -> SingleValueEncodingContainer {
        self
    }

    // MARK: - DictionaryComponentContainer

    internal func resolveValue() -> Any? {
        component?.resolveValue()
    }
}

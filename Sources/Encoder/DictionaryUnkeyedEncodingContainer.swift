internal final class DictionaryUnkeyedEncodingContainer:
    UnkeyedEncodingContainer,
    DictionaryComponentContainer {

    // MARK: - Instance Properties

    // Values are stored resolved, only nested containers are resolved along with the whole container.
    private var values: [Any] = []
    private var containers: [(index: Int, container: DictionaryComponentContainer)] = []

    internal let context: DictionaryComponentEncoder
    internal let codingPathNode: CodingPathNode

    internal var codingPath: [CodingKey] {
        codingPathNode.path
    }

    @inline(__always)
    internal var currentPosition: CodingPosition {
        CodingPosition(container: codingPathNode, key: .index(count))
    }

    internal var count: Int {
        values.count
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

    // `[Any]` cannot hold `nil` itself, so `nil` is kept as an element wrapped in `Any`.
    @inline(__always)
    private func element(from value: Any?) -> Any {
        value ?? value as Any
    }

    @inline(__always)
    private func collectComponent(_ component: consuming DictionaryComponent) {
        switch component {
        case let .value(value):
            values.append(element(from: value))

        case let .container(container):
            containers.append((values.count, container))

            // A placeholder that is replaced with the resolved value of the container.
            values.append(container)
        }
    }

    // MARK: - UnkeyedEncodingContainer

    internal func encodeNil() throws {
        collectComponent(context.encodeNilComponent(at: currentPosition))
    }

    internal func encode(_ value: Bool) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Int) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Int8) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Int16) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Int32) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Int64) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: UInt) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: UInt8) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: UInt16) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: UInt32) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: UInt64) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Double) throws {
        collectComponent(try context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: Float) throws {
        collectComponent(try context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode(_ value: String) throws {
        collectComponent(context.encodeComponentValue(value, at: currentPosition))
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        collectComponent(try context.encodeComponentValue(value, at: currentPosition))
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let container = DictionaryAnyKeyedEncodingContainer(
            context: context,
            codingPathNode: CodingPathNode(position: currentPosition)
        )

        collectComponent(.container(container))

        return KeyedEncodingContainer(
            DictionaryKeyedEncodingContainer<NestedKey>(container: container)
        )
    }

    internal func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = DictionaryUnkeyedEncodingContainer(
            context: context,
            codingPathNode: CodingPathNode(position: currentPosition)
        )

        collectComponent(.container(container))

        return container
    }

    internal func superEncoder() -> Encoder {
        let encoder = DictionarySingleValueEncodingContainer(
            context: context,
            position: currentPosition
        )

        collectComponent(.container(encoder))

        return encoder
    }

    // MARK: - DictionaryComponentContainer

    internal func resolveValue() -> Any? {
        for (index, container) in containers {
            values[index] = element(from: container.resolveValue())
        }

        return values
    }
}

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

    @inline(__always)
    private func append(_ element: consuming Any) {
        values.append(element)
    }

    // `[Any]` cannot hold `nil` itself, so `nil` is kept as an element wrapped in `Any`.
    @inline(__always)
    private func element(from component: Any?) -> Any {
        component ?? component as Any
    }

    @inline(__always)
    private func collect(_ component: Any?) {
        append(element(from: component))
    }

    private func collect<Container: DictionaryComponentContainer>(_ container: Container) -> Container {
        containers.append((values.count, container))

        // A placeholder that is replaced with the resolved value of the container.
        append(container)

        return container
    }

    // MARK: - UnkeyedEncodingContainer

    internal func encodeNil() throws {
        collect(context.encodeNil())
    }

    internal func encode(_ value: Bool) throws {
        collect(value)
    }

    internal func encode(_ value: Int) throws {
        collect(value)
    }

    internal func encode(_ value: Int8) throws {
        collect(value)
    }

    internal func encode(_ value: Int16) throws {
        collect(value)
    }

    internal func encode(_ value: Int32) throws {
        collect(value)
    }

    internal func encode(_ value: Int64) throws {
        collect(value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128) throws {
        collect(value)
    }

    internal func encode(_ value: UInt) throws {
        collect(value)
    }

    internal func encode(_ value: UInt8) throws {
        collect(value)
    }

    internal func encode(_ value: UInt16) throws {
        collect(value)
    }

    internal func encode(_ value: UInt32) throws {
        collect(value)
    }

    internal func encode(_ value: UInt64) throws {
        collect(value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128) throws {
        collect(value)
    }

    internal func encode(_ value: Double) throws {
        collect(try context.encodeFloatingPoint(value, at: currentPosition))
    }

    internal func encode(_ value: Float) throws {
        collect(try context.encodeFloatingPoint(value, at: currentPosition))
    }

    internal func encode(_ value: String) throws {
        collect(value)
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        collect(try context.encode(value, at: currentPosition))
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let container = DictionaryAnyKeyedEncodingContainer(
            context: context,
            codingPathNode: CodingPathNode(position: currentPosition)
        )

        return KeyedEncodingContainer(DictionaryKeyedEncodingContainer<NestedKey>(container: collect(container)))
    }

    internal func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = DictionaryUnkeyedEncodingContainer(
            context: context,
            codingPathNode: CodingPathNode(position: currentPosition)
        )

        return collect(container)
    }

    internal func superEncoder() -> Encoder {
        collect(DictionarySingleValueEncodingContainer(context: context, position: currentPosition))
    }

    // MARK: - DictionaryComponentContainer

    internal func resolveValue() -> Any? {
        for (index, container) in containers {
            values[index] = element(from: container.resolveValue())
        }

        return values
    }
}

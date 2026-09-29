internal final class DictionaryUnkeyedEncodingContainer:
    UnkeyedEncodingContainer,
    DictionaryComponentContainer {

    // MARK: - Nested Types

    // Accesses to the stored properties of a class are checked for exclusivity at run time,
    // so the elements are kept in one property, which every change accesses once.
    fileprivate struct Elements {

        // MARK: - Type Methods

        // `[Any]` cannot hold `nil` itself, so `nil` is kept as an element wrapped in `Any`.
        @inline(always)
        private static func element(from component: consuming Any?) -> Any {
            switch consume component {
            case let value?:
                value

            case nil:
                Optional<Any>.none as Any
            }
        }

        // MARK: - Instance Properties

        // Values are stored resolved, only nested containers are resolved along with the whole container.
        fileprivate private(set) var values: [Any] = []
        private var containers: [(index: Int, container: DictionaryComponentContainer)] = []

        // MARK: - Instance Methods

        @inline(always)
        private mutating func append(_ element: consuming Any) {
            // Most unkeyed containers of compact encodings hold a couple of elements, so room for two is reserved
            // up front. It saves a reallocation for every container of two and more elements, which grow as usual,
            // and costs memory only for containers of one element.
            if values.isEmpty {
                values.reserveCapacity(2)
            }

            values.append(element)
        }

        @inline(always)
        fileprivate mutating func append(component: consuming Any?) {
            append(Self.element(from: component))
        }

        fileprivate mutating func append(container: DictionaryComponentContainer) {
            containers.append((values.count, container))

            // A placeholder that is replaced with the resolved value of the container.
            append(container)
        }

        fileprivate consuming func resolveValues() -> [Any] {
            for (index, container) in containers {
                values[index] = Self.element(from: container.resolveValue())
            }

            return values
        }
    }

    // MARK: - Instance Properties

    private var elements = Elements()

    internal let context: DictionaryComponentEncoder
    internal let codingPathNode: CodingPathNode

    internal var codingPath: [CodingKey] {
        codingPathNode.path
    }

    @inline(always)
    internal var currentPosition: CodingPosition {
        CodingPosition(container: codingPathNode, key: .index(count))
    }

    internal var count: Int {
        elements.values.count
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

    @inline(always)
    private func collect(_ component: consuming Any?) {
        elements.append(component: component)
    }

    private func collect<Container: DictionaryComponentContainer>(_ container: Container) -> Container {
        elements.append(container: container)

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

    // The values are taken rather than copied, as a container is resolved once, along with the value it encodes.
    internal func resolveValue() -> Any? {
        var elements = Elements()

        swap(&elements, &self.elements)

        return elements.resolveValues()
    }
}

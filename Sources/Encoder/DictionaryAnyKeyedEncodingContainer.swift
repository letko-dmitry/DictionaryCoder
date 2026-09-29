internal final class DictionaryAnyKeyedEncodingContainer: DictionaryComponentContainer {

    // MARK: - Instance Properties

    // Values are stored resolved, only nested containers are resolved along with the whole container.
    private var values: [String: Any] = [:]
    private var containers: [String: DictionaryComponentContainer] = [:]

    internal let context: DictionaryComponentEncoder
    internal let codingPathNode: CodingPathNode

    internal var codingPath: [CodingKey] {
        codingPathNode.path
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
    private func encodeKey<Key: CodingKey>(_ key: Key) -> String {
        switch context.options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue

        case let .custom(closure):
            return closure(position(of: key).path).stringValue
        }
    }

    private func collect(_ container: DictionaryComponentContainer, forEncodedKey key: String) {
        values[key] = nil
        containers[key] = container
    }

    /// The nested container of the kind that is stored for the key, or a new one that replaces what is stored for it.
    private func nestedContainer<Key: CodingKey, Container: DictionaryComponentContainer>(
        forKey key: Key,
        makeContainer: (_ position: CodingPosition) -> Container
    ) -> Container {
        let encodedKey = encodeKey(key)

        if let container = containers[encodedKey] as? Container {
            return container
        }

        let container = makeContainer(position(of: key))

        collect(container, forEncodedKey: encodedKey)

        return container
    }

    // MARK: -

    @inline(__always)
    internal func position(of key: CodingKey) -> CodingPosition {
        CodingPosition(container: codingPathNode, key: .key(key))
    }

    @inline(__always)
    internal func collect<Key: CodingKey>(_ component: consuming Any?, forKey key: Key) {
        let key = encodeKey(key)

        if !containers.isEmpty {
            containers[key] = nil
        }

        values[key] = component
    }

    internal func nestedContainer<Key: CodingKey>(forKey key: Key) -> DictionaryAnyKeyedEncodingContainer {
        nestedContainer(forKey: key) { position in
            DictionaryAnyKeyedEncodingContainer(context: context, codingPathNode: CodingPathNode(position: position))
        }
    }

    internal func nestedUnkeyedContainer<Key: CodingKey>(forKey key: Key) -> DictionaryUnkeyedEncodingContainer {
        nestedContainer(forKey: key) { position in
            DictionaryUnkeyedEncodingContainer(context: context, codingPathNode: CodingPathNode(position: position))
        }
    }

    internal func superEncoder<Key: CodingKey>(forKey key: Key) -> DictionarySingleValueEncodingContainer {
        nestedContainer(forKey: key) { position in
            DictionarySingleValueEncodingContainer(context: context, position: position)
        }
    }

    // MARK: - DictionaryComponentContainer

    // The values are taken rather than copied, as a container is resolved once, along with the value it encodes.
    internal func resolveValue() -> Any? {
        var values: [String: Any] = [:]

        swap(&values, &self.values)

        for (key, container) in containers {
            values[key] = container.resolveValue()
        }

        return values
    }
}

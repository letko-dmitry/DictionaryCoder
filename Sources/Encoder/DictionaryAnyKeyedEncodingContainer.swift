import Foundation

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
            return closure(codingPathNode.appending(key).path).stringValue
        }
    }

    // MARK: -

    @inline(__always)
    internal func collectComponent<Key: CodingKey>(_ component: consuming DictionaryComponent, forKey key: Key) {
        let key = encodeKey(key)

        switch component {
        case let .value(value):
            if !containers.isEmpty {
                containers[key] = nil
            }

            values[key] = value

        case let .container(container):
            values[key] = nil
            containers[key] = container
        }
    }

    internal func nestedContainer<Key: CodingKey, NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> DictionaryAnyKeyedEncodingContainer {
        if let container = containers[encodeKey(key)] as? Self {
            return container
        }

        let container = DictionaryAnyKeyedEncodingContainer(
            context: context,
            codingPathNode: codingPathNode.appending(key)
        )

        collectComponent(.container(container), forKey: key)

        return container
    }

    internal func nestedUnkeyedContainer<Key: CodingKey>(forKey key: Key) -> UnkeyedEncodingContainer {
        if let container = containers[encodeKey(key)] as? DictionaryUnkeyedEncodingContainer {
            return container
        }

        let container = DictionaryUnkeyedEncodingContainer(
            context: context,
            codingPathNode: codingPathNode.appending(key)
        )

        collectComponent(.container(container), forKey: key)

        return container
    }

    internal func superEncoder<Key: CodingKey>(forKey key: Key) -> Encoder {
        if let container = containers[encodeKey(key)] as? DictionarySingleValueEncodingContainer {
            return container
        }

        let encoder = DictionarySingleValueEncodingContainer(
            context: context,
            codingPathNode: codingPathNode.appending(key)
        )

        collectComponent(.container(encoder), forKey: key)

        return encoder
    }

    // MARK: - DictionaryComponentContainer

    internal func resolveValue() -> Any? {
        var values = values

        for (key, container) in containers {
            values[key] = container.resolveValue()
        }

        return values
    }
}

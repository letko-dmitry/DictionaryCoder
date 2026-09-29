import Foundation

internal final class DictionaryAnyKeyedEncodingContainer: DictionaryComponentContainer {

    // MARK: - Instance Properties

    private var components: [String: DictionaryComponent] = [:]

    internal let context: DictionaryComponentEncoder
    internal let codingPath: [CodingKey]

    // MARK: - Initializers

    internal init(
        context: DictionaryComponentEncoder,
        codingPath: [CodingKey]
    ) {
        self.context = context
        self.codingPath = codingPath
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func encodeKey<Key: CodingKey>(_ key: Key) -> String {
        switch context.options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue

        case let .custom(closure):
            return closure(codingPath.appending(key)).stringValue
        }
    }

    // MARK: -

    @inline(__always)
    internal func collectComponent<Key: CodingKey>(_ component: consuming DictionaryComponent, forKey key: Key) {
        components[encodeKey(key)] = component
    }

    internal func nestedContainer<Key: CodingKey, NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> DictionaryAnyKeyedEncodingContainer {
        if case let .container(container as Self) = components[encodeKey(key)] {
            return container
        }

        let container = DictionaryAnyKeyedEncodingContainer(
            context: context,
            codingPath: codingPath.appending(key)
        )

        collectComponent(.container(container), forKey: key)

        return container
    }

    internal func nestedUnkeyedContainer<Key: CodingKey>(forKey key: Key) -> UnkeyedEncodingContainer {
        if case let .container(container as DictionaryUnkeyedEncodingContainer) = components[encodeKey(key)] {
            return container
        }

        let container = DictionaryUnkeyedEncodingContainer(
            context: context,
            codingPath: codingPath.appending(key)
        )

        collectComponent(.container(container), forKey: key)

        return container
    }

    internal func superEncoder<Key: CodingKey>(forKey key: Key) -> Encoder {
        if case let .container(container as DictionarySingleValueEncodingContainer) = components[encodeKey(key)] {
            return container
        }

        let encoder = DictionarySingleValueEncodingContainer(
            context: context,
            codingPath: codingPath.appending(key)
        )

        collectComponent(.container(encoder), forKey: key)

        return encoder
    }

    // MARK: - DictionaryComponentContainer

    internal func resolveValue() -> Any? {
        components.compactMapValues { $0.resolveValue() }
    }
}

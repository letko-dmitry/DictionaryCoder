internal struct DictionaryKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

    // MARK: - Instance Properties

    internal let container: DictionaryAnyKeyedEncodingContainer

    internal var context: DictionaryComponentEncoder {
        container.context
    }

    internal var codingPath: [CodingKey] {
        container.codingPath
    }

    // MARK: - Initializers

    internal init(container: DictionaryAnyKeyedEncodingContainer) {
        self.container = container
    }

    // MARK: - Instance Methods

    internal func encodeNil(forKey key: Key) throws {
        container.collect(context.encodeNil(), forKey: key)
    }

    internal func encode(_ value: Bool, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: Int, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: Int8, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: Int16, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: Int32, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: Int64, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: UInt, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: UInt8, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: UInt16, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: UInt32, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: UInt64, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode(_ value: Double, forKey key: Key) throws {
        container.collect(try context.encodeFloatingPoint(value, at: container.position(of: key)), forKey: key)
    }

    internal func encode(_ value: Float, forKey key: Key) throws {
        container.collect(try context.encodeFloatingPoint(value, at: container.position(of: key)), forKey: key)
    }

    internal func encode(_ value: String, forKey key: Key) throws {
        container.collect(value, forKey: key)
    }

    internal func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        container.collect(try context.encode(value, at: container.position(of: key)), forKey: key)
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        let container = container.nestedContainer(forKey: key)

        return KeyedEncodingContainer(DictionaryKeyedEncodingContainer<NestedKey>(container: container))
    }

    internal func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        container.nestedUnkeyedContainer(forKey: key)
    }

    internal func superEncoder(forKey key: Key) -> Encoder {
        container.superEncoder(forKey: key)
    }

    internal func superEncoder() -> Encoder {
        container.superEncoder(forKey: AnyCodingKey.super)
    }
}

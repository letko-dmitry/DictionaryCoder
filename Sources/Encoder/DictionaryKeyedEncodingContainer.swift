/// The kinds of nested encoders that a keyed container keeps for its keys.
internal enum DictionaryNestedEncoderKind {

    // MARK: - Enumeration Cases

    case keyedContainer
    case unkeyedContainer
    case superEncoder
}

/// The values of a keyed container.
internal struct DictionaryKeyedEncodingStorage {

    // MARK: - Instance Properties

    // Values are stored encoded, while the values of nested containers are taken along with the whole container.
    private var values: [String: Any] = [:]
    private var nestedEncoders: [String: (kind: DictionaryNestedEncoderKind, encoder: DictionaryValueEncoder)] = [:]

    // MARK: - Instance Methods

    internal mutating func reserveCapacity(_ capacity: Int) {
        values.reserveCapacity(capacity)
    }

    @inline(always)
    internal mutating func store(_ value: consuming Any?, forKey key: String) {
        if !nestedEncoders.isEmpty {
            nestedEncoders.removeValue(forKey: key)?.encoder.discard()
        }

        values[key] = value
    }

    internal mutating func store(
        _ encoder: DictionaryValueEncoder,
        as kind: DictionaryNestedEncoderKind,
        forKey key: String
    ) {
        values[key] = nil

        nestedEncoders.updateValue((kind, encoder), forKey: key)?.encoder.discard()
    }

    internal func nestedEncoder(forKey key: String, as kind: DictionaryNestedEncoderKind) -> DictionaryValueEncoder? {
        guard let nestedEncoder = nestedEncoders[key], nestedEncoder.kind == kind else {
            return nil
        }

        return nestedEncoder.encoder
    }

    /// Takes the values along with the values of nested containers, which leaves the storage empty.
    internal mutating func take() -> [String: Any] {
        var storage = Self()

        swap(&storage, &self)

        for (key, nestedEncoder) in storage.nestedEncoders {
            storage.values[key] = nestedEncoder.encoder.takeValue()
        }

        return storage.values
    }

    internal mutating func discard() {
        for nestedEncoder in nestedEncoders.values {
            nestedEncoder.encoder.discard()
        }

        self = Self()
    }
}

internal struct DictionaryKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

    // MARK: - Instance Properties

    internal let encoder: DictionaryValueEncoder

    internal var codingPath: [CodingKey] {
        encoder.codingPath
    }

    // MARK: - Initializers

    internal init(encoder: DictionaryValueEncoder) {
        self.encoder = encoder
    }

    // MARK: - Instance Methods

    @inline(always)
    private func store(_ value: consuming Any?, forKey key: Key) {
        // The key is encoded before the storage is accessed, as a custom strategy runs code of its own.
        let encodedKey = encoder.encodeKey(key)

        encoder.state.keyedValues.store(value, forKey: encodedKey)
    }

    // MARK: - KeyedEncodingContainerProtocol

    internal func encodeNil(forKey key: Key) throws {
        store(encoder.context.encodedNil, forKey: key)
    }

    internal func encode(_ value: Bool, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: Int, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: Int8, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: Int16, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: Int32, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: Int64, forKey key: Key) throws {
        store(value, forKey: key)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: UInt, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: UInt8, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: UInt16, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: UInt32, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: UInt64, forKey key: Key) throws {
        store(value, forKey: key)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode(_ value: Double, forKey key: Key) throws {
        store(try encoder.encodeFloatingPoint(value, at: CodingPosition(node: encoder, key: .key(key))), forKey: key)
    }

    internal func encode(_ value: Float, forKey key: Key) throws {
        store(try encoder.encodeFloatingPoint(value, at: CodingPosition(node: encoder, key: .key(key))), forKey: key)
    }

    internal func encode(_ value: String, forKey key: Key) throws {
        store(value, forKey: key)
    }

    internal func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        store(try encoder.encode(value, at: .key(key)), forKey: key)
    }

    // Unlike the default implementations, which go through generic code for every type.
    internal func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    @available(watchOS 11.0, *)
    internal func encodeIfPresent(_ value: Int128?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    @available(watchOS 11.0, *)
    internal func encodeIfPresent(_ value: UInt128?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        }
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        encoder.nestedEncoder(forKey: key, as: .keyedContainer).container(keyedBy: keyType)
    }

    internal func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.nestedEncoder(forKey: key, as: .unkeyedContainer).unkeyedContainer()
    }

    internal func superEncoder() -> Encoder {
        encoder.nestedEncoder(forKey: AnyCodingKey.super, as: .superEncoder)
    }

    internal func superEncoder(forKey key: Key) -> Encoder {
        encoder.nestedEncoder(forKey: key, as: .superEncoder)
    }
}

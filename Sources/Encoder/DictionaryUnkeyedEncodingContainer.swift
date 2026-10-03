/// The values of an unkeyed container.
internal struct DictionaryUnkeyedEncodingStorage {

    // MARK: - Type Methods

    // `[Any]` cannot hold `nil` itself, so `nil` is kept as an element wrapped in `Any`.
    @inline(always)
    private static func element(from value: consuming Any?) -> Any {
        switch consume value {
        case let value?:
            value

        case nil:
            Optional<Any>.none as Any
        }
    }

    // MARK: - Instance Properties

    // Values are stored encoded, while the values of nested containers are taken along with the whole container,
    // in place of the elements that stand for them until then.
    private var values: [Any] = []
    private var nestedEncoders: [(index: Int, encoder: DictionaryValueEncoder)] = []

    internal var count: Int {
        values.count
    }

    // MARK: - Instance Methods

    @inline(always)
    internal mutating func append(_ value: consuming Any?) {
        // Most unkeyed containers of compact encodings hold a couple of elements, so room for two is reserved
        // up front. It saves a reallocation for every container of two and more elements, which grow as usual,
        // and costs memory only for containers of one element.
        if values.isEmpty {
            values.reserveCapacity(2)
        }

        values.append(Self.element(from: value))
    }

    internal mutating func append(_ encoder: DictionaryValueEncoder) {
        nestedEncoders.append((values.count, encoder))

        append(nil)
    }

    /// Takes the values along with the values of nested containers, which leaves the storage empty.
    internal mutating func take() -> [Any] {
        var storage = Self()

        swap(&storage, &self)

        for (index, encoder) in storage.nestedEncoders {
            storage.values[index] = Self.element(from: encoder.takeValue())
        }

        return storage.values
    }

    internal mutating func discard() {
        for (_, encoder) in nestedEncoders {
            encoder.discard()
        }

        self = Self()
    }
}

internal struct DictionaryUnkeyedEncodingContainer: UnkeyedEncodingContainer {

    // MARK: - Instance Properties

    internal let encoder: DictionaryValueEncoder

    internal var codingPath: [CodingKey] {
        encoder.codingPath
    }

    internal var count: Int {
        encoder.state.unkeyedValues.count
    }

    // MARK: - Initializers

    internal init(encoder: DictionaryValueEncoder) {
        self.encoder = encoder
    }

    // MARK: - Instance Methods

    @inline(always)
    private func append(_ value: consuming Any?) {
        encoder.state.unkeyedValues.append(value)
    }

    // MARK: - UnkeyedEncodingContainer

    internal func encodeNil() throws {
        append(encoder.context.encodedNil)
    }

    internal func encode(_ value: Bool) throws {
        append(value)
    }

    internal func encode(_ value: Int) throws {
        append(value)
    }

    internal func encode(_ value: Int8) throws {
        append(value)
    }

    internal func encode(_ value: Int16) throws {
        append(value)
    }

    internal func encode(_ value: Int32) throws {
        append(value)
    }

    internal func encode(_ value: Int64) throws {
        append(value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128) throws {
        append(value)
    }

    internal func encode(_ value: UInt) throws {
        append(value)
    }

    internal func encode(_ value: UInt8) throws {
        append(value)
    }

    internal func encode(_ value: UInt16) throws {
        append(value)
    }

    internal func encode(_ value: UInt32) throws {
        append(value)
    }

    internal func encode(_ value: UInt64) throws {
        append(value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128) throws {
        append(value)
    }

    internal func encode(_ value: Double) throws {
        append(try encoder.encodeFloatingPoint(value, at: CodingPosition(node: encoder, key: .index(count))))
    }

    internal func encode(_ value: Float) throws {
        append(try encoder.encodeFloatingPoint(value, at: CodingPosition(node: encoder, key: .index(count))))
    }

    internal func encode(_ value: String) throws {
        append(value)
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        append(try encoder.encode(value, at: .index(count)))
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        encoder.nestedEncoderForNextElement().container(keyedBy: keyType)
    }

    internal func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        encoder.nestedEncoderForNextElement().unkeyedContainer()
    }

    internal func superEncoder() -> Encoder {
        encoder.nestedEncoderForNextElement()
    }
}

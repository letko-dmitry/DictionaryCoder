/// The values of an unkeyed container.
internal struct DictionaryUnkeyedEncodingStorage {

    // MARK: - Type Properties

    // Most unkeyed containers of compact encodings hold a couple of elements, so room for two is reserved
    // even when the last ones held fewer: it saves a reallocation for every container of two and more elements.
    private static let minimumCapacityHint: UInt8 = 2

    // Unkeyed containers of an encoder mostly hold as many values as its last ones, as the arrays of the elements
    // of an array do, so the capacity hint is limited to keep large arrays from wasting memory in small ones,
    // as the hint of keyed containers in the encoder is.
    private static let maximumCapacityHint = 16

    // MARK: - Type Methods

    // `[Any]` cannot hold `nil` itself, so `nil` is kept as an element wrapped in `Any`.
    @inline(always)
    private static func element(from value: consuming Any?) -> Any {
        switch consume value {
        case let value?:
            value

        case nil:
            Any?.none as Any
        }
    }

    // MARK: - Instance Properties

    // Values are stored encoded, while the values of nested containers are taken along with the whole container,
    // in place of the elements that stand for them until then.
    private var values: [Any] = []
    private var nestedEncoders: [(index: Int, encoder: DictionaryValueEncoder)] = []

    /// The capacity that the first value reserves: as many values as the last two containers held at least,
    /// so that a container of as many values does not grow while it is filled, and room for two otherwise.
    /// Both counts are bytes, as they are limited anyway, so that the storage grows by one word rather than two.
    private var capacityHint = Self.minimumCapacityHint
    private var lastCount: UInt8 = 0

    internal var count: Int {
        values.count
    }

    // MARK: - Instance Methods

    @inline(always)
    internal mutating func append(_ value: consuming Any?) {
        // Reserved with the first value rather than with the container, so that empty containers allocate nothing.
        if values.isEmpty {
            values.reserveCapacity(Int(capacityHint))
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

        let heldCount = UInt8(min(storage.values.count, Self.maximumCapacityHint))

        capacityHint = max(min(heldCount, storage.lastCount), Self.minimumCapacityHint)
        lastCount = heldCount

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

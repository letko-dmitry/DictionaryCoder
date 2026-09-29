import Foundation

/// Components of a keyed container. Foundation dictionaries, such as the ones from `JSONSerialization`
/// or property lists, are read in place, as converting one to `[String: Any]` bridges all of its keys up front.
internal enum DictionaryKeyedComponents {

    // MARK: - Enumeration Cases

    case native([String: Any])
    case foundation(NSDictionary)

    // MARK: - Instance Properties

    internal var count: Int {
        switch self {
        case let .native(components):
            components.count

        case let .foundation(components):
            components.count
        }
    }

    internal var keysAndValues: [(key: String, value: Any)] {
        switch self {
        case let .native(components):
            Array(components)

        case let .foundation(components):
            components.compactMap { key, value in (key as? String).map { ($0, value) } }
        }
    }

    // MARK: - Initializers

    internal init?(_ component: Any?) {
        guard let component else {
            return nil
        }

        // Checking the type first, as `as? [String: Any]` would bridge a Foundation dictionary as a whole.
        if type(of: component) is NSDictionary.Type, let components = component as? NSDictionary {
            self = .foundation(components)
        } else if let components = component as? [String: Any] {
            self = .native(components)
        } else {
            return nil
        }
    }

    // MARK: - Instance Methods

    internal func forEach(_ body: (_ key: String, _ component: Any) throws -> Void) rethrows {
        switch self {
        case let .native(components):
            for (key, component) in components {
                try body(key, component)
            }

        case let .foundation(components):
            for (key, component) in components {
                if let key = key as? String {
                    try body(key, component)
                }
            }
        }
    }

    internal func compactMapKeys<T>(_ transform: (_ key: String) -> T?) -> [T] {
        switch self {
        case let .native(components):
            components.keys.compactMap(transform)

        case let .foundation(components):
            components.allKeys.compactMap { ($0 as? String).flatMap(transform) }
        }
    }

    // MARK: - Subscripts

    @inline(__always)
    internal subscript(key: String) -> Any? {
        switch self {
        case let .native(components):
            components[key]

        case let .foundation(components):
            components.object(forKey: key)
        }
    }
}

// A class rather than a structure, as `KeyedDecodingContainer` copies a structure for every call,
// which retains each of its references.
internal final class DictionaryKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

    // MARK: - Instance Properties

    /// The decoder of the dictionary, which is the node of the coding path of its values.
    internal let decoder: DictionarySingleValueDecodingContainer
    internal let components: DictionaryKeyedComponents

    internal var context: DictionaryComponentDecoder {
        decoder.context
    }

    internal var codingPath: [CodingKey] {
        decoder.codingPath
    }

    internal var allKeys: [Key] {
        components.compactMapKeys(Key.init(stringValue:))
    }

    // MARK: - Initializers

    internal init(decoder: DictionarySingleValueDecodingContainer, components: DictionaryKeyedComponents) {
        switch decoder.context.options.keyDecodingStrategy {
        case .useDefaultKeys:
            self.components = components

        case let .custom(closure):
            let codingPath = decoder.codingPath
            let componentKeysAndValues = components.keysAndValues
                .sorted { $0.key < $1.key }
                .map { key, value in (closure(codingPath.appending(AnyCodingKey(key))).stringValue, value) }

            self.components = .native(Dictionary(componentKeysAndValues) { first, _ in first })
        }

        self.decoder = decoder
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func position(of key: CodingKey) -> CodingPosition {
        CodingPosition(container: decoder, key: .key(key))
    }

    // Unlike the default implementation of `decodeIfPresent`, looks the key up once rather than in `contains`,
    // `decodeNil` and `decode`.
    @inline(__always)
    private func decodeIfPresent<T>(forKey key: Key, _ decode: (_ component: Any) throws -> T) rethrows -> T? {
        guard let component = components[key.stringValue], !context.decodeNilComponent(from: component) else {
            return nil
        }

        return try decode(component)
    }

    @inline(__always)
    private func superDecoder(forAnyKey key: CodingKey) -> DictionarySingleValueDecodingContainer {
        DictionarySingleValueDecodingContainer(
            component: components[key.stringValue],
            context: context,
            position: position(of: key)
        )
    }

    // MARK: - KeyedDecodingContainerProtocol

    internal func contains(_ key: Key) -> Bool {
        components[key.stringValue] != nil
    }

    // A missing key decodes as `nil`, as it always has.
    internal func decodeNil(forKey key: Key) throws -> Bool {
        context.decodeNilComponent(from: components[key.stringValue])
    }

    internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
        try context.decodeWideInteger(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
        try context.decodeWideInteger(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try context.decodeFloatingPoint(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try context.decodeFloatingPoint(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try context.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try context.decode(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    @available(watchOS 11.0, *)
    internal func decodeIfPresent(_ type: Int128.Type, forKey key: Key) throws -> Int128? {
        try decodeIfPresent(forKey: key) { try context.decodeWideInteger(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    @available(watchOS 11.0, *)
    internal func decodeIfPresent(_ type: UInt128.Type, forKey key: Key) throws -> UInt128? {
        try decodeIfPresent(forKey: key) { try context.decodeWideInteger(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        try decodeIfPresent(forKey: key) { try context.decodeFloatingPoint(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        try decodeIfPresent(forKey: key) { try context.decodeFloatingPoint(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        try decodeIfPresent(forKey: key) { try context.decodePrimitive(type, from: $0, at: position(of: key)) }
    }

    internal func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        try decodeIfPresent(forKey: key) { try context.decode(type, from: $0, at: position(of: key)) }
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try superDecoder(forAnyKey: key).container(keyedBy: keyType)
    }

    internal func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try superDecoder(forAnyKey: key).unkeyedContainer()
    }

    internal func superDecoder(forKey key: Key) throws -> Decoder {
        superDecoder(forAnyKey: key)
    }

    internal func superDecoder() throws -> Decoder {
        superDecoder(forAnyKey: AnyCodingKey.super)
    }
}

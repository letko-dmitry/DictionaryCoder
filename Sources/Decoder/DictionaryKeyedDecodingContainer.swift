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

    // Takes the component unwrapped and borrowed, as unwrapping or passing an existential owned copies it.
    internal init?(_ component: borrowing Any) {
        let componentType = type(of: component)

        // Checking the type first, as `as? [String: Any]` would bridge a Foundation dictionary as a whole.
        if componentType == [String: Any].self {
            self = .native(unsafeCast(contentsOf: component, to: [String: Any].self))
        } else if componentType is NSDictionary.Type {
            self = .foundation(unsafeCast(contentsOf: component, to: NSDictionary.self))
        } else if let components = copy component as? [String: Any] {
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

    // A loop rather than `compactMap`, which goes through generic code for every key.
    internal func compactMapKeys<T>(_ transform: (_ key: String) -> T?) -> [T] {
        var values: [T] = []

        values.reserveCapacity(count)

        switch self {
        case let .native(components):
            for key in components.keys {
                if let value = transform(key) {
                    values.append(value)
                }
            }

        case let .foundation(components):
            for case let key as String in components.allKeys {
                if let value = transform(key) {
                    values.append(value)
                }
            }
        }

        return values
    }

    // MARK: - Subscripts

    // Unlike the rest, inlined by the optimizer rather than up front by `@inline(always)`,
    // which makes the lookups of optional values measurably slower.
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

// A structure of the decoder alone, which the box of `KeyedDecodingContainer` holds without allocating it
// and copies with one retain for every call, so the components are kept by the decoder of the dictionary.
internal struct DictionaryKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

    // MARK: - Instance Properties

    /// The decoder of the dictionary, which is the node of the coding path of its values.
    internal let decoder: DictionaryValueDecoder

    // The decoder keeps the components from the creation of the container.
    @inline(always)
    internal var components: DictionaryKeyedComponents {
        unsafe decoder.state.keyedComponents.unsafelyUnwrapped
    }

    internal var codingPath: [CodingKey] {
        decoder.codingPath
    }

    internal var allKeys: [Key] {
        components.compactMapKeys(Key.init(stringValue:))
    }

    // MARK: - Initializers

    internal init(decoder: DictionaryValueDecoder) {
        self.decoder = decoder
    }

    // MARK: - Instance Methods

    @inline(always)
    private func position(of key: consuming CodingKey) -> CodingPosition {
        CodingPosition(node: decoder, key: .key(key))
    }

    // Unlike the default implementation of `decodeIfPresent`, looks the key up once rather than in `contains`,
    // `decodeNil` and `decode`. Callers pass the component on with `consume`, as passing a binding copies it.
    @inline(always)
    private func presentComponent(forKey key: Key) -> Any? {
        guard let component = components[key.stringValue], !decoder.isNull(component) else {
            return nil
        }

        return component
    }

    @inline(always)
    private func superDecoder(forAnyKey key: consuming CodingKey) -> DictionaryValueDecoder {
        decoder.nestedDecoder(from: components[key.stringValue], at: .key(key))
    }

    // MARK: - KeyedDecodingContainerProtocol

    internal func contains(_ key: Key) -> Bool {
        components[key.stringValue] != nil
    }

    // A missing key decodes as `nil`, as it always has.
    internal func decodeNil(forKey key: Key) throws -> Bool {
        decoder.decodeNil(from: components[key.stringValue])
    }

    internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
        try decoder.decodeWideInteger(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
        try decoder.decodeWideInteger(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decoder.decodeFloatingPoint(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try decoder.decodeFloatingPoint(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try decoder.decodePrimitive(type, from: components[key.stringValue], at: position(of: key))
    }

    internal func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try decoder.decode(type, from: components[key.stringValue], at: .key(key))
    }

    internal func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    @available(watchOS 11.0, *)
    internal func decodeIfPresent(_ type: Int128.Type, forKey key: Key) throws -> Int128? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodeWideInteger(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    @available(watchOS 11.0, *)
    internal func decodeIfPresent(_ type: UInt128.Type, forKey key: Key) throws -> UInt128? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodeWideInteger(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodeFloatingPoint(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodeFloatingPoint(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decodePrimitive(type, from: consume component, at: position(of: key))
    }

    internal func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard let component = presentComponent(forKey: key) else {
            return nil
        }

        return try decoder.decode(type, from: consume component, at: .key(key))
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

extension DictionaryValueDecoder {

    // MARK: - Instance Methods

    /// The components with the keys converted by the key decoding strategy.
    internal func convertingKeys(of components: consuming DictionaryKeyedComponents) -> DictionaryKeyedComponents {
        switch context.options.keyDecodingStrategy {
        case .useDefaultKeys:
            return components

        case let .custom(closure):
            var convertedComponents = [String: Any](minimumCapacity: components.count)

            // The paths of the keys differ in the last key only, so one array is changed for all of them.
            var keyPath = codingPath

            keyPath.append(AnyCodingKey.super)

            // Keys are converted in order, so that the value of the smallest key wins when converted keys collide.
            for (key, component) in components.keysAndValues.sorted(by: { $0.key < $1.key }) {
                keyPath[keyPath.count - 1] = AnyCodingKey(key)

                let convertedKey = closure(keyPath).stringValue

                if convertedComponents.index(forKey: convertedKey) == nil {
                    convertedComponents[convertedKey] = component
                }
            }

            return .native(convertedComponents)
        }
    }
}

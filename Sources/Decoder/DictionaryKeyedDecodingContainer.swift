import Foundation

internal final class DictionaryKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

    // MARK: - Instance Properties

    internal let components: DictionaryKeyedComponents
    internal let context: DictionaryComponentDecoder
    internal let codingPathNode: CodingPathNode

    internal var codingPath: [CodingKey] {
        codingPathNode.path
    }

    internal var allKeys: [Key] {
        components.compactMapKeys { Key(stringValue: $0) }
    }

    // MARK: - Initializers

    internal init(
        components: DictionaryKeyedComponents,
        context: DictionaryComponentDecoder,
        codingPathNode: CodingPathNode
    ) {
        switch context.options.keyDecodingStrategy {
        case .useDefaultKeys:
            self.components = components

        case let .custom(closure):
            let codingPath = codingPathNode.path
            let componentKeysAndValues = components.keysAndValues
                .sorted { $0.key < $1.key }
                .map { key, value in (closure(codingPath.appending(AnyCodingKey(key))).stringValue, value) }

            self.components = .native(Dictionary(componentKeysAndValues) { first, _ in first })
        }

        self.context = context
        self.codingPathNode = codingPathNode
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func component<T>(of type: T.Type = T.self, forKey key: Key) throws -> T {
        let anyComponent = components[key.stringValue]

        guard let component = anyComponent as? T else {
            throw DecodingError.invalidComponent(
                anyComponent,
                forKey: key,
                at: codingPathNode.appending(key).path,
                expectation: type
            )
        }

        return component
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
    private func superDecoder(forAnyKey key: CodingKey) throws -> Decoder {
        DictionarySingleValueDecodingContainer(
            component: components[key.stringValue],
            context: context,
            codingPathNode: codingPathNode.appending(key)
        )
    }

    // MARK: - KeyedDecodingContainerProtocol

    internal func contains(_ key: Key) -> Bool {
        components[key.stringValue] != nil
    }

    internal func decodeNil(forKey key: Key) throws -> Bool {
        context.decodeNilComponent(from: try component(forKey: key))
    }

    internal func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try context.decodeComponentValue(from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try context.decodeComponentValue(of: type, from: try component(forKey: key), at: codingPathNode.appending(key))
    }

    internal func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    @available(watchOS 11.0, *)
    internal func decodeIfPresent(_ type: Int128.Type, forKey key: Key) throws -> Int128? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    @available(watchOS 11.0, *)
    internal func decodeIfPresent(_ type: UInt128.Type, forKey key: Key) throws -> UInt128? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(from: component, at: codingPathNode.appending(key))
        }
    }

    internal func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        try decodeIfPresent(forKey: key) { component in
            try context.decodeComponentValue(of: type, from: component, at: codingPathNode.appending(key))
        }
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
        try superDecoder(forAnyKey: key)
    }

    internal func superDecoder() throws -> Decoder {
        try superDecoder(forAnyKey: AnyCodingKey.super)
    }
}

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

extension DecodingError {

    // MARK: - Type Methods

    fileprivate static func invalidComponent<Key: CodingKey>(
        _ component: Any?,
        forKey key: Key,
        at codingPath: [CodingKey],
        expectation: Any.Type
    ) -> Self {
        switch component {
        case let component?:
            let context = Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \(expectation) but found \(type(of: component)) instead."
            )

            return .typeMismatch(expectation, context)

        case nil:
            let context = Context(
                codingPath: codingPath,
                debugDescription: "No value associated with key \(key.stringValue)."
            )

            return .keyNotFound(key, context)
        }
    }
}

import Foundation

/// Components of an unkeyed container. Arrays of `Any`, as the encoder writes them, and Foundation arrays,
/// such as the ones from `JSONSerialization` or property lists, are read in place,
/// as converting an array wraps or bridges every element up front.
internal enum DictionaryUnkeyedComponents {

    // MARK: - Enumeration Cases

    case native([Any])
    case foundation(NSArray)

    // Other arrays, such as `[Int?]`, are converted, which unwraps their optional elements.
    case optionals([Any?])

    // MARK: - Instance Properties

    internal var count: Int {
        switch self {
        case let .native(components):
            components.count

        case let .foundation(components):
            components.count

        case let .optionals(components):
            components.count
        }
    }

    // MARK: - Initializers

    internal init?(_ component: Any?) {
        guard let component else {
            return nil
        }

        let componentType = type(of: component)

        if componentType == [Any].self, let components = component as? [Any] {
            self = .native(components)
        } else if componentType is NSArray.Type, let components = component as? NSArray {
            self = .foundation(components)
        } else if let components = component as? [Any?] {
            self = .optionals(components)
        } else {
            return nil
        }
    }

    // MARK: - Subscripts

    @inline(always)
    internal subscript(index: Int) -> Any? {
        switch self {
        case let .native(components):
            let component = components[index]

            // `nil` is kept in an array of `Any` as `Optional<Any>.none`, which is how the encoder writes it.
            return type(of: component) == Optional<Any>.self ? nil : component

        case let .foundation(components):
            return components[index]

        case let .optionals(components):
            return components[index]
        }
    }
}

internal final class DictionaryUnkeyedDecodingContainer: UnkeyedDecodingContainer {

    // MARK: - Instance Properties

    /// The decoder of the array, which is the node of the coding path of its elements.
    internal let decoder: DictionarySingleValueDecodingContainer
    internal let components: DictionaryUnkeyedComponents

    internal private(set) var currentIndex = 0

    internal var context: DictionaryComponentDecoder {
        decoder.context
    }

    internal var codingPath: [CodingKey] {
        decoder.codingPath
    }

    @inline(always)
    internal var currentPosition: CodingPosition {
        CodingPosition(node: decoder, key: .index(currentIndex))
    }

    internal var count: Int? {
        components.count
    }

    internal var isAtEnd: Bool {
        currentIndex == count
    }

    // MARK: - Initializers

    internal init(decoder: DictionarySingleValueDecodingContainer, components: DictionaryUnkeyedComponents) {
        self.decoder = decoder
        self.components = components
    }

    // MARK: - Instance Methods

    @inline(always)
    private func peekNextComponent() throws -> Any? {
        guard currentIndex < components.count else {
            throw DecodingError.containerAtEnd(at: currentPosition)
        }

        return components[currentIndex]
    }

    // Returns a value decoded from the current component and moves to the next one,
    // so that the container stays at a component that fails to decode.
    @inline(always)
    private func advancing<T>(_ value: consuming T) -> T {
        currentIndex += 1

        return value
    }

    @inline(always)
    private func superDecoder(for component: consuming Any?) -> DictionarySingleValueDecodingContainer {
        DictionarySingleValueDecodingContainer(
            component: component,
            context: context,
            position: currentPosition
        )
    }

    // MARK: - UnkeyedDecodingContainer

    internal func decodeNil() throws -> Bool {
        guard context.decodeNilComponent(from: try peekNextComponent()) else {
            return false
        }

        currentIndex += 1

        return true
    }

    internal func decode(_ type: Bool.Type) throws -> Bool {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Int.Type) throws -> Int {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Int8.Type) throws -> Int8 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Int16.Type) throws -> Int16 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Int32.Type) throws -> Int32 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Int64.Type) throws -> Int64 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: Int128.Type) throws -> Int128 {
        try advancing(context.decodeWideInteger(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: UInt.Type) throws -> UInt {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: UInt8.Type) throws -> UInt8 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: UInt16.Type) throws -> UInt16 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: UInt32.Type) throws -> UInt32 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: UInt64.Type) throws -> UInt64 {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    @available(watchOS 11.0, *)
    internal func decode(_ type: UInt128.Type) throws -> UInt128 {
        try advancing(context.decodeWideInteger(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Double.Type) throws -> Double {
        try advancing(context.decodeFloatingPoint(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: Float.Type) throws -> Float {
        try advancing(context.decodeFloatingPoint(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode(_ type: String.Type) throws -> String {
        try advancing(context.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try advancing(context.decode(type, from: peekNextComponent(), at: currentPosition))
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try advancing(superDecoder(for: peekNextComponent()).container(keyedBy: keyType))
    }

    internal func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try advancing(superDecoder(for: peekNextComponent()).unkeyedContainer())
    }

    internal func superDecoder() throws -> Decoder {
        try advancing(superDecoder(for: peekNextComponent()))
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension DecodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func containerAtEnd(at position: CodingPosition) -> any Error {
        let context = Context(codingPath: position.path, debugDescription: "Unkeyed container is at end.")

        return Self.valueNotFound(Any.self, context)
    }
}

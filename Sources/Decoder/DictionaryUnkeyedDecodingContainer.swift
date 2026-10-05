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

    // MARK: - Type Methods

    // Casting to `Any?` unwraps a wrapped optional, though a direct cast is reported to always succeed.
    private static func cast<T>(_ component: Any, to type: T.Type) -> T {
        component as! T
    }

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

        if componentType == [Any].self {
            self = .native(unsafeCast(contentsOf: component, to: [Any].self))
        } else if componentType is NSArray.Type, let components = component as? NSArray {
            self = .foundation(components)
        } else if let components = component as? [Any?] {
            self = .optionals(components)
        } else {
            return nil
        }
    }

    // MARK: - Subscripts

    @inline(__always)
    internal subscript(index: Int) -> Any? {
        switch self {
        case let .native(components):
            let component = components[index]

            // Optional elements, such as `nil` that the encoder writes, are kept in an array of `Any` wrapped,
            // so they are unwrapped as converting the array to `[Any?]` would.
            return type(of: component) == Optional<Any>.self ? Self.cast(component, to: Any?.self) : component

        case let .foundation(components):
            return components[index]

        case let .optionals(components):
            return components[index]
        }
    }
}

// A structure of three words, which the existential of an unkeyed container holds without allocating it,
// so the components are kept by the decoder of the array.
internal struct DictionaryUnkeyedDecodingContainer: UnkeyedDecodingContainer {

    // MARK: - Instance Properties

    /// The decoder of the array, which is the node of the coding path of its elements.
    internal let decoder: DictionaryValueDecoder
    internal let componentCount: Int

    internal private(set) var currentIndex = 0

    internal var codingPath: [CodingKey] {
        decoder.codingPath
    }

    @inline(__always)
    internal var currentPosition: CodingPosition {
        CodingPosition(node: decoder, key: .index(currentIndex))
    }

    internal var count: Int? {
        componentCount
    }

    internal var isAtEnd: Bool {
        currentIndex == componentCount
    }

    // MARK: - Initializers

    internal init(decoder: DictionaryValueDecoder, count: Int) {
        self.decoder = decoder
        self.componentCount = count
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func peekNextComponent() throws -> Any? {
        guard currentIndex < componentCount else {
            throw DecodingError.containerAtEnd(at: currentPosition)
        }

        // The decoder keeps the components from the creation of the container.
        return decoder.state.unkeyedComponents.unsafelyUnwrapped[currentIndex]
    }

    // Returns a value decoded from the current component and moves to the next one,
    // so that the container stays at a component that fails to decode.
    @inline(__always)
    private mutating func advancing<T>(_ value: consuming T) -> T {
        currentIndex += 1

        return value
    }

    @inline(__always)
    private func superDecoder(for component: Any?) -> DictionaryValueDecoder {
        decoder.nestedDecoder(from: component, at: .index(currentIndex))
    }

    // MARK: - UnkeyedDecodingContainer

    internal mutating func decodeNil() throws -> Bool {
        guard decoder.decodeNil(from: try peekNextComponent()) else {
            return false
        }

        currentIndex += 1

        return true
    }

    internal mutating func decode(_ type: Bool.Type) throws -> Bool {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Int.Type) throws -> Int {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    @available(watchOS 11.0, *)
    internal mutating func decode(_ type: Int128.Type) throws -> Int128 {
        try advancing(decoder.decodeWideInteger(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: UInt.Type) throws -> UInt {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    @available(watchOS 11.0, *)
    internal mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
        try advancing(decoder.decodeWideInteger(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Double.Type) throws -> Double {
        try advancing(decoder.decodeFloatingPoint(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: Float.Type) throws -> Float {
        try advancing(decoder.decodeFloatingPoint(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode(_ type: String.Type) throws -> String {
        try advancing(decoder.decodePrimitive(type, from: peekNextComponent(), at: currentPosition))
    }

    internal mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try advancing(decoder.decode(type, from: peekNextComponent(), at: .index(currentIndex)))
    }

    internal mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try advancing(superDecoder(for: peekNextComponent()).container(keyedBy: keyType))
    }

    internal mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try advancing(superDecoder(for: peekNextComponent()).unkeyedContainer())
    }

    internal mutating func superDecoder() throws -> Decoder {
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

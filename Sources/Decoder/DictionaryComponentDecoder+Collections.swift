import Foundation

extension DictionaryComponentDecoder {

    // MARK: - Instance Methods

    // Arrays of primitive values are decoded in place as well,
    // bypassing `Array.init(from:)` that goes through an unkeyed container for every element.
    @inline(never)
    internal func decodePrimitiveArray(
        of type: Any.Type,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Any? {
        let identifiers = PrimitiveArrayType.identifiers

        switch ObjectIdentifier(type) {
        case identifiers.string:
            return try decodeArray(of: String.self, from: component, at: codingPathNode())

        case identifiers.bool:
            return try decodeArray(of: Bool.self, from: component, at: codingPathNode())

        case identifiers.int:
            return try decodeArray(of: Int.self, from: component, at: codingPathNode())

        case identifiers.int8:
            return try decodeArray(of: Int8.self, from: component, at: codingPathNode())

        case identifiers.int16:
            return try decodeArray(of: Int16.self, from: component, at: codingPathNode())

        case identifiers.int32:
            return try decodeArray(of: Int32.self, from: component, at: codingPathNode())

        case identifiers.int64:
            return try decodeArray(of: Int64.self, from: component, at: codingPathNode())

        case identifiers.uInt:
            return try decodeArray(of: UInt.self, from: component, at: codingPathNode())

        case identifiers.uInt8:
            return try decodeArray(of: UInt8.self, from: component, at: codingPathNode())

        case identifiers.uInt16:
            return try decodeArray(of: UInt16.self, from: component, at: codingPathNode())

        case identifiers.uInt32:
            return try decodeArray(of: UInt32.self, from: component, at: codingPathNode())

        case identifiers.uInt64:
            return try decodeArray(of: UInt64.self, from: component, at: codingPathNode())

        case identifiers.double:
            return try decodeArray(of: Double.self, from: component, at: codingPathNode())

        case identifiers.float:
            return try decodeArray(of: Float.self, from: component, at: codingPathNode())

        default:
            return nil
        }
    }

    // Returns `nil` for a component that is not an array, leaving the error to the generic decoding.
    private func decodeArray<Element: Decodable>(
        of type: Element.Type,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> [Element]? {
        // The components are read directly rather than through their subscript,
        // which checks every element for `nil` and the kind of the components.
        switch DictionaryUnkeyedComponents(component) {
        case let .native(components):
            return try decodeElements(of: type, count: components.count, at: codingPathNode()) { components[$0] }

        case let .foundation(components):
            return try decodeElements(of: type, count: components.count, at: codingPathNode()) { components[$0] }

        case let .optionals(components):
            return try decodeElements(of: type, count: components.count, at: codingPathNode()) { components[$0] }

        case nil:
            return nil
        }
    }

    private func decodeElements<Element: Decodable>(
        of type: Element.Type,
        count: Int,
        at codingPathNode: @autoclosure () -> CodingPathNode,
        component: (_ index: Int) -> Any?
    ) throws -> [Element] {
        try (0..<count).map { index in
            try decodeComponentValue(of: type, from: component(index), at: codingPathNode().appending(index: index))
        }
    }

    // Dictionaries of primitive values keyed by strings are decoded in place as well,
    // bypassing `Dictionary.init(from:)` that goes through a keyed container for every element.
    @inline(never)
    internal func decodePrimitiveDictionary(
        of type: Any.Type,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Any? {
        let identifiers = PrimitiveDictionaryType.identifiers

        switch ObjectIdentifier(type) {
        case identifiers.string:
            return try decodeDictionary(of: String.self, from: component, at: codingPathNode())

        case identifiers.bool:
            return try decodeDictionary(of: Bool.self, from: component, at: codingPathNode())

        case identifiers.int:
            return try decodeDictionary(of: Int.self, from: component, at: codingPathNode())

        case identifiers.int8:
            return try decodeDictionary(of: Int8.self, from: component, at: codingPathNode())

        case identifiers.int16:
            return try decodeDictionary(of: Int16.self, from: component, at: codingPathNode())

        case identifiers.int32:
            return try decodeDictionary(of: Int32.self, from: component, at: codingPathNode())

        case identifiers.int64:
            return try decodeDictionary(of: Int64.self, from: component, at: codingPathNode())

        case identifiers.uInt:
            return try decodeDictionary(of: UInt.self, from: component, at: codingPathNode())

        case identifiers.uInt8:
            return try decodeDictionary(of: UInt8.self, from: component, at: codingPathNode())

        case identifiers.uInt16:
            return try decodeDictionary(of: UInt16.self, from: component, at: codingPathNode())

        case identifiers.uInt32:
            return try decodeDictionary(of: UInt32.self, from: component, at: codingPathNode())

        case identifiers.uInt64:
            return try decodeDictionary(of: UInt64.self, from: component, at: codingPathNode())

        case identifiers.double:
            return try decodeDictionary(of: Double.self, from: component, at: codingPathNode())

        case identifiers.float:
            return try decodeDictionary(of: Float.self, from: component, at: codingPathNode())

        default:
            return nil
        }
    }

    // Returns `nil` for a component that is not a dictionary, leaving the error to the generic decoding,
    // and for keys converted by a strategy, which the generic decoding applies to the keys of dictionaries too.
    private func decodeDictionary<Value: Decodable>(
        of type: Value.Type,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> [String: Value]? {
        guard case .useDefaultKeys = options.keyDecodingStrategy,
              let components = DictionaryKeyedComponents(component) else {
            return nil
        }

        var dictionary = [String: Value](minimumCapacity: components.count)

        try components.forEach { key, component in
            dictionary[key] = try decodeComponentValue(
                of: type,
                from: component,
                at: codingPathNode().appending(AnyCodingKey(key))
            )
        }

        return dictionary
    }
}

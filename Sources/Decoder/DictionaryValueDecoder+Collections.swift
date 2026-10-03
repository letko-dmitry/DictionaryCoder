import Foundation

extension DictionaryValueDecoder {

    // MARK: - Instance Methods

    // Arrays of primitive values are decoded in place as well,
    // bypassing `Array.init(from:)` that goes through an unkeyed container for every element.
    @inline(never)
    internal func decodePrimitiveArray<T: Decodable>(
        of type: T.Type,
        from component: Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        let identifiers = PrimitiveArrayType.identifiers

        // The collection is boxed, so that it is read as `T` once rather than in a copy for every type.
        let values: Any? = switch ObjectIdentifier(type) {
        case identifiers.string:
            try decodeArray(of: String.self, from: component, at: key())

        case identifiers.bool:
            try decodeArray(of: Bool.self, from: component, at: key())

        case identifiers.int:
            try decodeArray(of: Int.self, from: component, at: key())

        case identifiers.int8:
            try decodeArray(of: Int8.self, from: component, at: key())

        case identifiers.int16:
            try decodeArray(of: Int16.self, from: component, at: key())

        case identifiers.int32:
            try decodeArray(of: Int32.self, from: component, at: key())

        case identifiers.int64:
            try decodeArray(of: Int64.self, from: component, at: key())

        case identifiers.uInt:
            try decodeArray(of: UInt.self, from: component, at: key())

        case identifiers.uInt8:
            try decodeArray(of: UInt8.self, from: component, at: key())

        case identifiers.uInt16:
            try decodeArray(of: UInt16.self, from: component, at: key())

        case identifiers.uInt32:
            try decodeArray(of: UInt32.self, from: component, at: key())

        case identifiers.uInt64:
            try decodeArray(of: UInt64.self, from: component, at: key())

        case identifiers.double:
            try decodeArray(of: Double.self, from: component, at: key())

        case identifiers.float:
            try decodeArray(of: Float.self, from: component, at: key())

        default:
            nil
        }

        if let values {
            return unsafeCast(contentsOf: values, to: T.self)
        }

        // Components of other kinds are left to the generic decoding.
        return try decodeNestedValue(from: component, at: key()) { decoder in
            try T(from: decoder)
        }
    }

    // Returns `nil` for a component that is not an array, leaving the error to the generic decoding.
    private func decodeArray<Element: Decodable>(
        of type: Element.Type,
        from component: Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> [Element]? {
        // The components are read directly rather than through their subscript,
        // which checks every element for `nil` and the kind of the components.
        switch DictionaryUnkeyedComponents(component) {
        case let .native(components):
            return try decodeElements(of: type, count: components.count, at: key()) { components[$0] }

        case let .foundation(components):
            return try decodeElements(of: type, count: components.count, at: key()) { components[$0] }

        case let .optionals(components):
            return try decodeElements(of: type, count: components.count, at: key()) { components[$0] }

        case nil:
            return nil
        }
    }

    private func decodeElements<Element: Decodable>(
        of type: Element.Type,
        count: Int,
        at key: @autoclosure () -> CodingPathKey,
        component: (_ index: Int) -> Any?
    ) throws -> [Element] {
        try (0..<count).map { index in
            try decodeElement(
                of: type,
                from: component(index),
                at: CodingPathNode(parent: self, key: key()).position(at: .index(index))
            )
        }
    }

    /// Decodes an element of a primitive collection, which is a primitive value or a floating point number.
    @inline(always)
    private func decodeElement<Element: Decodable>(
        of type: Element.Type,
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Element {
        if type == Double.self {
            return unsafeCast(try decodeFloatingPoint(Double.self, from: component, at: position()), to: Element.self)
        }

        if type == Float.self {
            return unsafeCast(try decodeFloatingPoint(Float.self, from: component, at: position()), to: Element.self)
        }

        return try decodePrimitive(type, from: component, at: position())
    }

    // Dictionaries of primitive values keyed by strings are decoded in place as well,
    // bypassing `Dictionary.init(from:)` that goes through a keyed container for every element.
    @inline(never)
    internal func decodePrimitiveDictionary<T: Decodable>(
        of type: T.Type,
        from component: Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        let identifiers = PrimitiveDictionaryType.identifiers

        // The collection is boxed, so that it is read as `T` once rather than in a copy for every type.
        let values: Any? = switch ObjectIdentifier(type) {
        case identifiers.string:
            try decodeDictionary(of: String.self, from: component, at: key())

        case identifiers.bool:
            try decodeDictionary(of: Bool.self, from: component, at: key())

        case identifiers.int:
            try decodeDictionary(of: Int.self, from: component, at: key())

        case identifiers.int8:
            try decodeDictionary(of: Int8.self, from: component, at: key())

        case identifiers.int16:
            try decodeDictionary(of: Int16.self, from: component, at: key())

        case identifiers.int32:
            try decodeDictionary(of: Int32.self, from: component, at: key())

        case identifiers.int64:
            try decodeDictionary(of: Int64.self, from: component, at: key())

        case identifiers.uInt:
            try decodeDictionary(of: UInt.self, from: component, at: key())

        case identifiers.uInt8:
            try decodeDictionary(of: UInt8.self, from: component, at: key())

        case identifiers.uInt16:
            try decodeDictionary(of: UInt16.self, from: component, at: key())

        case identifiers.uInt32:
            try decodeDictionary(of: UInt32.self, from: component, at: key())

        case identifiers.uInt64:
            try decodeDictionary(of: UInt64.self, from: component, at: key())

        case identifiers.double:
            try decodeDictionary(of: Double.self, from: component, at: key())

        case identifiers.float:
            try decodeDictionary(of: Float.self, from: component, at: key())

        default:
            nil
        }

        if let values {
            return unsafeCast(contentsOf: values, to: T.self)
        }

        // Components of other kinds and dictionaries of keys converted by a strategy are left to the generic decoding.
        return try decodeNestedValue(from: component, at: key()) { decoder in
            try T(from: decoder)
        }
    }

    // Returns `nil` for a component that is not a dictionary, leaving the error to the generic decoding,
    // and for keys converted by a strategy, which the generic decoding applies to the keys of dictionaries too.
    private func decodeDictionary<Value: Decodable>(
        of type: Value.Type,
        from component: Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> [String: Value]? {
        guard case .useDefaultKeys = context.options.keyDecodingStrategy,
              let components = DictionaryKeyedComponents(component) else {
            return nil
        }

        var dictionary = [String: Value](minimumCapacity: components.count)

        try components.forEach { componentKey, component in
            dictionary[componentKey] = try decodeElement(
                of: type,
                from: component,
                at: CodingPathNode(parent: self, key: key()).position(at: .key(AnyCodingKey(componentKey)))
            )
        }

        return dictionary
    }
}

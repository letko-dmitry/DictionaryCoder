import Foundation

extension DictionaryValueDecoder {

    // MARK: - Instance Methods

    // Bridging a Foundation object through `as? T` looks the bridging up on every call,
    // while bridging one known to be of the class that `T` bridges from calls the same conversion directly.
    @inline(always)
    private func bridgeFoundationComponent<T>(_ component: Any, of componentType: Any.Type, to type: T.Type) -> T? {
        if T.self == String.self {
            guard componentType is NSString.Type else {
                return nil
            }

            return unsafeCast(contentsOf: component, to: NSString.self) as? T
        }

        if T.self == Data.self {
            guard componentType is NSData.Type else {
                return nil
            }

            return unsafeCast(contentsOf: component, to: NSData.self) as? T
        }

        guard componentType is NSNumber.Type else {
            return nil
        }

        return unsafeCast(contentsOf: component, to: NSNumber.self) as? T
    }

    // The date is made here rather than in the caller, as a resilient Foundation value in a function
    // makes the compiler reserve stack space for it on every call, whatever the type.
    @inline(never)
    private func decodeDate<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        let date: Date

        switch context.options.dateDecodingStrategy {
        case .deferredToDate:
            // What `Date.init(from:)` decodes, without a decoder of its own.
            let timeInterval = try decodeFloatingPoint(
                Double.self,
                from: consume component,
                at: position(at: key())
            )

            date = Date(timeIntervalSinceReferenceDate: timeInterval)

        case .secondsSince1970:
            date = Date(timeIntervalSince1970: try decodePrimitive(from: consume component, at: position(at: key())))

        case .millisecondsSince1970:
            let milliseconds: Double = try decodePrimitive(from: consume component, at: position(at: key()))

            date = Date(timeIntervalSince1970: milliseconds / 1000.0)

        case let .iso8601(style):
            let formattedDate = try decodePrimitive(
                String.self,
                from: consume component,
                at: position(at: key())
            )

            guard let parsedDate = style.date(from: formattedDate) else {
                throw DecodingError.dataCorrupted(
                    at: position(at: key()),
                    debugDescription: "Expected date string to be ISO8601-formatted."
                )
            }

            date = parsedDate

        case let .formatted(dateFormatter):
            let formattedDate = try decodePrimitive(
                String.self,
                from: consume component,
                at: position(at: key())
            )

            guard let formattedDate = dateFormatter.date(from: formattedDate) else {
                throw DecodingError.dataCorrupted(
                    at: position(at: key()),
                    debugDescription: "Date string does not match format expected by formatter."
                )
            }

            date = formattedDate

        case let .custom(closure):
            date = try decodeNestedValue(from: consume component, at: key(), decoding: closure)
        }

        return unsafeCast(date, to: T.self)
    }

    @inline(never)
    private func decodeData<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        switch context.options.dataDecodingStrategy {
        case .deferredToData:
            return try decodeNestedValue(from: consume component, at: key()) { decoder in
                try T(from: decoder)
            }

        case .base64:
            let base64EncodedString = try decodePrimitive(
                String.self,
                from: consume component,
                at: position(at: key())
            )

            guard let data = Data(base64Encoded: base64EncodedString) else {
                throw DecodingError.dataCorrupted(
                    at: position(at: key()),
                    debugDescription: "Encountered Data is not valid Base64."
                )
            }

            return unsafeCast(data, to: T.self)

        case .blob:
            let data = try decodePrimitive(Data.self, from: consume component, at: position(at: key()))

            return unsafeCast(data, to: T.self)

        case let .custom(closure):
            return unsafeCast(try decodeNestedValue(from: consume component, at: key(), decoding: closure), to: T.self)
        }
    }

    @inline(never)
    private func decodeURL<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        if let url = copy component as? URL {
            return unsafeCast(url, to: T.self)
        }

        let string: String = try decodePrimitive(from: consume component, at: position(at: key()))

        guard let url = URL(string: string) else {
            throw DecodingError.dataCorrupted(
                at: position(at: key()),
                debugDescription: "String is not valid URL."
            )
        }

        return unsafeCast(url, to: T.self)
    }

    // Kept out of `decode(_:from:at:)`, as the compiler reserves stack space for the generic copies here
    // on entry to the function, which would slow down decoding of every other value.
    @inline(never)
    private func decodePrimitiveValue<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        try decodePrimitive(type, from: consume component, at: position())
    }

    @inline(never)
    private func decodeTypedValue<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        let typeIdentifier = ObjectIdentifier(type)

        // Nested values are mostly of the same type as the last one, as the elements of an array,
        // so its kind is not looked up again.
        if typeIdentifier != state.nestedValueType {
            switch ValueKind(of: type) {
            case .double:
                let value = try decodeFloatingPoint(Double.self, from: consume component, at: position(at: key()))

                return unsafeCast(value, to: T.self)

            case .float:
                let value = try decodeFloatingPoint(Float.self, from: consume component, at: position(at: key()))

                return unsafeCast(value, to: T.self)

            case .date:
                return try decodeDate(type, from: consume component, at: key())

            case .data:
                return try decodeData(type, from: consume component, at: key())

            case .url:
                return try decodeURL(type, from: consume component, at: key())

            case .decimal:
                return unsafeCast(try decodeDecimal(from: consume component, at: key()), to: T.self)

            case .int128:
                if #available(watchOS 11.0, *) {
                    let value = try decodeWideInteger(Int128.self, from: component, at: position(at: key()))

                    return unsafeCast(value, to: T.self)
                }

            case .uInt128:
                if #available(watchOS 11.0, *) {
                    let value = try decodeWideInteger(UInt128.self, from: component, at: position(at: key()))

                    return unsafeCast(value, to: T.self)
                }

            // Collections of primitive values are decoded in place as well, bypassing the initializers
            // of arrays and dictionaries that go through a container for every element.
            case .primitiveArray:
                return try decodePrimitiveArray(type, from: component, at: key())

            case .primitiveDictionary:
                return try decodePrimitiveDictionary(type, from: component, at: key())

            case .nested:
                state.nestedValueType = typeIdentifier
            }
        }

        return try decodeNestedValue(from: consume component, at: key()) { decoder in
            try T(from: decoder)
        }
    }

    // MARK: -

    /// Whether the component stands for `nil`.
    @inline(always)
    internal func decodeNil(from component: Any?) -> Bool {
        // Through `map`, as unwrapping the optional with `guard let` would copy the existential.
        component.map(isNull) ?? true
    }

    /// Whether the component is `NSNull`.
    @inline(always)
    internal func isNull(_ component: Any) -> Bool {
        // Unlike `is NSNull`, checking the type does not bridge Swift values to Objective-C objects.
        type(of: component) is NSNull.Type
    }

    /// Decodes a value that dictionaries hold as it is, such as a string, a number or data.
    @inline(always)
    internal func decodePrimitive<T: Decodable>(
        _ type: T.Type = T.self,
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        // Taken out of the optional rather than copied, as copying an existential goes through its type.
        guard let component = consume component else {
            return try decodeConvertedNumber(from: nil, at: position())
        }

        let componentType = Swift.type(of: component)

        if componentType == T.self {
            return unsafeCast(contentsOf: component, to: T.self)
        }

        if let value = bridgeFoundationComponent(component, of: componentType, to: type) {
            return value
        }

        if let value = component as? T {
            return value
        }

        return try decodeConvertedNumber(from: component, at: position())
    }

    internal func decodeFloatingPoint<T: FloatingPoint & Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        // The strategy is checked first, so that numbers are not cast to `String` with the default strategy.
        if case .convertFromString = context.options.nonConformingFloatDecodingStrategy,
           let string = copy component as? String {
            switch context.options.nonConformingFloatDecodingStrategy {
            case let .convertFromString(positiveInfinity, _, _) where string == positiveInfinity:
                return T.infinity

            case let .convertFromString(_, negativeInfinity, _) where string == negativeInfinity:
                return -T.infinity

            case let .convertFromString(_, _, nan) where string == nan:
                return T.nan

            case .convertFromString, .throw:
                break
            }
        }

        let number: T = try decodePrimitive(from: consume component, at: position())

        guard number.isFinite else {
            throw DecodingError.nonConformingNumber(number, at: position())
        }

        return number
    }

    /// Decodes a value of any type nested in the container of this decoder at the key, or at the position
    /// of this decoder without a key: values that dictionaries hold as they are, such as numbers and arrays of them,
    /// are converted in place, and other values decode themselves with decoders of their own.
    @inline(always)
    internal func decode<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at key: @autoclosure () -> CodingPathKey
    ) throws -> T {
        // Primitive values are decoded in place,
        // so that an array of numbers, for example, does not create a nested decoder for each element.
        if PrimitiveTypes.contains(type) {
            return try decodePrimitiveValue(type, from: consume component, at: position(at: key()))
        }

        return try decodeTypedValue(type, from: consume component, at: key())
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension DecodingError {

    // MARK: - Type Methods

    @inline(never)
    internal static func dataCorrupted(at position: CodingPosition, debugDescription: String) -> any Error {
        Self.dataCorrupted(Context(codingPath: position.path, debugDescription: debugDescription))
    }

    @inline(never)
    fileprivate static func nonConformingNumber<T: FloatingPoint>(
        _ number: T,
        at position: CodingPosition
    ) -> any Error {
        dataCorrupted(at: position, debugDescription: "Parsed dictionary number \(number) does not fit in \(T.self).")
    }
}

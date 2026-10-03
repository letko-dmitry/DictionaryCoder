import Foundation

extension DictionaryValueEncoder {

    // MARK: - Instance Methods

    @inline(never)
    private func encodeDate<T: Encodable>(_ value: T, at key: @autoclosure () -> CodingPathKey) throws -> Any? {
        let date = unsafeCast(value, to: Date.self)

        switch context.options.dateEncodingStrategy {
        case .deferredToDate:
            // What `Date.encode(to:)` encodes, without an encoder of its own.
            return try encodeFloatingPoint(
                date.timeIntervalSinceReferenceDate,
                at: position(at: key())
            )

        case .millisecondsSince1970:
            return date.timeIntervalSince1970 * 1000.0

        case .secondsSince1970:
            return date.timeIntervalSince1970

        case .iso8601:
            return Date.ISO8601FormatStyle.internetDateTime.format(date)

        case let .formatted(dateFormatter):
            return dateFormatter.string(from: date)

        case let .custom(closure):
            return try encodeNestedValue(at: key()) { encoder in
                try closure(date, encoder)
            }
        }
    }

    @inline(never)
    private func encodeData<T: Encodable>(_ value: T, at key: @autoclosure () -> CodingPathKey) throws -> Any? {
        switch context.options.dataEncodingStrategy {
        case .deferredToData:
            return try encodeNestedValue(at: key()) { encoder in
                try value.encode(to: encoder)
            }

        case .base64:
            return unsafeCast(value, to: Data.self).base64EncodedString()

        case .blob:
            return value

        case let .custom(closure):
            let data = unsafeCast(value, to: Data.self)

            return try encodeNestedValue(at: key()) { encoder in
                try closure(data, encoder)
            }
        }
    }

    @inline(never)
    private func encodeURL<T>(_ value: T) -> Any? {
        unsafeCast(value, to: URL.self).absoluteString
    }

    // Values that are kept as they are, here rather than inline, as boxing a value of a resilient type
    // makes the compiler reserve stack space for it on entry to the function that boxes it.
    @inline(never)
    private func encodeUnchangedValue<T>(_ value: T) -> Any? {
        value
    }

    // Reads the value as an array of its type, so it is called only for arrays of primitive values.
    @inline(never)
    private func encodePrimitiveArray<T>(_ value: T) -> [Any]? {
        let identifiers = PrimitiveArrayType.identifiers

        switch ObjectIdentifier(T.self) {
        case identifiers.string:
            return unsafeCast(value, to: [String].self).map { $0 as Any }

        case identifiers.bool:
            return unsafeCast(value, to: [Bool].self).map { $0 as Any }

        case identifiers.int:
            return unsafeCast(value, to: [Int].self).map { $0 as Any }

        case identifiers.int8:
            return unsafeCast(value, to: [Int8].self).map { $0 as Any }

        case identifiers.int16:
            return unsafeCast(value, to: [Int16].self).map { $0 as Any }

        case identifiers.int32:
            return unsafeCast(value, to: [Int32].self).map { $0 as Any }

        case identifiers.int64:
            return unsafeCast(value, to: [Int64].self).map { $0 as Any }

        case identifiers.uInt:
            return unsafeCast(value, to: [UInt].self).map { $0 as Any }

        case identifiers.uInt8:
            return unsafeCast(value, to: [UInt8].self).map { $0 as Any }

        case identifiers.uInt16:
            return unsafeCast(value, to: [UInt16].self).map { $0 as Any }

        case identifiers.uInt32:
            return unsafeCast(value, to: [UInt32].self).map { $0 as Any }

        case identifiers.uInt64:
            return unsafeCast(value, to: [UInt64].self).map { $0 as Any }

        // Non-finite numbers depend on the strategy, so such arrays are encoded element by element.
        case identifiers.double:
            let values = unsafeCast(value, to: [Double].self)

            return values.allSatisfy(\.isFinite) ? values.map { $0 as Any } : nil

        case identifiers.float:
            let values = unsafeCast(value, to: [Float].self)

            return values.allSatisfy(\.isFinite) ? values.map { $0 as Any } : nil

        default:
            return nil
        }
    }

    // Kept out of `encode(_:at:)`, as the compiler allocates stack for the Foundation values here
    // on entry to the function, which would slow down encoding of every primitive value.
    @inline(never)
    private func encodeTypedValue<T: Encodable>(_ value: T, at key: @autoclosure () -> CodingPathKey) throws -> Any? {
        let type = ObjectIdentifier(T.self)

        // Nested values are mostly of the same type as the last one, as the elements of an array,
        // so its kind is not looked up again.
        if type != state.nestedValueType {
            // The value is converted only in the functions called for its kind, as the compiler reserves stack space
            // for a conversion on entry to the function that makes it, whatever the type of the value.
            switch ValueKind(of: T.self) {
            case .double:
                return try encodeFloatingPoint(unsafeCast(value, to: Double.self), at: position(at: key()))

            case .float:
                return try encodeFloatingPoint(unsafeCast(value, to: Float.self), at: position(at: key()))

            case .date:
                return try encodeDate(value, at: key())

            case .data:
                return try encodeData(value, at: key())

            case .url:
                return encodeURL(value)

            // Decimals are kept as numbers, as in `JSONEncoder`, rather than encoded in their own keyed representation.
            case .decimal, .int128, .uInt128:
                return encodeUnchangedValue(value)

            // Arrays of primitive values are encoded in place as well,
            // bypassing `Array.encode(to:)` that goes through an unkeyed container for every element.
            case .primitiveArray:
                if let elements = encodePrimitiveArray(value) {
                    return elements
                }

            case .primitiveDictionary, .nested:
                state.nestedValueType = type
            }
        }

        return try encodeNestedValue(at: key()) { encoder in
            try value.encode(to: encoder)
        }
    }

    // MARK: -

    internal func encodeFloatingPoint<T: FloatingPoint & Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        if value.isFinite {
            return value
        }

        switch context.options.nonConformingFloatEncodingStrategy {
        case let .convertToString(positiveInfinity, _, _) where value == T.infinity:
            return positiveInfinity

        case let .convertToString(_, negativeInfinity, _) where value == -T.infinity:
            return negativeInfinity

        case let .convertToString(_, _, nan):
            return nan

        case .throw:
            throw EncodingError.invalidFloatingPointValue(value, at: position())
        }
    }

    /// Encodes a value of any type nested in the container of this encoder at the key, or at the position
    /// of this encoder without a key: values that dictionaries hold as they are, such as numbers and arrays of them,
    /// are kept in place, and other values encode themselves with encoders of their own.
    @inline(always)
    internal func encode<T: Encodable>(_ value: T, at key: @autoclosure () -> CodingPathKey) throws -> Any? {
        // Primitive values are encoded in place,
        // so that an array of numbers, for example, does not create a nested encoder for each element.
        if PrimitiveTypes.contains(T.self) {
            return value
        }

        return try encodeTypedValue(value, at: key())
    }
}

extension Date.ISO8601FormatStyle {

    // MARK: - Type Properties

    // Creating a style costs nearly as much as formatting a date with it, so a single one is shared.
    // It formats dates as `JSONEncoder` does, dropping fractions of a second rather than rounding them.
    internal static let internetDateTime = Self()
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension EncodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func invalidFloatingPointValue<T: FloatingPoint>(
        _ value: T,
        at position: CodingPosition
    ) -> any Error {
        let valueDescription: String

        switch value {
        case T.infinity:
            valueDescription = "\(T.self).infinity"

        case -T.infinity:
            valueDescription = "-\(T.self).infinity"

        default:
            valueDescription = "\(T.self).nan"
        }

        let debugDescription = """
            Unable to encode \(valueDescription) directly in Dictionary.
            Use DictionaryNonConformingFloatEncodingStrategy.convertToString to specify how the value should be encoded.
            """

        return Self.invalidValue(value, Context(codingPath: position.path, debugDescription: debugDescription))
    }
}

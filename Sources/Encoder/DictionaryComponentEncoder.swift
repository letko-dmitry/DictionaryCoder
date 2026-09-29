import Foundation

/// Encodes values to components with the options and user info of a `DictionaryEncoder`,
/// for the encoders of all values of a dictionary.
internal final class DictionaryComponentEncoder {

    // MARK: - Instance Properties

    internal let options: DictionaryEncodingOptions
    internal let userInfo: [CodingUserInfoKey: Any]

    // MARK: - Initializers

    internal init(options: DictionaryEncodingOptions, userInfo: [CodingUserInfoKey: Any]) {
        self.options = options
        self.userInfo = userInfo
    }

    // MARK: - Instance Methods

    private func encodeNonPrimitiveValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            position: position()
        )

        try value.encode(to: encoder)

        return encoder.resolveValue()
    }

    private func encodeCustomizedValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition,
        closure: (_ value: T, _ encoder: Encoder) throws -> Void
    ) throws -> Any? {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            position: position()
        )

        try closure(value, encoder)

        return encoder.resolveValue()
    }

    @inline(never)
    private func encodeDate<T>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        let date = value as! Date

        switch options.dateEncodingStrategy {
        case .deferredToDate:
            return try encodeNonPrimitiveValue(date, at: position())

        case .millisecondsSince1970:
            return date.timeIntervalSince1970 * 1000.0

        case .secondsSince1970:
            return date.timeIntervalSince1970

        case .iso8601:
            return Date.ISO8601FormatStyle.internetDateTime.format(date)

        case let .formatted(dateFormatter):
            return dateFormatter.string(from: date)

        case let .custom(closure):
            return try encodeCustomizedValue(date, at: position(), closure: closure)
        }
    }

    @inline(never)
    private func encodeData<T>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        let data = value as! Data

        switch options.dataEncodingStrategy {
        case .deferredToData:
            return try encodeNonPrimitiveValue(data, at: position())

        case .base64:
            return data.base64EncodedString()

        case .blob:
            return data

        case let .custom(closure):
            return try encodeCustomizedValue(data, at: position(), closure: closure)
        }
    }

    @inline(never)
    private func encodeURL<T>(_ value: T) -> Any? {
        (value as! URL).absoluteString
    }

    @inline(never)
    private func encodeFloatingPoint<T, Number: FloatingPoint & Encodable>(
        _ value: T,
        as type: Number.Type,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        try encodeFloatingPoint(value as! Number, at: position())
    }

    @inline(never)
    private func encodeUnchangedValue<T>(_ value: T) -> Any? {
        value
    }

    // Casts the value, so it is called only for arrays of primitive values:
    // the compiler reserves stack space for the generic copies here on every call.
    @inline(never)
    private func encodePrimitiveArray<T>(_ value: T) -> [Any]? {
        let identifiers = PrimitiveArrayType.identifiers

        switch ObjectIdentifier(T.self) {
        case identifiers.string:
            return (value as! [String]).map { $0 as Any }

        case identifiers.bool:
            return (value as! [Bool]).map { $0 as Any }

        case identifiers.int:
            return (value as! [Int]).map { $0 as Any }

        case identifiers.int8:
            return (value as! [Int8]).map { $0 as Any }

        case identifiers.int16:
            return (value as! [Int16]).map { $0 as Any }

        case identifiers.int32:
            return (value as! [Int32]).map { $0 as Any }

        case identifiers.int64:
            return (value as! [Int64]).map { $0 as Any }

        case identifiers.uInt:
            return (value as! [UInt]).map { $0 as Any }

        case identifiers.uInt8:
            return (value as! [UInt8]).map { $0 as Any }

        case identifiers.uInt16:
            return (value as! [UInt16]).map { $0 as Any }

        case identifiers.uInt32:
            return (value as! [UInt32]).map { $0 as Any }

        case identifiers.uInt64:
            return (value as! [UInt64]).map { $0 as Any }

        // Non-finite numbers depend on the strategy, so such arrays are encoded element by element.
        case identifiers.double:
            let values = value as! [Double]

            return values.allSatisfy(\.isFinite) ? values.map { $0 as Any } : nil

        case identifiers.float:
            let values = value as! [Float]

            return values.allSatisfy(\.isFinite) ? values.map { $0 as Any } : nil

        default:
            return nil
        }
    }

    // MARK: -

    internal func encodeNil() -> Any? {
        switch options.nilEncodingStrategy {
        case .useNil:
            nil

        case .useNSNull:
            NSNull()
        }
    }

    internal func encodeFloatingPoint<T: FloatingPoint & Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        if value.isFinite {
            return value
        }

        switch options.nonConformingFloatEncodingStrategy {
        case let .convertToString(positiveInfinity, _, _) where value == T.infinity:
            return positiveInfinity

        case let .convertToString(_, negativeInfinity, _) where value == -T.infinity:
            return negativeInfinity

        case let .convertToString(_, _, nan):
            return nan

        case .throw:
            throw EncodingError.invalidFloatingPointValue(value, at: position().path)
        }
    }

    /// Encodes a value of any type: values that dictionaries hold as they are, such as numbers and arrays of them,
    /// are kept in place, and other values encode themselves with encoders of their own.
    @inline(__always)
    internal func encode<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        // Primitive values are encoded in place,
        // so that an array of numbers, for example, does not create a nested encoder for each element.
        if PrimitiveTypes.contains(T.self) {
            return value
        }

        return try encodeTypedValue(value, at: position())
    }

    // Kept out of `encode(_:at:)`, as the compiler allocates stack for the Foundation values here
    // on entry to the function, which would slow down encoding of every primitive value.
    @inline(never)
    private func encodeTypedValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any? {
        // The value is converted only in the functions called for its type, as the compiler reserves stack space
        // for a conversion on entry to the function that makes it, whatever the type of the value.
        switch ObjectIdentifier(T.self) {
        case ObjectIdentifier(Double.self):
            return try encodeFloatingPoint(value, as: Double.self, at: position())

        case ObjectIdentifier(Float.self):
            return try encodeFloatingPoint(value, as: Float.self, at: position())

        case ObjectIdentifier(Date.self):
            return try encodeDate(value, at: position())

        case ObjectIdentifier(Data.self):
            return try encodeData(value, at: position())

        case ObjectIdentifier(URL.self):
            return encodeURL(value)

        // Decimals are kept as numbers, as in `JSONEncoder`, rather than encoded in their own keyed representation.
        case ObjectIdentifier(Decimal.self):
            return encodeUnchangedValue(value)

        default:
            // Arrays of primitive values are encoded in place as well,
            // bypassing `Array.encode(to:)` that goes through an unkeyed container for every element.
            if PrimitiveArrayType.contains(T.self), let elements = encodePrimitiveArray(value) {
                return elements
            }

            if #available(watchOS 11.0, *) {
                if T.self == Int128.self || T.self == UInt128.self {
                    return encodeUnchangedValue(value)
                }
            }

            return try encodeNonPrimitiveValue(value, at: position())
        }
    }
}

extension Date.ISO8601FormatStyle {

    // MARK: - Type Properties

    // Creating a style costs nearly as much as formatting a date with it, so a single one is shared.
    // It formats dates as `JSONEncoder` does, dropping fractions of a second rather than rounding them.
    internal static let internetDateTime = Self()
}

extension EncodingError {

    // MARK: - Type Methods

    fileprivate static func invalidFloatingPointValue<T: FloatingPoint>(
        _ value: T,
        at codingPath: [CodingKey]
    ) -> EncodingError {
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

        return .invalidValue(value, Context(codingPath: codingPath, debugDescription: debugDescription))
    }
}

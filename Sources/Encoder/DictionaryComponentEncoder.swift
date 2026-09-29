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

    @inline(__always)
    private func encodePrimitiveValue(
        _ value: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        .value(value)
    }

    private func encodeNonPrimitiveValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            position: position()
        )

        try value.encode(to: encoder)

        return .value(encoder.resolveValue())
    }

    private func encodeCustomizedValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition,
        closure: (_ value: T, _ encoder: Encoder) throws -> Void
    ) throws -> DictionaryComponent {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            position: position()
        )

        try closure(value, encoder)

        return .value(encoder.resolveValue())
    }

    private func encodeNil(at position: @autoclosure () -> CodingPosition) -> DictionaryComponent {
        switch options.nilEncodingStrategy {
        case .useNil:
            return encodePrimitiveValue(nil, at: position())

        case .useNSNull:
            return encodePrimitiveValue(NSNull(), at: position())
        }
    }

    @inline(never)
    private func encodeDate<T>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        let date = value as! Date

        switch options.dateEncodingStrategy {
        case .deferredToDate:
            return try encodeNonPrimitiveValue(date, at: position())

        case .millisecondsSince1970:
            return encodePrimitiveValue(date.timeIntervalSince1970 * 1000.0, at: position())

        case .secondsSince1970:
            return encodePrimitiveValue(date.timeIntervalSince1970, at: position())

        case .iso8601:
            return encodePrimitiveValue(Date.ISO8601FormatStyle.internetDateTime.format(date), at: position())

        case let .formatted(dateFormatter):
            return encodePrimitiveValue(dateFormatter.string(from: date), at: position())

        case let .custom(closure):
            return try encodeCustomizedValue(date, at: position(), closure: closure)
        }
    }

    @inline(never)
    private func encodeData<T>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        let data = value as! Data

        switch options.dataEncodingStrategy {
        case .deferredToData:
            return try encodeNonPrimitiveValue(data, at: position())

        case .base64:
            return encodePrimitiveValue(data.base64EncodedString(), at: position())

        case .blob:
            return encodePrimitiveValue(data, at: position())

        case let .custom(closure):
            return try encodeCustomizedValue(data, at: position(), closure: closure)
        }
    }

    private func encodeFloatingPoint<T: FloatingPoint & Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        if value.isFinite {
            return encodePrimitiveValue(value, at: position())
        }

        switch options.nonConformingFloatEncodingStrategy {
        case let .convertToString(positiveInfinity, _, _) where value == T.infinity:
            return encodePrimitiveValue(positiveInfinity, at: position())

        case let .convertToString(_, negativeInfinity, _) where value == -T.infinity:
            return encodePrimitiveValue(negativeInfinity, at: position())

        case let .convertToString(_, _, nan):
            return encodePrimitiveValue(nan, at: position())

        case .throw:
            throw EncodingError.invalidFloatingPointValue(value, at: position().path)
        }
    }

    @inline(never)
    private func encodeURL<T>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        encodePrimitiveValue((value as! URL).absoluteString, at: position())
    }

    @inline(never)
    private func encodeFloatingPoint<T, Number: FloatingPoint & Encodable>(
        _ value: T,
        as type: Number.Type,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value as! Number, at: position())
    }

    @inline(never)
    private func encodeUnchangedValue<T>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
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

    @inline(__always)
    internal func encodeNilComponent(at position: @autoclosure () -> CodingPosition) -> DictionaryComponent {
        encodeNil(at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Bool,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int8,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int16,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int32,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int64,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @available(watchOS 11.0, *)
    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int128,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt8,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt16,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt32,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt64,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @available(watchOS 11.0, *)
    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt128,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Double,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Float,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: String,
        at position: @autoclosure () -> CodingPosition
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: position())
    }

    @inline(__always)
    internal func encodeComponentValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
        // Primitive values are encoded in place,
        // so that an array of numbers, for example, does not create a nested encoder for each element.
        if PrimitiveTypes.contains(T.self) {
            return encodePrimitiveValue(value, at: position())
        }

        return try encodeTypedValue(value, at: position())
    }

    // Kept out of `encodeComponentValue`, as the compiler allocates stack for the Foundation values here
    // on entry to the function, which would slow down encoding of every primitive value.
    @inline(never)
    private func encodeTypedValue<T: Encodable>(
        _ value: T,
        at position: @autoclosure () -> CodingPosition
    ) throws -> DictionaryComponent {
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
            return try encodeURL(value, at: position())

        // Decimals are kept as numbers, as in `JSONEncoder`, rather than encoded in their own keyed representation.
        case ObjectIdentifier(Decimal.self):
            return encodeUnchangedValue(value, at: position())

        default:
            // Arrays of primitive values are encoded in place as well,
            // bypassing `Array.encode(to:)` that goes through an unkeyed container for every element.
            if PrimitiveArrayType.contains(T.self), let elements = encodePrimitiveArray(value) {
                return encodePrimitiveValue(elements, at: position())
            }

            if #available(watchOS 11.0, *) {
                if T.self == Int128.self || T.self == UInt128.self {
                    return encodeUnchangedValue(value, at: position())
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

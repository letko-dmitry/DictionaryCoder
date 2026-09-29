import Foundation

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
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        .value(value)
    }

    private func encodeNonPrimitiveValue<T: Encodable>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            codingPathNode: codingPathNode()
        )

        try value.encode(to: encoder)

        return .value(encoder.resolveValue())
    }

    private func encodeCustomizedValue<T: Encodable>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode,
        closure: (_ value: T, _ encoder: Encoder) throws -> Void
    ) throws -> DictionaryComponent {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            codingPathNode: codingPathNode()
        )

        try closure(value, encoder)

        return .value(encoder.resolveValue())
    }

    private func encodeNil(at codingPathNode: @autoclosure () -> CodingPathNode) -> DictionaryComponent {
        switch options.nilEncodingStrategy {
        case .useNil:
            return encodePrimitiveValue(nil, at: codingPathNode())

        case .useNSNull:
            return encodePrimitiveValue(NSNull(), at: codingPathNode())
        }
    }

    @inline(never)
    private func encodeDate<T>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        let date = value as! Date

        switch options.dateEncodingStrategy {
        case .deferredToDate:
            return try encodeNonPrimitiveValue(date, at: codingPathNode())

        case .millisecondsSince1970:
            return encodePrimitiveValue(date.timeIntervalSince1970 * 1000.0, at: codingPathNode())

        case .secondsSince1970:
            return encodePrimitiveValue(date.timeIntervalSince1970, at: codingPathNode())

        case .iso8601:
            return encodePrimitiveValue(Date.ISO8601FormatStyle.internetDateTime.format(date), at: codingPathNode())

        case let .formatted(dateFormatter):
            return encodePrimitiveValue(dateFormatter.string(from: date), at: codingPathNode())

        case let .custom(closure):
            return try encodeCustomizedValue(date, at: codingPathNode(), closure: closure)
        }
    }

    @inline(never)
    private func encodeData<T>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        let data = value as! Data

        switch options.dataEncodingStrategy {
        case .deferredToData:
            return try encodeNonPrimitiveValue(data, at: codingPathNode())

        case .base64:
            return encodePrimitiveValue(data.base64EncodedString(), at: codingPathNode())

        case .blob:
            return encodePrimitiveValue(data, at: codingPathNode())

        case let .custom(closure):
            return try encodeCustomizedValue(data, at: codingPathNode(), closure: closure)
        }
    }

    private func encodeFloatingPoint<T: FloatingPoint & Encodable>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        if value.isFinite {
            return encodePrimitiveValue(value, at: codingPathNode())
        }

        switch options.nonConformingFloatEncodingStrategy {
        case let .convertToString(positiveInfinity, _, _) where value == T.infinity:
            return encodePrimitiveValue(positiveInfinity, at: codingPathNode())

        case let .convertToString(_, negativeInfinity, _) where value == -T.infinity:
            return encodePrimitiveValue(negativeInfinity, at: codingPathNode())

        case let .convertToString(_, _, nan):
            return encodePrimitiveValue(nan, at: codingPathNode())

        case .throw:
            throw EncodingError.invalidFloatingPointValue(value, at: codingPathNode().path)
        }
    }

    @inline(never)
    private func encodeURL<T>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        encodePrimitiveValue((value as! URL).absoluteString, at: codingPathNode())
    }

    @inline(never)
    private func encodeFloatingPoint<T, Number: FloatingPoint & Encodable>(
        _ value: T,
        as type: Number.Type,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value as! Number, at: codingPathNode())
    }

    @inline(never)
    private func encodeUnchangedValue<T>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    // MARK: -

    @inline(__always)
    internal func encodeNilComponent(at codingPathNode: @autoclosure () -> CodingPathNode) -> DictionaryComponent {
        encodeNil(at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Bool,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int8,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int16,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int32,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int64,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @available(watchOS 11.0, *)
    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int128,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt8,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt16,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt32,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt64,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @available(watchOS 11.0, *)
    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt128,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Double,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Float,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: String,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPathNode())
    }

    @inline(__always)
    internal func encodeComponentValue<T: Encodable>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        // Primitive values are encoded in place,
        // so that an array of numbers, for example, does not create a nested encoder for each element.
        if PrimitiveTypes.contains(T.self) {
            return encodePrimitiveValue(value, at: codingPathNode())
        }

        return try encodeTypedValue(value, at: codingPathNode())
    }

    // Kept out of `encodeComponentValue`, as the compiler allocates stack for the Foundation values here
    // on entry to the function, which would slow down encoding of every primitive value.
    @inline(never)
    private func encodeTypedValue<T: Encodable>(
        _ value: T,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> DictionaryComponent {
        // The value is converted only in the functions called for its type, as the compiler reserves stack space
        // for a conversion on entry to the function that makes it, whatever the type of the value.
        switch ObjectIdentifier(T.self) {
        case ObjectIdentifier(Double.self):
            return try encodeFloatingPoint(value, as: Double.self, at: codingPathNode())

        case ObjectIdentifier(Float.self):
            return try encodeFloatingPoint(value, as: Float.self, at: codingPathNode())

        case ObjectIdentifier(Date.self):
            return try encodeDate(value, at: codingPathNode())

        case ObjectIdentifier(Data.self):
            return try encodeData(value, at: codingPathNode())

        case ObjectIdentifier(URL.self):
            return try encodeURL(value, at: codingPathNode())

        // Decimals are kept as numbers, as in `JSONEncoder`, rather than encoded in their own keyed representation.
        case ObjectIdentifier(Decimal.self):
            return encodeUnchangedValue(value, at: codingPathNode())

        default:
            if #available(watchOS 11.0, *) {
                if T.self == Int128.self || T.self == UInt128.self {
                    return encodeUnchangedValue(value, at: codingPathNode())
                }
            }

            return try encodeNonPrimitiveValue(value, at: codingPathNode())
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

        return .invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: debugDescription))
    }
}

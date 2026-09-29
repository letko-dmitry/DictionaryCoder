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
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        .value(value)
    }

    private func encodeNonPrimitiveValue<T: Encodable>(
        _ value: T,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            codingPath: codingPath()
        )

        try value.encode(to: encoder)

        return .value(encoder.resolveValue())
    }

    private func encodeCustomizedValue<T: Encodable>(
        _ value: T,
        at codingPath: @autoclosure () -> [CodingKey],
        closure: (_ value: T, _ encoder: Encoder) throws -> Void
    ) throws -> DictionaryComponent {
        let encoder = DictionarySingleValueEncodingContainer(
            context: self,
            codingPath: codingPath()
        )

        try closure(value, encoder)

        return .value(encoder.resolveValue())
    }

    private func encodeNil(at codingPath: @autoclosure () -> [CodingKey]) -> DictionaryComponent {
        switch options.nilEncodingStrategy {
        case .useNil:
            return encodePrimitiveValue(nil, at: codingPath())

        case .useNSNull:
            return encodePrimitiveValue(NSNull(), at: codingPath())
        }
    }

    private func encodeDate(
        _ date: Date,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            return try encodeNonPrimitiveValue(date, at: codingPath())

        case .millisecondsSince1970:
            return encodePrimitiveValue(date.timeIntervalSince1970 * 1000.0, at: codingPath())

        case .secondsSince1970:
            return encodePrimitiveValue(date.timeIntervalSince1970, at: codingPath())

        case .iso8601:
            return encodePrimitiveValue(ISO8601DateFormatter.internetDateTime.string(from: date), at: codingPath())

        case let .formatted(dateFormatter):
            return encodePrimitiveValue(dateFormatter.string(from: date), at: codingPath())

        case let .custom(closure):
            return try encodeCustomizedValue(date, at: codingPath(), closure: closure)
        }
    }

    private func encodeData(
        _ data: Data,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            return try encodeNonPrimitiveValue(data, at: codingPath())

        case .base64:
            return encodePrimitiveValue(data.base64EncodedString(), at: codingPath())

        case .blob:
            return encodePrimitiveValue(data, at: codingPath())

        case let .custom(closure):
            return try encodeCustomizedValue(data, at: codingPath(), closure: closure)
        }
    }

    private func encodeFloatingPoint<T: FloatingPoint & Encodable>(
        _ value: T,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        if value.isFinite {
            return encodePrimitiveValue(value, at: codingPath())
        }

        switch options.nonConformingFloatEncodingStrategy {
        case let .convertToString(positiveInfinity, _, _) where value == T.infinity:
            return encodePrimitiveValue(positiveInfinity, at: codingPath())

        case let .convertToString(_, negativeInfinity, _) where value == -T.infinity:
            return encodePrimitiveValue(negativeInfinity, at: codingPath())

        case let .convertToString(_, _, nan):
            return encodePrimitiveValue(nan, at: codingPath())

        case .throw:
            throw EncodingError.invalidFloatingPointValue(value, at: codingPath())
        }
    }

    private func encodeURL(_ url: URL, at codingPath: @autoclosure () -> [CodingKey]) throws -> DictionaryComponent {
        encodePrimitiveValue(url.absoluteString, at: codingPath())
    }

    // MARK: -

    @inline(__always)
    internal func encodeNilComponent(at codingPath: @autoclosure () -> [CodingKey]) -> DictionaryComponent {
        encodeNil(at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Bool,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int8,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int16,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int32,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Int64,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt8,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt16,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt32,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: UInt64,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Double,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: Float,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        try encodeFloatingPoint(value, at: codingPath())
    }

    @inline(__always)
    internal func encodeComponentValue(
        _ value: String,
        at codingPath: @autoclosure () -> [CodingKey]
    ) -> DictionaryComponent {
        encodePrimitiveValue(value, at: codingPath())
    }

    internal func encodeComponentValue<T: Encodable>(
        _ value: T,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> DictionaryComponent {
        switch value {
        case let date as Date:
            return try encodeDate(date, at: codingPath())

        case let data as Data:
            return try encodeData(data, at: codingPath())

        case let url as URL:
            return try encodeURL(url, at: codingPath())

        default:
            return try encodeNonPrimitiveValue(value, at: codingPath())
        }
    }
}

extension ISO8601DateFormatter {

    // MARK: - Type Properties

    // Configured once and then only used to format and parse dates, which is thread-safe.
    fileprivate nonisolated(unsafe) static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = .withInternetDateTime
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return formatter
    }()
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

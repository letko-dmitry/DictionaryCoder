import Foundation

internal final class DictionaryComponentDecoder {

    // MARK: - Instance Properties

    internal let options: DictionaryDecodingOptions
    internal let userInfo: [CodingUserInfoKey: Any]

    // MARK: - Initializers

    internal init(options: DictionaryDecodingOptions, userInfo: [CodingUserInfoKey: Any]) {
        self.options = options
        self.userInfo = userInfo
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func decodePrimitiveValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> T {
        guard let value = component as? T else {
            throw DecodingError.invalidComponent(component, of: T.self, at: codingPath())
        }

        return value
    }

    private func decodeNonPrimitiveValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: consuming Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> T {
        let decoder = DictionarySingleValueDecodingContainer(
            component: component,
            context: self,
            codingPath: codingPath()
        )

        return try T(from: decoder)
    }

    private func decodeCustomizedValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: consuming Any?,
        at codingPath: @autoclosure () -> [CodingKey],
        closure: (_ decoder: Decoder) throws -> T
    ) throws -> T {
        let decoder = DictionarySingleValueDecodingContainer(
            component: component,
            context: self,
            codingPath: codingPath()
        )

        return try closure(decoder)
    }

    private func decodeFloatingPointValue<T: FloatingPoint & Decodable>(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> T {
        switch component {
        case let string as String:
            switch options.nonConformingFloatDecodingStrategy {
            case let .convertFromString(positiveInfinity, _, _) where string == positiveInfinity:
                return T.infinity

            case let .convertFromString(_, negativeInfinity, _) where string == negativeInfinity:
                return -T.infinity

            case let .convertFromString(_, _, nan) where string == nan:
                return T.nan

            case .convertFromString, .throw:
                break
            }

        case let number as T where number.isFinite:
            return number

        case let number as T:
            let errorContext = DecodingError.Context(
                codingPath: codingPath(),
                debugDescription: "Parsed dictionary number \(number) does not fit in \(T.self)."
            )

            throw DecodingError.dataCorrupted(errorContext)

        default:
            break
        }

        throw DecodingError.invalidComponent(component, of: T.self, at: codingPath())
    }

    private func decodeDate(
        from component: consuming Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Date {
        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try decodeNonPrimitiveValue(from: component, at: codingPath())

        case .secondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: codingPath()))

        case .millisecondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: codingPath()) / 1000.0)

        case .iso8601:
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: codingPath())
            let date: Date?

            if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
                date = try? Date.ISO8601FormatStyle().parse(formattedDate)
            } else {
                date = ISO8601DateFormatter.internetDateTime.date(from: formattedDate)
            }

            guard let date else {
                let errorContext = DecodingError.Context(
                    codingPath: codingPath(),
                    debugDescription: "Expected date string to be ISO8601-formatted."
                )

                throw DecodingError.dataCorrupted(errorContext)
            }

            return date

        case .formatted(let dateFormatter):
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: codingPath())

            guard let date = dateFormatter.date(from: formattedDate) else {
                let errorContext = DecodingError.Context(
                    codingPath: codingPath(),
                    debugDescription: "Date string does not match format expected by formatter."
                )

                throw DecodingError.dataCorrupted(errorContext)
            }

            return date

        case .custom(let closure):
            return try decodeCustomizedValue(from: component, at: codingPath(), closure: closure)
        }
    }

    private func decodeData(
        from component: consuming Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Data {
        switch options.dataDecodingStrategy {
        case .deferredToData:
            return try decodeNonPrimitiveValue(from: component, at: codingPath())

        case .base64:
            let base64EncodedString = try decodePrimitiveValue(of: String.self, from: component, at: codingPath())

            guard let data = Data(base64Encoded: base64EncodedString) else {
                let errorContext = DecodingError.Context(
                    codingPath: codingPath(),
                    debugDescription: "Encountered Data is not valid Base64."
                )

                throw DecodingError.dataCorrupted(errorContext)
            }

            return data

        case .blob:
            return try decodePrimitiveValue(from: component, at: codingPath())

        case .custom(let closure):
            return try decodeCustomizedValue(from: component, at: codingPath(), closure: closure)
        }
    }

    private func decodeURL(from component: Any?, at codingPath: @autoclosure () -> [CodingKey]) throws -> URL {
        if let url = component as? URL {
            return url
        }

        guard let url = URL(string: try decodePrimitiveValue(from: component, at: codingPath())) else {
            let errorContext = DecodingError.Context(
                codingPath: codingPath(),
                debugDescription: "String is not valid URL."
            )

            throw DecodingError.dataCorrupted(errorContext)
        }

        return url
    }

    // MARK: -

    @inline(__always)
    internal func decodeNilComponent(from component: Any?) -> Bool {
        component.isNil || component is NSNull
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Bool {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Int {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Int8 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Int16 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Int32 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Int64 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> UInt {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> UInt8 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> UInt16 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> UInt32 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> UInt64 {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Double {
        try decodeFloatingPointValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> Float {
        try decodeFloatingPointValue(from: component, at: codingPath())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> String {
        try decodePrimitiveValue(from: component, at: codingPath())
    }

    internal func decodeComponentValue<T: Decodable>(
        of type: T.Type,
        from component: consuming Any?,
        at codingPath: @autoclosure () -> [CodingKey]
    ) throws -> T {
        switch T.self {
        case is Date.Type:
            return try decodeDate(from: component, at: codingPath()) as! T

        case is Data.Type:
            return try decodeData(from: component, at: codingPath()) as! T

        case is URL.Type:
            return try decodeURL(from: component, at: codingPath()) as! T

        default:
            return try decodeNonPrimitiveValue(from: component, at: codingPath())
        }
    }
}

extension ISO8601DateFormatter {

    // MARK: - Type Properties

    // Configured once and then only used to format and parse dates, which is thread-safe.
    fileprivate nonisolated(unsafe) static let internetDateTime = ISO8601DateFormatter()
}

extension DecodingError {

    // MARK: - Type Methods

    fileprivate static func invalidComponent(
        _ component: Any?,
        of expectedType: Any.Type,
        at codingPath: [CodingKey]
    ) -> DecodingError {
        let componentDescription = component.map { "\(type(of: $0))" } ?? "nil"

        let context = Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(expectedType) but found \(componentDescription) instead."
        )

        return .typeMismatch(expectedType, context)
    }
}

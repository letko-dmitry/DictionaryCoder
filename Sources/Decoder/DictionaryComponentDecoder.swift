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
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> T {
        guard let value = component as? T else {
            throw DecodingError.invalidComponent(component, of: T.self, at: codingPathNode().path)
        }

        return value
    }

    private func decodeNonPrimitiveValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: consuming Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> T {
        let decoder = DictionarySingleValueDecodingContainer(
            component: component,
            context: self,
            codingPathNode: codingPathNode()
        )

        return try T(from: decoder)
    }

    private func decodeCustomizedValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: consuming Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode,
        closure: (_ decoder: Decoder) throws -> T
    ) throws -> T {
        let decoder = DictionarySingleValueDecodingContainer(
            component: component,
            context: self,
            codingPathNode: codingPathNode()
        )

        return try closure(decoder)
    }

    private func decodeFloatingPointValue<T: FloatingPoint & Decodable>(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
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
                codingPath: codingPathNode().path,
                debugDescription: "Parsed dictionary number \(number) does not fit in \(T.self)."
            )

            throw DecodingError.dataCorrupted(errorContext)

        default:
            break
        }

        throw DecodingError.invalidComponent(component, of: T.self, at: codingPathNode().path)
    }

    private func decodeDate(
        from component: consuming Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Date {
        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try decodeNonPrimitiveValue(from: component, at: codingPathNode())

        case .secondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: codingPathNode()))

        case .millisecondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: codingPathNode()) / 1000.0)

        case .iso8601:
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: codingPathNode())
            let date: Date?

            if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
                date = try? Date.ISO8601FormatStyle().parse(formattedDate)
            } else {
                date = ISO8601DateFormatter.internetDateTime.date(from: formattedDate)
            }

            guard let date else {
                let errorContext = DecodingError.Context(
                    codingPath: codingPathNode().path,
                    debugDescription: "Expected date string to be ISO8601-formatted."
                )

                throw DecodingError.dataCorrupted(errorContext)
            }

            return date

        case .formatted(let dateFormatter):
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: codingPathNode())

            guard let date = dateFormatter.date(from: formattedDate) else {
                let errorContext = DecodingError.Context(
                    codingPath: codingPathNode().path,
                    debugDescription: "Date string does not match format expected by formatter."
                )

                throw DecodingError.dataCorrupted(errorContext)
            }

            return date

        case .custom(let closure):
            return try decodeCustomizedValue(from: component, at: codingPathNode(), closure: closure)
        }
    }

    private func decodeData(
        from component: consuming Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Data {
        switch options.dataDecodingStrategy {
        case .deferredToData:
            return try decodeNonPrimitiveValue(from: component, at: codingPathNode())

        case .base64:
            let base64EncodedString = try decodePrimitiveValue(of: String.self, from: component, at: codingPathNode())

            guard let data = Data(base64Encoded: base64EncodedString) else {
                let errorContext = DecodingError.Context(
                    codingPath: codingPathNode().path,
                    debugDescription: "Encountered Data is not valid Base64."
                )

                throw DecodingError.dataCorrupted(errorContext)
            }

            return data

        case .blob:
            return try decodePrimitiveValue(from: component, at: codingPathNode())

        case .custom(let closure):
            return try decodeCustomizedValue(from: component, at: codingPathNode(), closure: closure)
        }
    }

    private func decodeURL(from component: Any?, at codingPathNode: @autoclosure () -> CodingPathNode) throws -> URL {
        if let url = component as? URL {
            return url
        }

        guard let url = URL(string: try decodePrimitiveValue(from: component, at: codingPathNode())) else {
            let errorContext = DecodingError.Context(
                codingPath: codingPathNode().path,
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
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Bool {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Int {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Int8 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Int16 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Int32 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Int64 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> UInt {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> UInt8 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> UInt16 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> UInt32 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> UInt64 {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Double {
        try decodeFloatingPointValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Float {
        try decodeFloatingPointValue(from: component, at: codingPathNode())
    }

    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> String {
        try decodePrimitiveValue(from: component, at: codingPathNode())
    }

    internal func decodeComponentValue<T: Decodable>(
        of type: T.Type,
        from component: consuming Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> T {
        // Primitive values are decoded in place,
        // so that an array of numbers, for example, does not create a nested decoder for each element.
        if PrimitiveTypes.contains(type) {
            return try decodePrimitiveValue(of: type, from: component, at: codingPathNode())
        }

        switch ObjectIdentifier(type) {
        case ObjectIdentifier(Double.self):
            return try decodeFloatingPointValue(from: component, at: codingPathNode()) as Double as! T

        case ObjectIdentifier(Float.self):
            return try decodeFloatingPointValue(from: component, at: codingPathNode()) as Float as! T

        case ObjectIdentifier(Date.self):
            return try decodeDate(from: component, at: codingPathNode()) as! T

        case ObjectIdentifier(Data.self):
            return try decodeData(from: component, at: codingPathNode()) as! T

        case ObjectIdentifier(URL.self):
            return try decodeURL(from: component, at: codingPathNode()) as! T

        default:
            return try decodeNonPrimitiveValue(from: component, at: codingPathNode())
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

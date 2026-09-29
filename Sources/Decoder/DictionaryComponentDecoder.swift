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
        if let value = component as? T {
            return value
        }

        return try decodeConvertedNumber(from: component, at: codingPathNode())
    }

    // Arrays of primitive values are decoded in place as well,
    // bypassing `Array.init(from:)` that goes through an unkeyed container for every element.
    @inline(never)
    private func decodePrimitiveArray(
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
        guard let components = component as? [Any] else {
            return nil
        }

        return try components.indices.map { index in
            try decodeComponentValue(of: type, from: components[index], at: codingPathNode().appending(index: index))
        }
    }

    // Numbers of other types are converted the same way as `NSNumber`,
    // so a dictionary decodes equally whether it holds Swift numbers or `NSNumber` instances.
    // Unlike `NSNumber`, booleans are not converted to or from numbers here, as in `JSONDecoder`.
    @inline(never)
    private func decodeConvertedNumber<T: Decodable>(
        of type: T.Type = T.self,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> T {
        let number = component as? NSNumber

        guard let number, !isBoolean(number), !(T.self is Bool.Type), let value = number as? T else {
            throw DecodingError.invalidComponent(component, of: T.self, at: codingPathNode().path)
        }

        return value
    }

    // Booleans are bridged to `NSNumber` too, so they are told apart by their Core Foundation type.
    private func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    // Decimals are decoded from numbers, as in `JSONDecoder`.
    private func decodeDecimal(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Decimal {
        if let decimal = component as? Decimal {
            return decimal
        }

        if let number = component as? NSNumber, !isBoolean(number) {
            return number.decimalValue
        }

        // Decimals encoded in their own keyed representation, as earlier versions did, are still decoded.
        if component is [String: Any] {
            return try decodeNonPrimitiveValue(from: component, at: codingPathNode())
        }

        throw DecodingError.invalidComponent(component, of: Decimal.self, at: codingPathNode().path)
    }

    // `NSNumber` does not bridge 128-bit integers, so other integers are converted exactly.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    private func decodeWideInteger<T: FixedWidthInteger & Decodable>(
        of type: T.Type = T.self,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> T {
        if let value = component as? T {
            return value
        }

        let value: T? = switch component {
        case let integer as any BinaryInteger:
            T(exactly: integer)

        case let number as NSNumber where !isBoolean(number):
            (number as? Int64).flatMap(T.init(exactly:)) ?? (number as? UInt64).flatMap(T.init(exactly:))

        default:
            nil
        }

        guard let value else {
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
        if let string = component as? String {
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
        }

        let number: T = try decodePrimitiveValue(from: component, at: codingPathNode())

        guard number.isFinite else {
            let errorContext = DecodingError.Context(
                codingPath: codingPathNode().path,
                debugDescription: "Parsed dictionary number \(number) does not fit in \(T.self)."
            )

            throw DecodingError.dataCorrupted(errorContext)
        }

        return number
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

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> Int128 {
        try decodeWideInteger(from: component, at: codingPathNode())
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

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @inline(__always)
    internal func decodeComponentValue(
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> UInt128 {
        try decodeWideInteger(from: component, at: codingPathNode())
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

        case ObjectIdentifier(Decimal.self):
            return try decodeDecimal(from: component, at: codingPathNode()) as! T

        default:
            if let array = try decodePrimitiveArray(of: type, from: component, at: codingPathNode()) {
                return array as! T
            }

            if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
                if type == Int128.self {
                    return try decodeWideInteger(from: component, at: codingPathNode()) as Int128 as! T
                }

                if type == UInt128.self {
                    return try decodeWideInteger(from: component, at: codingPathNode()) as UInt128 as! T
                }
            }

            return try decodeNonPrimitiveValue(from: component, at: codingPathNode())
        }
    }
}

// Identifiers of generic types are cached, as looking up their metadata on every call is costly.
private struct PrimitiveArrayType {

    // MARK: - Type Properties

    fileprivate static let identifiers = Self()

    // MARK: - Instance Properties

    fileprivate let string = ObjectIdentifier([String].self)
    fileprivate let bool = ObjectIdentifier([Bool].self)
    fileprivate let int = ObjectIdentifier([Int].self)
    fileprivate let int8 = ObjectIdentifier([Int8].self)
    fileprivate let int16 = ObjectIdentifier([Int16].self)
    fileprivate let int32 = ObjectIdentifier([Int32].self)
    fileprivate let int64 = ObjectIdentifier([Int64].self)
    fileprivate let uInt = ObjectIdentifier([UInt].self)
    fileprivate let uInt8 = ObjectIdentifier([UInt8].self)
    fileprivate let uInt16 = ObjectIdentifier([UInt16].self)
    fileprivate let uInt32 = ObjectIdentifier([UInt32].self)
    fileprivate let uInt64 = ObjectIdentifier([UInt64].self)
    fileprivate let double = ObjectIdentifier([Double].self)
    fileprivate let float = ObjectIdentifier([Float].self)
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

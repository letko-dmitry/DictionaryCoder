import Foundation

/// Decodes values from components with the options and user info of a `DictionaryDecoder`,
/// for the decoders of all values of a dictionary.
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

    @inline(always)
    private func decodePrimitiveValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        guard let component else {
            return try decodeConvertedNumber(from: component, at: position())
        }

        let componentType = Swift.type(of: component)

        if componentType == T.self, let value = component as? T {
            return value
        }

        if let value = bridgeFoundationComponent(component, of: componentType, to: type) {
            return value
        }

        if let value = component as? T {
            return value
        }

        return try decodeConvertedNumber(from: component, at: position())
    }

    // Bridging a Foundation object through `as? T` looks the bridging up on every call,
    // while bridging one known to be of the class that `T` bridges from calls the same conversion directly.
    @inline(always)
    private func bridgeFoundationComponent<T>(_ component: Any, of componentType: Any.Type, to type: T.Type) -> T? {
        if T.self == String.self {
            guard componentType is NSString.Type, let string = component as? NSString else {
                return nil
            }

            return string as? T
        }

        if T.self == Data.self {
            guard componentType is NSData.Type, let data = component as? NSData else {
                return nil
            }

            return data as? T
        }

        guard componentType is NSNumber.Type, let number = component as? NSNumber else {
            return nil
        }

        return number as? T
    }

    internal func decodeNonPrimitiveValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        let decoder = DictionarySingleValueDecodingContainer(
            component: component,
            context: self,
            position: position()
        )

        return try T(from: decoder)
    }

    private func decodeCustomizedValue<T: Decodable>(
        of type: T.Type = T.self,
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition,
        closure: (_ decoder: Decoder) throws -> T
    ) throws -> T {
        let decoder = DictionarySingleValueDecodingContainer(
            component: component,
            context: self,
            position: position()
        )

        return try closure(decoder)
    }

    internal func decodeFloatingPoint<T: FloatingPoint & Decodable>(
        _ type: T.Type,
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        // The strategy is checked first, so that numbers are not cast to `String` with the default strategy.
        if case .convertFromString = options.nonConformingFloatDecodingStrategy, let string = component as? String {
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

        let number: T = try decodePrimitiveValue(from: component, at: position())

        guard number.isFinite else {
            throw DecodingError.nonConformingNumber(number, at: position())
        }

        return number
    }

    private func decodeDate(
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Any {
        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try decodeNonPrimitiveValue(of: Date.self, from: component, at: position())

        case .secondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: position()))

        case .millisecondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: position()) / 1000.0)

        case .iso8601:
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: position())

            guard let date = try? Date.ISO8601FormatStyle.internetDateTime.parse(formattedDate) else {
                throw DecodingError.dataCorrupted(
                    at: position(),
                    debugDescription: "Expected date string to be ISO8601-formatted."
                )
            }

            return date

        case .formatted(let dateFormatter):
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: position())

            guard let date = dateFormatter.date(from: formattedDate) else {
                throw DecodingError.dataCorrupted(
                    at: position(),
                    debugDescription: "Date string does not match format expected by formatter."
                )
            }

            return date

        case .custom(let closure):
            return try decodeCustomizedValue(from: component, at: position(), closure: closure)
        }
    }

    private func decodeData(
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> Data {
        switch options.dataDecodingStrategy {
        case .deferredToData:
            return try decodeNonPrimitiveValue(from: component, at: position())

        case .base64:
            let base64EncodedString = try decodePrimitiveValue(of: String.self, from: component, at: position())

            guard let data = Data(base64Encoded: base64EncodedString) else {
                throw DecodingError.dataCorrupted(
                    at: position(),
                    debugDescription: "Encountered Data is not valid Base64."
                )
            }

            return data

        case .blob:
            return try decodePrimitiveValue(from: component, at: position())

        case .custom(let closure):
            return try decodeCustomizedValue(from: component, at: position(), closure: closure)
        }
    }

    private func decodeURL(from component: Any?, at position: @autoclosure () -> CodingPosition) throws -> Any {
        if let url = component as? URL {
            return url
        }

        guard let url = URL(string: try decodePrimitiveValue(from: component, at: position())) else {
            throw DecodingError.dataCorrupted(at: position(), debugDescription: "String is not valid URL.")
        }

        return url
    }

    // Kept out of `decode(_:from:at:)`, as the compiler reserves stack space for the generic copies here
    // on entry to the function, which would slow down decoding of every other value.
    @inline(never)
    private func decodePrimitiveComponentValue<T: Decodable>(
        of type: T.Type,
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        try decodePrimitiveValue(of: type, from: component, at: position())
    }

    // MARK: -

    @inline(always)
    internal func decodeNilComponent(from component: Any?) -> Bool {
        guard let component else {
            return true
        }

        // Unlike `is NSNull`, checking the type does not bridge Swift values to Objective-C objects.
        return type(of: component) is NSNull.Type
    }

    /// Decodes a string, a boolean or an integer that fits in 64 bits.
    @inline(always)
    internal func decodePrimitive<T: Decodable>(
        _ type: T.Type,
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        try decodePrimitiveValue(of: type, from: component, at: position())
    }

    /// Decodes a value of any type: values that dictionaries hold as they are, such as numbers and arrays of them,
    /// are converted in place, and other values are decoded by themselves with decoders of their own.
    internal func decode<T: Decodable>(
        _ type: T.Type,
        from component: consuming Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        // Primitive values are decoded in place,
        // so that an array of numbers, for example, does not create a nested decoder for each element.
        if PrimitiveTypes.contains(type) {
            return try decodePrimitiveComponentValue(of: type, from: component, at: position())
        }

        switch ObjectIdentifier(type) {
        case ObjectIdentifier(Double.self):
            return try decodeFloatingPoint(Double.self, from: component, at: position()) as! T

        case ObjectIdentifier(Float.self):
            return try decodeFloatingPoint(Float.self, from: component, at: position()) as! T

        // Dates and URLs are returned as `Any`, as a resilient Foundation value in this function
        // would make the compiler reserve stack space for it on every call, whatever the type.
        case ObjectIdentifier(Date.self):
            return try decodeDate(from: component, at: position()) as! T

        case ObjectIdentifier(Data.self):
            return try decodeData(from: component, at: position()) as! T

        case ObjectIdentifier(URL.self):
            return try decodeURL(from: component, at: position()) as! T

        case ObjectIdentifier(Decimal.self):
            return try decodeDecimal(from: component, at: position()) as! T

        default:
            if PrimitiveArrayType.contains(type),
               let array = try decodePrimitiveArray(of: type, from: component, at: position()) {
                return array as! T
            }

            if PrimitiveDictionaryType.contains(type),
               let dictionary = try decodePrimitiveDictionary(of: type, from: component, at: position()) {
                return dictionary as! T
            }

            if #available(watchOS 11.0, *) {
                if type == Int128.self {
                    return try decodeWideInteger(Int128.self, from: component, at: position()) as! T
                }

                if type == UInt128.self {
                    return try decodeWideInteger(UInt128.self, from: component, at: position()) as! T
                }
            }

            return try decodeNonPrimitiveValue(from: component, at: position())
        }
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension DecodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func dataCorrupted(at position: CodingPosition, debugDescription: String) -> any Error {
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

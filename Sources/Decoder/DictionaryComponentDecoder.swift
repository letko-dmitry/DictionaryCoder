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
        guard let component else {
            return try decodeConvertedNumber(from: component, at: codingPathNode())
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

        return try decodeConvertedNumber(from: component, at: codingPathNode())
    }

    // Bridging a Foundation object through `as? T` looks the bridging up on every call,
    // while bridging one known to be of the class that `T` bridges from calls the same conversion directly.
    @inline(__always)
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
    ) throws -> Any {
        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try decodeNonPrimitiveValue(of: Date.self, from: component, at: codingPathNode())

        case .secondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: codingPathNode()))

        case .millisecondsSince1970:
            return Date(timeIntervalSince1970: try decodePrimitiveValue(from: component, at: codingPathNode()) / 1000.0)

        case .iso8601:
            let formattedDate = try decodePrimitiveValue(of: String.self, from: component, at: codingPathNode())

            guard let date = try? Date.ISO8601FormatStyle.internetDateTime.parse(formattedDate) else {
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

    private func decodeURL(from component: Any?, at codingPathNode: @autoclosure () -> CodingPathNode) throws -> Any {
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

    // Kept out of `decodeComponentValue`, as the compiler reserves stack space for the generic copies here
    // on entry to the function, which would slow down decoding of every other value.
    @inline(never)
    private func decodePrimitiveComponentValue<T: Decodable>(
        of type: T.Type,
        from component: Any?,
        at codingPathNode: @autoclosure () -> CodingPathNode
    ) throws -> T {
        try decodePrimitiveValue(of: type, from: component, at: codingPathNode())
    }

    // MARK: -

    @inline(__always)
    internal func decodeNilComponent(from component: Any?) -> Bool {
        guard let component else {
            return true
        }

        // Unlike `is NSNull`, checking the type does not bridge Swift values to Objective-C objects.
        return type(of: component) is NSNull.Type
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

    @available(watchOS 11.0, *)
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

    @available(watchOS 11.0, *)
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
            return try decodePrimitiveComponentValue(of: type, from: component, at: codingPathNode())
        }

        switch ObjectIdentifier(type) {
        case ObjectIdentifier(Double.self):
            return try decodeFloatingPointValue(from: component, at: codingPathNode()) as Double as! T

        case ObjectIdentifier(Float.self):
            return try decodeFloatingPointValue(from: component, at: codingPathNode()) as Float as! T

        // Dates and URLs are returned as `Any`, as a resilient Foundation value in this function
        // would make the compiler reserve stack space for it on every call, whatever the type.
        case ObjectIdentifier(Date.self):
            return try decodeDate(from: component, at: codingPathNode()) as! T

        case ObjectIdentifier(Data.self):
            return try decodeData(from: component, at: codingPathNode()) as! T

        case ObjectIdentifier(URL.self):
            return try decodeURL(from: component, at: codingPathNode()) as! T

        case ObjectIdentifier(Decimal.self):
            return try decodeDecimal(from: component, at: codingPathNode()) as! T

        default:
            if PrimitiveArrayType.contains(type),
               let array = try decodePrimitiveArray(of: type, from: component, at: codingPathNode()) {
                return array as! T
            }

            if PrimitiveDictionaryType.contains(type),
               let dictionary = try decodePrimitiveDictionary(of: type, from: component, at: codingPathNode()) {
                return dictionary as! T
            }

            if #available(watchOS 11.0, *) {
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

import Foundation

extension DictionaryValueDecoder {

    // MARK: - Instance Methods

    // Numbers of other types are converted the same way as `NSNumber`,
    // so a dictionary decodes equally whether it holds Swift numbers or `NSNumber` instances.
    // Unlike `NSNumber`, booleans are not converted to or from numbers here, as in `JSONDecoder`.
    @inline(never)
    internal func decodeConvertedNumber<T: Decodable>(
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        let number = component as? NSNumber

        guard let number, !isBoolean(number), !(T.self is Bool.Type), let value = number as? T else {
            throw DecodingError.invalidComponent(component, of: T.self, at: position())
        }

        return value
    }

    // Booleans are bridged to `NSNumber` too, so they are told apart by their Core Foundation type.
    private func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    internal func decodeDecimal(from component: Any?, at key: @autoclosure () -> CodingPathKey) throws -> Decimal {
        let strategy = context.options.decimalDecodingStrategy

        if strategy.contains(.number) {
            if let decimal = component as? Decimal {
                return decimal
            }

            if let number = component as? NSNumber, !isBoolean(number) {
                return number.decimalValue
            }
        }

        guard strategy.contains(.deferredToDecimal) else {
            throw DecodingError.invalidComponent(component, of: Decimal.self, at: position(at: key()))
        }

        return try decodeNestedValue(from: component, at: key()) { decoder in
            try Decimal(from: decoder)
        }
    }

    @available(watchOS 11.0, *)
    internal func decodeWideInteger<T: FixedWidthInteger & Decodable>(
        _ type: T.Type,
        from component: Any?,
        at position: @autoclosure () -> CodingPosition
    ) throws -> T {
        guard let value = wideInteger(of: type, from: component) else {
            throw DecodingError.invalidComponent(component, of: T.self, at: position())
        }

        return value
    }

    // `NSNumber` does not bridge 128-bit integers, so other integers are converted exactly.
    // The conversion takes no position, so that it is not copied for every caller along with its closure.
    @available(watchOS 11.0, *)
    @inline(never)
    private func wideInteger<T: FixedWidthInteger>(of type: T.Type, from component: Any?) -> T? {
        if let value = component as? T {
            return value
        }

        return switch component {
        case let integer as any BinaryInteger:
            T(exactly: integer)

        case let number as NSNumber where !isBoolean(number):
            (number as? Int64).flatMap(T.init(exactly:)) ?? (number as? UInt64).flatMap(T.init(exactly:))

        default:
            nil
        }
    }
}

// Errors are made out of line and returned boxed, as an error or its context in a function,
// both of a resilient layout, would make the compiler reserve stack space for them on every call.
extension DecodingError {

    // MARK: - Type Methods

    @inline(never)
    fileprivate static func invalidComponent(
        _ component: Any?,
        of expectedType: Any.Type,
        at position: CodingPosition
    ) -> any Error {
        let componentDescription = component.map { "\(type(of: $0))" } ?? "nil"

        let context = Context(
            codingPath: position.path,
            debugDescription: "Expected to decode \(expectedType) but found \(componentDescription) instead."
        )

        return Self.typeMismatch(expectedType, context)
    }
}

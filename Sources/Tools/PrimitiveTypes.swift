import Foundation

internal enum PrimitiveTypes {

    // MARK: - Type Methods

    /// Whether values of the type are stored in dictionaries as they are,
    /// so they are encoded and decoded without nested containers.
    @inline(__always)
    internal static func contains(_ type: Any.Type) -> Bool {
        type == String.self
            || type == Bool.self
            || type == Int.self
            || type == Int8.self
            || type == Int16.self
            || type == Int32.self
            || type == Int64.self
            || type == UInt.self
            || type == UInt8.self
            || type == UInt16.self
            || type == UInt32.self
            || type == UInt64.self
    }
}

// Identifiers of generic types are cached, as looking up their metadata on every call is costly.
internal struct PrimitiveArrayType {

    // MARK: - Type Properties

    internal static let identifiers = Self()

    // MARK: - Type Methods

    internal static func contains(_ type: Any.Type) -> Bool {
        let identifiers = Self.identifiers

        switch ObjectIdentifier(type) {
        case identifiers.string, identifiers.bool, identifiers.double, identifiers.float,
             identifiers.int, identifiers.int8, identifiers.int16, identifiers.int32, identifiers.int64,
             identifiers.uInt, identifiers.uInt8, identifiers.uInt16, identifiers.uInt32, identifiers.uInt64:
            return true

        default:
            return false
        }
    }

    // MARK: - Instance Properties

    internal let string = ObjectIdentifier([String].self)
    internal let bool = ObjectIdentifier([Bool].self)
    internal let int = ObjectIdentifier([Int].self)
    internal let int8 = ObjectIdentifier([Int8].self)
    internal let int16 = ObjectIdentifier([Int16].self)
    internal let int32 = ObjectIdentifier([Int32].self)
    internal let int64 = ObjectIdentifier([Int64].self)
    internal let uInt = ObjectIdentifier([UInt].self)
    internal let uInt8 = ObjectIdentifier([UInt8].self)
    internal let uInt16 = ObjectIdentifier([UInt16].self)
    internal let uInt32 = ObjectIdentifier([UInt32].self)
    internal let uInt64 = ObjectIdentifier([UInt64].self)
    internal let double = ObjectIdentifier([Double].self)
    internal let float = ObjectIdentifier([Float].self)
}

// Identifiers of generic types are cached, as looking up their metadata on every call is costly.
internal struct PrimitiveDictionaryType {

    // MARK: - Type Properties

    internal static let identifiers = Self()

    // MARK: - Type Methods

    internal static func contains(_ type: Any.Type) -> Bool {
        let identifiers = Self.identifiers

        switch ObjectIdentifier(type) {
        case identifiers.string, identifiers.bool, identifiers.double, identifiers.float,
             identifiers.int, identifiers.int8, identifiers.int16, identifiers.int32, identifiers.int64,
             identifiers.uInt, identifiers.uInt8, identifiers.uInt16, identifiers.uInt32, identifiers.uInt64:
            return true

        default:
            return false
        }
    }

    // MARK: - Instance Properties

    internal let string = ObjectIdentifier([String: String].self)
    internal let bool = ObjectIdentifier([String: Bool].self)
    internal let int = ObjectIdentifier([String: Int].self)
    internal let int8 = ObjectIdentifier([String: Int8].self)
    internal let int16 = ObjectIdentifier([String: Int16].self)
    internal let int32 = ObjectIdentifier([String: Int32].self)
    internal let int64 = ObjectIdentifier([String: Int64].self)
    internal let uInt = ObjectIdentifier([String: UInt].self)
    internal let uInt8 = ObjectIdentifier([String: UInt8].self)
    internal let uInt16 = ObjectIdentifier([String: UInt16].self)
    internal let uInt32 = ObjectIdentifier([String: UInt32].self)
    internal let uInt64 = ObjectIdentifier([String: UInt64].self)
    internal let double = ObjectIdentifier([String: Double].self)
    internal let float = ObjectIdentifier([String: Float].self)
}

import Foundation

/// Reads a value of a generic type as the type that it is known to be, without the copy that a cast makes.
@inline(__always)
internal func unsafeCast<T, Value>(_ value: borrowing T, to type: Value.Type) -> Value {
    withUnsafePointer(to: value) { pointer in
        UnsafeRawPointer(pointer).assumingMemoryBound(to: Value.self).pointee
    }
}

/// Reads the value of an existential as the type that it is known to be, without the copy and the lookup
/// that a cast makes.
@inline(__always)
internal func unsafeCast<Value>(contentsOf existential: Any, to type: Value.Type) -> Value {
    // Passing the existential to a generic parameter opens it, so the value itself is read.
    func read<T>(_ value: T) -> Value {
        unsafeCast(value, to: Value.self)
    }

    return read(existential)
}

internal struct PrimitiveArrayType {

    // MARK: - Type Properties

    // Identifiers of generic types are cached, as looking up their metadata on every call is costly.
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

internal struct PrimitiveDictionaryType {

    // MARK: - Type Properties

    // Identifiers of generic types are cached, as looking up their metadata on every call is costly.
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

/// How dictionaries hold the values of a type other than the primitive ones, which are checked for in place.
internal enum ValueKind {

    // MARK: - Nested Types

    // Identifiers of types of other modules and of generic types are cached,
    // as looking up their metadata on every call is costly.
    private struct Identifiers {

        // MARK: - Type Properties

        static let shared = Self()

        // MARK: - Instance Properties

        let date = ObjectIdentifier(Date.self)
        let data = ObjectIdentifier(Data.self)
        let url = ObjectIdentifier(URL.self)
        let decimal = ObjectIdentifier(Decimal.self)
        let int128: ObjectIdentifier?
        let uInt128: ObjectIdentifier?

        // MARK: - Initializers

        init() {
            if #available(watchOS 11.0, *) {
                int128 = ObjectIdentifier(Int128.self)
                uInt128 = ObjectIdentifier(UInt128.self)
            } else {
                int128 = nil
                uInt128 = nil
            }
        }
    }

    // MARK: - Enumeration Cases

    /// Values that are coded in containers of their own.
    case nested

    case double
    case float
    case date
    case data
    case url
    case decimal
    case int128
    case uInt128

    /// Arrays of primitive values.
    case primitiveArray

    /// Dictionaries of primitive values keyed by strings.
    case primitiveDictionary

    // MARK: - Initializers

    // Out of line and not generic, as comparing a type with all of these inline makes coding values of every type
    // slower, through the lookups of the metadata and the stack space that the comparisons take.
    @inline(never)
    internal init(of type: Any.Type) {
        let identifiers = Identifiers.shared
        let typeIdentifier = ObjectIdentifier(type)

        switch typeIdentifier {
        case ObjectIdentifier(Double.self):
            self = .double

        case ObjectIdentifier(Float.self):
            self = .float

        case identifiers.date:
            self = .date

        case identifiers.data:
            self = .data

        case identifiers.url:
            self = .url

        case identifiers.decimal:
            self = .decimal

        case identifiers.int128:
            self = .int128

        case identifiers.uInt128:
            self = .uInt128

        default:
            if PrimitiveArrayType.contains(type) {
                self = .primitiveArray
            } else if PrimitiveDictionaryType.contains(type) {
                self = .primitiveDictionary
            } else {
                self = .nested
            }
        }
    }
}

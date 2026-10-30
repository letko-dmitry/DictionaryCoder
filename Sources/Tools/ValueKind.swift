import Foundation

/// Reads a value of a generic type as the type that it is known to be, without the copy that a cast makes.
@inline(always)
internal func unsafeCast<T, Value>(_ value: borrowing T, to type: Value.Type) -> Value {
    withUnsafePointer(to: value) { pointer in
        unsafe UnsafeRawPointer(pointer).assumingMemoryBound(to: Value.self).pointee
    }
}

/// Reads the value of an existential as the type that it is known to be, without the copy and the lookup
/// that a cast makes.
@inline(always)
internal func unsafeCast<Value>(contentsOf existential: Any, to type: Value.Type) -> Value {
    // Passing the existential to a generic parameter opens it, so the value itself is read.
    // Inlined, as a call copies the value through its type, while inline it is a load of a known type.
    @inline(always)
    func read<T>(_ value: T) -> Value {
        unsafeCast(value, to: Value.self)
    }

    return read(existential)
}

/// The type that an existential holds its value as, which is read from the existential rather than looked up
/// at run time, as `type(of:)` does. It is the type of the value itself, unless the value is an object held
/// as `AnyObject`, as Swift collections bridged from Foundation ones hold their elements, or as a superclass.
@inline(always)
internal func storedType(of existential: Any) -> Any.Type {
    @inline(always)
    func type<T>(_ value: T) -> Any.Type {
        T.self
    }

    return type(existential)
}

/// The type of the value of an existential, which is looked up at run time only for an object held as `AnyObject`.
@inline(always)
internal func valueType(of existential: Any, storedAs storedType: Any.Type) -> Any.Type {
    storedType == AnyObject.self ? type(of: existential) : storedType
}

internal struct PrimitiveArrayTypes {

    // MARK: - Type Properties

    // Identifiers of generic types are cached, as looking up their metadata on every call is costly.
    internal static let identifiers = Self()

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

    internal var all: [ObjectIdentifier] {
        [string, bool, int, int8, int16, int32, int64, uInt, uInt8, uInt16, uInt32, uInt64, double, float]
    }
}

internal struct PrimitiveDictionaryTypes {

    // MARK: - Type Properties

    // Identifiers of generic types are cached, as looking up their metadata on every call is costly.
    internal static let identifiers = Self()

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

    internal var all: [ObjectIdentifier] {
        [string, bool, int, int8, int16, int32, int64, uInt, uInt8, uInt16, uInt32, uInt64, double, float]
    }
}

internal enum PrimitiveTypes {

    // MARK: - Type Methods

    /// Whether values of the type are stored in dictionaries as they are,
    /// so they are encoded and decoded without nested containers.
    @inline(always)
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
internal enum ValueKind: UInt8 {

    // MARK: - Nested Types

    /// The kinds of the types that are not coded in containers of their own, by the identifiers of the types.
    ///
    /// A lookup hashes the bits of an identifier rather than comparing it with all of them,
    /// as most types are of nested values, which match none.
    private struct Table {

        // MARK: - Type Properties

        // Identifiers of types of other modules and of generic types are cached,
        // as looking up their metadata on every call is costly.
        static let shared = Self()

        // A power of two, more than three times the kinds, so that most lookups end at their first slot.
        private static let slotCount = 128
        private static let slotMask = slotCount - 1

        // MARK: - Type Methods

        // Metadata is aligned, so the lowest bits of an identifier are the same for all types.
        private static func slot(of identifier: UInt) -> Int {
            Int(truncatingIfNeeded: (identifier >> 4) ^ (identifier >> 11)) & slotMask
        }

        private static func slot(after slot: Int) -> Int {
            (slot + 1) & slotMask
        }

        // Out of line, as it runs once for every kind, and inlined it would copy the probing for every one.
        @inline(never)
        private static func insert(
            _ kind: ValueKind,
            for identifier: ObjectIdentifier,
            into entries: UnsafeMutableBufferPointer<UInt>
        ) {
            let bits = UInt(bitPattern: identifier)
            var slot = Self.slot(of: bits)

            while unsafe entries[slot] != 0 {
                slot = Self.slot(after: slot)
            }

            unsafe entries[slot] = bits
            unsafe entries[slotCount + slot] = UInt(kind.rawValue)
        }

        // MARK: - Instance Properties

        // The bits of the identifiers, then the raw values of their kinds, in one array of words rather than arrays
        // of the identifiers and the kinds themselves, which would make the compiler emit their metadata,
        // value witnesses and the copying of each array. Zero, an address of no type, marks an empty slot.
        private let entries: [UInt]

        // MARK: - Initializers

        private init() {
            // Filled in place, as setting the elements of an array one by one makes the compiler emit
            // the copying of the array, which no other code here needs.
            entries = unsafe [UInt](unsafeUninitializedCapacity: 2 * Self.slotCount) { buffer, count in
                unsafe buffer.initialize(repeating: 0)
                count = 2 * Self.slotCount

                unsafe Self.insert(.double, for: ObjectIdentifier(Double.self), into: buffer)
                unsafe Self.insert(.float, for: ObjectIdentifier(Float.self), into: buffer)
                unsafe Self.insert(.date, for: ObjectIdentifier(Date.self), into: buffer)
                unsafe Self.insert(.data, for: ObjectIdentifier(Data.self), into: buffer)
                unsafe Self.insert(.url, for: ObjectIdentifier(URL.self), into: buffer)
                unsafe Self.insert(.decimal, for: ObjectIdentifier(Decimal.self), into: buffer)

                if #available(watchOS 11.0, *) {
                    unsafe Self.insert(.int128, for: ObjectIdentifier(Int128.self), into: buffer)
                    unsafe Self.insert(.uInt128, for: ObjectIdentifier(UInt128.self), into: buffer)
                }

                for identifier in PrimitiveArrayTypes.identifiers.all {
                    unsafe Self.insert(.primitiveArray, for: identifier, into: buffer)
                }

                for identifier in PrimitiveDictionaryTypes.identifiers.all {
                    unsafe Self.insert(.primitiveDictionary, for: identifier, into: buffer)
                }
            }
        }

        // MARK: - Instance Methods

        // Inlined along with the initializer of the kind, which is all that calls it.
        @inline(always)
        func kind(of identifier: ObjectIdentifier) -> ValueKind {
            let bits = UInt(bitPattern: identifier)

            // Read through a buffer, as the mask keeps every slot within the entries, which the bounds checks
            // of the array cannot tell.
            return entries.withUnsafeBufferPointer { entries in
                var slot = Self.slot(of: bits)

                while unsafe entries[slot] != 0 {
                    if unsafe entries[slot] == bits {
                        let rawValue = unsafe UInt8(truncatingIfNeeded: entries[Self.slotCount + slot])

                        return ValueKind(rawValue: rawValue) ?? .nested
                    }

                    slot = Self.slot(after: slot)
                }

                return .nested
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

    // Inlined, as only the two functions that code values of other types look their types up,
    // so that a lookup costs them no call.
    @inline(always)
    internal init(of type: Any.Type) {
        self = Table.shared.kind(of: ObjectIdentifier(type))
    }
}

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

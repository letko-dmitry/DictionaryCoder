import Foundation

/// A coding path stored as a linked list, so that a nested container extends the path of its parent
/// in constant time, and the array of keys is built only when it is needed.
internal indirect enum CodingPathNode {

    // MARK: - Enumeration Cases

    case root
    case key(CodingKey, parent: CodingPathNode)
    case index(Int, parent: CodingPathNode)

    // MARK: - Instance Properties

    internal var path: [CodingKey] {
        var keys: [CodingKey] = []
        var node = self

        while true {
            switch node {
            case .root:
                return keys.reversed()

            case let .key(key, parent):
                keys.append(key)
                node = parent

            case let .index(index, parent):
                keys.append(AnyCodingKey(index))
                node = parent
            }
        }
    }

    // MARK: - Instance Methods

    @inline(__always)
    internal func appending(_ key: CodingKey) -> Self {
        .key(key, parent: self)
    }

    @inline(__always)
    internal func appending(index: Int) -> Self {
        .index(index, parent: self)
    }
}

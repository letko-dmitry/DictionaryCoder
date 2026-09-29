/// A key of a value in its container: a coding key, or the index of an element in an unkeyed container,
/// which becomes a coding key only when a coding path is built.
internal enum CodingPathKey {

    // MARK: - Enumeration Cases

    case key(CodingKey)
    case index(Int)

    // MARK: - Instance Properties

    internal var codingKey: CodingKey {
        switch self {
        case let .key(key):
            key

        case let .index(index):
            AnyCodingKey(index)
        }
    }
}

/// Where a value is: the node of its container and its key there, both `nil` for the root value.
internal struct CodingPosition {

    // MARK: - Type Properties

    internal static var root: Self {
        Self(container: nil, key: nil)
    }

    // MARK: - Instance Properties

    internal let container: CodingPathNode?
    internal let key: CodingPathKey?

    internal var path: [CodingKey] {
        var keys: [CodingKey] = []
        var position = self

        while let key = position.key {
            keys.append(key.codingKey)

            guard let container = position.container else {
                break
            }

            position = container.position
        }

        return keys.reversed()
    }
}

/// A node of a coding path, which is stored as a linked list, so that a nested value extends the path
/// of its container in constant time, and the array of keys is built only when it is needed.
///
/// The decoders of values are nodes themselves, as every nested value is decoded with a decoder of its own.
/// The containers of the encoder keep nodes of their own, as the containers keep nested containers,
/// which would otherwise refer back to them.
internal class CodingPathNode {

    // MARK: - Instance Properties

    internal final let position: CodingPosition

    internal final var path: [CodingKey] {
        position.path
    }

    // MARK: - Initializers

    internal init(position: CodingPosition) {
        self.position = position
    }
}

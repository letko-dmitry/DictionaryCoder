/// A key of a value in its container: a coding key, or the index of an element in an unkeyed container,
/// which becomes a coding key only when a coding path is built. Neither stands for the position of the container.
///
/// A structure rather than an enumeration with payloads, which the runtime copies by interpreting its layout.
internal struct CodingPathKey {

    // MARK: - Type Properties

    internal static var empty: Self {
        Self(codingKey: nil, index: -1)
    }

    // MARK: - Type Methods

    internal static func key(_ key: CodingKey) -> Self {
        Self(codingKey: key, index: -1)
    }

    internal static func index(_ index: Int) -> Self {
        Self(codingKey: nil, index: index)
    }

    // MARK: - Instance Properties

    internal let codingKey: CodingKey?
    internal let index: Int

    internal var pathKey: CodingKey? {
        if let codingKey {
            return codingKey
        }

        return index < 0 ? nil : AnyCodingKey(index)
    }
}

/// Where a value without a coder of its own is: the node of its container and its key there.
internal struct CodingPosition {

    // MARK: - Instance Properties

    internal let node: CodingPathNode
    internal let key: CodingPathKey

    internal var path: [CodingKey] {
        node.path(appending: key.pathKey)
    }
}

/// A node of a coding path, which is stored as a linked list, so that a nested value extends the path
/// of its container in constant time, and the array of keys is built only when it is needed.
///
/// The coders of values are nodes themselves, as every nested value is coded with a coder of its own.
/// A node without a key stands for the same value as its parent, such as a value that a single value container
/// encodes with a coder of its own.
internal class CodingPathNode {

    // MARK: - Instance Properties

    @exclusivity(unchecked)
    private final var uncheckedParent: CodingPathNode?

    @exclusivity(unchecked)
    private final var uncheckedKey: CodingPathKey

    // Accessed without the exclusivity checks that every access to a stored property of a class makes,
    // as no access lasts while anything else runs.
    internal final var parent: CodingPathNode? {
        get { unsafe uncheckedParent }
        set { unsafe uncheckedParent = newValue }
    }

    internal final var key: CodingPathKey {
        get { unsafe uncheckedKey }
        set { unsafe uncheckedKey = newValue }
    }

    internal final var path: [CodingKey] {
        path(appending: nil)
    }

    // MARK: - Initializers

    internal init(parent: CodingPathNode?, key: CodingPathKey) {
        unsafe self.uncheckedParent = parent
        unsafe self.uncheckedKey = key
    }

    // MARK: - Instance Methods

    /// The path of the node, followed by the key if there is one, which is built in one array from the end.
    internal final func path(appending lastKey: CodingKey?) -> [CodingKey] {
        var keys: [CodingKey] = []

        if let lastKey {
            keys.append(lastKey)
        }

        var node: CodingPathNode? = self

        while let current = node {
            if let key = current.key.pathKey {
                keys.append(key)
            }

            node = current.parent
        }

        keys.reverse()

        return keys
    }

    /// The position of a value in the container of this node.
    internal final func position(at key: CodingPathKey) -> CodingPosition {
        CodingPosition(node: self, key: key)
    }
}

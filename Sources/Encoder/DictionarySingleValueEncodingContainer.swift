/// The encoder of a value, which is its single value container as well.
///
/// It keeps the position of the value rather than a node of its coding path,
/// as a node is needed only for the containers of the value.
internal final class DictionarySingleValueEncodingContainer:
    Encoder,
    SingleValueEncodingContainer,
    DictionaryComponentContainer {

    // MARK: - Type Methods

    // Accesses to the stored properties of a class are checked for exclusivity at run time,
    // so the component is checked and stored in one access.
    @inline(__always)
    private static func store(_ component: consuming DictionaryComponent, in slot: inout DictionaryComponent?) -> Bool {
        guard slot == nil else {
            return false
        }

        slot = component

        return true
    }

    @inline(__always)
    private static func container<Container: DictionaryComponentContainer>(
        in slot: inout DictionaryComponent?,
        makeContainer: () -> Container
    ) -> Container {
        if case let .container(container as Container) = slot {
            return container
        }

        let container = makeContainer()

        slot = .container(container)

        return container
    }

    // MARK: - Instance Properties

    private var component: DictionaryComponent?

    internal let context: DictionaryComponentEncoder
    internal let position: CodingPosition

    internal var codingPath: [CodingKey] {
        position.path
    }

    internal var userInfo: [CodingUserInfoKey: Any] {
        context.userInfo
    }

    // MARK: - Initializers

    internal init(
        context: DictionaryComponentEncoder,
        position: CodingPosition
    ) {
        self.context = context
        self.position = position
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func collect(_ component: consuming Any?, of value: Any?) throws {
        guard Self.store(.value(component), in: &self.component) else {
            let errorContext = EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Single value container already has encoded value"
            )

            throw EncodingError.invalidValue(value as Any, errorContext)
        }
    }

    // MARK: - SingleValueEncodingContainer

    internal func encodeNil() throws {
        try collect(context.encodeNil(), of: nil)
    }

    internal func encode(_ value: Bool) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: Int) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: Int8) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: Int16) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: Int32) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: Int64) throws {
        try collect(value, of: value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: Int128) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: UInt) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: UInt8) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: UInt16) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: UInt32) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: UInt64) throws {
        try collect(value, of: value)
    }

    @available(watchOS 11.0, *)
    internal func encode(_ value: UInt128) throws {
        try collect(value, of: value)
    }

    internal func encode(_ value: Double) throws {
        try collect(context.encodeFloatingPoint(value, at: position), of: value)
    }

    internal func encode(_ value: Float) throws {
        try collect(context.encodeFloatingPoint(value, at: position), of: value)
    }

    internal func encode(_ value: String) throws {
        try collect(value, of: value)
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        try collect(context.encode(value, at: position), of: value)
    }

    // MARK: - Encoder

    internal func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = Self.container(in: &component) {
            DictionaryAnyKeyedEncodingContainer(context: context, codingPathNode: CodingPathNode(position: position))
        }

        return KeyedEncodingContainer(DictionaryKeyedEncodingContainer<Key>(container: container))
    }

    internal func unkeyedContainer() -> UnkeyedEncodingContainer {
        Self.container(in: &component) {
            DictionaryUnkeyedEncodingContainer(context: context, codingPathNode: CodingPathNode(position: position))
        }
    }

    internal func singleValueContainer() -> SingleValueEncodingContainer {
        self
    }

    // MARK: - DictionaryComponentContainer

    // The component is taken rather than copied, as a value is resolved once, when it is encoded.
    internal func resolveValue() -> Any? {
        component.take()?.resolveValue()
    }
}

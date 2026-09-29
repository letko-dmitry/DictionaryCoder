import Foundation

internal final class DictionaryUnkeyedEncodingContainer:
    UnkeyedEncodingContainer,
    DictionaryComponentContainer {

    // MARK: - Instance Properties

    private var components: [DictionaryComponent] = []

    internal let context: DictionaryComponentEncoder
    internal let codingPath: [CodingKey]

    @inline(__always)
    internal var currentCodingPath: [CodingKey] {
        codingPath.appending(AnyCodingKey(count))
    }

    internal var count: Int {
        components.count
    }

    // MARK: - Initializers

    internal init(
        context: DictionaryComponentEncoder,
        codingPath: [CodingKey]
    ) {
        self.context = context
        self.codingPath = codingPath
    }

    // MARK: - Instance Methods

    @inline(__always)
    private func collectComponent(_ component: consuming DictionaryComponent) {
        components.append(component)
    }

    // MARK: - UnkeyedEncodingContainer

    internal func encodeNil() throws {
        collectComponent(context.encodeNilComponent(at: currentCodingPath))
    }

    internal func encode(_ value: Bool) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Int) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Int8) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Int16) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Int32) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Int64) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: UInt) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: UInt8) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: UInt16) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: UInt32) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: UInt64) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Double) throws {
        collectComponent(try context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: Float) throws {
        collectComponent(try context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode(_ value: String) throws {
        collectComponent(context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func encode<T: Encodable>(_ value: T) throws {
        collectComponent(try context.encodeComponentValue(value, at: currentCodingPath))
    }

    internal func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let container = DictionaryAnyKeyedEncodingContainer(
            context: context,
            codingPath: currentCodingPath
        )

        collectComponent(.container(container))

        return KeyedEncodingContainer(
            DictionaryKeyedEncodingContainer<NestedKey>(container: container)
        )
    }

    internal func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = DictionaryUnkeyedEncodingContainer(
            context: context,
            codingPath: currentCodingPath
        )

        collectComponent(.container(container))

        return container
    }

    internal func superEncoder() -> Encoder {
        let encoder = DictionarySingleValueEncodingContainer(
            context: context,
            codingPath: currentCodingPath
        )

        collectComponent(.container(encoder))

        return encoder
    }

    // MARK: - DictionaryComponentContainer

    internal func resolveValue() -> Any? {
        components.map { component in
            let value = component.resolveValue()

            return value ?? value as Any
        }
    }
}

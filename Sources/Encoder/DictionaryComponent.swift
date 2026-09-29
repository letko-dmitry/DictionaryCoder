internal enum DictionaryComponent {

    // MARK: - Enumeration Cases

    case value(Any?)
    case container(DictionaryComponentContainer)

    // MARK: - Instance Methods

    internal consuming func resolveValue() -> Any? {
        switch consume self {
        case .value(let value):
            value

        case .container(let container):
            container.resolveValue()
        }
    }
}

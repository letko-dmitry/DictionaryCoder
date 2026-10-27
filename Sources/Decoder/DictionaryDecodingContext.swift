/// The options and user info of one decoding, shared by the decoders of all its values.
internal final class DictionaryDecodingContext: Sendable {

    // MARK: - Instance Properties

    internal let options: DictionaryDecodingOptions

    // MARK: - Initializers

    internal init(options: DictionaryDecodingOptions) {
        self.options = options
    }
}

/// The options and user info of a `DictionaryDecoder`, shared by the decoders of its values until the options change.
internal final class DictionaryDecodingContext: Sendable {

    // MARK: - Instance Properties

    internal let options: DictionaryDecodingOptions

    // MARK: - Initializers

    internal init(options: DictionaryDecodingOptions) {
        self.options = options
    }
}

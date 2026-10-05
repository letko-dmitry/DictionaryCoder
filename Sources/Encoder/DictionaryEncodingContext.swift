import Foundation

/// The options and user info of one encoding, shared by the encoders of all its values.
internal final class DictionaryEncodingContext {

    // MARK: - Instance Properties

    internal let options: DictionaryEncodingOptions

    /// What `nil` is encoded as.
    internal let encodedNil: Any?

    // MARK: - Initializers

    internal init(options: DictionaryEncodingOptions) {
        self.options = options

        switch options.nilEncodingStrategy {
        case .useNil:
            self.encodedNil = nil

        case .useNSNull:
            self.encodedNil = NSNull()
        }
    }
}

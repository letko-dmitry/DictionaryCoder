import Foundation

/// The options and user info of a `DictionaryEncoder`, shared by the encoders of its values until the options change.
internal final class DictionaryEncodingContext: Sendable {

    // MARK: - Instance Properties

    internal let options: DictionaryEncodingOptions

    /// What `nil` is encoded as.
    internal let encodedNil: (any Sendable)?

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

/// The strategies for decoding decimals, which can be combined to accept both representations.
public struct DictionaryDecimalDecodingStrategy: OptionSet, Sendable {

    // MARK: - Type Properties

    // Computed and emitted into clients rather than stored, so that a client gets a constant rather than a call.

    /// The strategy that decodes decimals from the keyed representation of the decimal type itself.
    @inline(always)
    @export(implementation)
    public static var deferredToDecimal: Self {
        Self(rawValue: 1 << 0)
    }

    /// The strategy that decodes decimals from numbers, such as `Decimal`, `NSDecimalNumber` or `Double`.
    @inline(always)
    @export(implementation)
    public static var number: Self {
        Self(rawValue: 1 << 1)
    }

    // MARK: - Instance Properties

    public let rawValue: Int

    // MARK: - Initializers

    @inline(always)
    @export(implementation)
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

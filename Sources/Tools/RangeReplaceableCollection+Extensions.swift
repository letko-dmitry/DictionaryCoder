extension RangeReplaceableCollection {

    // MARK: - Instance Methods

    @inline(always)
    internal func appending(_ element: Element) -> Self {
        var collection = self

        collection.append(element)

        return collection
    }
}

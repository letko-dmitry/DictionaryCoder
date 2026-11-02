import XCTest

@testable import DictionaryCoder

final class ValueKindTests: XCTestCase {

    // MARK: - Instance Methods

    func testThatValueKindMatchesTypesCodedInPlace() {
        XCTAssertEqual(ValueKind(of: Double.self), .double)
        XCTAssertEqual(ValueKind(of: Float.self), .float)
        XCTAssertEqual(ValueKind(of: Date.self), .date)
        XCTAssertEqual(ValueKind(of: Data.self), .data)
        XCTAssertEqual(ValueKind(of: URL.self), .url)
        XCTAssertEqual(ValueKind(of: Decimal.self), .decimal)
        XCTAssertEqual(ValueKind(of: Int128.self), .int128)
        XCTAssertEqual(ValueKind(of: UInt128.self), .uInt128)
    }

    func testThatValueKindMatchesPrimitiveArrays() {
        let types: [Any.Type] = [
            [String].self,
            [Bool].self,
            [Int].self,
            [Int8].self,
            [Int16].self,
            [Int32].self,
            [Int64].self,
            [UInt].self,
            [UInt8].self,
            [UInt16].self,
            [UInt32].self,
            [UInt64].self,
            [Double].self,
            [Float].self
        ]

        for type in types {
            XCTAssertEqual(ValueKind(of: type), .primitiveArray, "\(type)")
        }
    }

    func testThatValueKindMatchesPrimitiveDictionaries() {
        let types: [Any.Type] = [
            [String: String].self,
            [String: Bool].self,
            [String: Int].self,
            [String: Int8].self,
            [String: Int16].self,
            [String: Int32].self,
            [String: Int64].self,
            [String: UInt].self,
            [String: UInt8].self,
            [String: UInt16].self,
            [String: UInt32].self,
            [String: UInt64].self,
            [String: Double].self,
            [String: Float].self
        ]

        for type in types {
            XCTAssertEqual(ValueKind(of: type), .primitiveDictionary, "\(type)")
        }
    }

    func testThatValueKindIsNestedForOtherTypes() {
        struct Value { }

        let types: [Any.Type] = [
            Value.self,
            Double?.self,
            [Int?].self,
            [[Int]].self,
            [Date].self,
            Set<Int>.self,
            [Int: Int].self,
            [String: Int?].self,
            [String: [Int]].self
        ]

        for type in types {
            XCTAssertEqual(ValueKind(of: type), .nested, "\(type)")
        }
    }
}

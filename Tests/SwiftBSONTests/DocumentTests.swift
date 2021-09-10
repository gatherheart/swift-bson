import Foundation
import Nimble
@testable import SwiftBSON
import XCTest

final class DocumentTests: BSONTestCase {
    // This is a test in itself, will fail to compile on unsupported values
    static let smallTestDoc: BSONDocument = [
        "int": 0xBAD1DEA,
        "int32": .int32(32),
        "int64": .int64(64)
    ]

    func testCount() {
        expect(DocumentTests.smallTestDoc.count).to(equal(3))
    }

    func testKeys() {
        expect(DocumentTests.smallTestDoc.keys).to(equal(["int", "int32", "int64"]))
    }

    func testValues() {
        expect(DocumentTests.smallTestDoc.values[0]).to(equal(0xBAD1DEA))
        expect(DocumentTests.smallTestDoc.values[1]).to(equal(.int32(32)))
        expect(DocumentTests.smallTestDoc.values[2]).to(equal(.int64(64)))
    }

    func testSubscript() {
        expect(DocumentTests.smallTestDoc["int"]).to(equal(0xBAD1DEA))
    }

    func testDynamicMemberLookup() {
        expect(DocumentTests.smallTestDoc.int).to(equal(0xBAD1DEA))
    }

    func testModifying() {
        var doc: BSONDocument = ["a": .int32(32), "b": .int64(64), "c": 20]
        doc["a"] = .int32(45) // change
        doc["c"] = .int32(90) // change type
        doc["b"] = nil // delete
        doc["d"] = 3 // append
        let res: BSONDocument = ["a": .int32(45), "c": .int32(90), "d": 3]
        expect(doc.buffer.toByteString()).to(equal(res.buffer.toByteString()))
    }

    func testDelete() {
        var doc: BSONDocument = ["a": .int32(32), "b": .int64(64), "c": 20]
        doc["a"] = nil
        doc["z"] = nil // deleting a key that doesn't exist should be a no-op
        expect(["b", "c"]).to(equal(doc.keys))
    }

    func testDefault() {
        let d: BSONDocument = ["hello": 12]
        expect(d["hello", default: 0xBAD1DEA]).to(equal(12))
        expect(d["a", default: 0xBAD1DEA]).to(equal(0xBAD1DEA))
    }

    // Set up test document values
    static let testDoc: BSONDocument = [
        "string": "test string",
        "true": true,
        "false": false,
        "int": 25,
        "int32": .int32(5),
        "int64": .int64(10),
        "double": .double(15),
        "decimal128": .decimal128(try! BSONDecimal128("1.2E+10")),
        "minkey": .minKey,
        "maxkey": .maxKey,
        "date": .datetime(Date(timeIntervalSince1970: 500.004)),
        "timestamp": .timestamp(BSONTimestamp(timestamp: 5, inc: 10)),
        "nestedarray": [[1, 2], [.int32(3), .int32(4)]],
        "nesteddoc": ["a": 1, "b": 2, "c": false, "d": [3, 4]],
        "oid": .objectID(try! BSONObjectID("507f1f77bcf86cd799439011")),
        "regex": .regex(BSONRegularExpression(pattern: "^abc", options: "imx")),
        "array1": [1, 2],
        "array2": ["string1", "string2"],
        "null": .null,
        "code": .code(BSONCode(code: "console.log('hi');")),
        "codewscope": .codeWithScope(BSONCodeWithScope(code: "console.log(x);", scope: ["x": 2]))
    ]

    func testDocument() throws {
        var doc = DocumentTests.testDoc // make a copy to mutate in this test

        // A Data object to pass into test BSON Binary objects
        guard let testData = Data(base64Encoded: "//8=") else {
            XCTFail("Failed to create test binary data")
            return
        }

        guard let uuidData = Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==") else {
            XCTFail("Failed to create test UUID data")
            return
        }

        let binaryData: BSONDocument = [
            "binary0": .binary(try BSONBinary(data: testData, subtype: .generic)),
            "binary1": .binary(try BSONBinary(data: testData, subtype: .function)),
            "binary2": .binary(try BSONBinary(data: testData, subtype: .binaryDeprecated)),
            "binary3": .binary(try BSONBinary(data: uuidData, subtype: .uuidDeprecated)),
            "binary4": .binary(try BSONBinary(data: uuidData, subtype: .uuid)),
            "binary5": .binary(try BSONBinary(data: testData, subtype: .md5)),
            "binary6": .binary(try BSONBinary(data: testData, subtype: .userDefined(200)))
        ]
        for (k, v) in binaryData {
            doc[k] = v
        }

        // UUIDs must have 16 bytes
        expect(try BSONBinary(data: testData, subtype: .uuidDeprecated))
            .to(throwError(errorType: BSONError.InvalidArgumentError.self))
        expect(try BSONBinary(data: testData, subtype: .uuid))
            .to(throwError(errorType: BSONError.InvalidArgumentError.self))

        let expectedKeys = [
            "string", "true", "false", "int", "int32", "int64", "double", "decimal128",
            "minkey", "maxkey", "date", "timestamp", "nestedarray", "nesteddoc", "oid",
            "regex", "array1", "array2", "null", "code", "codewscope", "binary0", "binary1",
            "binary2", "binary3", "binary4", "binary5", "binary6"
        ]
        expect(doc.count).to(equal(expectedKeys.count))
        expect(doc.keys).to(equal(expectedKeys))

        expect(doc["string"]).to(equal("test string"))
        expect(doc["true"]).to(equal(true))
        expect(doc["false"]).to(equal(false))
        expect(doc["int"]).to(equal(25))
        expect(doc["int32"]).to(equal(.int32(5)))
        expect(doc["int64"]).to(equal(.int64(10)))
        expect(doc["double"]).to(equal(15.0))
        expect(doc["decimal128"]).to(equal(.decimal128(try BSONDecimal128("1.2E+10"))))
        expect(doc["minkey"]).to(equal(.minKey))
        expect(doc["maxkey"]).to(equal(.maxKey))
        expect(doc["date"]).to(equal(.datetime(Date(timeIntervalSince1970: 500.004))))
        expect(doc["timestamp"]).to(equal(.timestamp(BSONTimestamp(timestamp: 5, inc: 10))))
        expect(doc["oid"]).to(equal(.objectID(try BSONObjectID("507f1f77bcf86cd799439011"))))

        let regex = doc["regex"]!.regexValue!
        expect(regex).to(equal(BSONRegularExpression(pattern: "^abc", options: "imx")))
        expect(try regex.toNSRegularExpression()).to(equal(try NSRegularExpression(
            pattern: "^abc",
            options: NSRegularExpression.optionsFromString("imx")
        )))

        expect(doc["array1"]).to(equal([1, 2]))
        expect(doc["array2"]).to(equal(["string1", "string2"]))
        expect(doc["null"]).to(equal(.null))

        let code = doc["code"]?.codeValue
        expect(code?.code).to(equal("console.log('hi');"))

        let codewscope = doc["codewscope"]?.codeWithScopeValue
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        expect(doc["binary0"]).to(equal(.binary(try BSONBinary(data: testData, subtype: .generic))))
        expect(doc["binary1"]).to(equal(.binary(try BSONBinary(data: testData, subtype: .function))))
        expect(doc["binary2"]).to(equal(.binary(try BSONBinary(data: testData, subtype: .binaryDeprecated))))
        expect(doc["binary3"]).to(equal(.binary(try BSONBinary(data: uuidData, subtype: .uuidDeprecated))))
        expect(doc["binary4"]).to(equal(.binary(try BSONBinary(data: uuidData, subtype: .uuid))))
        expect(doc["binary5"]).to(equal(.binary(try BSONBinary(data: testData, subtype: .md5))))
        expect(doc["binary6"]).to(equal(.binary(try BSONBinary(data: testData, subtype: .userDefined(200)))))

        let nestedArray = doc["nestedarray"]?.arrayValue?.compactMap { $0.arrayValue?.compactMap { $0.toInt() } }
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(doc["nesteddoc"]).to(equal(["a": 1, "b": 2, "c": false, "d": [3, 4]]))
    }

    func testDocumentDynamicMemberLookup() throws {
        // Test reading various types
        expect(DocumentTests.testDoc.string).to(equal("test string"))
        expect(DocumentTests.testDoc.true).to(equal(true))
        expect(DocumentTests.testDoc.false).to(equal(false))
        expect(DocumentTests.testDoc.int).to(equal(25))
        expect(DocumentTests.testDoc.int32).to(equal(.int32(5)))
        expect(DocumentTests.testDoc.int64).to(equal(.int64(10)))
        expect(DocumentTests.testDoc.double).to(equal(15.0))
        expect(DocumentTests.testDoc.decimal128).to(equal(.decimal128(try BSONDecimal128("1.2E+10"))))
        expect(DocumentTests.testDoc.minkey).to(equal(.minKey))
        expect(DocumentTests.testDoc.maxkey).to(equal(.maxKey))
        expect(DocumentTests.testDoc.date).to(equal(.datetime(Date(timeIntervalSince1970: 500.004))))
        expect(DocumentTests.testDoc.timestamp).to(equal(.timestamp(BSONTimestamp(timestamp: 5, inc: 10))))
        expect(DocumentTests.testDoc.oid).to(equal(.objectID(try BSONObjectID("507f1f77bcf86cd799439011"))))

        let codewscope = DocumentTests.testDoc.codewscope?.codeWithScopeValue
        expect(codewscope?.code).to(equal("console.log(x);"))
        expect(codewscope?.scope).to(equal(["x": 2]))

        let code = DocumentTests.testDoc.code?.codeValue
        expect(code?.code).to(equal("console.log('hi');"))

        expect(DocumentTests.testDoc.array1).to(equal([1, 2]))
        expect(DocumentTests.testDoc.array2).to(equal(["string1", "string2"]))
        expect(DocumentTests.testDoc.null).to(equal(.null))

        let regex = DocumentTests.testDoc.regex!.regexValue!
        expect(regex).to(equal(BSONRegularExpression(pattern: "^abc", options: "imx")))
        expect(try regex.toNSRegularExpression()).to(equal(try NSRegularExpression(
            pattern: "^abc",
            options: NSRegularExpression.optionsFromString("imx")
        )))

        let nestedArray = DocumentTests.testDoc.nestedarray?.arrayValue?.compactMap {
            $0.arrayValue?.compactMap { $0.toInt() }
        }
        expect(nestedArray?[0]).to(equal([1, 2]))
        expect(nestedArray?[1]).to(equal([3, 4]))

        expect(DocumentTests.testDoc.nesteddoc).to(equal(["a": 1, "b": 2, "c": false, "d": [3, 4]]))
        expect(DocumentTests.testDoc.nesteddoc?.documentValue?.a).to(equal(1))

        // Test assignment
        var doc = BSONDocument()
        let subdoc: BSONDocument = ["d": 2.5]

        doc.a = 1
        doc.b = "b"
        doc.c = .document(subdoc)

        expect(doc.a).to(equal(1))
        expect(doc.b).to(equal("b"))
        expect(doc.c).to(equal(.document(subdoc)))

        doc.a = 2
        doc.b = "different"

        expect(doc.a).to(equal(2))
        expect(doc.b).to(equal("different"))
    }

    func testEquatable() {
        expect(["hi": true, "hello": "hi", "cat": 2] as BSONDocument)
            .to(equal(["hi": true, "hello": "hi", "cat": 2] as BSONDocument))
    }

    func testEqualsIgnoreKeyOrder() throws {
        // basic comparisons
        let doc1: BSONDocument = ["foo": "bar", "bread": 1]
        let doc2: BSONDocument = ["foo": "bar", "bread": 1]
        expect(doc1.equalsIgnoreKeyOrder(doc2)).to(equal(true))

        let doc3: BSONDocument = ["foo": "bar", "bread": 1]
        let doc4: BSONDocument = ["foo": "foo", "bread": 2]
        expect(doc3.equalsIgnoreKeyOrder(doc4)).to(equal(false))

        // more complex comparisons
        let a: BSONDocument = [
            "string": "test string",
            "true": true,
            "false": false,
            "int": 25,
            "int32": .int32(5),
            "int64": .int64(10),
            "double": .double(15),
            "regex": .regex(BSONRegularExpression(pattern: "^abc", options: "imx")),
            "decimal128": .decimal128(try! BSONDecimal128("1.2E+10")),
            "minkey": .minKey,
            "maxkey": .maxKey,
            "date": .datetime(Date(timeIntervalSince1970: 500.004)),
            "timestamp": .timestamp(BSONTimestamp(timestamp: 5, inc: 10)),
            "nesteddoc": ["a": 1, "b": 2, "c": false, "d": [3, 4]],
            "oid": .objectID(try! BSONObjectID("507f1f77bcf86cd799439011")),
            "array1": [1, 2],
            "array2": ["string1", "string2"],
            "null": .null,
            "code": .code(BSONCode(code: "console.log('hi');")),
            "nestedarray": [[1, 2], [.int32(3), .int32(4)], ["x": 1, "y": 2]],
            "codewscope": .codeWithScope(BSONCodeWithScope(code: "console.log(x);", scope: ["y": 1, "x": 2]))
        ]

        let b: BSONDocument = [
            "true": true,
            "int": 25,
            "int32": .int32(5),
            "int64": .int64(10),
            "string": "test string",
            "double": .double(15),
            "decimal128": .decimal128(try! BSONDecimal128("1.2E+10")),
            "minkey": .minKey,
            "date": .datetime(Date(timeIntervalSince1970: 500.004)),
            "timestamp": .timestamp(BSONTimestamp(timestamp: 5, inc: 10)),
            "nestedarray": [[1, 2], [.int32(3), .int32(4)], ["y": 2, "x": 1]],
            "codewscope": .codeWithScope(BSONCodeWithScope(code: "console.log(x);", scope: ["x": 2, "y": 1])),
            "nesteddoc": ["b": 2, "a": 1, "d": [3, 4], "c": false],
            "oid": .objectID(try! BSONObjectID("507f1f77bcf86cd799439011")),
            "false": false,
            "regex": .regex(BSONRegularExpression(pattern: "^abc", options: "imx")),
            "array1": [1, 2],
            "array2": ["string1", "string2"],
            "null": .null,
            "code": .code(BSONCode(code: "console.log('hi');")),
            "maxkey": .maxKey
        ]

        // comparing two documents with the same key-value pairs in different order should return true
        expect(a.equalsIgnoreKeyOrder(b)).to(equal(true))

        let c: BSONDocument = [
            "true": true,
            "int": 52,
            "int32": .int32(15),
            "int64": .int64(100),
            "string": "this is different string",
            "double": .double(15),
            "decimal128": .decimal128(try! BSONDecimal128("1.2E+10")),
            "minkey": .minKey,
            "date": .datetime(Date(timeIntervalSince1970: 500.004)),
            "array1": [1, 2],
            "timestamp": .timestamp(BSONTimestamp(timestamp: 5, inc: 10)),
            "nestedarray": [[1, 2], [.int32(3), .int32(4)]],
            "codewscope": .codeWithScope(BSONCodeWithScope(code: "console.log(x);", scope: ["x": 2])),
            "nesteddoc": ["1": 1, "2": 2, "3": true, "4": [5, 6]],
            "oid": .objectID(try! BSONObjectID("507f1f77bcf86cd799439011")),
            "false": false,
            "regex": .regex(BSONRegularExpression(pattern: "^abc", options: "imx")),
            "array2": ["string3", "string2", "string1"],
            "null": .null,
            "code": .code(BSONCode(code: "console.log('hi');")),
            "maxkey": .maxKey
        ]

        // comparing two documents with same keys but different values should return false
        expect(a.equalsIgnoreKeyOrder(c)).to(equal(false))
    }

    func testRawBSON() throws {
        let doc = try BSONDocument(fromJSON: "{\"a\":[{\"$numberInt\":\"10\"}]}")
        let fromRawBSON = try BSONDocument(fromBSON: doc.buffer)
        expect(doc).to(equal(fromRawBSON))
    }

    func testCopyOnWriteBehavior() {
        var doc1: BSONDocument = ["a": 1]
        var doc2 = doc1

        doc2["b"] = 2

        // only should have mutated doc2
        expect(doc1["b"]).to(beNil())
        expect(doc2["b"]).to(equal(2))

        doc1["c"] = 3

        // mutating doc1 should not mutate doc2
        expect(doc1["c"]).to(equal(3))
        expect(doc2["c"]).to(beNil())
    }

    func testIntEncodesAsInt32OrInt64() {
        guard !BSONTestCase.is32Bit else {
            return
        }

        let int32min_sub1 = Int64(Int32.min) - Int64(1)
        let int32max_add1 = Int64(Int32.max) + Int64(1)

        let doc: BSONDocument = [
            "int32min": BSON(Int(Int32.min)),
            "int32max": BSON(Int(Int32.max)),
            "int32min-1": BSON(Int(int32min_sub1)),
            "int32max+1": BSON(Int(int32max_add1)),
            "int64min": BSON(Int(Int64.min)),
            "int64max": BSON(Int(Int64.max))
        ]

        expect(doc["int32min"]).to(equal(.int64(Int64(Int32.min))))
        expect(doc["int32max"]).to(equal(.int64(Int64(Int32.max))))
        expect(doc["int32min-1"]).to(equal(.int64(int32min_sub1)))
        expect(doc["int32max+1"]).to(equal(.int64(int32max_add1)))
        expect(doc["int64min"]).to(equal(.int64(Int64.min)))
        expect(doc["int64max"]).to(equal(.int64(Int64.max)))
    }

    func testNilInNestedArray() throws {
        let arr1: BSON = ["a", "b", "c", .null]
        let arr2: BSON = ["d", "e", .null, "f"]

        let doc = ["a1": arr1, "a2": arr2]

        expect(doc["a1"]).to(equal(arr1))
        expect(doc["a2"]).to(equal(arr2))
    }

    // Test overwriting with value of same type
    func testOverwritingValues() throws {
        var doc = DocumentTests.testDoc

        doc["string"] = "hi"
        doc["true"] = false
        doc["false"] = true
        doc["int"] = 1000
        doc["int32"] = .int32(15)
        doc["int64"] = .int64(4)
        doc["double"] = 3.0
        doc["decimal128"] = .decimal128(try BSONDecimal128("100"))
        doc["minkey"] = .minKey
        doc["maxkey"] = .maxKey
        doc["date"] = .datetime(Date(msSinceEpoch: 2000))
        doc["timestamp"] = .timestamp(BSONTimestamp(timestamp: 20, inc: 30))
        doc["nestedarray"] = [[3, 4], [.int32(5), .int32(6)]]
        doc["nesteddoc"] = ["e": 5, "f": 6]
        let newOid = BSONObjectID()
        doc["oid"] = .objectID(newOid)
        doc["regex"] = .regex(BSONRegularExpression(pattern: "xyz$", options: "ix"))
        doc["array1"] = [10, 11, 12]
        doc["array2"] = ["zzzzzz"]
        doc["null"] = .null
        doc["code"] = .code(BSONCode(code: "console.log('bye');"))
        doc["codewscope"] = .codeWithScope(BSONCodeWithScope(code: "console.log(z);", scope: ["z": 100]))

        expect(doc).to(equal([
            "string": "hi",
            "true": false,
            "false": true,
            "int": 1000,
            "int32": .int32(15),
            "int64": .int64(4),
            "double": 3.0,
            "decimal128": .decimal128(try BSONDecimal128("100")),
            "minkey": .minKey,
            "maxkey": .maxKey,
            "date": .datetime(Date(msSinceEpoch: 2000)),
            "timestamp": .timestamp(BSONTimestamp(timestamp: 20, inc: 30)),
            "nestedarray": [[3, 4], [.int32(5), .int32(6)]],
            "nesteddoc": ["e": 5, "f": 6],
            "oid": .objectID(newOid),
            "regex": .regex(BSONRegularExpression(pattern: "xyz$", options: "ix")),
            "array1": [10, 11, 12],
            "array2": ["zzzzzz"],
            "null": .null,
            "code": .code(BSONCode(code: "console.log('bye');")),
            "codewscope": .codeWithScope(BSONCodeWithScope(code: "console.log(z);", scope: ["z": 100]))
        ]))
    }

    // test replacing values with values of different types
    func testReplaceValueWithNewType() throws {
        var doc = DocumentTests.testDoc

        doc["string"] = false
        doc["true"] = "hi"
        doc["false"] = 1000
        doc["int"] = true
        doc["int32"] = .int64(4)
        doc["int64"] = .int32(15)
        doc["double"] = .decimal128(try BSONDecimal128("100"))
        doc["decimal128"] = 3.0
        doc["minkey"] = .maxKey
        doc["maxkey"] = .minKey
        doc["date"] = .timestamp(BSONTimestamp(timestamp: 20, inc: 30))
        doc["timestamp"] = .datetime(Date(msSinceEpoch: 2000))
        doc["nestedarray"] = ["e": 5, "f": 6]
        doc["nesteddoc"] = [[3, 4], [.int32(5), .int32(6)]]
        doc["oid"] = .regex(BSONRegularExpression(pattern: "xyz$", options: "ix"))
        let newOid = BSONObjectID()
        doc["regex"] = .objectID(newOid)
        doc["array1"] = [10, 11, 12]
        doc["array2"] = .null
        doc["null"] = ["zzzzzz"]
        doc["code"] = .codeWithScope(BSONCodeWithScope(code: "console.log(z);", scope: ["z": 100]))
        doc["codewscope"] = .code(BSONCode(code: "console.log('bye');"))

        expect(doc).to(equal([
            "string": false,
            "true": "hi",
            "false": 1000,
            "int": true,
            "int32": .int64(4),
            "int64": .int32(15),
            "double": .decimal128(try BSONDecimal128("100")),
            "decimal128": 3.0,
            "minkey": .maxKey,
            "maxkey": .minKey,
            "date": .timestamp(BSONTimestamp(timestamp: 20, inc: 30)),
            "timestamp": .datetime(Date(msSinceEpoch: 2000)),
            "nestedarray": ["e": 5, "f": 6],
            "nesteddoc": [[3, 4], [.int32(5), .int32(6)]],
            "oid": .regex(BSONRegularExpression(pattern: "xyz$", options: "ix")),
            "regex": .objectID(newOid),
            "array1": [10, 11, 12],
            "array2": .null,
            "null": ["zzzzzz"],
            "code": .codeWithScope(BSONCodeWithScope(code: "console.log(z);", scope: ["z": 100])),
            "codewscope": .code(BSONCode(code: "console.log('bye');"))
        ]))
    }

    // test setting both overwritable and nonoverwritable values to nil
    func testDeletions() throws {
        var copy = DocumentTests.testDoc
        for key in DocumentTests.testDoc.keys {
            copy[key] = nil
        }
        expect(copy).to(equal([:]))
    }

    func testDocumentDictionarySimilarity() throws {
        var doc: BSONDocument = ["hello": "world", "swift": 4.2, "null": .null, "remove_me": "please"]
        let dict: [String: BSON] = ["hello": "world", "swift": 4.2, "null": .null, "remove_me": "please"]

        expect(doc["hello"]).to(equal(dict["hello"]))
        expect(doc["swift"]).to(equal(dict["swift"]))
        expect(doc["nonexistent key"]).to(beNil())
        expect(doc["null"]).to(equal(dict["null"]))

        doc["remove_me"] = nil

        expect(doc["remove_me"]).to(beNil())
        expect(doc.hasKey("remove_me")).to(beFalse())
    }

    func testDefaultSubscript() throws {
        let doc: BSONDocument = ["hello": "world"]
        let floatVal = 18.2
        let stringVal = "this is a string"
        expect(doc["DNE", default: .double(floatVal)]).to(equal(.double(floatVal)))
        expect(doc["hello", default: .double(floatVal)]).to(equal(doc["hello"]))
        expect(doc["DNE", default: .string(stringVal)]).to(equal(.string(stringVal)))
        expect(doc["DNE", default: .null]).to(equal(.null))
        expect(doc["autoclosure test", default: .double(floatVal * floatVal)]).to(equal(.double(floatVal * floatVal)))
        expect(doc["autoclosure test", default: .string("\(stringVal) and \(floatVal)" + stringVal)])
            .to(equal(.string("\(stringVal) and \(floatVal)" + stringVal)))
    }

    func testMultibyteCharacterStrings() throws {
        let str = String(repeating: "🇧🇷", count: 10)

        var doc: BSONDocument = ["first": .string(str)]
        expect(doc["first"]).to(equal(.string(str)))

        let doc1: BSONDocument = [str: "second"]
        expect(doc1[str]).to(equal("second"))

        let abt = try CodecTests.AllBSONTypes.factory()
        try Mirror(reflecting: abt).children.forEach { child in
            let value = child.value as! BSONValue
            doc[str] = try value.toBSON()
            expect(doc[str]).to(equal(try value.toBSON()))
        }
    }

    struct UUIDWrapper: Codable {
        let uuid: UUID
    }

    func testUUIDEncodingStrategies() throws {
        let uuid = UUID(uuidString: "26cd7610-fd5a-4253-94b7-e8c4ea97b6cb")!

        let binary = try BSONBinary(from: uuid)
        let uuidStruct = UUIDWrapper(uuid: uuid)
        let encoder = BSONEncoder()

        let defaultEncoding = try encoder.encode(uuidStruct)
        expect(defaultEncoding["uuid"]).to(equal(.binary(binary)))

        encoder.uuidEncodingStrategy = .binary
        let binaryEncoding = try encoder.encode(uuidStruct)
        expect(binaryEncoding["uuid"]).to(equal(.binary(binary)))

        encoder.uuidEncodingStrategy = .deferredToUUID
        let deferred = try encoder.encode(uuidStruct)
        expect(deferred["uuid"]).to(equal(.string(uuid.uuidString)))
    }

    func testUUIDDecodingStrategies() throws {
        // randomly generated uuid
        let uuid = UUID(uuidString: "2c380a6c-7bc5-48cb-84a2-b26777a72276")!

        let decoder = BSONDecoder()

        // UUID default decoder expects a string
        decoder.uuidDecodingStrategy = .deferredToUUID
        let stringDoc: BSONDocument = ["uuid": .string(uuid.description)]
        let badString: BSONDocument = ["uuid": "hello"]
        let deferredStruct = try decoder.decode(UUIDWrapper.self, from: stringDoc)
        expect(deferredStruct.uuid).to(equal(uuid))
        expect(try decoder.decode(UUIDWrapper.self, from: badString)).to(throwError(CodecTests.dataCorruptedErr))

        decoder.uuidDecodingStrategy = .binary
        let uuidt = uuid.uuid
        let bytes = Data([
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])
        let binaryDoc: BSONDocument = ["uuid": .binary(try BSONBinary(data: bytes, subtype: .uuid))]
        let binaryStruct = try decoder.decode(UUIDWrapper.self, from: binaryDoc)
        expect(binaryStruct.uuid).to(equal(uuid))

        let badBinary: BSONDocument = ["uuid": .binary(try BSONBinary(data: bytes, subtype: .generic))]
        expect(try decoder.decode(UUIDWrapper.self, from: badBinary)).to(throwError(CodecTests.dataCorruptedErr))

        expect(try decoder.decode(UUIDWrapper.self, from: stringDoc)).to(throwError(CodecTests.typeMismatchErr))
    }

    struct DateWrapper: Codable {
        let date: Date
    }

    func testDateEncodingStrategies() throws {
        let date = Date(timeIntervalSince1970: 123)
        let dateStruct = DateWrapper(date: date)

        let encoder = BSONEncoder()

        let defaultEncoding = try encoder.encode(dateStruct)
        expect(defaultEncoding["date"]).to(equal(.datetime(date)))

        encoder.dateEncodingStrategy = .bsonDateTime
        let bsonDate = try encoder.encode(dateStruct)
        expect(bsonDate["date"]).to(equal(.datetime(date)))

        encoder.dateEncodingStrategy = .secondsSince1970
        let secondsSince1970 = try encoder.encode(dateStruct)
        expect(secondsSince1970["date"]).to(equal(.double(date.timeIntervalSince1970)))

        encoder.dateEncodingStrategy = .millisecondsSince1970
        let millisecondsSince1970 = try encoder.encode(dateStruct)
        expect(millisecondsSince1970["date"]).to(equal(.int64(date.msSinceEpoch)))

        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            encoder.dateEncodingStrategy = .iso8601
            let iso = try encoder.encode(dateStruct)
            expect(iso["date"]).to(equal(.string(BSONDecoder.iso8601Formatter.string(from: date))))
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .full
        formatter.dateStyle = .short

        encoder.dateEncodingStrategy = .formatted(formatter)
        let formatted = try encoder.encode(dateStruct)
        expect(formatted["date"]).to(equal(.string(formatter.string(from: date))))

        encoder.dateEncodingStrategy = .deferredToDate
        let deferred = try encoder.encode(dateStruct)
        expect(deferred["date"]).to(equal(.double(date.timeIntervalSinceReferenceDate)))

        encoder.dateEncodingStrategy = .custom { d, e in
            var container = e.singleValueContainer()
            try container.encode(Int64(d.timeIntervalSince1970 + 12))
        }
        let custom = try encoder.encode(dateStruct)
        expect(custom["date"]).to(equal(.int64(Int64(date.timeIntervalSince1970 + 12))))

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let noSecondsDate = DateWrapper(date: dateFormatter.date(from: "1/2/19")!)
        encoder.dateEncodingStrategy = .custom { d, e in
            var container = e.unkeyedContainer()
            try dateFormatter.string(from: d).split(separator: "/").forEach { component in
                try container.encode(String(component))
            }
        }
        let customArr = try encoder.encode(noSecondsDate)
        expect(dateFormatter.date(from: (customArr["date"]?
                .arrayValue?
                .compactMap { $0.stringValue }
                .joined(separator: "/"))!)
        ).to(equal(noSecondsDate.date))

        enum DateKeys: String, CodingKey {
            case month, day, year
        }

        encoder.dateEncodingStrategy = .custom { d, e in
            var container = e.container(keyedBy: DateKeys.self)
            let components = dateFormatter.string(from: d).split(separator: "/").map { String($0) }
            try container.encode(components[0], forKey: .month)
            try container.encode(components[1], forKey: .day)
            try container.encode(components[2], forKey: .year)
        }
        let customDoc = try encoder.encode(noSecondsDate)
        expect(customDoc["date"]).to(equal(["month": "1", "day": "2", "year": "19"]))

        encoder.dateEncodingStrategy = .custom { _, _ in }
        let customNoop = try encoder.encode(noSecondsDate)
        expect(customNoop["date"]).to(equal([:]))
    }

    func testDateDecodingStrategies() throws {
        let decoder = BSONDecoder()

        let date = Date(timeIntervalSince1970: 125.0)

        // Default is .bsonDateTime
        let bsonDate: BSONDocument = ["date": .datetime(date)]
        let defaultStruct = try decoder.decode(DateWrapper.self, from: bsonDate)
        expect(defaultStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .bsonDateTime
        let bsonDateStruct = try decoder.decode(DateWrapper.self, from: bsonDate)
        expect(bsonDateStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .millisecondsSince1970
        let msInt64: BSONDocument = ["date": .int64(date.msSinceEpoch)]
        let msInt64Struct = try decoder.decode(DateWrapper.self, from: msInt64)
        expect(msInt64Struct.date).to(equal(date))
        expect(try BSONDecoder().decode(DateWrapper.self, from: msInt64)).to(throwError(CodecTests.typeMismatchErr))

        let msDouble: BSONDocument = ["date": .double(Double(date.msSinceEpoch))]
        let msDoubleStruct = try decoder.decode(DateWrapper.self, from: msDouble)
        expect(msDoubleStruct.date).to(equal(date))

        decoder.dateDecodingStrategy = .secondsSince1970
        let sDouble: BSONDocument = ["date": .double(date.timeIntervalSince1970)]
        let sDoubleStruct = try decoder.decode(DateWrapper.self, from: sDouble)
        expect(sDoubleStruct.date).to(equal(date))

        let sInt64: BSONDocument = ["date": .double(date.timeIntervalSince1970)]
        let sInt64Struct = try decoder.decode(DateWrapper.self, from: sInt64)
        expect(sInt64Struct.date).to(equal(date))

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US")

        decoder.dateDecodingStrategy = .formatted(formatter)
        let formatted: BSONDocument = ["date": .string(formatter.string(from: date))]
        let badlyFormatted: BSONDocument = ["date": "this is not a date"]
        let formattedStruct = try decoder.decode(DateWrapper.self, from: formatted)
        expect(formattedStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.dataCorruptedErr))
        expect(try decoder.decode(DateWrapper.self, from: sDouble)).to(throwError(CodecTests.typeMismatchErr))

        if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            decoder.dateDecodingStrategy = .iso8601
            let isoDoc: BSONDocument = ["date": .string(BSONDecoder.iso8601Formatter.string(from: date))]
            let isoStruct = try decoder.decode(DateWrapper.self, from: isoDoc)
            expect(isoStruct.date).to(equal(date))
            expect(try decoder.decode(DateWrapper.self, from: formatted)).to(throwError(CodecTests.dataCorruptedErr))
            expect(try decoder.decode(DateWrapper.self, from: badlyFormatted))
                .to(throwError(CodecTests.dataCorruptedErr))
        }

        decoder.dateDecodingStrategy = .custom { decode in try Date(from: decode) }
        let customDoc: BSONDocument = ["date": .double(date.timeIntervalSinceReferenceDate)]
        let customStruct = try decoder.decode(DateWrapper.self, from: customDoc)
        expect(customStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.typeMismatchErr))

        decoder.dateDecodingStrategy = .deferredToDate
        let deferredStruct = try decoder.decode(DateWrapper.self, from: customDoc)
        expect(deferredStruct.date).to(equal(date))
        expect(try decoder.decode(DateWrapper.self, from: badlyFormatted)).to(throwError(CodecTests.typeMismatchErr))
    }

    func testDataCodingStrategies() throws {
        struct DataWrapper: Codable {
            let data: Data
        }

        let encoder = BSONEncoder()
        let decoder = BSONDecoder()

        let data = Data(base64Encoded: "dGhlIHF1aWNrIGJyb3duIGZveCBqdW1wZWQgb3ZlciB0aGUgbGF6eSBzaGVlcCBkb2cu")!
        let binaryData = try BSONBinary(data: data, subtype: .generic)
        let arrData = data.map { byte in Int32(byte) }
        let dataStruct = DataWrapper(data: data)

        let defaultDoc = try encoder.encode(dataStruct)
        expect(defaultDoc["data"]?.binaryValue).to(equal(binaryData))
        let roundTripDefault = try decoder.decode(DataWrapper.self, from: defaultDoc)
        expect(roundTripDefault.data).to(equal(data))

        encoder.dataEncodingStrategy = .binary
        decoder.dataDecodingStrategy = .binary
        let binaryDoc = try encoder.encode(dataStruct)
        expect(binaryDoc["data"]?.binaryValue).to(equal(binaryData))
        let roundTripBinary = try decoder.decode(DataWrapper.self, from: binaryDoc)
        expect(roundTripBinary.data).to(equal(data))

        encoder.dataEncodingStrategy = .deferredToData
        decoder.dataDecodingStrategy = .deferredToData
        let deferredDoc = try encoder.encode(dataStruct)
        expect(deferredDoc["data"]?.arrayValue?.compactMap { $0.int32Value }).to(equal(arrData))
        let roundTripDeferred = try decoder.decode(DataWrapper.self, from: deferredDoc)
        expect(roundTripDeferred.data).to(equal(data))
        expect(try decoder.decode(DataWrapper.self, from: defaultDoc)).to(throwError(CodecTests.typeMismatchErr))

        encoder.dataEncodingStrategy = .base64
        decoder.dataDecodingStrategy = .base64
        let base64Doc = try encoder.encode(dataStruct)
        expect(base64Doc["data"]?.stringValue).to(equal(data.base64EncodedString()))
        let roundTripBase64 = try decoder.decode(DataWrapper.self, from: base64Doc)
        expect(roundTripBase64.data).to(equal(data))
        expect(try decoder.decode(DataWrapper.self, from: ["data": "this is not base64 encoded~"]))
            .to(throwError(CodecTests.dataCorruptedErr))

        let customEncodedDoc: BSONDocument = [
            "d": .string(data.base64EncodedString()),
            "hash": .int64(Int64(data.hashValue))
        ]
        encoder.dataEncodingStrategy = .custom { _, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(customEncodedDoc)
        }
        decoder.dataDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let doc = try container.decode(BSONDocument.self)
            guard let d = Data(base64Encoded: doc["d"]!.stringValue!) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "bad base64"))
            }
            expect(d.hashValue).to(equal(data.hashValue))
            return d
        }
        let customDoc = try encoder.encode(dataStruct)
        expect(customDoc["data"]).to(equal(.document(customEncodedDoc)))
        let roundTripCustom = try decoder.decode(DataWrapper.self, from: customDoc)
        expect(roundTripCustom.data).to(equal(data))

        encoder.dataEncodingStrategy = .custom { _, _ in }
        expect(try encoder.encode(dataStruct)).to(equal(["data": [:]]))
    }

    func testIntegerLiteral() {
        let doc: BSONDocument = ["int": 12]

        if BSONTestCase.is32Bit {
            expect(doc["int"]).to(equal(.int32(12)))
            expect(doc["int"]?.type).to(equal(.int32))
        } else {
            expect(doc["int"]?.type).to(equal(.int64))
            expect(doc["int"]).to(equal(.int64(12)))
        }

        let bson: BSON = 12
        expect(doc["int"]).to(equal(bson))
    }

    func testInvalidBSON() throws {
        let invalidData = [
            Data(count: 0), // too short
            Data(count: 4), // too short
            Data(hexString: "0100000000")!, // incorrectly sized
            Data(hexString: "0500000001")! // correctly sized, but doesn't end with null byte
        ]

        for data in invalidData {
            expect(try BSONDocument(fromBSON: data)).to(throwError(errorType: BSONError.InvalidArgumentError.self))
        }
    }

    func testWithID() throws {
        let doc1: BSONDocument = ["a": .int32(1)]

        let withID1 = try doc1.withID()
        expect(withID1.keys).to(equal(["_id", "a"]))
        expect(withID1["_id"]?.objectIDValue).toNot(beNil())

        let data = withID1.toData()
        // 4 for length, 17 for "_id": oid, 7 for "a": 1, 1 for null terminator
        expect(data).to(haveCount(29))

        // build what we expect the data to look like
        let length = "1d000000" // little-endian Int32 rep of 29
        // byte prefix for ObjectID + "_id" as cstring + oid bytes
        let oid = "07" + "5f696400" + withID1["_id"]!.objectIDValue!.hex
        // byte prefix for Int32 + "a" as cstring + little-endian Int32 rep of 1
        let a = "10" + "6100" + "01000000"

        let expectedHex = length + oid + a + "00" // null terminator
        expect(data.hexDescription).to(equal(expectedHex))

        // verify a document with an _id is unchanged by calling this method
        let doc2: BSONDocument = ["x": 1, "_id": .objectID()]
        let withID2 = try doc2.withID()
        expect(withID2).to(equal(doc2))
    }

    func testDuplicateKeyInBSON() throws {
        // contains multiple values for key "a"
        let hex = "1b0000001261000100000000000000126100020000000000000000"
        let data = Data(hexString: hex)!
        expect(try BSONDocument(fromBSON: data)).to(throwError(errorType: BSONError.InvalidArgumentError.self))
    }

    func testNoElementValidation() throws {
        let tooMany = BSON_ALLOCATOR.buffer(bytes: Data(hexString: "2300000000")!)
        expect(try BSONDocument(fromBSONWithoutValidatingElements: tooMany))
            .to(throwError(errorType: BSONError.InvalidArgumentError.self))

        let tooFew = BSON_ALLOCATOR.buffer(bytes: Data(hexString: "0B0000001069000100000000")!)
        expect(try BSONDocument(fromBSONWithoutValidatingElements: tooFew))
            .to(throwError(errorType: BSONError.InvalidArgumentError.self))
    }
}

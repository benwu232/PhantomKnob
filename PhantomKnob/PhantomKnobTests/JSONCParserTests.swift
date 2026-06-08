// PhantomKnobTests/JSONCParserTests.swift
import XCTest
@testable import PhantomKnob

final class JSONCParserTests: XCTestCase {
    func testStripComments() {
        let jsonc = """
        {
            // 单行注释
            "key": "value", /* 多行
            注释 */
            "number": 123
        }
        """
        let cleaned = JSONCParser.stripComments(from: jsonc)
        XCTAssertFalse(cleaned.contains("单行注释"))
        XCTAssertFalse(cleaned.contains("多行"))
        XCTAssertTrue(cleaned.contains("\"key\": \"value\""))
    }
}

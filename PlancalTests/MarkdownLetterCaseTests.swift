import XCTest
@testable import Plancal

final class MarkdownLetterCaseTests: XCTestCase {
    func testLowercaseTransformsSelectedText() {
        XCTAssertEqual(MarkdownLetterCase.lowercase.transform("Plan THIS"), "plan this")
    }

    func testUppercaseTransformsSelectedText() {
        XCTAssertEqual(MarkdownLetterCase.uppercase.transform("Plan this"), "PLAN THIS")
    }

    func testTitleCaseCapitalizesWordsAcrossPunctuationAndLines() {
        XCTAssertEqual(
            MarkdownLetterCase.title.transform("mIXed-case\nnext LINE"),
            "Mixed-Case\nNext Line"
        )
    }
}

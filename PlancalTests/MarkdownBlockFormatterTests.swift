import XCTest
@testable import Plancal

final class MarkdownBlockFormatterTests: XCTestCase {
    func testChecklistFormatsEverySelectedLine() {
        XCTAssertEqual(
            MarkdownBlockFormatter.transform(
                "First\nSecond\nThird",
                to: .taskList
            ),
            "- [ ] First\n- [ ] Second\n- [ ] Third"
        )
    }

    func testChecklistTogglesOffEverySelectedLine() {
        XCTAssertEqual(
            MarkdownBlockFormatter.transform(
                "- [ ] First\n- [x] Second",
                to: .taskList
            ),
            "First\nSecond"
        )
    }

    func testChangingAListStyleDoesNotStackMarkers() {
        XCTAssertEqual(
            MarkdownBlockFormatter.transform(
                "- First\n* Second\n1. Third",
                to: .taskList
            ),
            "- [ ] First\n- [ ] Second\n- [ ] Third"
        )
    }

    func testHeadingFormatsEveryLineAndPreservesBlankLines() {
        XCTAssertEqual(
            MarkdownBlockFormatter.transform(
                "First\n\nSecond\n",
                to: .heading(2)
            ),
            "## First\n\n## Second\n"
        )
    }
}

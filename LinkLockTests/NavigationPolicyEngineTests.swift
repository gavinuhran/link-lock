import XCTest
@testable import LinkLock

/// Unit tests for NavigationPolicyEngine.
///
/// Uses the raw-value overload `decide(url:isMainFrame:sessionState:)` so tests
/// run without requiring a live WKWebView or WKNavigationAction.
final class NavigationPolicyEngineTests: XCTestCase {

    // MARK: - Fixtures

    let canonical     = URL(string: "https://example.com/page")!
    let canonicalFrag = URL(string: "https://example.com/page#section2")!
    let otherPath     = URL(string: "https://example.com/other")!
    let otherQuery    = URL(string: "https://example.com/page?q=1")!
    let otherDomain   = URL(string: "https://attacker.com/page")!
    let resolving     = SessionState.resolving(originalURL: URL(string: "https://bit.ly/abc")!)

    var locked: SessionState { .locked(canonicalURL: canonical) }

    // MARK: - Scheme Blocking

    func test_youtubeScheme_blocks() {
        let url = URL(string: "youtube://watch?v=abc")!
        assertBlocks(.nonHttpScheme, url: url, main: true, state: locked)
    }

    func test_mailtoScheme_blocks() {
        let url = URL(string: "mailto:user@example.com")!
        assertBlocks(.nonHttpScheme, url: url, main: true, state: locked)
    }

    func test_telScheme_blocks() {
        let url = URL(string: "tel:+15555550100")!
        assertBlocks(.nonHttpScheme, url: url, main: true, state: locked)
    }

    func test_itmsScheme_blocks() {
        let url = URL(string: "itms-apps://itunes.apple.com/app/id123")!
        assertBlocks(.nonHttpScheme, url: url, main: true, state: locked)
    }

    func test_fbScheme_blocks() {
        let url = URL(string: "fb://profile/123")!
        assertBlocks(.nonHttpScheme, url: url, main: true, state: locked)
    }

    func test_httpScheme_doesNotBlockOnScheme() {
        // http is allowed at the scheme level (may be blocked by other rules)
        let url = URL(string: "http://example.com/page")!
        // Locked state, same resource → allow
        let result = NavigationPolicyEngine.decide(url: url, isMainFrame: true, sessionState: locked)
        // http://example.com/page != https://example.com/page → block by mainFrameNavigation, not nonHttpScheme
        if case .block(let reason) = result {
            XCTAssertNotEqual(reason, .nonHttpScheme, "http:// should not be blocked as nonHttpScheme")
        }
    }

    // MARK: - Subframe (iframe)

    func test_subframe_http_allows() {
        assertAllows(url: URL(string: "https://ads.example.com")!, main: false, state: locked)
    }

    func test_subframe_nonHttp_blocks() {
        // Non-http scheme is caught before the frame check, so subframes also get blocked.
        assertBlocks(.nonHttpScheme, url: URL(string: "fb://thing")!, main: false, state: locked)
    }

    // MARK: - Resolving Phase (redirect chain)

    func test_resolving_allowsAnyHttpsURL() {
        assertAllows(url: URL(string: "https://redirect.example.com/landing")!, main: true, state: resolving)
    }

    func test_resolving_allowsDifferentDomain() {
        assertAllows(url: URL(string: "https://totally-different.com")!, main: true, state: resolving)
    }

    func test_resolving_blocksBadScheme() {
        // Even in resolving phase, non-http schemes must be blocked.
        assertBlocks(.nonHttpScheme, url: URL(string: "tel:+1234")!, main: true, state: resolving)
    }

    // MARK: - Locked Phase — Allow Cases

    func test_locked_sameURL_allows() {
        assertAllows(url: canonical, main: true, state: locked)
    }

    func test_locked_fragmentOnly_allows() {
        assertAllows(url: canonicalFrag, main: true, state: locked)
    }

    func test_locked_multipleFragments_allows() {
        let url = URL(string: "https://example.com/page#top")!
        assertAllows(url: url, main: true, state: locked)
    }

    // MARK: - Locked Phase — Block Cases

    func test_locked_differentPath_blocks() {
        assertBlocks(.mainFrameNavigation, url: otherPath, main: true, state: locked)
    }

    func test_locked_differentQuery_blocks() {
        assertBlocks(.mainFrameNavigation, url: otherQuery, main: true, state: locked)
    }

    func test_locked_differentDomain_blocks() {
        assertBlocks(.mainFrameNavigation, url: otherDomain, main: true, state: locked)
    }

    func test_locked_samePathDifferentQuery_blocks() {
        let url = URL(string: "https://example.com/page?ref=home")!
        assertBlocks(.mainFrameNavigation, url: url, main: true, state: locked)
    }

    // MARK: - Idle / Ended States

    func test_idle_allowsByDefault() {
        assertAllows(url: canonical, main: true, state: .idle)
    }

    func test_ended_allowsByDefault() {
        assertAllows(url: canonical, main: true, state: .ended)
    }

    // MARK: - Response Policy

    func test_responsePolicy_normalMime_allows() {
        let result = NavigationPolicyEngine.decideResponse(
            mimeType: "text/html", contentDisposition: nil)
        XCTAssertAllow(result)
    }

    func test_responsePolicy_attachmentDisposition_blocks() {
        let result = NavigationPolicyEngine.decideResponse(
            mimeType: "application/octet-stream",
            contentDisposition: "attachment; filename=\"file.zip\"")
        XCTAssertBlockReason(.downloadBlocked, result)
    }

    func test_responsePolicy_inlinePDF_allows() {
        let result = NavigationPolicyEngine.decideResponse(
            mimeType: "application/pdf", contentDisposition: "inline")
        XCTAssertAllow(result)
    }

    func test_responsePolicy_nilDisposition_allows() {
        let result = NavigationPolicyEngine.decideResponse(
            mimeType: "application/pdf", contentDisposition: nil)
        XCTAssertAllow(result)
    }

    // MARK: - URL+Canonical Extension

    func test_sameResource_noFragment() {
        XCTAssertTrue(canonical.sameResource(as: canonical))
    }

    func test_sameResource_fragmentIgnored() {
        XCTAssertTrue(canonical.sameResource(as: canonicalFrag))
        XCTAssertTrue(canonicalFrag.sameResource(as: canonical))
    }

    func test_sameResource_differentPath_false() {
        XCTAssertFalse(canonical.sameResource(as: otherPath))
    }

    func test_sameResource_differentQuery_false() {
        XCTAssertFalse(canonical.sameResource(as: otherQuery))
    }

    func test_sameResource_differentDomain_false() {
        XCTAssertFalse(canonical.sameResource(as: otherDomain))
    }
}

// MARK: - Assertion Helpers

private extension NavigationPolicyEngineTests {

    func assertAllows(url: URL, main: Bool, state: SessionState,
                      file: StaticString = #filePath, line: UInt = #line) {
        let result = NavigationPolicyEngine.decide(url: url, isMainFrame: main, sessionState: state)
        XCTAssertAllow(result, file: file, line: line)
    }

    func assertBlocks(_ reason: BlockReason, url: URL, main: Bool, state: SessionState,
                      file: StaticString = #filePath, line: UInt = #line) {
        let result = NavigationPolicyEngine.decide(url: url, isMainFrame: main, sessionState: state)
        XCTAssertBlockReason(reason, result, file: file, line: line)
    }
}

// MARK: - Custom XCT Helpers

func XCTAssertAllow(_ decision: PolicyDecision,
                    file: StaticString = #filePath, line: UInt = #line) {
    if case .allow = decision { return }
    XCTFail("Expected .allow, got \(decision)", file: file, line: line)
}

func XCTAssertBlockReason(_ expected: BlockReason, _ decision: PolicyDecision,
                           file: StaticString = #filePath, line: UInt = #line) {
    guard case .block(let reason) = decision else {
        XCTFail("Expected .block(\(expected)), got \(decision)", file: file, line: line)
        return
    }
    XCTAssertEqual(reason, expected, file: file, line: line)
}

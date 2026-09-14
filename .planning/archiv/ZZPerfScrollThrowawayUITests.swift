//  WEGWERF-TESTCODE — Perf-Diagnose, wird nach dem Lauf geloescht.
import XCTest

final class ZZPerfScrollThrowawayUITests: XCTestCase {

    @MainActor
    func testScrollReiseListeForProfiling() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData"]
        app.launch()

        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 20))
        reisenTab.tap()

        // Warten bis Liste steht
        RunLoop.current.run(until: Date().addingTimeInterval(3))

        // 20 s durchgehend scrollen — Messfenster fuer den Time Profiler
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }
}

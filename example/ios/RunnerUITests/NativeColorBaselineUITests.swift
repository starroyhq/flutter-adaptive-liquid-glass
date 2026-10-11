import XCTest

/// Run this class alone on its own fresh simulator. The separately installed
/// app is pure UIKit and does not launch the Flutter example or its probe.
final class NativeColorBaselineUITests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "dev.starroyhq.liquidGlassColorBaseline")

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
  }

  override func tearDownWithError() throws {
    if app.state == .runningForeground {
      let hierarchy = XCTAttachment(string: String(app.debugDescription.prefix(16000)))
      hierarchy.name = "UIKit baseline lifecycle and accessibility state"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = "UIKit baseline final system state"
      screenshot.lifetime = .keepAlways
      add(screenshot)
    }
    app.terminate()
  }

  func testFirstUIKitColorPaletteSelectsBlack() throws {
    let open = app.buttons["baseline-open-color"]
    XCTAssertTrue(open.waitForExistence(timeout: 30))
    XCTAssertTrue(open.isEnabled && open.isHittable)
    XCTAssertTrue(app.staticTexts["Presentation calls: 0"].exists)
    let initial = try readSelectionState(app.staticTexts["baseline-host-selection-state"])
    XCTAssertEqual(initial.calls, 0)
    XCTAssertEqual(initial.terminals, 0)
    XCTAssertTrue(app.staticTexts["Color value: ff2463b8"].exists)

    // Exactly one real system-input click. No accessibilityActivate(), warmup,
    // programmatic color selection, second click, or retry opens the palette.
    open.tap()
    let palette = app.otherElements["UIColorPicker"]
    XCTAssertTrue(palette.waitForExistence(timeout: 15), "The first system palette must appear")
    XCTAssertTrue(palette.staticTexts["Preview color"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.otherElements.matching(identifier: "UIColorPicker").count, 1)
    let black = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(black|黑色) 0")
    ).firstMatch
    XCTAssertTrue(black.waitForExistence(timeout: 10))
    black.tap()

    let close = palette.buttons.matching(
      NSPredicate(format: "label IN %@", ["close", "Close", "Done", "关闭", "關閉"])
    ).firstMatch
    XCTAssertTrue(close.waitForExistence(timeout: 10))
    close.tap()
    XCTAssertTrue(palette.waitForNonExistence(timeout: 10))
    let hostState = app.staticTexts["baseline-host-selection-state"]
    XCTAssertTrue(hostState.waitForExistence(timeout: 15))
    // UIKit can emit continuous and completed callbacks for one selection.
    // The fixture latches its raw count at the first completed callback, without
    // deduplication. Any callback after that, including on close, must fail here.
    let afterClose = try readSelectionState(hostState)
    XCTAssertGreaterThan(afterClose.calls, 0)
    XCTAssertEqual(afterClose.terminals, 1)
    XCTAssertEqual(afterClose.calls, afterClose.firstTerminal,
                   "Closing must not emit another raw selection callback after the first completed selection")
    XCTAssertEqual(afterClose.continuous, "false")
    XCTAssertEqual(afterClose.argb, "ff000000")
    XCTAssertTrue(app.staticTexts["Color value: ff000000"].exists)
    XCTAssertTrue(app.staticTexts["Presentation calls: 1"].exists)
    XCTAssertTrue(open.isEnabled, "Closing must release the owned picker")
  }

  private struct SelectionState {
    let calls: Int
    let firstTerminal: Int
    let terminals: Int
    let continuous: String
    let argb: String
  }

  private struct InvalidSelectionState: Error {
    let raw: String
  }

  private func readSelectionState(_ element: XCUIElement) throws -> SelectionState {
    guard element.exists else { throw InvalidSelectionState(raw: "missing") }
    let raw = element.label
    let fields = raw.split(separator: " ").map { $0.split(separator: "=", maxSplits: 1) }
    guard fields.count == 5,
          fields.allSatisfy({ $0.count == 2 }),
          fields[0][0] == "callbacks", let calls = Int(fields[0][1]), calls >= 0,
          fields[1][0] == "firstTerminal", let firstTerminal = Int(fields[1][1]), firstTerminal >= 0,
          fields[2][0] == "terminals", let terminals = Int(fields[2][1]), terminals >= 0,
          fields[3][0] == "continuous", ["none", "true", "false"].contains(String(fields[3][1])),
          fields[4][0] == "argb", fields[4][1].count == 8 else {
      throw InvalidSelectionState(raw: raw)
    }
    return SelectionState(calls: calls, firstTerminal: firstTerminal, terminals: terminals,
                          continuous: String(fields[3][1]), argb: String(fields[4][1]))
  }
}

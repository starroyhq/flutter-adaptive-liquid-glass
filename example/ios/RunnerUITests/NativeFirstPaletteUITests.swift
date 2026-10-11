import XCTest

/// Run alone on a fresh simulator, with GLASS_MATCH_CATALOG_COLOR=true.
/// This separates the catalog's composition from palette parameters and first use.
final class NativeFirstPaletteUITests: XCTestCase {
  private let app = XCUIApplication()

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-glass-color-lifecycle-diagnostics"]
    app.launch()
  }

  override func tearDownWithError() throws {
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "Matched probe final accessibility state"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Matched probe final visual state"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.terminate()
  }

  func testFirstMatchedProbePaletteSelectsBlackOnce() throws {
    let probe = app.buttons["Open accessibility probe"]
    XCTAssertTrue(probe.waitForExistence(timeout: 30))
    probe.tap()
    XCTAssertTrue(app.staticTexts["Accessibility renderer: native"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.staticTexts["Palette configuration: catalog"].exists)
    XCTAssertTrue(app.staticTexts["Color value: ff2463b8"].exists)
    XCTAssertTrue(app.staticTexts["Color calls: 0"].exists)
    let well = app.buttons["Sample color"]
    XCTAssertTrue(well.isEnabled && well.isHittable)
    // Exactly one physical touch: no prior color picker, AX activation or retry.
    well.tap()
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
    XCTAssertTrue(app.staticTexts["Color calls: 1"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.staticTexts["Color value: ff000000"].exists)
    XCTAssertTrue(app.staticTexts["Accessibility activation: none"].exists)
    XCTAssertFalse(app.staticTexts["Color calls: 2"].exists)
  }
}

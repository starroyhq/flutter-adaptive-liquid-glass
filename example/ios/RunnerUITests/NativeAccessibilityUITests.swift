import XCTest

final class NativeAccessibilityUITests: XCTestCase {
  private let app = XCUIApplication()
  private var traceURL: URL?

  override func setUpWithError() throws {
    continueAfterFailure = false
    let trace = FileManager.default.temporaryDirectory
      .appendingPathComponent("native-color-well-\(UUID().uuidString).log")
    XCTAssertTrue(FileManager.default.createFile(atPath: trace.path, contents: nil))
    traceURL = trace
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                           "--glass-color-well-trace", trace.path]
    app.launch()
    let probe = app.buttons["Open accessibility probe"]
    XCTAssertTrue(probe.waitForExistence(timeout: 30))
    probe.tap()
    XCTAssertTrue(app.staticTexts["Accessibility renderer: native"].waitForExistence(timeout: 20))
  }

  override func tearDownWithError() throws {
    defer {
      if let traceURL { try? FileManager.default.removeItem(at: traceURL) }
      traceURL = nil
    }
    guard let traceURL else { return }
    let trace = (try? String(contentsOf: traceURL, encoding: .utf8)) ?? ""
    let attachment = XCTAttachment(string: trace.isEmpty
      ? "Native color diagnostics unavailable: the app did not write the opt-in simulator trace."
      : trace)
    // Synthetic, bounded state only. Keep it available in the job log as well
    // as the result bundle, without downloading the whole bundle to inspect it.
    print("COLOR_WELL_TRACE_BEGIN\n\(trace)COLOR_WELL_TRACE_END")
    attachment.name = "Native color well state trace"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testNativeLabelsUpdateWithoutExtraCallbacks() throws {
    let theme = app.buttons["theme"]
    XCTAssertTrue(theme.waitForExistence(timeout: 10))
    XCTAssertEqual(theme.label, "Toggle theme")
    XCTAssertEqual(app.buttons["back"].label, "Back to catalog")
    XCTAssertTrue(app.buttons["Sample color"].exists)
    let initialColorName = app.buttons["Sample color"].value as? String ?? ""
    XCTAssertFalse(initialColorName.isEmpty)

    theme.tap()
    expectText("Navigation calls: 1")
    expectText("Appearance: dark")
    XCTAssertEqual(theme.label, "Toggle theme")
    XCTAssertTrue(app.buttons["Sample color"].exists)

    app.buttons["Rename controls"].tap()
    XCTAssertEqual(theme.label, "Switch appearance")
    XCTAssertFalse(app.buttons["Sample color"].exists)
    XCTAssertTrue(app.buttons["Accent color"].exists)
    theme.tap()
    expectText("Navigation calls: 2")
    expectText("Appearance: light")

    app.buttons["Set red programmatically"].tap()
    expectText("Color calls: 0")
    expectText("Color value: ffff0000")
    let redColorName = app.buttons["Accent color"].value as? String ?? ""
    XCTAssertFalse(redColorName.isEmpty)
    XCTAssertNotEqual(redColorName, initialColorName)
    app.buttons["Disable color"].tap()
    XCTAssertFalse(app.buttons["Accent color"].isEnabled)
    app.buttons["Activate color accessibility"].tap()
    expectText("Accessibility activation: false")
    XCTAssertFalse(app.otherElements["UIColorPicker"].exists)
    expectText("Color calls: 0")
    app.buttons["Enable color"].tap()
    XCTAssertTrue(app.buttons["Accent color"].isEnabled)
    attachHierarchy("Labels after native configuration updates")
  }

  func testColorWellKeepsSystemPickerAndAccessibilityActivation() throws {
    let well = app.buttons["Sample color"]
    XCTAssertTrue(well.waitForExistence(timeout: 10))
    well.tap()
    // The system palette must appear after a real touch, not a direct callback.
    let palette = waitForPalette(title: "Sample palette")
    attachHierarchy("Native color palette after physical touch")
    // System service labels follow the device language, independently of the
    // app's launch locale. Target the grid's accessible black swatch.
    let blackSwatch = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(black|黑色) 0")
    ).firstMatch
    XCTAssertTrue(blackSwatch.waitForExistence(timeout: 10))
    blackSwatch.tap()
    closePalette(palette)
    expectText("Color calls: 1")
    expectText("Color value: ff000000")
    app.buttons["Activate color accessibility"].tap()
    _ = waitForPalette(title: "Sample palette")
    attachHierarchy("Native color palette after accessibility activation")
    let whiteSwatch = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(white|白色) 100")
    ).firstMatch
    XCTAssertTrue(whiteSwatch.waitForExistence(timeout: 10))
    whiteSwatch.tap()
    closePalette(palette)
    expectText("Accessibility activation: true")
    expectText("Color calls: 2")
    expectText("Color value: ffffffff")
    app.buttons["Activate color accessibility"].tap()
    _ = waitForPalette(title: "Sample palette")
    closePalette(palette)
    expectText("Color calls: 2")
  }

  func testCatalogColorPickerReopensAfterNativeTabRecreation() throws {
    app.buttons["back"].tap()
    let pickersTab = app.buttons["Pickers"]
    XCTAssertTrue(pickersTab.waitForExistence(timeout: 10))
    pickersTab.tap()
    openCatalogColorPicker()
    closePalette(app.otherElements["UIColorPicker"])
    app.buttons["Controls"].tap()
    pickersTab.tap()
    openCatalogColorPicker()
    closePalette(app.otherElements["UIColorPicker"])
  }

  private func openCatalogColorPicker() {
    let well = app.buttons["Preview color"]
    for _ in 0..<4 {
      if well.exists && well.isHittable { break }
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.76))
        .press(forDuration: 0.05,
               thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.46)),
               withVelocity: .slow, thenHoldForDuration: 0.2)
    }
    XCTAssertTrue(well.exists && well.isHittable)
    // Flutter's scroll/layout tickers do not participate in XCTest idleness.
    // Resolve one measured-center system tap after three stable AX frames.
    // The probe deliberately retains element.tap() as an independent control.
    var previousFrame = CGRect.null
    var stableSamples = 0
    var samples: [String] = []
    let settled = NSPredicate { _, _ in
      let frame = well.frame
      samples.append("t=\(ProcessInfo.processInfo.systemUptime) frame=\(frame)")
      let valid = !frame.isNull && !frame.isInfinite && !frame.isEmpty
      stableSamples = valid && frame == previousFrame ? stableSamples + 1 : 0
      previousFrame = frame
      return stableSamples >= 2
    }
    let result = XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 45)
    let frames = XCTAttachment(string: samples.joined(separator: "\n"))
    frames.name = "Catalog color well frame samples"
    frames.lifetime = .keepAlways
    add(frames)
    XCTAssertEqual(result, .completed)
    XCTAssertTrue(well.isEnabled && well.isHittable)
    well.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    _ = waitForPalette(title: "Preview color")
  }

  private func waitForPalette(title: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
    // iOS 26 exposes a plain title in its floating palette; iOS 27 wraps that
    // title in a navigation bar. Both expose this named system container.
    let palette = app.otherElements["UIColorPicker"]
    XCTAssertTrue(palette.waitForExistence(timeout: 15), "The system palette must appear", file: file, line: line)
    XCTAssertTrue(palette.staticTexts[title].waitForExistence(timeout: 10), "The caller's palette title must be present", file: file, line: line)
    return palette
  }

  private func closePalette(_ palette: XCUIElement) {
    let close = palette.buttons.matching(
      NSPredicate(format: "label IN %@", ["close", "Close", "Done", "关闭", "關閉"])
    ).firstMatch
    XCTAssertTrue(close.waitForExistence(timeout: 10))
    close.tap()
    XCTAssertTrue(palette.waitForNonExistence(timeout: 10))
  }

  private func expectText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 15), text, file: file, line: line)
  }

  private func attachHierarchy(_ name: String) {
    let tree = XCTAttachment(string: app.debugDescription)
    tree.name = name
    tree.lifetime = .keepAlways
    add(tree)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}

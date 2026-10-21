import XCTest

final class NativeAccessibilityUITests: XCTestCase {
  private let app = XCUIApplication()
  private var paletteHasAppeared = false

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    let probe = app.buttons["Open accessibility probe"]
    XCTAssertTrue(probe.waitForExistence(timeout: 30))
    probe.tap()
    XCTAssertTrue(app.staticTexts["Accessibility renderer: native"].waitForExistence(timeout: 20))
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
    let palette = try waitForPalette(title: "Sample palette")
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
    _ = try waitForPalette(title: "Sample palette")
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
    _ = try waitForPalette(title: "Sample palette")
    closePalette(palette)
    expectText("Color calls: 2")
  }

  func testCatalogColorPickerReopensAfterNativeTabRecreation() throws {
    app.buttons["back"].tap()
    let pickersTab = app.buttons["Pickers"]
    XCTAssertTrue(pickersTab.waitForExistence(timeout: 10))
    pickersTab.tap()
    try openCatalogColorPicker()
    closePalette(app.otherElements["UIColorPicker"])
    app.buttons["Controls"].tap()
    pickersTab.tap()
    try openCatalogColorPicker()
    closePalette(app.otherElements["UIColorPicker"])
  }

  func testDuplicateActivationAndBackgroundCancelOnlyOwnedPalette() throws {
    app.buttons["Activate color accessibility twice"].tap()
    let palette = try waitForPalette(title: "Sample palette")
    XCTAssertEqual(app.otherElements.matching(identifier: "UIColorPicker").count, 1)
    closePalette(palette)
    expectText("Accessibility activation: true,false")
    expectText("Color calls: 0")

    app.buttons["Sample color"].tap()
    _ = try waitForPalette(title: "Sample palette")
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(palette.waitForNonExistence(timeout: 10))
    expectText("Color calls: 0")
    app.buttons["Sample color"].tap()
    _ = try waitForPalette(title: "Sample palette")
    closePalette(palette)
    expectText("Color calls: 0")
  }

  func testClearingLabelDuringPresentationRestoresSystemActivation() throws {
    app.buttons["Open then clear color label"].tap()
    expectText("Color label: system")
    let defaultWell = app.buttons.matching(
      NSPredicate(format: "label IN %@", ["Color", "颜色", "顏色"])
    ).firstMatch
    XCTAssertTrue(defaultWell.waitForExistence(timeout: 15))
    XCTAssertTrue(app.otherElements["UIColorPicker"].waitForNonExistence(timeout: 10))
    expectText("Color calls: 0")
    defaultWell.tap()
    let palette = try waitForPalette(title: "Sample palette")
    closePalette(palette)
    expectText("Color calls: 0")
    app.buttons["Restore custom color label"].tap()
    XCTAssertTrue(app.buttons["Sample color"].waitForExistence(timeout: 10))
    app.buttons["Sample color"].tap()
    _ = try waitForPalette(title: "Sample palette")
    closePalette(palette)
    expectText("Color calls: 0")
  }

  func testRemovingSourceDuringPresentationCancelsOwnedPalette() throws {
    app.buttons["Open then remove color well"].tap()
    expectText("Accessibility activation: true")
    expectText("Color source: removed")
    XCTAssertFalse(app.buttons["Sample color"].exists)
    XCTAssertTrue(app.otherElements["UIColorPicker"].waitForNonExistence(timeout: 10))
    expectText("Color calls: 0")
    app.buttons["Restore color well"].tap()
    expectText("Color source: mounted")
    app.buttons["Sample color"].tap()
    let palette = try waitForPalette(title: "Sample palette 1")
    XCTAssertEqual(app.otherElements.matching(identifier: "UIColorPicker").count, 1)
    closePalette(palette)
    expectText("Color calls: 0")
  }

  func testProgrammaticDismissalReleasesOnlyTheDepartingPalette() throws {
    let enable = app.buttons["Enable native lifecycle controls"]
    for _ in 0..<4 {
      if enable.exists && enable.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(enable.exists && enable.isHittable)
    enable.tap()
    expectText("Native lifecycle controls ready")
    let well = app.buttons["Sample color"]
    for _ in 0..<4 {
      if well.exists && well.isHittable { break }
      app.swipeDown()
    }
    XCTAssertTrue(well.exists && well.isHittable)
    well.tap()
    let palette = try waitForPalette(title: "Sample palette")

    // A full-screen child removes the palette from view without dismissing it.
    // Return to the same controller and verify its real delegate still works.
    app.buttons["Cover palette"].tap()
    expectText("Nested native cover")
    expectText("Native palette covered")
    app.buttons["Return to palette"].tap()
    expectText("Original native palette restored")
    _ = try waitForPalette(title: "Sample palette")
    let blackSwatch = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(black|黑色) 0")
    ).firstMatch
    XCTAssertTrue(blackSwatch.waitForExistence(timeout: 10))
    blackSwatch.tap()
    closePalette(palette)
    expectText("Color calls: 1")
    expectText("Color value: ff000000")

    well.tap()
    _ = try waitForPalette(title: "Sample palette")
    app.buttons["Dismiss palette"].tap()
    expectText("Native palette programmatically dismissed")
    XCTAssertTrue(palette.waitForNonExistence(timeout: 10))
    // This is a new physical activation, without remounting the source well.
    well.tap()
    _ = try waitForPalette(title: "Sample palette")
    app.buttons["Cover palette"].tap()
    expectText("Nested native cover")
    expectText("Native palette covered")
    app.buttons["Close lifecycle controls"].tap()
    XCTAssertTrue(app.buttons["Dismiss palette"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Nested native cover"].waitForNonExistence(timeout: 10))
    _ = try waitForPalette(title: "Sample palette")
    let whiteSwatch = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(white|白色) 100")
    ).firstMatch
    XCTAssertTrue(whiteSwatch.waitForExistence(timeout: 10))
    whiteSwatch.tap()
    closePalette(palette)
    expectText("Color calls: 2")
    expectText("Color value: ffffffff")
  }

  func testBackgroundCancelsPaletteWhileItsFullScreenChildIsPresented() throws {
    let enable = app.buttons["Enable native lifecycle controls"]
    for _ in 0..<4 {
      if enable.exists && enable.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(enable.exists && enable.isHittable)
    enable.tap()
    expectText("Native lifecycle controls ready")
    let well = app.buttons["Sample color"]
    for _ in 0..<4 {
      if well.exists && well.isHittable { break }
      app.swipeDown()
    }
    XCTAssertTrue(well.exists && well.isHittable)
    well.tap()
    let palette = try waitForPalette(title: "Sample palette")
    app.buttons["Cover palette"].tap()
    expectText("Nested native cover")
    expectText("Native palette covered")

    // Keep the child presented when cancellation starts. Dismissing only that
    // child must not be mistaken for completion of the owned palette's exit.
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.staticTexts["Nested native cover"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(palette.waitForNonExistence(timeout: 10))
    expectText("Color calls: 0")
    XCTAssertTrue(well.exists && well.isHittable)

    // The original source remains mounted. A new physical activation must own
    // a fresh palette with its delegate intact, without replaying old events.
    well.tap()
    _ = try waitForPalette(title: "Sample palette")
    XCTAssertEqual(app.otherElements.matching(identifier: "UIColorPicker").count, 1)
    let blackSwatch = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(black|黑色) 0")
    ).firstMatch
    XCTAssertTrue(blackSwatch.waitForExistence(timeout: 10))
    blackSwatch.tap()
    closePalette(palette)
    expectText("Color calls: 1")
    expectText("Color value: ff000000")
  }

  func testExternalDismissalReleasesPaletteWhileFullScreenChildIsPresented() throws {
    let enable = app.buttons["Enable native lifecycle controls"]
    for _ in 0..<4 {
      if enable.exists && enable.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(enable.exists && enable.isHittable)
    enable.tap()
    expectText("Native lifecycle controls ready")
    let well = app.buttons["Sample color"]
    for _ in 0..<4 {
      if well.exists && well.isHittable { break }
      app.swipeDown()
    }
    XCTAssertTrue(well.exists && well.isHittable)
    well.tap()
    let palette = try waitForPalette(title: "Sample palette")
    app.buttons["Cover palette"].tap()
    expectText("Nested native cover")
    expectText("Native palette covered")

    // This fixture calls the original palette's verified presenter directly.
    // The source stays mounted and active; there is no package cancellation.
    app.buttons["Dismiss covered stack"].tap()
    expectText("Covered native stack externally dismissed")
    XCTAssertTrue(app.staticTexts["Nested native cover"].waitForNonExistence(timeout: 10))
    XCTAssertTrue(palette.waitForNonExistence(timeout: 10))
    expectText("Color calls: 0")
    XCTAssertTrue(well.exists && well.isHittable)

    well.tap()
    _ = try waitForPalette(title: "Sample palette")
    XCTAssertEqual(app.otherElements.matching(identifier: "UIColorPicker").count, 1)
    let blackSwatch = app.otherElements.matching(
      NSPredicate(format: "label MATCHES[c] %@", "(black|黑色) 0")
    ).firstMatch
    XCTAssertTrue(blackSwatch.waitForExistence(timeout: 10))
    blackSwatch.tap()
    closePalette(palette)
    expectText("Color calls: 1")
    expectText("Color value: ff000000")
  }

  func testNativeControlsReachFlutterCallbacks() throws {
    app.buttons["back"].tap()
    let searchTab = app.buttons["Search"]
    XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
    searchTab.tap()
    let openProbe = app.buttons["Open native controls probe"]
    XCTAssertTrue(openProbe.waitForExistence(timeout: 10))
    openProbe.tap()
    expectText("Tab: 2")

    // The system tab bar: a tab, then its separate search-style button.
    let alpha = app.buttons["Alpha"]
    XCTAssertTrue(alpha.waitForExistence(timeout: 10))
    alpha.tap()
    expectText("Tab: 0")
    app.buttons["Find"].tap()
    expectText("Find presses: 1")
    expectText("Tab: 0")

    // The system segmented control.
    app.buttons["Two"].tap()
    expectText("Segment: 1")

    // Standalone icon buttons carry their id and semantic label natively.
    let add = app.buttons["probe-add"]
    XCTAssertTrue(add.waitForExistence(timeout: 10))
    XCTAssertEqual(add.label, "Add item")
    add.tap()
    expectText("Icon presses: 1")
    app.buttons["probe-close"].tap()
    expectText("Icon presses: 2")
    XCTAssertFalse(app.buttons["probe-disabled"].isEnabled)
    attachHierarchy("Native controls probe after its callbacks")

    // The covered catalog tab bar takes taps again once the probe has left.
    app.buttons["Back"].tap()
    XCTAssertTrue(waitUntilHittable(searchTab))
    app.buttons["Controls"].tap()
    XCTAssertTrue(openProbe.waitForNonExistence(timeout: 10))
    searchTab.tap()
    XCTAssertTrue(openProbe.waitForExistence(timeout: 10))
  }

  func testCapsuleButtonsUpdateInPlace() throws {
    openCatalogSearchEntry("Open native controls probe")
    expectText("Tab: 2")
    // A standalone icon, a prominent standalone icon and a prominent text
    // button, whose enabled state the probe's toggles change.
    let delete = app.buttons["probe-disabled"]
    let up = app.buttons["probe-up"]
    let send = app.buttons["probe-send"]
    XCTAssertTrue(send.waitForExistence(timeout: 10))
    XCTAssertFalse(delete.isEnabled)
    XCTAssertTrue(up.isEnabled)
    XCTAssertTrue(send.isEnabled)
    let buttons = ["probe-disabled": delete, "probe-up": up, "probe-send": send]
    attachFrames("r2-update-frames", buttons)
    attachScreen("r2-update-0-initial")

    app.buttons["Toggle Delete"].tap()
    app.buttons["Toggle Move up"].tap()
    expectText("Delete enabled: true")
    expectText("Move up enabled: false")
    // The same native buttons, updated rather than replaced.
    XCTAssertTrue(delete.exists && up.exists && send.exists)
    XCTAssertTrue(waitUntil(delete, "enabled == true"))
    XCTAssertTrue(waitUntil(up, "enabled == false"))
    XCTAssertTrue(waitUntil(send, "enabled == false"))
    Thread.sleep(forTimeInterval: 1.5)
    attachScreen("r2-update-1-toggled")

    delete.tap()
    expectText("Icon presses: 1")
    tapCenter(of: up)
    XCTAssertFalse(app.staticTexts["Icon presses: 2"].waitForExistence(timeout: 2))
    tapCenter(of: send)
    XCTAssertFalse(app.staticTexts["Send presses: 1"].waitForExistence(timeout: 2))

    app.buttons["Toggle Delete"].tap()
    app.buttons["Toggle Move up"].tap()
    expectText("Delete enabled: false")
    expectText("Move up enabled: true")
    XCTAssertTrue(waitUntil(delete, "enabled == false"))
    XCTAssertTrue(waitUntil(up, "enabled == true"))
    XCTAssertTrue(waitUntil(send, "enabled == true"))
    Thread.sleep(forTimeInterval: 1.5)
    attachScreen("r2-update-2-restored")

    up.tap()
    expectText("Icon presses: 2")
    send.tap()
    expectText("Send presses: 1")
    tapCenter(of: delete)
    XCTAssertFalse(app.staticTexts["Icon presses: 3"].waitForExistence(timeout: 2))
  }

  func testSegmentedControlRestoresRefusedChoice() throws {
    openCatalogSearchEntry("Open native controls probe")
    expectText("Tab: 2")
    let publicSegment = app.buttons["Public"]
    let locked = app.buttons["Locked"]
    XCTAssertTrue(publicSegment.waitForExistence(timeout: 10))
    XCTAssertTrue(publicSegment.isSelected)
    // The probe refuses Locked without rebuilding the control.
    locked.tap()
    expectText("Locked attempts: 1")
    XCTAssertTrue(waitUntil(publicSegment, "selected == true", timeout: 5))
    XCTAssertTrue(waitUntil(locked, "selected == false", timeout: 5))
    expectText("Access: public")
    attachScreen("r2-segment-refused")
  }

  func testPopupsHideNativeControlsBeneathThem() throws {
    openCatalogSearchEntry("Open native layout probe")
    expectText("Popup result: none")
    // A tab, a segment, a text capsule and a standalone icon on the page.
    let beneath = [
      "Saved": app.buttons["Saved"],
      "Grid": app.buttons["Grid"],
      "layout-alert": app.buttons["layout-alert"],
      "layout-plus-tap": app.buttons["layout-plus-tap"],
    ]
    expectTappable(beneath)
    attachFrames("r2-popups-frames", beneath)
    attachScreen("r2-popup-0-initial")

    button(labelled: "Menu").tap()
    let first = app.buttons["First choice"]
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    expectHidden(beneath)
    Thread.sleep(forTimeInterval: 1)
    attachScreen("r2-popup-1-menu-open")
    first.tap()
    expectText("Popup result: menu first")
    expectTappable(beneath)
    attachScreen("r2-popup-2-menu-closed")

    app.buttons["layout-alert"].tap()
    let ok = app.buttons["OK"]
    XCTAssertTrue(ok.waitForExistence(timeout: 10))
    expectHidden(beneath)
    Thread.sleep(forTimeInterval: 1)
    attachScreen("r2-popup-3-alert-open")
    ok.tap()
    expectText("Popup result: alert ok")
    expectTappable(beneath)
    attachScreen("r2-popup-4-alert-closed")

    // Native buttons inside the sheet stay visible and take taps.
    app.buttons["layout-sheet"].tap()
    let sheetAction = app.buttons["layout-sheet-action"]
    XCTAssertTrue(waitUntilHittable(sheetAction))
    expectHidden(beneath)
    Thread.sleep(forTimeInterval: 1)
    attachScreen("r2-popup-5-sheet-open")
    sheetAction.tap()
    expectText("Sheet presses: 1")
    app.buttons["layout-sheet-close"].tap()
    expectText("Popup result: sheet closed")
    expectTappable(beneath)
    attachScreen("r2-popup-6-sheet-closed")
  }

  func testStandaloneIconLongPressStillFires() throws {
    // Both halves run, so a failure shows whether only the standalone icon or
    // also the capsule control lost its long press.
    continueAfterFailure = true
    openCatalogSearchEntry("Open native layout probe")
    let hold = app.buttons["layout-plus-hold"]
    XCTAssertTrue(waitUntilHittable(hold))
    hold.press(forDuration: 1.2)
    expectText("Icon holds: 1")
    expectText("Icon taps: 0")
    hold.tap()
    expectText("Icon taps: 1")
    expectText("Icon holds: 1")

    // The control: a long press on a text capsule, which is not standalone.
    button(labelled: "Menu").press(forDuration: 1.2)
    let second = app.buttons["Second choice"]
    XCTAssertTrue(second.waitForExistence(timeout: 10))
    second.tap()
    expectText("Popup result: menu second")
    attachScreen("r2-hold")
  }

  /// Leaves the accessibility probe and opens an entry of the catalog's
  /// Search page.
  private func openCatalogSearchEntry(_ title: String) {
    app.buttons["back"].tap()
    let searchTab = app.buttons["Search"]
    XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
    searchTab.tap()
    let entry = app.buttons[title]
    XCTAssertTrue(entry.waitForExistence(timeout: 10))
    entry.tap()
  }

  /// A button found by its label, for native buttons whose identifier is the
  /// default `button`.
  private func button(labelled label: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
  }

  private func waitUntil(_ element: XCUIElement, _ format: String, timeout: TimeInterval = 10) -> Bool {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  private func waitUntilNotHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
    waitUntil(element, "exists == false OR hittable == false", timeout: timeout)
  }

  private func expectHidden(_ elements: [String: XCUIElement], file: StaticString = #filePath, line: UInt = #line) {
    for (name, element) in elements.sorted(by: { $0.key < $1.key }) {
      XCTAssertTrue(waitUntilNotHittable(element), "\(name) must not take taps beneath a popup", file: file, line: line)
    }
  }

  private func expectTappable(_ elements: [String: XCUIElement], file: StaticString = #filePath, line: UInt = #line) {
    for (name, element) in elements.sorted(by: { $0.key < $1.key }) {
      XCTAssertTrue(waitUntilHittable(element), "\(name) must take taps", file: file, line: line)
    }
  }

  /// Taps where a disabled element is, which an element tap may refuse.
  private func tapCenter(of element: XCUIElement) {
    element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
  }

  private func attachScreen(_ name: String) {
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  /// Element frames in points, one `name x,y,width,height` line each.
  private func attachFrames(_ name: String, _ elements: [String: XCUIElement]) {
    let lines = elements.sorted(by: { $0.key < $1.key }).map { id, element in
      let frame = element.frame
      return "\(id) \(frame.minX),\(frame.minY),\(frame.width),\(frame.height)"
    }
    let frames = XCTAttachment(string: lines.joined(separator: "\n"))
    frames.name = name
    frames.lifetime = .keepAlways
    add(frames)
  }

  private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
    let hittable = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
    return XCTWaiter.wait(for: [hittable], timeout: timeout) == .completed
  }

  private func openCatalogColorPicker() throws {
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
    _ = try waitForPalette(title: "Preview color")
  }

  private func waitForPalette(title: String, file: StaticString = #filePath, line: UInt = #line) throws -> XCUIElement {
    // iOS 26 exposes a plain title in its floating palette; iOS 27 wraps that
    // title in a navigation bar. Both expose this named system container.
    let palette = app.otherElements["UIColorPicker"]
    if !palette.waitForExistence(timeout: 15) {
      // The first palette of a fresh app process sometimes never appears on
      // hosted iOS 26.5, also in a pure UIKit app without this package (see
      // doc/native-accessibility-validation.md). Only that first presentation
      // is skipped; a later one that does not appear fails the test, and the
      // CI job fails when every palette case was skipped.
      if !paletteHasAppeared {
        throw XCTSkip("Known first-use limitation: the first system palette did not appear", file: file, line: line)
      }
      XCTFail("The system palette must appear", file: file, line: line)
    }
    paletteHasAppeared = true
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

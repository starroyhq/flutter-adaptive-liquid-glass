import XCTest

/// Drives the installed Flutter example through the system input service.
/// This intentionally does not use Flutter's synthetic pointer test channel.
final class NativeSliderUITests: XCTestCase {
  private let app = XCUIApplication()

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
  }

  func testSlowForwardAndReverseDragsKeepOneEditingCycle() throws {
    let renderer = app.staticTexts["21 component capabilities · native"]
    XCTAssertTrue(renderer.waitForExistence(timeout: 20), "Use an iOS 26+ runtime with native rendering")

    let slider = app.sliders["Preview level"]
    let counts = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Gestures:")).firstMatch
    for _ in 0..<5 {
      if slider.exists && slider.isHittable && counts.exists && counts.isHittable { break }
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.78))
      let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.48))
      start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }
    XCTAssertTrue(slider.exists && slider.isHittable, "The native slider must be visible")
    XCTAssertTrue(counts.exists && counts.isHittable, "Flutter callback counters must be visible")
    // XCTest does not track Flutter scroll tickers as application activity.
    // Wait for layout to stop moving before resolving a thumb coordinate.
    var previousFrame = CGRect.null
    var stableSamples = 0
    let settled = NSPredicate { _, _ in
      let frame = slider.frame
      stableSamples = frame == previousFrame ? stableSamples + 1 : 0
      previousFrame = frame
      return stableSamples >= 2
    }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 8), .completed)
    var snapshot = try readSnapshot()
    let initial = XCTAttachment(string: "Slider frame: \(slider.frame)\n\(app.debugDescription)")
    initial.name = "Native slider accessibility hierarchy"
    initial.lifetime = .keepAlways
    add(initial)
    XCTAssertEqual(snapshot.starts, 0)
    XCTAssertEqual(snapshot.ends, 0)

    for (index, destination) in [0.8, 0.2, 0.8, 0.2].enumerated() {
      let previous = snapshot
      XCTContext.runActivity(named: "Slow drag \(index + 1): \(previous.value) to \(destination)") { _ in
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: previous.value, dy: 0.5))
        let end = slider.coordinate(withNormalizedOffset: CGVector(dx: destination, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
      }
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = "Slider after drag \(index + 1)"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      let completed = NSPredicate { [weak self] _, _ in
        guard let current = try? self?.readSnapshot() else { return false }
        return current.ends >= previous.ends + 1
      }
      let outcome = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: completed, object: nil)], timeout: 5)
      snapshot = try readSnapshot()
      let observed = "value \(snapshot.value), starts \(snapshot.starts), ends \(snapshot.ends), lastEnd \(String(describing: snapshot.lastEnd)); slider frame \(slider.frame)"
      let callbackSnapshot = XCTAttachment(string: "Drag \(index + 1), target \(destination): \(observed)")
      callbackSnapshot.name = "Flutter slider callback snapshot \(index + 1)"
      callbackSnapshot.lifetime = .keepAlways
      add(callbackSnapshot)
      XCTAssertEqual(outcome, .completed, "Observed \(observed)")
      XCTAssertEqual(snapshot.starts, previous.starts + 1, "One continuous drag must begin once; observed \(observed)")
      XCTAssertEqual(snapshot.ends, previous.ends + 1, "One continuous drag must end once; observed \(observed)")
      if destination > previous.value {
        XCTAssertGreaterThan(snapshot.value, previous.value)
      } else {
        XCTAssertLessThan(snapshot.value, previous.value)
      }
      // The example has ten divisions. Verify the destination, not merely
      // one changed tick, so an interrupted drag cannot pass this acceptance.
      XCTAssertEqual(snapshot.value, destination, accuracy: 0.051, "The controlled value must reach the requested slider detent")
      XCTAssertEqual(try XCTUnwrap(snapshot.lastEnd), snapshot.value, accuracy: 0.001, "Flutter's final callback must match its displayed controlled value")
    }
  }

  private struct Snapshot {
    let value: Double
    let starts: Int
    let ends: Int
    let lastEnd: Double?
  }

  private func readSnapshot() throws -> Snapshot {
    let valueLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Value:")).firstMatch.label
    let counts = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Gestures:")).firstMatch.label
    let value = try XCTUnwrap(Double(valueLabel.replacingOccurrences(of: "Value: ", with: "")))
    let regex = try NSRegularExpression(pattern: #"Gestures: (\d+) / (\d+) · Last end: ([\d.]+|none)"#)
    let text = counts as NSString
    let match = try XCTUnwrap(regex.firstMatch(in: counts, range: NSRange(location: 0, length: text.length)))
    return Snapshot(
      value: value,
      starts: try XCTUnwrap(Int(text.substring(with: match.range(at: 1)))),
      ends: try XCTUnwrap(Int(text.substring(with: match.range(at: 2)))),
      lastEnd: Double(text.substring(with: match.range(at: 3)))
    )
  }
}

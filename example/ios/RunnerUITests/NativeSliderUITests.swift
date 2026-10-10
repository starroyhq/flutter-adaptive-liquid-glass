import XCTest

/// Drives the installed Flutter example through the system input service.
/// This intentionally does not use Flutter's synthetic pointer test channel.
final class NativeSliderUITests: XCTestCase {
  private let app = XCUIApplication()

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--liquid-glass-slider-trace"]
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
    // Hosted CI accessibility snapshots can each take several seconds; allow
    // time to collect three frames, not just to finish the scroll animation.
    let settlingStarted = ProcessInfo.processInfo.systemUptime
    var frameSamples: [String] = []
    var previousFrame = CGRect.null
    var stableSamples = 0
    let settled = NSPredicate { _, _ in
      let queryStarted = ProcessInfo.processInfo.systemUptime
      let frame = slider.frame
      let queryFinished = ProcessInfo.processInfo.systemUptime
      frameSamples.append("t=\(queryFinished - settlingStarted)s, query=\(queryFinished - queryStarted)s, frame=\(frame)")
      let valid = !frame.isNull && !frame.isInfinite && !frame.isEmpty
      stableSamples = valid && frame == previousFrame ? stableSamples + 1 : 0
      previousFrame = frame
      return stableSamples >= 2
    }
    let settlingResult = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 45)
    let frameHistory = frameSamples.joined(separator: "\n")
    let settlingAttachment = XCTAttachment(string: frameHistory)
    settlingAttachment.name = "Slider frame settling samples"
    settlingAttachment.lifetime = .keepAlways
    add(settlingAttachment)
    XCTAssertEqual(settlingResult, .completed, "Slider did not return three identical nonempty frames within 45 seconds:\n\(frameHistory)")
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
      // Reading the two Flutter labels also requires remote accessibility
      // snapshots. Wait for the result without ever repeating the gesture.
      let outcome = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: completed, object: nil)], timeout: 30)
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

    // A real press that does not change the value is still an editing cycle.
    // Repeat it to ensure a committed touch identity does not block the next
    // physical interaction while rejecting late system editing callbacks.
    for index in 1...2 {
      let previous = snapshot
      slider.coordinate(withNormalizedOffset: CGVector(dx: previous.value, dy: 0.5))
        .press(forDuration: 0.2)
      let completed = NSPredicate { [weak self] _, _ in
        guard let current = try? self?.readSnapshot() else { return false }
        return current.ends >= previous.ends + 1
      }
      let outcome = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: completed, object: nil)], timeout: 30)
      snapshot = try readSnapshot()
      let observed = "Stationary press \(index): value \(snapshot.value), starts \(snapshot.starts), ends \(snapshot.ends), lastEnd \(String(describing: snapshot.lastEnd))"
      let attachment = XCTAttachment(string: observed)
      attachment.name = "Stationary slider callback snapshot \(index)"
      attachment.lifetime = .keepAlways
      add(attachment)
      XCTAssertEqual(outcome, .completed, observed)
      XCTAssertEqual(snapshot.starts, previous.starts + 1, observed)
      XCTAssertEqual(snapshot.ends, previous.ends + 1, observed)
      XCTAssertEqual(snapshot.value, previous.value, accuracy: 0.001, observed)
      XCTAssertEqual(try XCTUnwrap(snapshot.lastEnd), snapshot.value, accuracy: 0.001, observed)
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

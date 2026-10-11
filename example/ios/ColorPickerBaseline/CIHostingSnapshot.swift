// Read-only CI evidence. Never activate an app, capture pixels, or inspect any
// other application's windows. Compile for macOS, not into the UIKit fixture.
import AppKit
import CoreGraphics
import Foundation

let simulatorApps = NSWorkspace.shared.runningApplications.filter {
  $0.bundleIdentifier == "com.apple.iphonesimulator"
}
let simulatorPIDs = Set(simulatorApps.map { Int($0.processIdentifier) })
let windowInfo = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
  as? [[String: Any]] ?? []
let windows: [[String: Any]] = windowInfo.compactMap { info in
  guard let pid = info[kCGWindowOwnerPID as String] as? Int,
        simulatorPIDs.contains(pid) else { return nil }
  return [
    "ownerPID": pid,
    "name": info[kCGWindowName as String] as? String ?? "",
    "bounds": info[kCGWindowBounds as String] as? [String: Any] ?? [:],
    "onScreen": info[kCGWindowIsOnscreen as String] as? Bool ?? false,
    "layer": info[kCGWindowLayer as String] as? Int ?? -1,
  ]
}
let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
let evidence: [String: Any] = [
  "sessionAvailable": !session.isEmpty,
  "onConsole": session[kCGSessionOnConsoleKey as String] as? Bool ?? false,
  "loginDone": session[kCGSessionLoginDoneKey as String] as? Bool ?? false,
  // Read-only preflight. Never request permission or alter the TCC database.
  "screenCaptureAccess": CGPreflightScreenCaptureAccess(),
  "applications": simulatorApps.map {
    ["pid": Int($0.processIdentifier),
     "executable": $0.executableURL?.path ?? "",
     "finishedLaunching": $0.isFinishedLaunching] as [String: Any]
  },
  "windows": windows,
]
let data = try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([10]))

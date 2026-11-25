"""Run one native interaction suite on a dedicated simulator."""

import json
import os
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "example/ios"
DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
PALETTE_TESTS = {
    "testBackgroundCancelsPaletteWhileItsFullScreenChildIsPresented",
    "testCatalogColorPickerReopensAfterNativeTabRecreation",
    "testClearingLabelDuringPresentationRestoresSystemActivation",
    "testColorWellKeepsSystemPickerAndAccessibilityActivation",
    "testDuplicateActivationAndBackgroundCancelOnlyOwnedPalette",
    "testExternalDismissalReleasesPaletteWhileFullScreenChildIsPresented",
    "testProgrammaticDismissalReleasesOnlyTheDepartingPalette",
    "testRemovingSourceDuringPresentationCancelsOwnedPalette",
}
SIMULATOR_FAILURES = (
    "kAXErrorIPCTimeout",
    "Timed out while evaluating UI query",
    "Failed to get screenshot: Timed out while requesting screenshot",
    "Failed to terminate dev.starroyhq.flutterAdaptiveLiquidGlass.example:",
    "Native test fixture did not reach the foreground",
    "Native test fixture did not load the catalog",
)


def tests_for(suite):
    names = {}
    for case in ("NativeAccessibilityUITests", "NativeSliderUITests"):
        source = (IOS / f"RunnerUITests/{case}.swift").read_text()
        names[case] = set(re.findall(r"^  func (test\w+)\(", source, re.MULTILINE))
        if not names[case]:
            raise SystemExit(f"No tests found in {case}")
    accessibility = names["NativeAccessibilityUITests"]
    if missing := PALETTE_TESTS - accessibility:
        raise SystemExit(f"Missing palette tests: {sorted(missing)}")
    if suite == "palette":
        return {f"NativeAccessibilityUITests/{name}" for name in PALETTE_TESTS}
    names["NativeAccessibilityUITests"] -= PALETTE_TESTS
    return {f"{case}/{name}" for case, tests in names.items() for name in tests}


def run_tool(*command, timeout=120, **options):
    return subprocess.run(command, check=True, timeout=timeout, text=True, **options)


def read_json(*command):
    return json.loads(run_tool(*command, capture_output=True).stdout)


def simctl(*args, **options):
    return run_tool("xcrun", "simctl", *args, **options)


def get_runtime(major):
    candidates = [
        runtime for runtime in read_json("xcrun", "simctl", "list", "runtimes", "--json")["runtimes"]
        if runtime.get("isAvailable")
        and runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
        and runtime["version"].split(".")[0] == major
        and any(item["identifier"] == DEVICE_TYPE for item in runtime.get("supportedDeviceTypes", []))
    ]
    if not candidates:
        raise SystemExit(f"No available iOS {major} runtime runs iPhone 17 Pro")
    runtime = max(candidates, key=lambda item: tuple(map(int, item["version"].split("."))))
    with (Path(runtime["runtimeRoot"]) / "System/Library/CoreServices/SystemVersion.plist").open("rb") as source:
        version = plistlib.load(source)["ProductVersion"]
    if version.split(".")[0] != major:
        raise SystemExit(f"Expected iOS {major}, found {version}")
    return runtime["identifier"], version


def result_json(bundle, query):
    return read_json("xcrun", "xcresulttool", "get", "test-results", query, "--path", str(bundle), "--format", "json")


def only_simulator_failures(bundle):
    if not bundle.exists():
        return False
    failures = result_json(bundle, "summary")["testFailures"]
    return bool(failures) and all(
        any(reason in issue.get("failureText", "") for reason in SIMULATOR_FAILURES)
        for issue in failures
    )


def test_cases(nodes):
    for node in nodes:
        if node["nodeType"] == "Test Case":
            yield node["nodeIdentifier"].removesuffix("()"), node["result"]
        yield from test_cases(node.get("children", []))


def require_complete_results(bundle, expected, suite):
    cases = list(test_cases(result_json(bundle, "tests")["testNodes"]))
    ids = {case for case, _ in cases}
    if ids != expected or len(cases) != len(expected):
        raise SystemExit(f"Unexpected test coverage: missing {sorted(expected - ids)}, unexpected {sorted(ids - expected)} or duplicates")
    allowed = {"Passed", "Skipped"} if suite == "palette" else {"Passed"}
    if any(result not in allowed for _, result in cases):
        raise SystemExit(f"Unexpected test outcomes: {cases}")
    skipped = sorted(case for case, result in cases if result == "Skipped")
    if len(skipped) == len(expected):
        raise SystemExit("Every palette case was skipped; the system palette never appeared")
    return [f"{len(cases) - len(skipped)}/{len(expected)} tests passed"] + [
        f"Existing palette first-use skip: {case}" for case in skipped
    ]


def run_suite(runtime, name, tests, bundle):
    device = simctl("create", name, DEVICE_TYPE, runtime, capture_output=True).stdout.strip()
    try:
        # Wait for this device's first-boot migration without enumerating the
        # runner's full device list once the requested runtime is ready.
        simctl("bootstatus", device, "-b", timeout=600)
        run_tool(
            "xcodebuild", "-workspace", "Runner.xcworkspace", "-scheme", "NativeSliderAcceptance",
            "-configuration", "Debug", "-sdk", "iphonesimulator",
            "-destination", f"platform=iOS Simulator,id={device}",
            "-derivedDataPath", "../build/ios-native-interaction", "-resultBundlePath", str(bundle),
            "-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1",
            "-collect-test-diagnostics", "never",
            *(f"-only-testing:RunnerUITests/{test}" for test in sorted(tests)),
            "ARCHS=arm64", "ONLY_ACTIVE_ARCH=NO", "CODE_SIGNING_ALLOWED=NO", "test-without-building",
            cwd=IOS, timeout=1500,
        )
    finally:
        try:
            simctl("shutdown", device)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            # Deletion still runs even if the device already shut down.
            pass
        simctl("delete", device)


def main():
    suite = os.environ["GLASS_NATIVE_SUITE"]
    if suite not in {"controls", "palette"}:
        raise SystemExit(f"Unknown native test suite {suite}")
    tests = tests_for(suite)
    runtime, version = get_runtime(os.environ["GLASS_IOS_MAJOR"])
    results = IOS.parent / "build/native-interaction"
    results.mkdir(parents=True, exist_ok=True)
    lines = [f"Native interaction: iPhone 17 Pro on iOS {version}, {suite}"]
    for attempt in (1, 2):
        name = f"Liquid Glass {suite} {os.environ['GITHUB_RUN_ID']} attempt {attempt}"
        bundle = results / f"attempt-{attempt}.xcresult"
        try:
            run_suite(runtime, name, tests, bundle)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            if attempt == 2:
                raise
            if isinstance(error, subprocess.TimeoutExpired) and error.cmd[:3] == ("xcrun", "simctl", "bootstatus"):
                message = "Simulator boot timed out; retrying once on a new simulator."
            elif isinstance(error, subprocess.CalledProcessError) and only_simulator_failures(bundle):
                message = "XCTest simulator communication failed; retrying once on a new simulator."
            else:
                raise
            print(message, flush=True)
            lines.append(message)
        else:
            lines.extend(require_complete_results(bundle, tests, suite))
            break
    print("\n".join(lines), flush=True)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()

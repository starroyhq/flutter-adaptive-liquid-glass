#!/usr/bin/env python3
"""One CI environment comparison; the application and XCTest are untouched."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import time


def output(command):
    return subprocess.check_output(command, text=True).strip()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def append_record(path, phase, value):
    with path.open("a") as destination:
        destination.write(json.dumps({
            "time": datetime.now(timezone.utc).isoformat(),
            "phase": phase,
            **value,
        }, sort_keys=True) + "\n")


def gui_processes():
    # comm contains the executable, not argv or the process environment.
    processes = []
    for line in output(["ps", "-axww", "-o", "pid=,ppid=,comm="]).splitlines():
        fields = line.strip().split(maxsplit=2)
        if len(fields) == 3 and Path(fields[2]).name in {"Simulator", "DeviceHub"}:
            processes.append({"pid": int(fields[0]), "ppid": int(fields[1]),
                              "comm": fields[2]})
    return processes


def matching_windows(snapshot, executable, device_name):
    pids = {app["pid"] for app in snapshot["applications"]
            if Path(app["executable"]).resolve() == executable}
    return [window for window in snapshot["windows"]
            if window["ownerPID"] in pids and window["onScreen"]
            and window["layer"] == 0 and device_name in window["name"]
            and window["bounds"].get("Width", 0) > 0
            and window["bounds"].get("Height", 0) > 0]


def run(args, command):
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    summary = {"mode": args.mode, "deviceID": args.device, "testStarted": False,
               "environmentValid": False}
    try:
        developer = Path(output(["xcode-select", "-p"])).resolve()
        selected_override = os.environ.get("DEVELOPER_DIR")
        if selected_override:
            override_path = Path(selected_override).resolve()
            if override_path.suffix == ".app":
                override_path /= "Contents/Developer"
            if override_path != developer:
                raise RuntimeError("DEVELOPER_DIR differs from xcode-select; do not mix Xcodes.")
        simctl = Path(output(["xcrun", "--find", "simctl"])).resolve()
        if not simctl.is_relative_to(developer):
            raise RuntimeError("xcrun simctl does not belong to the selected Xcode.")
        simulator_app = developer / "Applications/Simulator.app"
        if not simulator_app.is_dir():
            raise RuntimeError("Selected Xcode has no Simulator.app; do not substitute another Xcode.")
        with (simulator_app / "Contents/Info.plist").open("rb") as source:
            app_info = plistlib.load(source)
        executable = (simulator_app / "Contents/MacOS" / app_info["CFBundleExecutable"]).resolve()
        if app_info["CFBundleIdentifier"] != "com.apple.iphonesimulator" or not executable.is_file():
            raise RuntimeError("Cannot verify the selected Xcode's Simulator executable.")
        devices = json.loads(output([str(simctl), "list", "devices", "--json"]))["devices"]
        booted_devices = [{"id": device["udid"], "name": device["name"], "runtime": runtime}
                          for runtime, items in devices.items() for device in items
                          if device["state"] == "Booted"]
        matches = [(runtime, device) for runtime, items in devices.items() for device in items
                   if device["udid"] == args.device]
        if len(matches) != 1 or matches[0][1]["state"] != "Booted":
            raise RuntimeError("The job's exact simulator is not booted.")
        runtime, device = matches[0]
        summary["deviceName"] = device["name"]
        summary["jobIsOnlyBootedDevice"] = (
            len(booted_devices) == 1 and booted_devices[0]["id"] == args.device
        )
        if not device["name"].startswith("Liquid Glass First Palette "):
            raise RuntimeError("Refusing a device outside this job's diagnostic fixture.")

        repository = Path(__file__).resolve().parents[3]
        inputs = ["example/ios/ColorPickerBaseline/ColorPickerBaseline.swift",
                  "example/ios/ColorPickerBaseline/Info.plist",
                  "example/ios/RunnerUITests/NativeColorBaselineUITests.swift"]
        policy = subprocess.run(["defaults", "read", "com.apple.CoreSimulator",
                                 "FramebufferServerRendererPolicy"], capture_output=True, text=True)
        write_json(destination / "environment.json", {
            **summary, "developerDirectory": str(developer), "simctl": str(simctl),
            "simulatorExecutable": str(executable), "runtime": runtime,
            "bootedDevices": booted_devices,
            "xcodeVersion": output(["xcodebuild", "-version"]),
            "sourceCommit": output(["git", "-C", str(repository), "rev-parse", "HEAD"]),
            "sourceSHA256": {name: hashlib.sha256((repository / name).read_bytes()).hexdigest()
                             for name in inputs},
            "launchManager": output(["launchctl", "managername"]),
            "launchManagerUID": output(["launchctl", "manageruid"]),
            "consoleUID": os.stat("/dev/console").st_uid,
            "framebufferRendererPolicy": policy.stdout.strip() if policy.returncode == 0 else "missing",
        })
        if not summary["jobIsOnlyBootedDevice"]:
            raise RuntimeError("Another device is booted on this fresh host; do not shut it down or substitute it.")
        # Both arms compile and execute the same read-only observer.
        helper = destination / "hosting-snapshot"
        subprocess.run(["xcrun", "--sdk", "macosx", "swiftc",
                        str(Path(__file__).with_name("CIHostingSnapshot.swift")),
                        "-o", str(helper)], check=True)

        def snapshot(phase):
            state = json.loads(output([str(helper)]))
            append_record(destination / "windows.jsonl", phase, state)
            return state

        initial_processes = gui_processes()
        append_record(destination / "processes.jsonl", "before-launch", {"processes": initial_processes})
        initial = snapshot("before-launch")
        if initial_processes or initial["applications"]:
            raise RuntimeError("A Simulator GUI already exists on this fresh host; comparison is invalid.")
        if not initial["onConsole"] or not initial["loginDone"]:
            raise RuntimeError("Cannot verify the same logged-in Aqua session for this comparison.")

        if args.mode == "gui":
            subprocess.run(["open", "-a", str(simulator_app), "--args",
                            "-CurrentDeviceUDID", args.device], check=True)
            # Wait for an observable GUI condition, not for a palette/service
            # warmup. This does not change any XCTest timeout or test input.
            deadline = time.monotonic() + 30
            while True:
                state = snapshot("verify-gui-device")
                matches = matching_windows(state, executable, device["name"])
                if matches:
                    summary["verifiedDeviceWindows"] = matches
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("Simulator opened without a verifiable window for this job's device.")
                time.sleep(0.5)

        summary["environmentValid"] = True
        summary["guiObservedDuringTest"] = False
        summary["unexpectedGUIExecutableObserved"] = False
        summary["guiMissingDuringTest"] = False
        summary["guiDeviceWindowMissingAtSample"] = False
        summary["windowSamplesDuringTest"] = 0
        # Inherit stdout/stderr; the original xcodebuild invocation and its exit
        # status remain visible. No app launch, click, retry or screenshot here.
        process = subprocess.Popen(command)
        summary["testStarted"] = True
        next_window_sample = time.monotonic()
        try:
            while True:
                processes = gui_processes()
                append_record(destination / "processes.jsonl", "xcodebuild-running", {"processes": processes})
                expected = [item for item in processes if Path(item["comm"]).resolve() == executable]
                summary["guiObservedDuringTest"] |= bool(expected)
                summary["unexpectedGUIExecutableObserved"] |= len(expected) != len(processes)
                if args.mode == "gui" and not expected:
                    summary["guiMissingDuringTest"] = True
                # Both arms observe windows at the same low frequency. A live
                # process alone does not prove this device has a GUI window.
                if time.monotonic() >= next_window_sample:
                    state = snapshot("xcodebuild-running")
                    summary["windowSamplesDuringTest"] += 1
                    if args.mode == "gui" and not matching_windows(state, executable, device["name"]):
                        summary["guiDeviceWindowMissingAtSample"] = True
                    next_window_sample = time.monotonic() + 10
                try:
                    returncode = process.wait(timeout=2)
                    break
                except subprocess.TimeoutExpired:
                    pass
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait()
        summary["xcodebuildExitCode"] = returncode
        final = snapshot("after-xcodebuild")
        summary["finalDeviceWindows"] = matching_windows(final, executable, device["name"])
        if (summary["unexpectedGUIExecutableObserved"] or summary["guiMissingDuringTest"]
                or summary["guiDeviceWindowMissingAtSample"]):
            summary["environmentValid"] = False
            summary["invalidReason"] = "The selected GUI or its job-device window was missing at a sample, or another GUI host appeared."
        if args.mode == "simctl-only" and summary["guiObservedDuringTest"]:
            summary["environmentValid"] = False
            summary["invalidReason"] = "xcodebuild started Simulator GUI; the arms no longer distinguish GUI hosting."
            summary["interpretation"] = "xcodebuild started Simulator GUI; this arm was not GUI-free."
        else:
            summary["interpretation"] = "A single diagnostic result does not establish a root cause or repair."
        print(json.dumps(summary, indent=2, sort_keys=True), flush=True)
        return returncode if returncode else (0 if summary["environmentValid"] else 2)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        summary["environmentValid"] = False
        summary["invalidReason"] = str(error)
        print(f"Hosting experiment invalid: {error}", file=sys.stderr, flush=True)
        return 2
    finally:
        write_json(destination / "summary.json", summary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["simctl-only", "gui"], required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or command[0] != "xcodebuild":
        parser.error("Pass the unchanged xcodebuild test command after --.")
    return run(args, command)


if __name__ == "__main__":
    sys.exit(main())

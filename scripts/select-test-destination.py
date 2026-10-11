#!/usr/bin/env python3
"""Choose a connected physical iPhone locally, or a simulator explicitly in CI."""
import json
import os
import subprocess
import sys

mode = sys.argv[1]
minimum_os = 27

def run(*args):
    return json.loads(subprocess.check_output(args, text=True))

def version(text):
    return tuple(int(part) for part in text.split(".") if part.isdigit())

if mode == "--device":
    payload = run("xcrun", "devicectl", "list", "devices", "--quiet", "--timeout", "20", "--json-output", "-")
    candidates = []
    for device in payload.get("result", {}).get("devices", []):
        properties = device.get("properties", {})
        hardware = properties.get("hardware", device.get("hardwareProperties", {}))
        connection = properties.get("connection", device.get("connectionProperties", {}))
        software = properties.get("software", device.get("deviceProperties", {}))
        os_version = software.get("osVersionNumber", "0")
        if isinstance(os_version, dict):
            os_version = os_version.get("stringValue", "0")
        if (hardware.get("reality") == "physical" and hardware.get("platform") == "iOS"
                and connection.get("state", connection.get("tunnelState")) == "connected"
                and version(os_version) >= (minimum_os,)):
            candidates.append((hardware.get("udid"), connection.get("transportType")))
    wired = [candidate for candidate in candidates if candidate[1] == "wired"]
    candidates = wired or candidates
    if len(candidates) != 1 or not candidates[0][0]:
        sys.exit("Connect and unlock one iOS 27+ device with Developer Mode enabled, or set TEST_DESTINATION='platform=iOS,id=YOUR_UDID'.")
    print("platform=iOS,id=" + candidates[0][0])
elif mode == "--simulator":
    payload = run("xcrun", "simctl", "list", "devices", "available", "-j")
    candidates = []
    for runtime, devices in payload.get("devices", {}).items():
        if ".iOS-" not in runtime:
            continue
        os_version = version(runtime.split(".iOS-")[1].replace("-", "."))
        for device in devices:
            if device.get("isAvailable") and device["name"].startswith("iPhone") and os_version >= (minimum_os,):
                candidates.append((device.get("state") == "Booted", os_version, device["name"], device["udid"]))
    if not candidates:
        sys.exit("Install an iOS 27+ simulator runtime in Xcode Settings > Components.")
    print("platform=iOS Simulator,id=" + sorted(candidates, reverse=True)[0][3])
else:
    sys.exit("Expected --device or --simulator")

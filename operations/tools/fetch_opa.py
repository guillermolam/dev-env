#!/usr/bin/env python3
"""Download and verify the pinned OPA binary used by controller tests."""

import hashlib
import platform
import stat
import sys
import urllib.request
from pathlib import Path

VERSION = "1.22.4"
SHA256 = {
    "darwin_arm64": "e6dfa065844e3a1553d665ccc4a2c0a25d1ca3925f6ed8fbaf0fa1ec2060d2a5",
    "darwin_amd64": "b49637ad3606644ca7052611daf9672aa436428f5dc0e22c7cc28ba8c64c8cd7",
    "linux_arm64": "ea958fca8a657e4ce04df74c9b1c30220b368ddcf75fb3aa50bf306d55775dbf",
    "linux_amd64": "b76461cf4db0f77946ef557d727a1da5d7a22ba930844678c9be0bebd2c9d0f6",
}


def main():
    machine = {"x86_64": "amd64"}.get(platform.machine(), platform.machine())
    key = f"{platform.system().lower()}_{machine}"
    digest = SHA256.get(key)
    if not digest:
        sys.exit(f"no pinned OPA binary for {key}")
    asset = f"opa_{key}"
    destination = Path(__file__).resolve().parents[1] / ".cache" / "opa"
    destination.parent.mkdir(parents=True, exist_ok=True)
    url = f"https://github.com/open-policy-agent/opa/releases/download/v{VERSION}/{asset}"
    urllib.request.urlretrieve(url, destination)
    actual = hashlib.sha256(destination.read_bytes()).hexdigest()
    if actual != digest:
        destination.unlink()
        sys.exit("OPA checksum mismatch")
    destination.chmod(destination.stat().st_mode | stat.S_IEXEC)
    print(destination)


if __name__ == "__main__":
    main()

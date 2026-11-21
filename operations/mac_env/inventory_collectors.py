"""Read-only collectors with explicit snapshot state and a shared probe boundary."""

import hashlib
import os
import platform
import shutil
import subprocess
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

COVERAGE = "Partial inventory; failed probes do not imply absence. Nix closures, MAS, language packages and signatures are not fully covered."


def command(args, probes):
    try:
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=90,
            env={**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1"},
        )
    except (OSError, subprocess.TimeoutExpired):
        probes.append({"command": args, "status": "unavailable_or_timeout"})
        return None
    return record_command(args, result, probes)


def record_command(args, result, probes):
    probes.append(
        {
            "command": args,
            "status": "ok" if result.returncode == 0 else "failed",
            "exit_code": result.returncode,
        }
    )
    return result.stdout if result.returncode == 0 else None


@dataclass
class Snapshot:
    observed_at: str = field(default_factory=lambda: datetime.now(UTC).isoformat())
    rows: list = field(default_factory=list)
    probes: list = field(default_factory=list)

    def add(
        self,
        kind,
        name,
        version="",
        method="unknown",
        path="",
        provenance="unknown",
        evidence="filesystem",
        confidence="observed",
        notes="",
    ):
        self.rows.append(
            {
                "kind": kind,
                "name": name,
                "version": version,
                "install_method": method,
                "path": str(path),
                "provenance": provenance,
                "evidence": evidence,
                "confidence": confidence,
                "observed_at": self.observed_at,
                "notes": notes,
            }
        )

    def probe(self, args):
        return command(args, self.probes)

    def document(self):
        return {
            "schema_version": 1,
            "observed_at": self.observed_at,
            "rows": self.rows,
            "probes": self.probes,
            "coverage": COVERAGE,
        }


def collect_host(snapshot):
    snapshot.add(
        "host",
        "macOS",
        platform.mac_ver()[0],
        path="/",
        provenance="platform.mac_ver",
        evidence="Python platform",
        notes=f"architecture={platform.machine()}",
    )


def collect_executables(snapshot):
    for name in ("nix", "brew", "git", "python3", "op", "vulnix", "restic", "darwin-rebuild"):
        collect_executable(snapshot, name)


def collect_executable(snapshot, name):
    binary = shutil.which(name)
    if binary:
        record_executable(snapshot, name, binary)


def record_executable(snapshot, name, binary):
    target = Path(binary).resolve()
    nix_managed = str(target).startswith("/nix/store/")
    snapshot.add(
        "executable",
        name,
        method="Nix" if nix_managed else "unknown",
        path=binary,
        provenance=str(target),
        confidence="inferred" if nix_managed else "observed",
        notes="Resolved target; not proof of original installer identity",
    )


def collect_brew(snapshot):
    brew = shutil.which("brew")
    if not brew:
        return
    collect_brew_categories(snapshot, brew)


def collect_brew_categories(snapshot, brew):
    prefix = snapshot.probe([brew, "--prefix"])
    for category in ("formula", "cask"):
        output = snapshot.probe([brew, "list", "--" + category, "--versions"])
        record_brew_output(snapshot, prefix, category, output)


def record_brew_output(snapshot, prefix, category, output):
    for line in (output or "").splitlines():
        record_brew_line(snapshot, prefix, category, line)


def brew_location(prefix, category, name):
    if not prefix:
        return ""
    directory = {"formula": "Cellar", "cask": "Caskroom"}[category]
    return Path(prefix.strip()) / directory / name


def record_brew_line(snapshot, prefix, category, line):
    parts = line.split()
    if not parts:
        return
    snapshot.add(
        "package",
        parts[0],
        " ".join(parts[1:]),
        "Homebrew " + category,
        brew_location(prefix, category, parts[0]),
        "Homebrew installed registry",
        "brew list --" + category + " --versions",
        notes="Detailed receipts not collected",
    )


def collect_receipts(snapshot):
    output = snapshot.probe(["/usr/sbin/pkgutil", "--pkgs"])
    for package in (output or "").splitlines():
        snapshot.add(
            "installer_receipt",
            package,
            method="macOS Installer receipt",
            provenance="pkgutil registry",
            evidence="pkgutil --pkgs",
            notes="Receipt may remain after removal; presence unverified",
        )


def collect_nix(snapshot):
    nix = shutil.which("nix")
    if nix:
        collect_nix_version(snapshot, nix)
    collect_profiles(snapshot)


def collect_nix_version(snapshot, nix):
    output = snapshot.probe([nix, "--version"])
    if output:
        snapshot.add("tool_version", "nix", output.strip(), path=nix, evidence="nix --version")


def collect_profiles(snapshot):
    locations = (
        Path("/run/current-system"),
        Path("/nix/var/nix/profiles/system"),
        Path.home() / ".nix-profile",
    )
    for location in locations:
        record_profile(snapshot, location)


def record_profile(snapshot, location):
    if location.exists() or location.is_symlink():
        snapshot.add(
            "nix_profile",
            location.name,
            method="Nix profile",
            path=location,
            provenance=str(location.resolve()),
            notes="Profile target only; closure enumeration pending",
        )


def configuration_paths(project):
    paths = [
        project / "flake.nix",
        project / "flake.lock",
        Path.home() / "Brewfile",
        Path.home() / ".zshrc",
        Path.home() / ".gitconfig",
        Path("/etc/nix/nix.conf"),
    ]
    paths.extend(sorted((project / "hosts").glob("**/*.nix")))
    paths.extend(sorted((project / "home").glob("**/*.nix")))
    return paths


def collect_configurations(snapshot, project):
    for location in filter(Path.is_file, configuration_paths(project)):
        record_configuration(snapshot, location)


def record_configuration(snapshot, location):
    try:
        digest = hashlib.sha256(location.read_bytes()).hexdigest()
        snapshot.add(
            "configuration",
            location.name,
            path=location,
            provenance="sha256:" + digest,
            notes="Content fingerprint only; ownership unknown",
        )
    except OSError:
        snapshot.probes.append({"path": str(location), "status": "unreadable"})


def inventory_name(location, kind):
    return location.stem if kind == "application" else location.name


def collect_glob(snapshot, base, pattern, kind, notes):
    for location in sorted(base.glob(pattern)):
        snapshot.add(kind, inventory_name(location, kind), path=location, notes=notes)


def collect_applications(snapshot):
    for base in (Path("/Applications"), Path.home() / "Applications"):
        collect_glob(
            snapshot,
            base,
            "*.app",
            "application",
            "Presence only; origin and signatures unverified",
        )


def collect_launch_definitions(snapshot):
    bases = (
        Path("/Library/LaunchDaemons"),
        Path("/Library/LaunchAgents"),
        Path.home() / "Library/LaunchAgents",
    )
    for base in bases:
        collect_glob(
            snapshot,
            base,
            "*.plist",
            "launch_definition",
            "Definition only; running state unchecked",
        )


def collect_data_directories(snapshot):
    paths = (
        Path.home() / name for name in ("Documents", "Desktop", "Downloads", "Pictures", "Git")
    )
    for location in filter(Path.is_dir, paths):
        snapshot.add(
            "data_directory", location.name, path=location, notes="Contents not enumerated"
        )


def collect_repositories(snapshot, git_root):
    for location in sorted(git_root.glob("*/*")):
        if (location / ".git").exists():
            record_repository(snapshot, location)


def record_repository(snapshot, location):
    head = snapshot.probe(["git", "-C", str(location), "rev-parse", "HEAD"])
    status = snapshot.probe(
        ["git", "-C", str(location), "status", "--porcelain", "--untracked-files=no"]
    )
    snapshot.add(
        "git_repository",
        location.name,
        (head or "").strip(),
        "Git checkout",
        location,
        evidence="git rev-parse HEAD; git status",
        notes=repository_notes(status),
    )


def repository_notes(status):
    changed = "unknown" if status is None else bool(status)
    return f"tracked_changes={changed}; untracked files and remotes omitted"


COLLECTORS = (
    collect_host,
    collect_executables,
    collect_brew,
    collect_receipts,
    collect_nix,
    collect_applications,
    collect_launch_definitions,
    collect_data_directories,
)


def collect(project, git_root):
    snapshot = Snapshot()
    for collector in COLLECTORS:
        collector(snapshot)
    collect_configurations(snapshot, Path(project))
    collect_repositories(snapshot, Path(git_root))
    return snapshot.document()

#!/usr/bin/env python3
"""Allow 1Password vault fsekn2smjmqh3jz3yien6pjifq and no other vault."""

import json
import re
import shlex
import sys

ALLOWED = "fsekn2smjmqh3jz3yien6pjifq"
SAFE = {
    "",
    "account",
    "completion",
    "docs",
    "environment",
    "help",
    "service-account",
    "signin",
    "signout",
    "update",
    "version",
    "whoami",
}
VALUED_FLAGS = {"--account", "--cache", "--config", "--encoding", "--session"}
OP_PART = re.compile(r"(?:^|\s)(?:\S*/)?op\b")


def allow():
    return {"permission": "allow"}


def deny():
    return {
        "permission": "deny",
        "user_message": (
            "1Password vault blocked. This project may use vault "
            "fsekn2smjmqh3jz3yien6pjifq only."
        ),
        "agent_message": (
            "Pass --vault fsekn2smjmqh3jz3yien6pjifq or "
            "op://fsekn2smjmqh3jz3yien6pjifq/ on every item, document, "
            "read, inject, run, and vault command. Do not list or read "
            "any other vault."
        ),
    }


def load_event():
    raw = sys.stdin.read()
    try:
        event = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return {}
    return event if isinstance(event, dict) else {}


def add_ref(refs, value):
    text = str(value).strip().strip("'\"")
    if text:
        refs.add(text)


def collect_refs(value, refs):
    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).lower() in {"vault", "vault_id", "vaultid"}:
                if isinstance(item, str):
                    add_ref(refs, item)
            collect_refs(item, refs)
        return
    if isinstance(value, list):
        for item in value:
            collect_refs(item, refs)
        return
    if not isinstance(value, str):
        return
    for match in re.finditer(r"--vault(?:=|\s+)(['\"]?)(\S+)\1", value):
        add_ref(refs, match.group(2))
    for match in re.finditer(r"op://([^/\s'\"]+)", value):
        add_ref(refs, match.group(1))
    for match in re.finditer(r"[?&]v=([A-Za-z0-9]{26})", value):
        add_ref(refs, match.group(1))


def op_parts(command):
    parts = re.split(r"&&|\|\||[;\n]", command)
    return [part.strip() for part in parts if OP_PART.search(part)]


def tokens_after_op(part):
    try:
        tokens = shlex.split(part)
    except ValueError:
        return None
    for index, token in enumerate(tokens):
        if token.rsplit("/", 1)[-1] == "op":
            return tokens[index + 1 :]
    return []


def subcommand(tokens):
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token in VALUED_FLAGS:
            index += 2
            continue
        if token.startswith("-"):
            index += 1
            continue
        return token
    return ""


def bad_part(part):
    refs = set()
    collect_refs(part, refs)
    if any(ref != ALLOWED for ref in refs):
        return True
    tokens = tokens_after_op(part)
    if tokens is None:
        return ALLOWED not in refs
    name = subcommand(tokens)
    if name in SAFE:
        return False
    if name == "vault" and "list" in tokens:
        return True
    if name == "vault" and "get" in tokens and ALLOWED in tokens:
        return False
    return ALLOWED not in refs


def command_texts(event):
    found = []
    command = event.get("command")
    if isinstance(command, str):
        found.append(command)
    for key in ("tool_input", "arguments", "input"):
        value = event.get(key)
        if isinstance(value, str):
            found.append(value)
        elif isinstance(value, (dict, list)):
            found.append(json.dumps(value))
    return found


def decide(event):
    scoped = {"texts": command_texts(event)}
    refs = set()
    collect_refs(scoped, refs)
    if any(ref != ALLOWED for ref in refs):
        return deny()
    for text in scoped["texts"]:
        if any(bad_part(part) for part in op_parts(text)):
            return deny()
    return allow()


def main():
    json.dump(decide(load_event()), sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

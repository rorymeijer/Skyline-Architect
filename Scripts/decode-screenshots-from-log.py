#!/usr/bin/env python3
"""Recovers screenshots printed by emit-screenshots-to-log.sh from a (GitHub Actions) log."""
import base64, os, re, sys

log, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
current, chunks = None, []
for raw in open(log, encoding="utf-8", errors="replace"):
    line = re.sub(r"^\S+Z ", "", raw.rstrip("\n"))  # strip Actions timestamps
    m = re.match(r"=====BEGIN-SCREENSHOT (.+)=====", line)
    if m:
        current, chunks = m.group(1), []
    elif line.startswith("=====END-SCREENSHOT") and current:
        with open(os.path.join(out, current), "wb") as fh:
            fh.write(base64.b64decode("".join(chunks)))
        print("wrote", current)
        current = None
    elif current:
        chunks.append(line.strip())

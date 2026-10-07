#!/usr/bin/env python3
"""Publish a CI log as a check run on the triggering commit.

Why: raw job logs live on Azure blob storage which is not reachable from
some environments; check runs and their annotations are served through the
REST API (api.github.com) and are always readable.

Reads env vars:
  GH_TOKEN   – token with checks:write
  REPO       – owner/name
  SHA        – commit to attach the check run to
  LOG_PATH   – log file to publish
  TITLE      – check run title
"""

import json
import os
import re
import sys
import urllib.request

MAX_SUMMARY = 60000
MAX_ANNOTATIONS = 50

# flutter analyzer line: "  error • message • path:line:col • code"
ANALYZER_LINE = re.compile(
    r"^\s*(error|warning) • (.+?) • (\S+):(\d+):(\d+) • (\S+)\s*$"
)


def main() -> int:
    log_path = os.environ["LOG_PATH"]
    title = os.environ.get("TITLE", "CI output")
    repo = os.environ["REPO"]
    sha = os.environ["SHA"]
    token = os.environ["GH_TOKEN"]

    try:
        with open(log_path, encoding="utf-8", errors="replace") as f:
            log = f.read()
    except OSError:
        log = "(log file not found)"

    annotations = []
    for line in log.splitlines():
        m = ANALYZER_LINE.match(line)
        if not m:
            continue
        level, message, path, line_no, _col, code = m.groups()
        annotations.append(
            {
                "path": path,
                "start_line": int(line_no),
                "end_line": int(line_no),
                "annotation_level": "failure" if level == "error" else "warning",
                "message": f"{message} ({code})",
            }
        )
        if len(annotations) >= MAX_ANNOTATIONS:
            break

    summary = log[-MAX_SUMMARY:]
    payload = {
        "name": f"CI output — {title}",
        "head_sha": sha,
        "status": "completed",
        "conclusion": os.environ.get("CONCLUSION", "failure"),
        "output": {
            "title": title,
            "summary": f"```\n{summary}\n```",
            "annotations": annotations,
        },
    }

    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/check-runs",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"check run created: {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"failed to create check run: {e.code} {e.read().decode()[:400]}",
              file=sys.stderr)
        # Do not fail the job because of the reporting step itself.
    return 0


if __name__ == "__main__":
    sys.exit(main())

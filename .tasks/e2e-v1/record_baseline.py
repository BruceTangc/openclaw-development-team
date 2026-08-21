#!/usr/bin/env python3
"""E2E CASE 9 基线记录器 v2：用 git ls-files 拿干净路径，避免 porcelain XY 前缀解析 bug。"""
import json
import os
import subprocess

REPO = "/root/.openclaw/workspace/_ref-tts-public"
OUT = "/root/.openclaw/workspace/openclaw-development-team/.tasks/e2e-v1/baseline-dlt-simulator.json"


def git(args):
    r = subprocess.run(["git"] + args, cwd=REPO, capture_output=True, text=True)
    return r.stdout.strip()


def main():
    # 修改的已跟踪文件 + 未跟踪文件（排除 .gitignore）
    modified = git(["ls-files", "-m"]).splitlines()
    untracked = git(["ls-files", "-o", "--exclude-standard"]).splitlines()
    dirty = [p for p in modified if p] + [p for p in untracked if p]

    hashes = {}
    for p in dirty:
        full = os.path.join(REPO, p)
        if os.path.isfile(full):
            h = subprocess.run(
                ["git", "hash-object", p], cwd=REPO,
                capture_output=True, text=True
            ).stdout.strip()
            hashes[p] = h

    baseline = {
        "repo": REPO,
        "branch": git(["branch", "--show-current"]),
        "head": git(["rev-parse", "HEAD"]),
        "head_msg": git(["log", "--oneline", "-1"]),
        "modified": [p for p in modified if p],
        "untracked": [p for p in untracked if p],
        "dirty_files": dirty,
        "file_hashes": hashes,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(baseline, f, indent=2, ensure_ascii=False)
    print(json.dumps(baseline, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

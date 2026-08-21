#!/usr/bin/env python3
"""E2E Case 证据记录器：把单个 Case 的真实执行证据落盘为 JSON。"""
import json
import os

EVIDENCE_DIR = "/root/.openclaw/workspace/openclaw-development-team/.tasks/e2e-v1/evidence"


def record(case_id, evidence):
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    path = os.path.join(EVIDENCE_DIR, f"case-{case_id}.json")
    with open(path, "w") as f:
        json.dump(evidence, f, indent=2, ensure_ascii=False)
    print(f"[recorded] {path}")


if __name__ == "__main__":
    import sys
    case_id = sys.argv[1]
    evidence = json.load(sys.stdin)
    record(case_id, evidence)

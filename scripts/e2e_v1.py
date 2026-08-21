#!/usr/bin/env python3
"""
E2E v1 验证脚本（CASE 1-10 的可复跑断言器）

本脚本不 mock、不伪造结果。它只对真实仓库的真实状态做断言，
供 E2E 报告引用真实证据。每个断言失败都会以非零退出码报告。

用法：
  python3 e2e_v1.py check-git-protection <repo>
  python3 e2e_v1.py check-version <repo>
  python3 e2e_v1.py check-changelog <repo>
  python3 e2e_v1.py check-release <repo> <tag>
"""
import sys
import subprocess
import json
import os


def run(cmd, cwd=None):
    r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def git(cmd, cwd):
    code, out, err = run(f"git {cmd}", cwd=cwd)
    if code != 0:
        raise RuntimeError(f"git {cmd} failed: {err}")
    return out


def check_git_protection(repo, baseline_file):
    """CASE 9 断言：baseline 记录的 dirty 文件在开发后仍原样存在。"""
    with open(baseline_file) as f:
        baseline = json.load(f)

    status = git("status --porcelain", repo)
    current = {}
    for line in status.splitlines():
        if not line.strip():
            continue
        path = line[3:].strip()
        current[path] = line[:2].strip()

    protected = baseline.get("dirty_files", [])
    ok = True
    for p in protected:
        # 该文件必须仍然存在且状态不变（未被 reset/覆盖导致消失或变化）
        if p not in current:
            print(f"FAIL: 受保护文件丢失: {p}")
            ok = False
        else:
            print(f"PASS: 受保护文件仍存在: {p} (状态 {current[p]})")

    # 快照 hash 对比（更严格：内容未变）
    for p in protected:
        if os.path.exists(os.path.join(repo, p)):
            code, h, _ = run(f"git hash-object '{p}'", cwd=repo)
            if code == 0 and p in baseline.get("file_hashes", {}):
                if h != baseline["file_hashes"][p]:
                    print(f"FAIL: 文件内容被改变: {p} ({baseline['file_hashes'][p]} -> {h})")
                    ok = False
    print("GIT_PROTECTION:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def check_version(repo):
    """CASE 7 断言：VERSION 文件存在且符合 SemVer。"""
    vfile = os.path.join(repo, "VERSION")
    if not os.path.exists(vfile):
        print("FAIL: 无 VERSION 文件")
        return 1
    v = open(vfile).read().strip()
    parts = v.lstrip("v").split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        print(f"FAIL: VERSION 非 SemVer: {v}")
        return 1
    print(f"PASS: VERSION = {v}")
    return 0


def check_changelog(repo, version):
    """CASE 7 断言：CHANGELOG.md 存在且含当前版本条目。"""
    cfile = os.path.join(repo, "CHANGELOG.md")
    if not os.path.exists(cfile):
        print("FAIL: 无 CHANGELOG.md")
        return 1
    content = open(cfile).read()
    if version.lstrip("v") not in content:
        print(f"FAIL: CHANGELOG 无版本 {version}")
        return 1
    print(f"PASS: CHANGELOG 含版本 {version}")
    return 0


def check_release(repo, tag):
    """CASE 8 断言：本地 tag 存在 + GitHub release 存在。"""
    tags = git("tag", repo).splitlines()
    if tag not in tags:
        print(f"FAIL: 本地无 tag {tag}")
        return 1
    print(f"PASS: 本地 tag {tag} 存在")

    code, out, err = run(f"gh release view {tag} --json tagName,name 2>&1", cwd=repo)
    if code != 0:
        print(f"FAIL: GitHub release 不存在: {err}")
        return 1
    print(f"PASS: GitHub release 存在: {out}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == "check-git-protection":
        sys.exit(check_git_protection(sys.argv[2], sys.argv[3]))
    elif cmd == "check-version":
        sys.exit(check_version(sys.argv[2]))
    elif cmd == "check-changelog":
        sys.exit(check_changelog(sys.argv[2], sys.argv[3]))
    elif cmd == "check-release":
        sys.exit(check_release(sys.argv[2], sys.argv[3]))
    else:
        print(f"未知命令 {cmd}")
        sys.exit(2)

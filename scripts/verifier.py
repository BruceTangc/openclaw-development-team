"""
verifier.py — Minimal Validator Stub。

对 Implementation Result 做 5 项最小校验，输出 verification_result。

用法：
  python3 verifier.py <implementation_result.yaml> [changed_files_dir]

5 项校验：
  1. changed_files 存在且非空
  2. tests 有执行记录
  3. tests 全部 pass
  4. acceptance_criteria 每条满足
  5. git diff 合理（changed_files 目录下文件存在 / 一致）
"""
import sys
import os
import yaml


def load_result(path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def check_changed_files(r):
    cf = r.get("changed_files") or []
    if not cf:
        return False, "changed_files 为空或缺失"
    return True, "changed_files 共 %d 项" % len(cf)


def check_tests_executed(r):
    tests = r.get("tests") or []
    if not tests:
        return False, "未执行任何测试（tests 为空）"
    return True, "执行 %d 个测试" % len(tests)


def check_tests_pass(r):
    tests = r.get("tests") or []
    failing = [t for t in tests if t.get("result") != "pass"]
    if failing:
        return False, "存在失败测试: %s" % [t.get("name") for t in failing]
    return True, "全部测试 result == pass"


def check_acceptance(r):
    ac = r.get("acceptance_criteria") or []
    if not ac:
        return False, "acceptance_criteria 为空"
    unmet = []
    for item in ac:
        # 支持两种形态：字符串 "x: 满足" 或 dict {k: v}
        if isinstance(item, dict):
            key, val = list(item.items())[0]
            ok = ("满足" in str(val)) or ("pass" in str(val).lower())
            if not ok:
                unmet.append(key)
        else:
            # 字符串形态，检查是否含"满足"
            if "满足" not in str(item):
                unmet.append(str(item))
    if unmet:
        return False, "未满足 criteria: %s" % unmet
    return True, "%d 条 criteria 全部满足" % len(ac)


def check_git_diff(r, files_dir):
    cf = r.get("changed_files") or []
    if not files_dir or not os.path.isdir(files_dir):
        return False, "changed_files_dir 不可得: %s" % files_dir
    missing = [p for p in cf if not os.path.exists(os.path.join(files_dir, os.path.basename(p)))]
    if missing:
        return False, "changed_files 声称的文件不存在: %s" % missing
    return True, "changed_files 文件均存在，与 git diff 一致"


def main():
    if len(sys.argv) < 2:
        print("usage: python3 verifier.py <impl_result.yaml> [files_dir]")
        sys.exit(2)
    impl_path = sys.argv[1]
    files_dir = sys.argv[2] if len(sys.argv) > 2 else None

    r = load_result(impl_path)
    task_id = r.get("task_id", "UNKNOWN")

    checks = []
    checks.append(("changed_files 存在", check_changed_files(r)))
    checks.append(("执行测试", check_tests_executed(r)))
    checks.append(("测试通过", check_tests_pass(r)))
    checks.append(("acceptance_criteria 满足", check_acceptance(r)))
    checks.append(("git diff 合理", check_git_diff(r, files_dir)))

    findings = []
    all_pass = True
    for name, (ok, msg) in checks:
        status = "PASS" if ok else "FAIL"
        if not ok:
            all_pass = False
            findings.append({"check": name, "result": "FAIL", "detail": msg})
        print("[%s] %s: %s" % (status, name, msg))

    status = "PASS" if all_pass else "FAIL"
    if r.get("status") == "BLOCKED":
        status = "BLOCKED"

    result = {
        "task_id": task_id,
        "status": status,
        "tests": r.get("tests") or [],
        "acceptance_criteria": r.get("acceptance_criteria") or [],
        "findings": findings,
        "evidence": {
            "impl_status": r.get("status"),
            "changed_files_count": len(r.get("changed_files") or []),
            "checks": [{"name": n, "result": "PASS" if ok else "FAIL"} for n, (ok, _) in checks],
        },
    }
    out_path = impl_path
    if "implementation" in impl_path:
        out_path = impl_path.replace("implementation", "verification")
    elif "impl" in impl_path:
        out_path = impl_path.replace("impl", "verification")
    else:
        # 防止覆盖输入文件
        out_path = impl_path + ".verification.yaml"
    with open(out_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(result, f, allow_unicode=True, sort_keys=False)
    print("---")
    print("verification status:", status)
    print("written:", out_path)
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()

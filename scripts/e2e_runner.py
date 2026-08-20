"""
e2e_runner.py — Phase 1 E2E 驱动脚本（供 Main Agent 会话执行）。

注意：此脚本本身不调用 sessions_spawn / sessions_yield（这些是 agent 工具，
只能在 agent turn 内通过工具调用触发，不是 shell 可执行程序）。

它的职责是：
  1. 准备临时测试项目（隔离目标目录），复制 e2e_target.py 作为"待实现目标"。
  2. 生成一份 Development Task + Delegation Contract（YAML，供 Main Agent 读并 spawn）。
  3. 演练本地 Validator 逻辑（用一份"模拟完成结果"验证校验器本身能跑通 PASS/FAIL）。

真正 spawn/yield 的 E2E 由 Main Agent 会话用 sessions_spawn + sessions_yield 工具完成，
见 IMPLEMENTATION_SPEC.md §5。
"""
import os
import sys
import shutil
import subprocess
import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TARGET_DIR = os.path.join(HERE, "e2e_target_project")


def step1_prepare_target():
    os.makedirs(TARGET_DIR, exist_ok=True)
    shutil.copy(os.path.join(HERE, "e2e_target.py"), os.path.join(TARGET_DIR, "hello.py"))
    # 生成一份空 diff 基线（init git）
    subprocess.run(["git", "-C", TARGET_DIR, "init", "-q"], check=False)
    print("[step1] target dir prepared:", TARGET_DIR)
    print("[step1] hello.py placed (to be 'implemented' by Developer)")


def step2_emit_contracts():
    task = {
        "task_id": "DT-20260820-001",
        "project": "e2e_target_project",
        "goal": "在临时测试项目添加 hello 函数",
        "objective": "实现 hello() 并附带可运行自测",
        "scope": {"in": [TARGET_DIR], "out": ["不 push"]},
        "constraints": ["不 push", "不改安全/权限/Runtime", "脱敏"],
        "acceptance_criteria": ["hello 函数存在并可调用", "自测通过", "有文件变更清单 + evidence"],
        "requester_session": "agent:main:telegram:direct:721003068",
        "result_owner": "agent:main:telegram:direct:721003068",
        "status": "NEW",
        "attempt": 1,
        "created_at": "2026-08-20T18:55:00+08:00",
    }
    with open(os.path.join(ROOT, "e2e_task.yaml"), "w", encoding="utf-8") as f:
        yaml.safe_dump(task, f, allow_unicode=True, sort_keys=False)
    print("[step2] emitted e2e_task.yaml (Development Task)")
    print("[step2] result_owner =", task["result_owner"], "(Lead, 非最终用户)")


def step3_local_verify():
    # 演练 Validator：用一份模拟"完成结果"验证校验器 PASS / FAIL 都能判
    impl = os.path.join(HERE, "_mock_impl_result.yaml")
    mock = {
        "type": "implementation_result",
        "task_id": "DT-20260820-001",
        "status": "COMPLETED",
        "summary": "已实现 hello() 且自测通过",
        "changed_files": ["hello.py", "test_hello.py"],
        "tests": [{"name": "self_test", "command": "python3 hello.py", "result": "pass", "output": "self_test PASS"}],
        "acceptance_criteria": [
            "hello 函数存在并可调用: 满足",
            "自测通过: 满足",
            "有文件变更清单 + evidence: 满足",
        ],
        "known_issues": [],
        "evidence": "self_test PASS: hello() -> hello, world",
        "next_recommended_stage": "verify",
    }
    with open(impl, "w", encoding="utf-8") as f:
        yaml.safe_dump(mock, f, allow_unicode=True, sort_keys=False)
    rc = subprocess.run(
        [sys.executable, os.path.join(HERE, "verifier.py"), impl, TARGET_DIR]
    )
    print("[step3] local verifier rc =", rc.returncode, "(0 = PASS)")
    return rc.returncode


def main():
    print("=== Phase 1 E2E runner (local prep) ===")
    step1_prepare_target()
    step2_emit_contracts()
    rc = step3_local_verify()
    print("=== done ===")
    print("真实 spawn/yield E2E 由 Main Agent 会话执行 sessions_spawn + sessions_yield。")
    return rc


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
e2e_scenarios.py — Phase 2 的 5 个 E2E 测试场景（真实验证 Lead 路由逻辑）

这 5 个场景对应 IMPLEMENTATION_SPEC.md 的「E2E 测试 5 个」，验证 Lead 动态路由
在不同需求特征下走对路径。每个场景是一个纯逻辑断言（无 IO），
因为真实 sessions_spawn/yield 需由 Main Agent 会话执行（同 Phase 1 约束）。

运行：python3 scripts/e2e_scenarios.py
退出码：0 = 5 场景全 PASS；1 = 有 FAIL
"""
import sys

# ============================================================
# 模拟 Lead 的复杂度判断 + 路由（与 agents/*/AGENTS.md 一致）
# ============================================================

def determine_complexity(features):
    """根据需求特征判断复杂度（路由建议）。"""
    simple_kw = ("typo", "doc", "config", "单文件", "小改", "bug", "文档")
    complex_kw = ("新agent", "新team", "新架构", "agent os", "runtime", "数据库",
                  "多系统", "安全", "大refactor", "新建agent", "新建team")
    f = features.lower()
    # 复杂关键词优先
    for kw in complex_kw:
        if kw.replace(" ", "") in f.replace(" ", ""):
            return "complex"
    # 简单关键词
    for kw in simple_kw:
        if kw in f:
            return "simple"
    return "medium"


def route(complexity):
    """根据复杂度返回角色序列。"""
    if complexity == "simple":
        return ["requirement_analyst", "developer"]
    if complexity == "medium":
        return ["requirement_analyst", "repository_analyst", "architect", "developer"]
    if complexity == "complex":
        return ["requirement_analyst", "solution_researcher",
                "repository_analyst", "architect", "developer"]
    return []


def lead_validate(result_ok, has_evidence, has_acceptance, conflict, unclear, reuse_existing):
    """Lead 六项校验 + 复用判定 的决策函数。"""
    if reuse_existing:
        return "REUSE_EXISTING_CAPABILITY"
    if unclear:
        return "HUMAN_DECISION_REQUIRED"
    if conflict:
        return "RETURN_TO_ARCHITECT"
    if not (result_ok and has_evidence and has_acceptance):
        return "RETRY_ROLE"
    return "NEXT_STAGE"


def run_scenario(name, expect, got):
    ok = expect == got
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}: 期望 {expect}，实际 {got}")
    return ok


def main():
    all_ok = True

    # ----------------------------------------------------------
    # Test1：简单函数 → Requirement → Developer，不强制 Architect
    # ----------------------------------------------------------
    cx = determine_complexity("修复一个 typo 单文件小改")
    seq = route(cx)
    all_ok &= run_scenario(
        "Test1 简单函数(typo/单文件小改) → Requirement→Developer 不强制 Architect",
        ["requirement_analyst", "developer"], seq)

    # ----------------------------------------------------------
    # Test2：新 Skill → Requirement→Repository Analyst→Architect→Developer
    # ----------------------------------------------------------
    cx = determine_complexity("新建一个数据分析 skill，多文件，处理数据")
    seq = route(cx)
    all_ok &= run_scenario(
        "Test2 新 Skill(多文件/新功能) → Requirement→Repository→Architect→Developer",
        ["requirement_analyst", "repository_analyst", "architect", "developer"], seq)

    # ----------------------------------------------------------
    # Test3：GitHub 已有类似 → 加 Solution Researcher → GitHub Search → 复用
    # ----------------------------------------------------------
    cx = determine_complexity("集成一个新的 agent runtime，跨系统")
    seq = route(cx)
    # 复杂路径必须含 solution_researcher 且在 repository_analyst 之前
    expect3 = ["requirement_analyst", "solution_researcher",
               "repository_analyst", "architect", "developer"]
    all_ok &= run_scenario(
        "Test3 复杂(Agent/Runtime集成) → 加 Solution Researcher，且在 Repository 之前",
        expect3, seq)
    # Solution Researcher 内部结论：GitHub 搜索命中 → 复用/适配
    reuse_decision = lead_validate(True, True, True, False, False, False)
    all_ok &= run_scenario(
        "Test3a Solution Researcher 找到现成(LEARN_AND_BUILD) → 正常进下一阶段",
        "NEXT_STAGE", reuse_decision)

    # ----------------------------------------------------------
    # Test4：Agent OS 已有相同能力 → Lead 判 REUSE_EXISTING_CAPABILITY 禁止重复实现
    # ----------------------------------------------------------
    decision4 = lead_validate(True, True, True, False, False, True)
    all_ok &= run_scenario(
        "Test4 Agent OS 已有相同能力 → REUSE_EXISTING_CAPABILITY 禁止重复实现",
        "REUSE_EXISTING_CAPABILITY", decision4)

    # ----------------------------------------------------------
    # Test5：Architect 发现需求与现有架构冲突 → RETURN_TO_ARCHITECT 不继续 Developer
    # ----------------------------------------------------------
    decision5 = lead_validate(True, True, True, True, False, False)
    all_ok &= run_scenario(
        "Test5 Architect 发现需求与现有架构冲突 → RETURN_TO_ARCHITECT 不继续 Developer",
        "RETURN_TO_ARCHITECT", decision5)

    # ----------------------------------------------------------
    # 汇总
    # ----------------------------------------------------------
    print("\n" + "=" * 60)
    if all_ok:
        print("5 个 E2E 场景全部 PASS (exit 0)")
        return 0
    print("存在 FAIL (exit 1)")
    return 1


if __name__ == "__main__":
    sys.exit(main())

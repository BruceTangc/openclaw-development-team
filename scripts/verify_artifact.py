#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_artifact.py — Generated Artifact Protocol Compliance Validator (P0)
============================================================================
P0-1 Verifier Hardening：用结构化 YAML parser 校验 x-agent-os 声明值，替换 grep 字段存在判断。

依据 Agent OS SKILL-INTEGRATION.md v1.3（当前真实 Protocol）的合法值白名单。
禁止自行发明协议值。协议基线从 scripts/protocol-baseline.sh 读取。

用法:
    python3 verify_artifact.py <artifact-dir> [skill|agent|project|auto]

退出码:
    0 = PASS（或全部合法 N/A）
    1 = FAIL（值非法 / 缺关键结构 / 结构化声明为否定 / ER 缺证据）
    2 = WARN（存在需 Reviewer 人工确认的 N/A / missing structured evidence，不自动阻断）
    3 = 用法错误 / 目录不存在

职责边界（P0-2）：本 validator 只做"值校验"与"结构校验"，不做自然语言语义判断。
    error/recovery/communication 判定依赖结构化字段：
        error_handling: {declared: true}
        recovery:       {declared: true, mechanism: retry}
        communication:  {parallel_runtime: false}
    历史 artifact 缺这些结构化字段 → 标注 missing structured evidence 交 Reviewer，
    不因正文出现/未出现某关键词而 FAIL，也不为兼容继续堆自然语言 Regex。

判定语义（对齐 Agent OS Contract）:
    应经过但未经过 → FAIL；Contract 条件性跳过且注明 → 不 FAIL；
    合法 N/A（结构级显式声明，非自然语言）→ 不计。

本 validator 只做"值校验"与"结构校验"；内容真实性由 Reviewer 人工确认。
"""
import os
import re
import sys
from pathlib import Path

# ---- Agent OS Protocol 合法值白名单（来自 SKILL-INTEGRATION.md v1.3，不发明新值）----
LAYER_VALUES = {"business", "cognition", "action", "control"}
ENTRY_MODE_VALUES = {"fast", "full", "both"}
VERIFICATION_VALUES = {"V0", "V1", "V2", "V3", "V4", "N/A"}
MEMORY_WRITE_VALUES = {"governed", "N/A", "none", "false"}
KNOWLEDGE_WRITE_VALUES = {"governed", "N/A", "none", "false"}
REQUIRES_KEYS = {
    "context", "goal_task_semantics", "task", "decision", "orchestrator",
    "permission", "verification", "evaluation", "writeback", "evolution",
}
REQUIRES_VALUES = {True, False, "conditional"}          # true/conditional/false
TRIGGER_PART = {"user", "heartbeat", "cron", "hook"}
DELEGATION_KEYS = {"max_level", "inherit_parent", "requires_scope", "scope", "delegation_scope"}
MAX_LEVEL_VALUES = {"L0", "L1", "L2", "L3", "L4"}
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$")

# ── P0-2：error/recovery/communication 一律用结构化字段判定，禁用自然语言 Regex 语义判断 ──
# 说明：本 validator 不再 grep 正文中的 "no error handling" / "retry" / "scheduler" 等关键词。
#       错误处理/恢复/并行 runtime 的判定由结构化字段承担（见下方 check 逻辑）；
#       正文语义真实性（"文档是否真的实现了 recovery"）由 Reviewer 人工确认。


REQUIRED_BASELINE_KEYS = [
    "AGENT_OS_PROTOCOL_VERSION",
    "AGENT_OS_ARCH_CONTRACT",
    "AGENT_OS_BASELINE_COMMIT",
    "AGENT_OS_BASELINE_LABEL",
]


def load_baseline(scripts_dir):
    """从 protocol-baseline.sh 读取协议基线（唯一真源）。

    fail-closed：文件不存在 / 无法读取 / 必需字段缺失 → 返回 None（调用方必须拒绝）。
    不做任何内嵌默认值，不参与第二真源。
    """
    bp = os.path.join(scripts_dir, "protocol-baseline.sh")
    if not os.path.isfile(bp):
        return None
    try:
        txt = Path(bp).read_text(encoding="utf-8")
    except OSError:
        return None
    baseline = {}
    for k in REQUIRED_BASELINE_KEYS:
        m = re.search(rf'^{k}=\s*"([^"]*)"', txt, re.M)
        if not m or not m.group(1):
            return None
        baseline[k] = m.group(1)
    return baseline


def find_yaml_files(artifact_dir):
    """定位声明文件并返回 {path, kind} 列表。"""
    candidates = []
    for name in ("SKILL.md", "_meta.json", "AGENTS.md", "README.md"):
        for p in Path(artifact_dir).rglob(name):
            if p.is_file():
                candidates.append((str(p), name))
    return candidates


def parse_frontmatter(path):
    """从 SKILL.md 解析 YAML frontmatter（--- 包裹）。返回 dict 或 None。"""
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    # 找第二个 ---
    end = text.find("\n---", 3)
    if end == -1:
        end = text.find("\n--- ", 3)
    if end == -1:
        return None
    fm = text[3:end].strip("\r\n")
    try:
        import yaml
        data = yaml.safe_load(fm) or {}
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def parse_meta_json(path):
    """解析 _meta.json。返回 dict 或 None。"""
    try:
        import json
        data = json.loads(Path(path).read_text(encoding="utf-8", errors="replace"))
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def parse_ag(path):
    """解析 AGENTS.md 中的 x-agent-os 块（宽松）。返回 dict 或 None。"""
    try:
        import yaml
        txt = Path(path).read_text(encoding="utf-8", errors="replace")
        # 提取 x-agent-os: 起的块
        m = re.search(r"x-agent-os:\s*\n(.*?)(\n\S|$)", txt, re.S)
        if not m:
            return None
        block = "x-agent-os:\n" + m.group(1)
        data = yaml.safe_load(block) or {}
        return data.get("x-agent-os") if isinstance(data, dict) else None
    except Exception:
        return None


def get_xagentos(decl_files):
    """从声明文件收集 x-agent-os 声明块。返回 (block_dict, source_file, raw_has_decl)。"""
    for path, kind in decl_files:
        raw_has = False
        try:
            raw_has = "x-agent-os" in Path(path).read_text(encoding="utf-8", errors="replace")
        except OSError:
            raw_has = False
        if kind == "SKILL.md":
            fm = parse_frontmatter(path)
            if fm and isinstance(fm.get("x-agent-os"), dict):
                return fm["x-agent-os"], path, True
        elif kind == "_meta.json":
            d = parse_meta_json(path)
            if d and isinstance(d.get("x-agent-os"), dict):
                return d["x-agent-os"], path, True
        elif kind == "AGENTS.md":
            x = parse_ag(path)
            if x:
                return x, path, True
        # 记录 raw 声明存在（用于"声明了但无法解析"的 WARN）
        if raw_has:
            return None, path, True
    return None, "", False


def check_artifact(artifact_dir, ptype, baseline):
    results = []
    p, f, w, fail = [], 0, 0, 0

    def _p(msg):
        nonlocal p
        p.append(msg)

    # ---- 收集声明文件 ----
    decl_files = find_yaml_files(artifact_dir)
    xa, src, raw_decl = get_xagentos(decl_files)

    # ---- 类型推断 ----
    if ptype == "auto":
        names = {k for _, k in decl_files}
        if "SKILL.md" in names or "_meta.json" in names:
            ptype = "project" if "AGENTS.md" in names and "SKILL.md" not in names else "skill"
        elif "AGENTS.md" in names:
            ptype = "agent"
        elif "README.md" in names:
            ptype = "project"
        else:
            return None, "ERROR: 无法推断类型，请显式传 type", 3

    # ---- 0. x-agent-os 声明 ----
    if xa is not None:
        _p("x-agent-os 声明存在且可解析 (%s)" % (src or "?"))
    elif raw_decl:
        w += 1
        results.append(("WARN", "x-agent-os 声明存在但无法解析为合法 YAML 结构（需人工确认，不自动 FAIL）"))
    else:
        # 纯项目（无 skill/agent 语义）可 N/A
        if ptype == "project" and not any(k in {n for _, n in decl_files} for k in ("SKILL.md", "AGENTS.md")):
            w += 1
            results.append(("WARN", "x-agent-os 缺失（纯项目，一般 N/A，需 Reviewer 确认）"))
        else:
            f += 1
            results.append(("FAIL", "缺少 x-agent-os 声明（适用场景必须）"))

    # ---- 1. Identity: layer ----
    if xa is not None:
        layer = xa.get("layer")
        if layer in LAYER_VALUES:
            _p("Identity: layer = %s (合法)" % layer)
        elif layer is None:
            w += 1
            results.append(("WARN", "layer 未声明（简单生成物可 N/A）"))
        else:
            f += 1
            results.append(("FAIL", "layer 非法值: %r（合法: %s）" % (layer, sorted(LAYER_VALUES))))

    # ---- 2. Context: requires 结构 ----
    if xa is not None:
        req = xa.get("requires")
        if isinstance(req, dict):
            bad = []
            for kk, vv in req.items():
                if kk not in REQUIRES_KEYS:
                    bad.append("%s(未知键)" % kk)
                elif vv not in REQUIRES_VALUES:
                    bad.append("%s=%r" % (kk, vv))
            if bad:
                f += 1
                results.append(("FAIL", "requires 结构非法: %s（键须∈%s，值须∈true|conditional|false）"
                                % ("; ".join(bad), sorted(REQUIRES_KEYS))))
            else:
                _p("Context: requires 节点矩阵结构合法 (%d 键)" % len(req))
        else:
            w += 1
            results.append(("WARN", "requires 未声明或非对象（简单生成物可 N/A）"))

    # ---- 3. Lifecycle: entry_mode ----
    if xa is not None:
        em = xa.get("entry_mode")
        if em in ENTRY_MODE_VALUES:
            _p("Lifecycle: entry_mode = %s (合法)" % em)
        elif em is None:
            w += 1
            results.append(("WARN", "entry_mode 未声明（无任务型生成物可 N/A）"))
        else:
            f += 1
            results.append(("FAIL", "entry_mode 非法值: %r（合法: %s）" % (em, sorted(ENTRY_MODE_VALUES))))

    # ---- 3b. path ----
    if xa is not None:
        pathv = xa.get("path")
        if isinstance(pathv, dict):
            bad = []
            for sub in ("fast", "full"):
                val = pathv.get(sub)
                if val not in (True, False):
                    bad.append("%s=%r" % (sub, val))
            if bad:
                f += 1
                results.append(("FAIL", "path 结构非法: %s（fast/full 须为 bool）" % "; ".join(bad)))
            else:
                _p("Lifecycle: path.fast/full 合法 (%s)" % {
                    "fast=%s,full=%s" % (pathv.get("fast"), pathv.get("full"))})
        else:
            w += 1
            results.append(("WARN", "path 未声明（可 N/A）"))

    # ---- 4. Memory/State ----
    if xa is not None:
        mw = xa.get("memory_write")
        if mw in MEMORY_WRITE_VALUES:
            _p("Memory/State: memory_write = %s (合法)" % mw)
        elif mw is None:
            w += 1
            results.append(("WARN", "memory_write 未声明（无状态生成物可 N/A）"))
        else:
            f += 1
            results.append(("FAIL", "memory_write 非法值: %r（合法: %s）" % (mw, sorted(MEMORY_WRITE_VALUES))))
        kw = xa.get("knowledge_write")
        if kw is not None and kw not in KNOWLEDGE_WRITE_VALUES:
            f += 1
            results.append(("FAIL", "knowledge_write 非法值: %r（合法: %s）" % (kw, sorted(KNOWLEDGE_WRITE_VALUES))))

    # ---- 5. Delegation（P0-2：仅结构级判定，禁用自然语言 N/A）----
    decl_delegation = None
    if xa is not None:
        d = xa.get("delegation")
        if isinstance(d, dict):
            decl_delegation = d
            bad = []
            for kk in ("max_level", "inherit_parent", "requires_scope"):
                if kk not in d:
                    bad.append("缺 %s" % kk)
            ml = d.get("max_level")
            if ml is not None and ml not in MAX_LEVEL_VALUES:
                bad.append("max_level=%r 非法" % ml)
            ip = d.get("inherit_parent")
            if ip is not None and not isinstance(ip, bool):
                bad.append("inherit_parent=%r 非 bool" % ip)
            rs = d.get("requires_scope")
            if rs is not None and not isinstance(rs, bool):
                bad.append("requires_scope=%r 非 bool" % rs)
            if bad:
                f += 1
                results.append(("FAIL", "delegation 结构非法: %s" % "; ".join(bad)))
            else:
                _p("Delegation: delegation 结构合法 (max_level=%s)" % ml)
        elif d is not None:
            f += 1
            results.append(("FAIL", "delegation 须为结构化对象"))
        # delegation_scope: single 显式声明 → 合法 N/A（结构级）
        elif xa.get("delegation_scope") == "single":
            results.append(("PASS", "Delegation: 显式 delegation_scope=single（合法 N/A）"))

    # 结构级: 若某文件声明了 delegation_scope: single / delegation: none → 合法 N/A
    if decl_delegation is None and xa is not None and xa.get("delegation_scope") not in ("single",):
        # 纯项目无 skill/agent 语义
        if ptype == "project" and not any(k in {n for _, n in decl_files} for k in ("SKILL.md", "AGENTS.md")):
            results.append(("PASS", "Delegation: N/A（纯项目，无 Multi-Agent 语义）"))
        elif xa.get("delegation") is None and xa.get("delegation_scope") is None:
            # 没有 delegation 块，也没有 delegation_scope → 若本地可判定"独立"则 N/A；否则 FAIL
            # 关键：delegation N/A 只能靠结构声明，不靠正文自然语言（P0-2）
            f += 1
            results.append(("FAIL", "缺少 delegation（Multi-Agent 适用场景必须；N/A 仅允许 delegation_scope=single 结构声明）"))

    # ---- 6. Handoff ----
    if xa is not None:
        out = xa.get("outputs")
        if isinstance(out, dict) and ("success_condition" in out or "evidence" in out):
            _p("Handoff: outputs 契约声明")
        elif out is not None:
            w += 1
            results.append(("WARN", "outputs 声明但缺 success_condition/evidence"))
        else:
            w += 1
            results.append(("WARN", "handoff/outputs 未显式声明（简单生成物可 N/A）"))

    # ---- 7. Communication（P0-2：结构化字段判定，替代 FORBIDDEN_RUNTIME 自然语言 grep）----
    # 负向违规检查：默认"无并行 runtime 声明"即合规（PASS）；只有结构化字段显式声明 parallel_runtime=true 才 FAIL。
    # 正文是否真建了并行 runtime 由 Reviewer 语义判断（§3.7 Protocol Compliance）。
    if xa is not None:
        comm = xa.get("communication")
        if comm is None:
            _p("Communication: 未结构化声明并行 runtime（语义判断交 Reviewer）")
        elif isinstance(comm, dict):
            pr = comm.get("parallel_runtime")
            if pr is True:
                f += 1
                results.append(("FAIL", "Communication: communication.parallel_runtime=true（显式声明 Agent OS 禁止的并行 runtime）"))
            elif pr is False:
                _p("Communication: communication.parallel_runtime=false（无并行 runtime，结构化声明）")
            elif pr is None:
                w += 1
                results.append(("WARN", "Communication: communication 块缺 parallel_runtime 字段（missing structured evidence，交 Reviewer）"))
            else:
                f += 1
                results.append(("FAIL", "Communication: communication.parallel_runtime 非法值: %r（须 bool）" % (pr,)))
        else:
            f += 1
            results.append(("FAIL", "Communication: communication 须为结构化对象"))

    # ---- 8. Error Handling（P0-2：结构化字段，替代 NEG_ERROR_* 自然语言 Regex）----
    # error_handling: {declared: true} → PASS；{declared: false} → FAIL（显式否定）；缺字段 → WARN 交 Reviewer。
    if xa is not None:
        eh = xa.get("error_handling")
        if eh is None:
            w += 1
            results.append(("WARN", "Error Handling: 未结构化声明 error_handling.declared（missing structured evidence，交 Reviewer）"))
        elif isinstance(eh, dict) and isinstance(eh.get("declared"), bool):
            if eh["declared"] is True:
                _p("Error Handling: error_handling.declared=true（结构化声明）")
            else:
                f += 1
                results.append(("FAIL", "Error Handling: error_handling.declared=false（显式声明不处理错误）"))
        else:
            f += 1
            results.append(("FAIL", "Error Handling: error_handling 结构非法（须 {declared: bool}）"))

    # ---- 9. Recovery（P0-2：结构化字段，替代 NEG_RECOVERY_* / RECOVERY_MECH 自然语言 Regex）----
    # recovery: {declared: true, mechanism: retry} → PASS；{declared: false} → FAIL；缺字段 → WARN 交 Reviewer。
    if xa is not None:
        rc = xa.get("recovery")
        if rc is None:
            w += 1
            results.append(("WARN", "Recovery: 未结构化声明 recovery.declared（missing structured evidence，交 Reviewer）"))
        elif isinstance(rc, dict) and isinstance(rc.get("declared"), bool):
            if rc["declared"] is True:
                mech = rc.get("mechanism")
                if isinstance(mech, str) and mech.strip():
                    _p("Recovery: recovery.declared=true, mechanism=%s（结构化声明）" % mech)
                else:
                    w += 1
                    results.append(("WARN", "Recovery: recovery.declared=true 但 mechanism 缺失（missing structured evidence，交 Reviewer）"))
            else:
                f += 1
                results.append(("FAIL", "Recovery: recovery.declared=false（显式声明不恢复）"))
        else:
            f += 1
            results.append(("FAIL", "Recovery: recovery 结构非法（须 {declared: bool, mechanism: str}）"))

    # ---- 10. Permissions（P0-6：L2+ 必须 true）----
    perm_fail = False
    if xa is not None and isinstance(xa.get("requires"), dict):
        prem = xa["requires"].get("permission")
        # 任务涉 L2+（需要权限门），但 permission 非 true → FAIL
        if prem is not None and prem is not True and prem != "conditional":
            # 无法从声明自动判任务 L 级；但"明确 permission:false"在 L2+ 必错 → 保守视为可疑
            f += 1
            results.append(("FAIL", "Permission: requires.permission 声明为 %r（L2+ 一律必须 true，false 不可接受）" % (prem,)))
            perm_fail = True
    if not perm_fail and xa is not None:
        lvl = xa.get("verification")
        # 若声明了 L2+ 能力的 outputs 需 permission 门 → 视为 L2+
        if isinstance(xa.get("outputs"), dict) and ("evidence" in xa.get("outputs", {})):
            _p("Permission: 声明 evidence 契约，需过 Permission Gate（L2+ 合规）")
        else:
            _p("Permission: 无 L2 外发迹象（按 L0-L1 处理，permission N/A 可接受）")

    # ---- 13. Versioning（K：SemVer + protocol_version == baseline）----
    if xa is not None:
        pv = xa.get("protocol_version")
        baseline_ver = baseline["AGENT_OS_PROTOCOL_VERSION"]
        if pv is None:
            w += 1
            results.append(("WARN", "protocol_version 未声明（应有，简单生成物可 N/A）"))
        elif str(pv) != baseline_ver:
            f += 1
            results.append(("FAIL", "protocol_version=%r 与当前 Protocol Baseline(%s) 不一致"
                            % (pv, baseline_ver)))
        else:
            _p("Versioning: protocol_version=%s == Baseline(%s)" % (pv, baseline_ver))
        ver = xa.get("version")
        if ver is not None and not (isinstance(ver, str) and SEMVER_RE.match(ver)):
            f += 1
            results.append(("FAIL", "version 非合法 SemVer: %r" % (ver,)))

    # ---- 14. Multi-Agent (L：delegation + provenance 结构) ----
    if decl_delegation is not None:
        prov = None
        if isinstance(xa.get("provenance"), dict):
            prov = xa["provenance"]
        elif isinstance(xa.get("provenance"), str):
            prov = xa["provenance"]
        elif "owner" in xa and "provenance" in xa:
            prov = xa["provenance"]
        if prov is not None:
            _p("Multi-Agent: delegation + provenance 结构齐备")
        else:
            w += 1
            results.append(("WARN", "Multi-Agent: 有 delegation 但 provenance 未结构化声明（需 Reviewer 确认）"))

    # ---- 11. Skill Discovery ----
    if ptype == "skill":
        sk = next((sp for sp, k in decl_files if k == "SKILL.md"), None)
        if sk:
            fm = parse_frontmatter(sk)
            if fm and fm.get("name") and fm.get("description"):
                _p("Skill Discovery: frontmatter name/description 存在")
            else:
                f += 1
                results.append(("FAIL", "Skill Discovery: SKILL.md 缺 name/description"))
    else:
        results.append(("PASS", "Skill Discovery: N/A（非 skill）"))

    # ---- 12. Installation ----
    if ptype == "project":
        rd = next((rp for rp, k in decl_files if k == "README.md"), None)
        if rd:
            try:
                txt = Path(rd).read_text(encoding="utf-8", errors="replace")
                if re.search(r"install|安装", txt, re.I):
                    _p("Installation: README 有安装说明")
                else:
                    w += 1
                    results.append(("WARN", "Installation: README 未提及安装（可能 N/A）"))
            except OSError:
                w += 1
        else:
            w += 1
            results.append(("WARN", "Installation: 无 README（项目交付应含 README）"))
    else:
        results.append(("PASS", "Installation: N/A（当前评估对象非可安装项目）"))

    # ---- P1: Execution Record evidence ----
    er_files = []
    for _pf in Path(artifact_dir).rglob("*"):
        if _pf.is_file() and re.search(r"execution[_-]?record", _pf.name, re.I):
            er_files.append(str(_pf))
    if er_files:
        req_nodes = ["context", "goal", "permission", "execution", "verification"]
        for er in er_files:
            try:
                er_text = Path(er).read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            # 找 steps 下节点
            for node in req_nodes:
                node_pattern = re.compile(rf"^\s{{2}}{node}(?:_task)?\s*:", re.M)
                if not node_pattern.search(er_text):
                    f += 1
                    results.append(("FAIL", "Execution Record 缺失规定节点: %s (%s)" % (node, er)))
                    continue
                # 该节点如果是 completed，必须有 evidence
                m = node_pattern.search(er_text)
                start = m.start()
                line_end = er_text.find("\n", start)
                line = er_text[start:line_end] if line_end != -1 else er_text[start:start+200]
                if re.search(r"completed", line, re.I) and not re.search(r"evidence\s*[:=]", line):
                    # 检查该节点行后直到下一节点的范围内
                    following = er_text[start: er_text.find("\n  ", line_end+1) if line_end+1 < len(er_text) else len(er_text)]
                    if not re.search(r"evidence\s*[:=]", following):
                        f += 1
                        results.append(("FAIL", "Execution Record 节点 %s 状态 completed 但无 evidence（%s）" % (node, er)))
        status_ok = re.search(r"completed|skipped|conditional", er_text, re.I)
        if status_ok:
            _p("Execution Record: status 三态可用")
        else:
            w += 1
            results.append(("WARN", "Execution Record: 无 status 三态标注"))
    else:
        w += 1
        results.append(("WARN", "Execution Record: 未找到（如为 Full Path/涉及 L2+ 产物应生成；需 Reviewer 确认是否 N/A）"))

    return results, p, f, w


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print("用法: verify_artifact.py <artifact-dir> [skill|agent|project|auto]")
        print("")
        print("职责边界：结构化值校验 + 结构校验（Schema / Required fields / Field value /")
        print("  Protocol baseline / Version / Execution Record / Evidence / Capability evidence）。")
        print("不做自然语言语义判断；error/recovery/communication 依赖结构化字段：")
        print("  error_handling: {declared: true}")
        print("  recovery:       {declared: true, mechanism: retry}")
        print("  communication:  {parallel_runtime: false}")
        print("缺结构化字段 → missing structured evidence 交 Reviewer（WARN，不自动 FAIL）。")
        return 3
    artifact_dir = sys.argv[1]
    ptype = sys.argv[2] if len(sys.argv) > 2 else "auto"
    if not os.path.isdir(artifact_dir):
        print("ERROR: 目录不存在: %s" % artifact_dir, file=sys.stderr)
        return 3

    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    baseline = load_baseline(scripts_dir)
    if baseline is None:
        print("ERROR: Protocol Baseline 不可用（protocol-baseline.sh 缺失/无法读取/必需字段缺失）"
              " — fail-closed: Compliance 不得 PASS", file=sys.stderr)
        return 1

    print("Artifact: %s  Type: %s" % (artifact_dir, ptype))
    print("Agent OS Protocol: %s (Architecture Contract %s / %s %s)" % (
        baseline["AGENT_OS_PROTOCOL_VERSION"], baseline["AGENT_OS_ARCH_CONTRACT"],
        baseline["AGENT_OS_BASELINE_LABEL"], baseline["AGENT_OS_BASELINE_COMMIT"]))
    print("")

    results, pass_list, fail_cnt, warn_cnt = check_artifact(artifact_dir, ptype, baseline)
    if results is None:
        print("ERROR: %s" % pass_list)
        return 3

    print("=== Protocol Compliance Checks (结构化值校验) ===")
    for lvl, msg in results:
        print("  [%s] %s" % (lvl, msg))
    for m in pass_list:
        print("  [PASS] %s" % m)

    print("")
    print("=== 汇总 ===")
    print("PASS=%d WARN=%d FAIL=%d" % (len(pass_list), warn_cnt, fail_cnt))
    if fail_cnt > 0:
        print("RESULT: FAIL")
        print("→ Protocol Compliance FAIL：Reviewer 必须 REJECT，Release BLOCKED")
        return 1
    elif warn_cnt > 0:
        print("RESULT: WARN（存在需 Reviewer 人工确认的 N/A / 未显式项，不自动阻断）")
        return 2
    else:
        print("RESULT: PASS")
        return 0


if __name__ == "__main__":
    sys.exit(main())

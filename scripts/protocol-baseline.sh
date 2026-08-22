#!/usr/bin/env bash
# protocol-baseline.sh — Agent OS Protocol 唯一 Baseline 源（机器判断单一真源）
# ===========================================================================
# P0-4：消除 protocol_version / architecture contract / baseline commit 的多处硬编码。
# 所有需要校验协议版本的脚本（protocol-compliance-check.sh / readiness / reviewer）
# 必须 source 本文件，禁止自行硬编码 v1.3 / v1.6 / ccef093。
#
# 来源：当前真实安装的 Agent OS Protocol（Core Protocol v1.3，Architecture Contract v1.6，
#       MA-1.1 冻结基线 commit ccef093），见 backup/agent-os-bak-20260820/docs/。
# 本文件是机器判断的权威来源；文档可以展示版本号，但不得作为脚本的第二真源。
#
# source 后提供：
#   AGENT_OS_PROTOCOL_VERSION   —— Core Protocol 版本（当前 "1.3"）
#   AGENT_OS_ARCH_CONTRACT      —— Architecture Contract 版本（当前 "v1.6"）
#   AGENT_OS_BASELINE_COMMIT    —— MA-1.x 冻结基线 commit（当前 "ccef093"）
#   AGENT_OS_BASELINE_LABEL     —— 人类可读基线标签（"MA-1.1"）
#
# 本文件纯声明：无副作用（source 安全），不推荐 standalone 执行。

AGENT_OS_PROTOCOL_VERSION="1.3"
AGENT_OS_ARCH_CONTRACT="v1.6"
AGENT_OS_BASELINE_COMMIT="ccef093"
AGENT_OS_BASELINE_LABEL="MA-1.1"

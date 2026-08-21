#!/usr/bin/env bash
# secret-patterns.sh — Development Team 统一 secrets 检测规则库（单一来源）
# ===================================================================
# readiness 与 Reviewer 共用此规则，禁止两处各维护一套（C1-3）。
# 用法： source "$(dirname "${BASH_SOURCE[0]}")/secret-patterns.sh"
# 提供：
#   SECRET_PATTERNS_ALL  —— 以空格分隔的「多条独立子正则」（readiness/Reviewer 用 grep -E -e 逐个测）
#   SECRET_PATTERN_COUNT —— 子正则数量
# 设计说明：不用单条带 `|` 分组的大正则（grep -E 对 `(a|b)` 分组与 `-----` 开头有解析坑），
#   改为多条独立子正则，每条用 `grep -E -e` 单独匹配，可靠且易维护/易加对抗项。
# 本文件为纯规则库：无副作用（source 安全）。

# 每条为一条独立 ERE 子正则（不含开头 ^，允许出现在行中）。全部要求足够长度以降低误报。
SECRET_PATTERNS_ALL=(
  # Stripe / 支付类（大小写+数字，修复原 [0-9a-z] 盲区）
  'sk_live_[A-Za-z0-9_]{16,}'
  'sk_test_[A-Za-z0-9_]{16,}'
  # OpenAI / Anthropic 类
  'sk-[A-Za-z0-9_-]{20,}'
  'sk-ant-[A-Za-z0-9_-]{20,}'
  # GitHub
  'ghp_[A-Za-z0-9]{20,}'
  'gho_[A-Za-z0-9]{36,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  # AWS / GCP / Azure
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  'AIza[0-9A-Za-z_-]{29,}'
  'ya29\.[A-Za-z0-9_-]{20,}'
  # Slack
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'xapp-[A-Za-z0-9-]{10,}'
  # Generic Bearer token（JWT 或长 token）
  'Bearer[[:space:]][A-Za-z0-9._~+/=-]{20,}'
  # private key 头（RSA / OPENSSH / EC / DSA / PGP）
  'BEGIN[[:space:]]+(RSA[[:space:]]+)?PRIVATE[[:space:]]+KEY'
  'BEGIN[[:space:]]+OPENSSH[[:space:]]+PRIVATE[[:space:]]+KEY'
  'BEGIN[[:space:]]+EC[[:space:]]+PRIVATE[[:space:]]+KEY'
  'BEGIN[[:space:]]+DSA[[:space:]]+PRIVATE[[:space:]]+KEY'
  'BEGIN[[:space:]]+PGP[[:space:]]+PRIVATE[[:space:]]+KEY'
  # 常见赋值式：password=/secret=/token=/api_key= 后接疑似值（避免裸词误报）
  'password[[:space:]]*[=:][[:space:]]*[A-Za-z0-9_!@#%^*+-]{6,}'
  'secret[[:space:]]*[=:][[:space:]]*[A-Za-z0-9_!@#%^*+-]{8,}'
  'api[_-]?key[[:space:]]*[=:][[:space:]]*[A-Za-z0-9_!@#%^*+-]{12,}'
  'token[[:space:]]*[=:][[:space:]]*[A-Za-z0-9_!@#%^*+-]{16,}'
  'client[_-]?secret[[:space:]]*[=:][[:space:]]*[A-Za-z0-9_!@#%^*+-]{16,}'
)

# 供调用方：把所有子正则用空格连接（方便打印/日志），但匹配必须逐条 -e
SECRET_PATTERNS_ALL_JOINED="${SECRET_PATTERNS_ALL[*]}"
SECRET_PATTERN_COUNT="${#SECRET_PATTERNS_ALL[@]}"

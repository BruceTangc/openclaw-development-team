# Implementation Plan — span_filter（跨度过滤策略）

> task_id: DT-20260821-E2E-C3
> task_type: FEATURE
> 目标仓库: dlt-simulator（真实，git 根 = _ref-tts-public）

## 1. 功能规格

### 目标
给 dlt-simulator 新增 `span_filter`（跨度过滤）策略：号码跨度（前区 max−min，后区 max−min）偏离历史均值时，压制「导致偏离」的号码，实现跨度回归。

### 语义（单号级权重，与现有策略架构一致）
- **前区（1-35，取 5）**：计算历史 window 期每期前区跨度 `max(front) − min(front)`，取均值 μ_f。
  - 理论跨度中心 = **24**（彩票经验值）
  - 若 μ_f > 24（历史号码偏分散）→ 压制「极端号」：前区 `n ≤ 10` 或 `n ≥ 26` 压到 **0.5**（让跨度收敛）
  - 若 μ_f < 24（历史号码偏集中）→ 压制「中心号」：前区 `11 ≤ n ≤ 25` 压到 **0.5**（让跨度发散）
  - 其余号码按 balanced 基础权重（1.0 + hot 1.5 + miss>15 1.0 + rising 0.5）
- **后区（1-12，取 2）**：计算历史 window 期后区跨度均值 μ_b，理论中心 = **6**。
  - 若 μ_b > 6 → 压制极端号：后区 `n ≤ 2` 或 `n ≥ 11` 压到 **0.5**
  - 若 μ_b < 6 → 压制中心号：后区 `3 ≤ n ≤ 10` 压到 **0.5**
  - 其余按 balanced（1.0 + hot 1.5）

### 边界/退化条件（客观正确解）
- `total == 0`（空数据）→ 前区/后区全 1.0（走既有空数据退化）
- `total == 1`（单期）→ 跨度只有 1 个样本，无法判断偏离 → 退化 balanced（不压制）
- window 参数：只截取统计期数范围，不影响单期/空数据判定
- 越界号码（data[0] 或历史数据含 36/0/13/0 等）→ 忽略，不参与压制，不崩溃
- 前后区独立统计

### 命名约束
- 策略名 `span_filter`，加入 `_KNOWN_STRATEGIES`
- `_compute_weights_single` 前区+后区分支各加 `elif name == "span_filter"`
- 参考 zone_filter（generator.py 第295行）的统计结构写法

## 2. Acceptance Criteria（可验证）
1. `span_filter` 加入 `_KNOWN_STRATEGIES`
2. 前区：μ_f > 24 时 n≤10 或 n≥26 权重==0.5，其余==balanced；μ_f < 24 时 11≤n≤25 权重==0.5，其余==balanced
3. 后区：μ_b > 6 时 n≤2 或 n≥11==0.5；μ_b < 6 时 3≤n≤10==0.5
4. 空数据→全 1.0
5. 单期→退化 balanced（不压制）
6. `span_filter+hot` 组合正常
7. 新增 test_span_filter.py 覆盖上述场景全 PASS
8. SKILL.md 策略表补 span_filter 条目
9. 全量测试无回归

## 3. Repository Constraints
只改/新增：generator.py、test_span_filter.py（新增）、SKILL.md
**绝对不碰**：history_cache.json（用户 M）、DEVELOPMENT_RESULT_E2E2.md、TASK_CONTRACT_DT-20260821-001/002.md（untracked）

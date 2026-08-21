# Implementation Plan — repeat_filter（重号过滤策略）

> task_id: DT-20260821-E2E-C2
> task_type: FEATURE
> 目标仓库: dlt-simulator（真实，git 根 = _ref-tts-public）

## 1. 功能规格（IDEAL 已由 Main Agent 归纳，无产品方向歧义）

### 目标
给 dlt-simulator 新增 `repeat_filter` 策略：压制「上期（最近一期）已开出的号码」的权重，体现彩票「重号概率低」的统计规律。

### 语义（单号级权重，与现有策略架构一致）
- **前区（1-35，取 5）**：
  - 上期开出的号码（在 `data[0]["front"]` 中）→ 权重压到 **0.5**（压制重号）
  - 未开出的号码 → balanced 基础权重（1.0 + hot 加成 1.5 + miss>15 加成 1.0 + rising 加成 0.5）
- **后区（1-12，取 2）**：
  - 上期开出的号码（在 `data[0]["back"]` 中）→ 权重压到 **0.5**
  - 未开出的号码 → balanced 基础权重

### 边界/退化条件
- `total == 0`（空数据）：全 1.0（走 `_compute_weights_single` 已有的空数据退化）
- `total >= 1`：`data[0]` 即最近一期，作为「上期」压制。只要有一期历史就压制，语义简洁。
- window 参数：`data = draws[:window] if window else draws`，`data[0]` 仍是最近一期，不受 window 影响（window 只截取统计期数范围）。
- 前后区独立统计（与 existing 策略一致）。

### 命名约束
- 策略名：`repeat_filter`（符合现有 even_filter / prime_filter / tail_filter / zone_filter 命名习惯）
- 加入 `_KNOWN_STRATEGIES`
- `_compute_weights_single` 前区分支 + 后区分支各加 `elif name == "repeat_filter"`

## 2. Acceptance Criteria（可验证）

1. `repeat_filter` 加入 `_KNOWN_STRATEGIES`
2. `compute_weights(draws, "repeat_filter")` 返回 `(front_w, back_w)`，两者都是 dict
3. 前区：上期开出的号码权重 == 0.5；未开出的号码权重 == 与 balanced 策略相同的值
4. 后区：上期开出的号码权重 == 0.5；未开出的 == balanced 同值
5. 空数据（total==0）→ 前区/后区全 1.0
6. 单期数据（total==1）→ 上期号码（即唯一那期）压到 0.5，其余 balanced
7. 多策略组合 `repeat_filter+hot` 正常（product 融合，不报错）
8. 新增测试文件 `test_repeat_filter.py` 覆盖上述场景，全部 PASS
9. SKILL.md 策略表补 `repeat_filter` 条目
10. 全量测试（含既有 71 个）无回归

## 3. Repository Constraints（必须遵守，CASE 9 保护）

只改/新增以下 3 个文件：
- `dlt-simulator/scripts/generator.py`（加 repeat_filter 前区+后区分支）
- `dlt-simulator/scripts/test_repeat_filter.py`（新增）
- `dlt-simulator/SKILL.md`（策略表补条目）

**绝对不碰（用户已有未提交修改，禁止覆盖）**：
- `dlt-simulator/data/history_cache.json`（用户已修改 M）
- `dlt-simulator/DEVELOPMENT_RESULT_E2E2.md`（untracked）
- `dlt-simulator/TASK_CONTRACT_DT-20260821-001.md`（untracked）
- `dlt-simulator/TASK_CONTRACT_DT-20260821-002.md`（untracked）

git commit 只 add 上述 3 个文件，禁止 `git add -A` / `git add .`

## 4. 工作流（TDD，同时作为 CASE 4 证据）

1. 先写测试 `test_repeat_filter.py`（TDD 测试先行）
2. 跑测试 → 记录「红」（功能未实现，测试失败）
3. 实现 `repeat_filter` 策略
4. 跑测试 → 「绿」（通过）
5. 跑全量测试确认无回归
6. feature branch 上 commit

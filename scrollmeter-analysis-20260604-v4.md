# Scroll Smoothness Analysis — 2026-06-04 (v4)
# 触控板滚动流畅度分析报告 — 2026-06-04（第四版）

**设备 / Device:** MacBook Pro 14-inch M3
**外接显示器 / External monitor:** ASUS PG27 4K @ 60 Hz
**Hub / 扩展坞:** HBP USB-C Hub（双 HDMI 4K 输出 / Dual HDMI 4K output）
**工具 / Tool:** ScrollMeter v1.4
**测试应用 / Test apps:** Chrome、Safari

> **v4 改动 / Changelog**
> 1. 修正 ⑦ DisplayLink Chrome OFF 的输入延迟均值：9.15 → **8.61 ms**（原数据从 ⑥ 误复制）
> 2. Hitch Ratio 阈值改用 Apple Tech Talk 10855 原文：< 5 smooth / 5-10 noticeable / **> 10 severe**（原"10 = 肉眼可感"措辞偏弱）
> 3. ⑤ Safari DisplayLink 评级保持"临界"但拆解：Hitch 2.56 = ✅ Apple smooth；FPS 56.9 = ⚠️ 跑不满 60Hz，是 FPS 拖低了综合评级，hitch 本身合格
> 4. **测试条件澄清**：A/B/C 三组都不是空闲基准，**都有 3 块活跃显示器**，唯一变量是"滚动渲染目标是否走 DisplayLink"：
>    - **A**：内置屏 120Hz 上滚动（触控板）+ **2 路 DisplayLink** 副屏（YouTube + 表格）→ 0 hitch
>    - **B**：内置屏活跃 + 内置 HDMI → ASUS PG27 上滚动（触控板）+ **1 路 DisplayLink** YouTube → 0 hitch
>    - **C**：内置屏活跃 + **DisplayLink → ASUS PG27 上滚动**（触控板）+ 第二路 DisplayLink YouTube → 10–12 ms/s
>
>    **两组干净对照同时成立 / Two clean counterfactuals:**
>    - **A vs C**：DisplayLink 总流数相同（各 2 路），唯一区别是滚动目标是否在 DisplayLink 路径 → 排除"DisplayLink 负载量本身有罪"
>    - **B vs C**：滚动目标是**同一台物理 ASUS PG27**，唯一区别是 cable 走内置 HDMI 还是 DisplayLink → 排除"显示器本身有问题"
>
>    两条互补对照同时把元凶锁定在**滚动渲染目标的传输路径走 DisplayLink** 这一动作上。<br>
>    *Test conditions clarified: All three groups had **3 active displays** and were NOT idle baselines. The only variable was whether the scroll rendering target was routed through DisplayLink.*
>    *- A: scroll on built-in 120Hz + **2× DisplayLink** (YouTube + spreadsheet) → 0 hitch*
>    *- B: built-in screen active + scroll on ASUS PG27 via built-in HDMI + **1× DisplayLink** YouTube → 0 hitch*
>    *- C: built-in screen active + scroll on ASUS PG27 via **DisplayLink** + second DisplayLink YouTube → 10–12 ms/s jank*
>
>    *Two complementary counterfactuals:*
>    *- A vs C: same DisplayLink total (2 streams), only the scroll-target transport differs → rules out "DisplayLink background load is to blame"*
>    *- B vs C: same physical ASUS PG27 as scroll target, only the cable path differs (built-in HDMI vs DisplayLink) → rules out "the monitor itself is at fault"*
>
>    *Together they pin the cause on **routing the scroll rendering through DisplayLink**, nothing else.*

---

## 🎬 测试环境负载 / Sustained Background Workload (A/B/C groups)

A/B/C 三组都不是空闲基准，**每组都有 3 块活跃显示器**。差异只在两件事：**滚动渲染目标是哪台屏**、以及那台屏**用什么 cable 接出去**。
All three trackpad groups (A/B/C) had **3 active displays each**; what differs is which display is the scroll target and how it's connected.

| Group | 屏 1 (Display 1) | 屏 2 (Display 2) | 屏 3 (Display 3) | DisplayLink<br>流数 |
|---|---|---|---|:---:|
| **A** | **内置屏 120Hz · 触控板滚动**<br>Built-in · trackpad scroll | DisplayLink → 4K 60Hz · YouTube 全屏 | DisplayLink → 4K 60Hz · 表格全屏<br>Spreadsheet fullscreen | **2** |
| **B** | 内置屏 · 活跃但非滚动目标<br>Built-in · active, not scroll target | **内置 HDMI → ASUS PG27 · 触控板滚动**<br>Built-in HDMI → ASUS PG27 · trackpad scroll | DisplayLink → 4K 60Hz · YouTube 全屏 | **1** |
| **C** | 内置屏 · 活跃但非滚动目标<br>Built-in · active, not scroll target | **DisplayLink → ASUS PG27 · 触控板滚动**<br>DisplayLink → ASUS PG27 · trackpad scroll | DisplayLink → 4K 60Hz · YouTube 全屏 | **2**<br>（含滚动目标 incl. scroll）|

---

### 两组互补的干净对照 / Two Complementary Clean Counterfactuals

**① A vs C —— 排除"DisplayLink 后台负载量有罪" / Rules out background-load hypothesis**

A 和 C 都有 **2 路 DisplayLink 同时在 USB 上软编码**，CPU 烧得一样多。
唯一区别：A 的滚动跑在原生内置屏；C 的滚动跑在 DisplayLink 路径上。
结果：A 0 hitch，C 10–12 ms/s。
→ 不是 DisplayLink 流数的问题。

A and C both run **2 concurrent DisplayLink software encoders** (identical CPU encoding burden). The only difference is whether the scroll target is on the built-in screen (A) or on DisplayLink (C). A → 0 hitch, C → 10–12 ms/s. Rules out "more DisplayLink connections cause jank".

**② B vs C —— 排除"显示器本身有问题" / Rules out monitor hypothesis**

B 和 C **滚动目标是同一台物理 ASUS PG27 4K60**，相同的内容、相同的触控板、相同活跃的 3 块屏。
唯一区别：cable 路径——B 走 MBP 内置 HDMI（硬件视频引擎），C 走 DisplayLink（USB 软编码）。
结果：B 0 hitch，C 10–12 ms/s。
→ 不是 ASUS 这台屏的问题，是 cable 路径的问题。

B and C scroll on **the same physical ASUS PG27 4K60** with the same content, same trackpad, same 3 active displays. Only the cable path differs — built-in HDMI (hardware video engine) for B, DisplayLink (USB software encoder) for C. B → 0 hitch, C → 10–12 ms/s. Rules out "the monitor is at fault" — it's the cable path.

---

**两条对照同时成立，把所有干扰因素都剥干净，只剩一个变量：**
**滚动渲染目标的传输路径是否经过 DisplayLink。**

**Both counterfactuals hold simultaneously, stripping away every confound. Only one variable remains:**
**whether the scroll rendering target's transport path goes through DisplayLink.**

---

## ⚠️ 重要测试条件说明 / Critical Test Condition Note

> **D 组（HBP Hub 双 HDMI）使用了不同的输入设备！**
> MBP 驱动两台外接 4K 显示器时需合上盖子（Clamshell 模式），触控板不可用，**实际使用的是外接鼠标滚轮**，而非 MBP 触控板。
>
> **Group D (HBP Hub Dual HDMI) used a different input device!**
> Driving two external 4K displays requires closing the MBP lid (Clamshell mode), making the built-in trackpad unavailable. **An external mouse scroll wheel was used instead.**

| 指标 Metric | 触控板 Trackpad（A/B/C 组）| 外接鼠标 Mouse wheel（D 组）|
|---|---|---|
| 事件/秒 Events/s | 53–111 /s | 15–18 /s |
| 总滚动量 Scrolled | 19,000–29,000 pt | 706–1,083 pt |
| Delta 特性 | 连续模拟值 + 惯性 Continuous + momentum | 离散固定步进 Discrete fixed steps |
| CV 天然本底 | 0.49–0.84 | 0.78–0.88（步进特性导致，非渲染问题）|

**结论：D 组的 CV 和输入延迟数据与 A/B/C 组不可横向比较。**
**帧交付质量指标（Hitch ratio、FPS、std dev）不受输入设备影响，仍然有效。**

> **Conclusion: CV and input latency from Group D cannot be compared with Groups A/B/C.**
> **Frame delivery metrics (Hitch ratio, FPS, std dev) are unaffected by input device and remain valid.**

---

## 📐 Apple Hitch Ratio 阈值参考 / Apple Hitch Ratio Thresholds

来源 / Source: Apple WWDC Tech Talk **10855** — *Explore UI animation hitches and the render loop*

| 范围 Range | Apple 原话 / Apple's wording | 中文 |
|---|---|---|
| **< 5 ms/s** | good, mostly unnoticeable | 流畅，用户大多察觉不到 |
| **5–10 ms/s** | user will notice some interruptions | 用户会注意到中断，建议排查 |
| **> 10 ms/s** | **greatly impacting** the user experience | 严重影响体验，立即优化 |

> 📌 5 ms/s 是"开始能察觉"的下限；10 ms/s 是"严重影响"的下限。
> 旧版把 10 ms/s 描述为"肉眼可感阈值"措辞偏弱——更准确的说法是"严重影响阈值"。

---

## 一、完整测试数据 / Full Test Results (10 configurations)

| # | 接法 Connection | 输入设备 Input | 应用 App | GPU | 实测FPS | Hitch ratio | CV | 输入延迟 | 评级 |
|---|---|---|---|---|---|---|---|---|---|
| ① | 内置屏 120Hz | 触控板 Trackpad | Chrome | ON  | **120.0** | **0.00** ms/s | 0.64 | 4.42 ms | ✅ 流畅 |
| ② | 内置屏 120Hz | 触控板 Trackpad | Chrome | OFF | **120.0** | **0.00** ms/s | 0.49 | 4.49 ms | ✅ 流畅 |
| ③ | 内置HDMI → ASUS PG27 | 触控板 Trackpad | Chrome | OFF | **60.0** | **0.00** ms/s | 0.61 | 7.92 ms | ✅ 流畅 |
| ④ | 内置HDMI → ASUS PG27 | 触控板 Trackpad | Chrome | ON  | **60.0** | **0.00** ms/s | 0.66 | 6.17 ms | ✅ 流畅 |
| ⑤ | DisplayLink → ASUS PG27 | 触控板 Trackpad | Safari | — | 56.9 | **2.56** ms/s ✅ | 0.63 | 8.08 ms | ⚠️ FPS 偏低 |
| ⑥ | DisplayLink → ASUS PG27 | 触控板 Trackpad | Chrome | ON  | 53.9 | **10.09** ms/s | 0.84 | 9.15 ms | ❌ 卡顿 |
| ⑦ | DisplayLink → ASUS PG27 | 触控板 Trackpad | Chrome | OFF | 59.0 | **12.47** ms/s | 0.74 | **8.61** ms 🆕 | ❌ 卡顿 |
| ⑧ | **HBP Hub 双HDMI** ★ | **外接鼠标 Mouse** | Chrome | ON  | **60.0** | **0.00** ms/s | 0.78 ※ | 7.77 ms ※ | ✅ 帧流畅 |
| ⑨ | **HBP Hub 双HDMI** ★ | **外接鼠标 Mouse** | Chrome | OFF | **60.0** | **0.00** ms/s | 0.81 ※ | 8.84 ms ※ | ✅ 帧流畅 |
| ⑩ | **HBP Hub 双HDMI** ★ | **外接鼠标 Mouse** | Safari | —   | **60.0** | **0.00** ms/s | 0.88 ※ | 7.63 ms ※ | ✅ 帧流畅 |

> ★ MBP 合盖 Clamshell 模式，外接鼠标滚轮输入
> ※ 与触控板测试不可横向比较 / Not comparable with trackpad tests
> 🆕 v4 修正 / fixed in v4

**⑤ Safari DisplayLink 评级拆解 / Breakdown:**
- Hitch ratio 2.56 ms/s — ✅ 在 Apple "smooth" 区间内（< 5）
- 实测 FPS 56.9 / 60 — ⚠️ 跑不满刷新率，帧间隔有抖动（std dev 1.60 ms）
- 综合"⚠️ FPS 偏低"是因为 **FPS 拖低**，不是 hitch 不合格

---

## 二、可对比指标汇总 / Comparable Metrics Summary

### 帧交付质量（各组均有效 / Valid across all groups）

| 接法 | 实测FPS | Hitch ratio | 帧间隔std dev | 综合评级 |
|---|---|---|---|---|
| 内置屏 120Hz（①②） | **120.0** | **0.00 ms/s** | 0.36–0.42 ms | ✅ 完美 |
| 内置HDMI 60Hz（③④） | **60.0** | **0.00 ms/s** | 0.33–0.35 ms | ✅ 完美 |
| HBP Hub 双HDMI 60Hz（⑧⑨⑩） | **60.0** | **0.00 ms/s** | 0.35–0.45 ms | ✅ 完美 |
| DisplayLink Safari（⑤） | 56.9 | 2.56 ms/s ✅ | 1.60 ms | ⚠️ Hitch 合格，FPS 偏低 |
| DisplayLink Chrome ON（⑥） | 53.9 | **10.09 ms/s** | 2.20 ms | ❌ 严重影响 (>10) |
| DisplayLink Chrome OFF（⑦） | 59.0 | **12.47 ms/s** | 3.42 ms | ❌ 严重影响 (>10) |

### 触控板滚动视觉流畅度（仅 A/B/C 组有效 / Trackpad groups only）

| 接法 | CV | 输入延迟均值 | 评级 |
|---|---|---|---|
| 内置屏 Chrome OFF（②） | **0.49** | 4.49 ms | ✅ 优秀 Good |
| 内置屏 Chrome ON（①） | 0.64 | 4.42 ms | ✅ 良好 |
| 内置HDMI Chrome OFF（③） | 0.61 | 7.92 ms | ✅ 良好 |
| 内置HDMI Chrome ON（④） | 0.66 | 6.17 ms | ✅ 良好 |
| DisplayLink Safari（⑤） | 0.63 | 8.08 ms | ✅ 良好 |
| DisplayLink Chrome OFF（⑦） | 0.74 | **8.61 ms** 🆕 | ⚠️ 轻微抖动 |
| DisplayLink Chrome ON（⑥） | 0.84 | 9.15 ms | ❌ 不均匀 |

---

## 三、Hitch Ratio 对比（所有组）/ Hitch Ratio Comparison

```
①  MBP 本屏 Chrome ON        ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
②  MBP 本屏 Chrome OFF       ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
③  内置HDMI Chrome OFF       ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
④  内置HDMI Chrome ON        ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
⑧  HBP双HDMI Chrome ON ★    ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
⑨  HBP双HDMI Chrome OFF ★   ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
⑩  HBP双HDMI Safari ★       ░░░░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
⑤  DisplayLink Safari        ████░░░░░░░░░░░░░░░░░  2.56 ms/s  ✅ (Apple smooth)
⑥  DisplayLink Chrome ON     ████████████████░░░░░  10.09 ms/s ❌
⑦  DisplayLink Chrome OFF    ████████████████████░  12.47 ms/s ❌
                              0       5       10       15  ms/s
                                      │        │
                                      │        └─ Apple "severely impacting" 阈值
                                      └────────── Apple "noticeable" 阈值

★ = Clamshell 合盖，外接鼠标（帧指标有效，CV/延迟不与触控板组比较）
```

---

## 四、核心发现 / Key Findings

### ✅ 发现 1：HBP Hub 双 HDMI 帧交付质量完美
### ✅ Finding 1: HBP Hub Dual HDMI Delivers Perfect Frames

**中文：** HBP Hub 同时驱动两台 4K 60Hz 显示器，Hitch ratio = 0，精确 60.0 fps，帧间隔 std dev 0.35–0.45 ms。帧交付质量与内置 HDMI 完全相当。HBP Hub 走的是 Thunderbolt 硬件视频桥接，不是 DisplayLink，因此没有 USB 软编码的性能损失。

**English:** The HBP Hub drives two 4K 60 Hz displays with zero hitches, steady 60.0 fps, and frame interval std dev of only 0.35–0.45 ms — identical to built-in HDMI quality. HBP Hub uses Thunderbolt hardware video bridging (not DisplayLink), so there is no USB software encoding overhead.

---

### ⚠️ 发现 2：D 组无法评估触控板流畅度
### ⚠️ Finding 2: Group D Cannot Assess Trackpad Scroll Smoothness

**中文：** Clamshell 合盖模式下触控板无法使用，D 组实际测量的是**外接鼠标滚轮**的行为。鼠标滚轮产生的是离散步进事件（15–18/s），而触控板产生连续模拟事件（54–111/s）——两者的 CV、stuck frames、输入延迟特征完全不同，不可混合比较。

**若需评估 HBP Hub 双屏接法下的触控板流畅度，需要：**
- 保持盖子打开（MBP M3 支持最多 3 个外接显示器 + 内置屏）
- 或额外连接外接触控板（Magic Trackpad）

**English:** In Clamshell mode the built-in trackpad is unavailable; Group D actually measured an **external mouse scroll wheel**. A mouse wheel produces discrete step events (15–18/s); a trackpad produces continuous analog events (54–111/s). Their CV, stuck-frame, and latency profiles are fundamentally incomparable.

**To assess trackpad scroll smoothness with HBP Hub dual monitors, options are:**
- Keep the lid open (MBP M3 supports up to 3 external + built-in displays)
- Or connect an external Magic Trackpad

---

### 🔴 发现 3：DisplayLink 是唯一卡顿来源
### 🔴 Finding 3: DisplayLink Is the Sole Source of Jank

同一台 MBP 同一台显示器：内置 HDMI → 0 卡顿；DisplayLink → 10–12 ms/s 卡顿（**Apple 标准"严重影响"区间**）。HBP Hub 双屏 → 0 卡顿。唯一变量是传输路径，硬件视频输出均无问题，DisplayLink 的 USB 软编码是唯一瓶颈。

**两条互补的反事实对照（详见"测试环境负载"章节）**：
- **A vs C** 控制 DisplayLink 流数（各 2 路）→ 排除负载量本身有罪
- **B vs C** 控制滚动目标显示器（同一台 ASUS PG27）→ 排除显示器本身有问题

唯一剩下的变量是"滚动渲染目标的传输路径走 DisplayLink"。其他所有干扰因素被这两组对照剥干净。

Same MBP, same monitor: built-in HDMI → zero hitches; DisplayLink → 10–12 ms/s (Apple's "**severely impacting**" range). HBP Hub dual → zero hitches. The only variable is the transport path; hardware video output works perfectly. DisplayLink's USB software encoding is the sole bottleneck.

**Two complementary counterfactuals (see "Sustained Background Workload" section):**
- **A vs C** controls for DisplayLink stream count (2 each) → rules out background load
- **B vs C** controls for the scroll-target monitor (same physical ASUS PG27) → rules out monitor

The only variable left is **routing the scroll rendering target through DisplayLink**. Every other confound is stripped away by these two parallel comparisons.

---

### 🟡 发现 4：Safari vs Chrome 差异只在 DisplayLink 下有意义
### 🟡 Finding 4: Browser Difference Only Matters on DisplayLink

硬件视频输出接法（内置 HDMI、HBP Hub）下，Safari 和 Chrome 的 Hitch 均为 0，选浏览器无影响。只有 DisplayLink 接法才需优先选 Safari（**Hitch 2.56 ms/s 仍在 Apple "smooth" 区间**；Chrome 10–12 ms/s 已"严重影响"）。

DisplayLink + Chrome 关闭 GPU 反而更差（12.47 vs 10.09 ms/s）：CPU 渲染与 USB 软编码同时抢 CPU，资源竞争加剧。在 DisplayLink 环境下，Chrome GPU 加速应**保持开启**。

---

## 五、数据完整性总结 / Data Validity Summary

| 指标 | A组（本屏）| B组（内置HDMI）| C组（DisplayLink）| D组（HBP Hub）|
|---|---|---|---|---|
| 输入设备 | 触控板 | 触控板 | 触控板 | **外接鼠标** |
| Hitch ratio ✓ | ✅ 有效 | ✅ 有效 | ✅ 有效 | ✅ 有效 |
| 实测 FPS ✓ | ✅ 有效 | ✅ 有效 | ✅ 有效 | ✅ 有效 |
| CV（视觉均匀度）| ✅ 有效 | ✅ 有效 | ✅ 有效 | ❌ 不可比（鼠标步进）|
| 输入延迟 | ✅ 触控板延迟 | ✅ 触控板延迟 | ✅ 触控板延迟 | ⚠️ 鼠标延迟（不同设备）|

---

## 六、待补测项 / Pending Re-tests

- [ ] **HBP Hub 双屏 + 触控板**：打开盖子（3屏模式）或接 Magic Trackpad，重测 CV 和输入延迟，获取真正可对比的视觉流畅度数据
      Re-test HBP Hub dual-monitor with trackpad input (lid open = 3-display mode, or external Magic Trackpad) to get comparable CV and latency data
- [ ] **DisplayLink + 更多应用**：确认 Safari 的流畅优势是否在所有场景均成立

---

## 七、接口方案结论 / Connection Method Conclusions

```
接口优先级（帧交付质量 / Frame delivery quality）：

内置屏 120Hz = 内置HDMI = HBP Hub双HDMI  >>>  DisplayLink+Safari  >  DisplayLink+Chrome
    （三者 Hitch = 0，FPS 稳定）        （Hitch ✅ 但 FPS 偏低）  （Hitch >10 严重影响）

注：HBP Hub 的触控板视觉流畅度待补测
Note: HBP Hub trackpad visual smoothness pending re-test
```

### 建议 / Recommendations

| 场景 Scenario | 建议 Recommendation |
|---|---|
| 需要双 4K 扩展屏 Dual 4K displays | ✅ **HBP Hub 双 HDMI**，帧交付完美；触控板体验待验证 |
| 单 4K 扩展屏 Single 4K | ✅ **MBP 内置 HDMI**，最简可靠 |
| 必须用 DisplayLink | ⚠️ 改用 **Safari**，GPU 保持开启 |
| 评估 HBP Hub 触控板体验 | 📋 待补测：打开盖子接3屏 或 接 Magic Trackpad |

---

## 八、技术背景 / Technical Background

```
各接法传输路径 / Transport path by connection method:

内置屏：
MBP GPU → [内置显示控制器] → 屏幕  (零延迟，120Hz)

内置 HDMI / HBP Hub HDMI（硬件视频引擎）：
MBP GPU → [Thunderbolt 硬件视频引擎] → HDMI → 显示器  (稳定，60Hz，不占CPU)

DisplayLink（USB 软编码，问题根源）：
MBP GPU → 截帧 → [CPU/GPU 软编码] → USB → 解码 → 显示器
          每帧走软件链路，受CPU负载影响，Chrome冲突最严重

输入设备对比 / Input device comparison:
触控板 Trackpad：连续模拟信号，53–111 events/s，有惯性动量
外接鼠标 Mouse：离散步进信号，15–18 events/s，无惯性
→ 两者的 CV 和 stuck frames 天然不可比
```

---

*Generated by ScrollMeter v1.4 — 2026-06-04 (v4, 10 tests)*
*v4 更新：修正 ⑦ 延迟数据；Hitch 阈值用 Apple Tech Talk 10855 原文标注；⑤ 评级拆解 Hitch / FPS*
*v4 update: Fixed row ⑦ latency; Apple Tech Talk 10855 thresholds; row ⑤ rating breakdown*

参考 / Reference:
- [Apple Tech Talk 10855 — Explore UI animation hitches and the render loop](https://developer.apple.com/videos/play/tech-talks/10855/)
- [Understanding hitches in your app — Apple Developer Documentation](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)

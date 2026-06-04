# Scroll Smoothness Analysis — 2026-06-04
# 触控板滚动流畅度分析报告 — 2026-06-04

**设备 / Device:** MacBook Pro 14-inch M3  
**外接显示器 / External monitor:** ASUS PG27 4K @ 60 Hz  
**工具 / Tool:** ScrollMeter v1.4  
**测试应用 / Test app:** Chrome、Safari（在 ASUS PG27 上滚动长页面 / scrolling long pages on ASUS PG27）

---

## 一、测试数据汇总 / Test Results Summary

| # | 场景 Scenario | 显示器 Display | 接口 Connection | 应用 App | Chrome GPU | 实测帧率 Actual FPS | Hitch 比率 Hitch Ratio | CV | 输入延迟均值 Latency Mean | 综合评级 Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| ① | MBP 本屏 Internal | 120 Hz | 内置 Built-in | Chrome | ON  | **120.0** | **0.00 ms/s** | 0.64 | 4.42 ms | ✅ 流畅 Smooth |
| ② | MBP 本屏 Internal | 120 Hz | 内置 Built-in | Chrome | OFF | **120.0** | **0.00 ms/s** | 0.49 | 4.49 ms | ✅ 流畅 Smooth |
| ③ | ASUS PG27 4K60 | 60 Hz | **内置 HDMI Built-in HDMI** | Chrome | OFF | **60.0** | **0.00 ms/s** | 0.61 | 7.92 ms | ✅ 流畅 Smooth |
| ④ | ASUS PG27 4K60 | 60 Hz | **内置 HDMI Built-in HDMI** | Chrome | ON  | **60.0** | **0.00 ms/s** | 0.66 | 6.17 ms | ✅ 流畅 Smooth |
| ⑤ | ASUS PG27 4K60 | 60 Hz | **DisplayLink** | Safari | —  | 56.9 | 2.56 ms/s | 0.63 | 8.08 ms | ⚠️ 临界 Borderline |
| ⑥ | ASUS PG27 4K60 | 60 Hz | **DisplayLink** | Chrome | ON  | 53.9 | **10.09 ms/s** | 0.84 | 9.15 ms | ❌ 卡顿 Jank |
| ⑦ | ASUS PG27 4K60 | 60 Hz | **DisplayLink** | Chrome | OFF | 59.0 | **12.47 ms/s** | 0.74 | 9.15 ms | ❌ 卡顿 Jank |

> **指标说明 / Metric reference**  
> - **Hitch ratio**：每秒卡顿毫秒数，苹果标准：< 5 流畅 / 5–10 临界 / > 10 肉眼可感知  
>   Milliseconds of dropped frames per second of scroll. Apple standard: <5 smooth / 5–10 borderline / >10 felt by users  
> - **CV（变异系数）**：每帧移动均匀度，< 0.3 优秀 / 0.3–0.5 良好 / 0.5–0.7 轻微抖动 / > 0.7 明显卡顿  
>   Per-frame movement uniformity. <0.3 excellent / 0.3–0.5 good / 0.5–0.7 noticeable jitter / >0.7 choppy  
> - **输入延迟 / Input latency**：触控板事件到下一帧的时间差，< 1 帧预算为优秀  
>   Time from touchpad event to next display frame. <1 frame budget = excellent

---

## 二、核心发现 / Key Findings

### 🔴 发现 1：DisplayLink 是卡顿根本原因
### 🔴 Finding 1: DisplayLink Is the Root Cause of Jank

**中文：**  
DisplayLink 并非硬件视频输出，而是将画面通过 USB 软件编码传输：CPU/GPU 编码 → USB 传输 → 接收器解码。这条链路导致：
- 实际帧率仅 53.9–59 fps（标称 60Hz 跑不满）
- Hitch ratio 高达 10–12 ms/s，超过苹果"肉眼可感知"阈值
- CV 达到 choppy 级别（0.74–0.84），帧间内容移动量极不均匀

**English:**  
DisplayLink is not hardware video output. It compresses and transmits the framebuffer over USB: CPU/GPU encode → USB transfer → receiver decode. This pipeline causes:
- Actual frame rate drops to 53.9–59 fps (below the rated 60 Hz)
- Hitch ratio reaches 10–12 ms/s, exceeding Apple's "user-perceptible" threshold of 10 ms/s
- CV reaches "choppy" level (0.74–0.84), meaning per-frame content movement is highly irregular

---

### ✅ 发现 2：内置 HDMI 接法完全正常
### ✅ Finding 2: Built-in HDMI Connection Is Fully Normal

**中文：**  
同一台 MBP、同一台显示器，换用内置 HDMI 口后，帧率精确 60.0 fps，零卡顿（Hitch ratio = 0），Chrome GPU 开关对结果几乎无影响。说明问题完全出在 DisplayLink 传输层，与显示器本身无关。

**English:**  
Using the same MBP and monitor but switching to the built-in HDMI port, the frame rate is a steady 60.0 fps with zero hitches. Chrome GPU acceleration makes no meaningful difference. This confirms the problem is entirely within the DisplayLink transport layer, not the monitor itself.

---

### 🟡 发现 3：Safari 在 DisplayLink 上明显优于 Chrome
### 🟡 Finding 3: Safari Is Significantly Smoother Than Chrome on DisplayLink

**中文：**  
| 浏览器 | Hitch ratio | 实测帧率 | CV |
|---|---|---|---|
| Safari（DisplayLink） | **2.56 ms/s** ✅ | 56.9 fps | 0.63 |
| Chrome GPU ON（DisplayLink） | 10.09 ms/s ❌ | 53.9 fps | 0.84 |
| Chrome GPU OFF（DisplayLink） | 12.47 ms/s ❌ | 59.0 fps | 0.74 |

Safari 使用 Metal / Core Animation 直接与 macOS 显示管线整合，对 DisplayLink 引入的额外延迟有更好的容忍性。Chrome 采用自有 Chromium Viz 合成器，与 DisplayLink 配合更差。

**English:**  
Safari uses Metal / Core Animation, deeply integrated with the macOS display pipeline, and tolerates the extra latency introduced by DisplayLink much better. Chrome uses the Chromium Viz compositor, an independent rendering pipeline that conflicts more severely with DisplayLink's overhead.

---

### 🟡 发现 4：Chrome 关闭 GPU 加速在 DisplayLink 下反而更差
### 🟡 Finding 4: Disabling Chrome GPU Acceleration Makes Things Worse on DisplayLink

**中文：**  
关闭 GPU 加速后 Hitch ratio 从 10.09 升至 12.47 ms/s。原因：软件渲染（CPU rasterization）与 DisplayLink 的 USB 编码同时抢占 CPU 资源，竞争加剧，反而更卡。在 DisplayLink 环境下，Chrome GPU 加速应**保持开启**。

**English:**  
Disabling GPU acceleration raises the hitch ratio from 10.09 to 12.47 ms/s. Software rendering (CPU rasterization) competes with DisplayLink's USB encoding for CPU time, worsening the contention. On a DisplayLink setup, Chrome GPU acceleration should remain **enabled**.

---

## 三、数据对比图 / Visual Comparison

### Hitch Ratio 对比（越低越好 / Lower is better）

```
MBP 本屏 Chrome GPU ON    ████░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
MBP 本屏 Chrome GPU OFF   ████░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
HDMI Chrome GPU OFF       ████░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
HDMI Chrome GPU ON        ████░░░░░░░░░░░░░░░░░░  0.00 ms/s  ✅
DisplayLink Safari        ██████░░░░░░░░░░░░░░░░  2.56 ms/s  ⚠️
DisplayLink Chrome ON     ██████████████████░░░░  10.09 ms/s ❌
DisplayLink Chrome OFF    ██████████████████████  12.47 ms/s ❌
                          0    2    5    8    10   12
                                        ↑ 肉眼感知阈值 Perceptible threshold
```

### 输入延迟对比 / Input Latency Comparison（越低越好 / Lower is better）

```
MBP 本屏 Chrome GPU ON    ████░░░░░░  4.42 ms  ✅
MBP 本屏 Chrome GPU OFF   ████░░░░░░  4.49 ms  ✅
HDMI Chrome GPU ON        ██████░░░░  6.17 ms  ✅
HDMI Chrome GPU OFF       ███████░░░  7.92 ms  ✅
DisplayLink Safari        ████████░░  8.08 ms  ✅
DisplayLink Chrome OFF    █████████░  8.61 ms  ✅
DisplayLink Chrome ON     █████████░  9.15 ms  ✅
                          0    5    10   (ms)  | 帧预算 Frame budget: 16.67ms
```

---

## 四、结论与建议 / Conclusions & Recommendations

### 接口优先级 / Connection Priority

```
内置屏幕 (120Hz) > 内置 HDMI (60Hz) > Thunderbolt Dock > DisplayLink
Built-in display   Built-in HDMI      Thunderbolt Dock   DisplayLink (avoid)
```

### 具体建议 / Specific Recommendations

| 场景 Scenario | 建议 Recommendation |
|---|---|
| 需要流畅外接 4K 屏 Need smooth 4K external display | 使用 MBP **内置 HDMI** 口，完全绕过 DisplayLink / Use MBP's **built-in HDMI** port — bypasses DisplayLink entirely |
| 必须使用 DisplayLink Must use DisplayLink | 改用 **Safari**，Hitch ratio 降至 2.56 ms/s（vs Chrome 的 10+）/ Switch to **Safari**; hitch ratio drops to 2.56 ms/s vs 10+ with Chrome |
| Chrome + DisplayLink Chrome with DisplayLink | **保持 GPU 加速开启**，关闭反而更差 / Keep GPU acceleration **enabled**; disabling it makes things worse |
| 多屏扩展 Multi-monitor expansion | 优先选 Thunderbolt Dock（硬件视频输出），避免 DisplayLink / Prefer Thunderbolt Dock (hardware video output); avoid DisplayLink |
| MBP 本屏使用 Using MBP internal display | 120Hz 完美，Chrome GPU 开关无影响 / 120 Hz is perfect; Chrome GPU setting makes no difference |

---

## 五、技术背景 / Technical Background

**为什么 DisplayLink 会卡 / Why DisplayLink Causes Jank:**

```
硬件 HDMI / Thunderbolt:
MBP GPU → [硬件视频引擎] → 信号输出 → 显示器
         ↑ 固定延迟，不占 CPU，帧率保证
         Hardware-fixed latency, no CPU usage, guaranteed frame rate

DisplayLink:
MBP GPU → 系统截帧 → CPU/GPU 软编码 → USB 传输 → 接收器解码 → 显示器
          ↑ 每帧都要走这条链路，受 CPU 负载、USB 带宽影响
          Every frame goes through this chain; impacted by CPU load and USB bandwidth
```

**为什么内置屏 CV 也有 0.49–0.64 / Why internal display CV is also 0.49–0.64:**  
CV 反映触控板事件与帧节奏的对齐程度。触控板约 100–110 events/s，120Hz 屏约每帧 0.9 个事件，并非每帧都有新 delta 到达，所以 CV 不会为 0，这是正常现象，与渲染质量无关。  
CV reflects alignment between touchpad events and frame cadence. The trackpad fires ~100–110 events/s; at 120 Hz that's ~0.9 events per frame, so not every frame gets new delta — this is normal and unrelated to rendering quality.

---

*Generated by ScrollMeter v1.4 — 2026-06-04*

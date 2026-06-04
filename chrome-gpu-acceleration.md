# Chrome "Use graphics acceleration when available" — 详解 / Deep Dive

> 这个开关在 Chrome 设置 → System 里。开启后浏览器滚动会更顺滑、卡顿减少。
> 下面分中英文说明它到底做了什么、为什么影响滚动、以及如何用本仓库的
> `scrollmeter` 量化前后差异。

---

## 中文版

### 1. 这个开关到底控制什么

"Use graphics acceleration when available"（"可用时使用图形加速"）控制 Chrome
是否把**页面渲染、合成、动画**交给 GPU 处理。

| 状态 | 谁来画屏幕 |
|---|---|
| **开启** | GPU 进程 + 合成器线程，CPU 只负责高层逻辑 |
| **关闭** | 全部由 CPU 用 Skia 软件栅格器（software rasterizer）完成 |

注意它不是单一开关，而是同时影响：合成（Compositing）、栅格化（Rasterization）、Canvas、WebGL、视频解码（Video Decode）等多条 GPU 通路。

### 2. 为什么开了之后滚动更流畅

要理解这一点，需要看 Chrome 的两条渲染路径：

**关闭（软件渲染路径）**
- 主线程一手包办：JS 执行 → DOM 解析 → 样式计算 → Layout → Paint → Raster → Composite
- 你每滑一像素，主线程都要为新进入可视区的内容**重新光栅化**
- 主线程被 JS 占满 = 滚动完全卡死
- 整张屏幕被 CPU 画成位图再交给显示器——CPU 满载，能稳 60 fps 都吃力

**开启（GPU 合成路径）**
- 主线程只做布局 + 录制"层"（layer）的绘制指令
- 栅格化分发到 GPU 进程里的 raster worker，使用 Skia GPU / Metal 后端
- 一条**独立的合成器线程（Compositor Thread）**专门负责滚动和动画
- 滚动时绝大多数情况下**不重新光栅化**，只是在 GPU 上对已有的层做一次矩阵位移
- 主线程哪怕被 JS 卡死，合成器线程仍能平滑滚动——这就是 Chrome 著名的**异步滚动（threaded scrolling）**

### 3. 感知层面的差别

| 维度 | 软件渲染 | GPU 加速 |
|---|---|---|
| 滚动卡顿 | 长页面普遍 | 罕见；偶尔新内容上屏（raster）有微小延迟 |
| 主线程被 JS 占满 | 滚动彻底停滞 | 滚动照常，新内容延迟出现（短暂白块） |
| 帧率稳定性 | 抖动大，丢帧多 | 稳定贴显示器刷新率 |
| CPU 占用 | 高 | 低（GPU 接管） |
| 功耗 | 表面低，实则 CPU 满载更耗电 | 总体更省（专用硬件） |
| 偶发渲染 bug | 几乎没有 | 显卡驱动兼容性差时可能花屏 |

### 4. macOS 上的特殊性

- Chrome 在 macOS 上的 GPU 后端是 **Metal**（已取代旧的 OpenGL）
- 触控板的**高精度滚动事件**会直接送进合成器线程，不经主线程
- **ProMotion 屏（120 Hz）** 只有在 GPU 加速开启时才能跑满刷新率；软件渲染基本只能维持 60 Hz
- **Retina 高分辨率屏**对 GPU 加速依赖更强——像素数是 1080p 屏的 4 倍以上，软件栅格化太慢

### 5. 什么时候反而要关掉

- 显卡驱动 bug 导致页面花屏/白屏——关掉做诊断
- 虚拟机里 GPU passthrough 不完整
- 某些老旧 Intel 集显在特定 Chrome 版本上有性能倒退

绝大多数现代 Mac 应当保持开启。

### 6. 怎么验证当前真实状态

地址栏访问 `chrome://gpu`，看 **Graphics Feature Status**：

```
Canvas:                    Hardware accelerated
Compositing:               Hardware accelerated
Multiple Raster Threads:   Enabled
Rasterization:             Hardware accelerated
Video Decode:              Hardware accelerated
WebGL:                     Hardware accelerated
```

任何一项变成 **"Software only"** 都说明那条通路没走 GPU。仅仅打开总开关
不代表所有项都加速了——驱动黑名单、显卡型号都可能让某项回退到软件。

### 7. 怎么用本仓库的 scrollmeter 量化它

1. 关闭 "Use graphics acceleration when available" → 重启 Chrome
2. 双击 `run-bench.command`，在窗口里滑触控板 10 秒（这里测的是系统级，不是 Chrome 内）
3. 记录报告
4. 打开同一开关 → 重启 Chrome → 再测一次（注意测的还是 scrollmeter 自己的窗口，结果反映系统 GPU 合成是否健康，间接相关）

**想直接测 Chrome 网页滚动差异**：在 Chrome 里打开 DevTools → Performance →
Record，滚动一段长页面，停止录制。看 **Frames** 轨道里的红色块（dropped frame）数量
和 **Main** 轨道的占用率。开启加速前后对比，红块数量通常下降一个数量级。

---

## English version

### 1. What the setting actually controls

"Use graphics acceleration when available" toggles whether Chrome offloads
**page rendering, compositing, and animations** to the GPU.

| State | Who draws the screen |
|---|---|
| **On** | GPU process + compositor thread; CPU handles only higher-level logic |
| **Off** | Everything goes through Skia's software rasterizer on the CPU |

It's not a single switch — it gates multiple GPU paths simultaneously:
compositing, rasterization, Canvas, WebGL, video decode, etc.

### 2. Why it makes scrolling smoother

Chrome's rendering pipeline takes one of two paths.

**Software path (acceleration off)**
- Main thread does everything: JS → DOM parse → style → Layout → Paint →
  Raster → Composite
- Every scroll event forces the main thread to **re-rasterize** the
  newly-visible content
- A busy main thread (JS work, garbage collection) = scrolling stalls outright
- The whole screen is drawn into a bitmap on CPU and handed to the display.
  CPU pegs, holding 60 fps is hard.

**GPU-composited path (acceleration on)**
- Main thread does layout + records paint commands into compositor **layers**
- Rasterization is dispatched to raster workers in the GPU process, using
  Skia's GPU backend (Metal on macOS)
- A dedicated **compositor thread** runs independently, handling scrolling and
  animations
- During scroll, layers are usually **not re-rasterized** — they're just
  translated on the GPU (one matrix per frame)
- Even if the main thread is jammed by JS, the compositor thread keeps
  scrolling. This is Chrome's **threaded scrolling**.

### 3. What you actually feel

| Axis | Software | GPU-accelerated |
|---|---|---|
| Scroll stutter | Common on long pages | Rare; brief tile-raster delay only |
| When JS blocks main thread | Scroll freezes | Scroll keeps moving; new tiles arrive late (briefly white) |
| Frame pacing | Jittery, frequent drops | Locked near display refresh |
| CPU usage | High | Low |
| Power draw | Appears low, actually high (CPU saturated) | Generally lower (purpose-built hw) |
| Rendering glitches | Practically none | Possible with driver bugs |

### 4. macOS specifics

- Chrome's macOS GPU backend is **Metal** (the old OpenGL path is gone)
- High-precision touchpad scroll events are routed directly to the compositor
  thread, bypassing the main thread
- **ProMotion (120 Hz)** displays only reach max refresh with acceleration on;
  software rendering caps near 60 Hz
- **Retina** panels have 4×+ the pixel count of 1080p — software rasterization
  there is brutally slow, so GPU is doubly important

### 5. When you'd want it off

- Driver bug causing page corruption or white-out — turn off as a diagnostic
- VMs without complete GPU passthrough
- Specific old Intel iGPUs on specific Chrome versions known to regress

For 99% of modern Macs, leave it on.

### 6. How to verify the real state

Visit `chrome://gpu` and look at **Graphics Feature Status**:

```
Canvas:                    Hardware accelerated
Compositing:               Hardware accelerated
Multiple Raster Threads:   Enabled
Rasterization:             Hardware accelerated
Video Decode:              Hardware accelerated
WebGL:                     Hardware accelerated
```

Anything reading **"Software only"** is stuck on the CPU path. Flipping the
master toggle doesn't guarantee every line is accelerated — driver blocklists
and GPU model can force individual features back to software.

### 7. Quantifying it with this repo's scrollmeter

1. Turn the setting **off** → relaunch Chrome
2. Double-click `run-bench.command`, scroll for 10 s inside its window
   (measures system-level smoothness; the GPU compositor is shared with
   Chrome)
3. Save the report
4. Turn the setting **on** → relaunch Chrome → re-measure

To directly measure **Chrome page scroll** (not the OS-level metric): open
DevTools → Performance → Record, scroll a long page, stop. Look at the
**Frames** lane for red blocks (dropped frames) and the **Main** lane
utilization. Toggling acceleration usually drops the red-block count by an
order of magnitude.

### 8. Typical scrollmeter delta you should see

| Metric | Software path | GPU path | Improvement |
|---|---|---|---|
| Hitch ratio | 15–25 ms/s | 1–5 ms/s | ~5–10× |
| Coef of variation | 0.7+ | 0.15–0.25 | ~3–4× |
| p99 frame interval | 30–50 ms (occasional 80+) | within 1–2× refresh budget | dramatic |
| Stuck frames | many | near zero | dramatic |

Numbers vary with Mac model, display refresh, and what else is running.
The shape of the improvement, however, is consistent.

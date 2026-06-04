# Safari vs Chrome — GPU 加速架构对比 / GPU Acceleration Architecture

> 配套阅读：`chrome-gpu-acceleration.md`（Chrome 侧的详解）
> Companion to: `chrome-gpu-acceleration.md` (the Chrome-side deep dive)

---

## 中文版

### 1. 一句话结论

**Safari 默认全程 GPU 加速，且根本没有给用户提供关闭开关。**
这是架构层面的设计，不是产品决策。

### 2. 核心对照

| 维度 | Safari (WebKit) | Chrome (Blink) |
|---|---|---|
| GPU 加速默认 | **强制开启** | 默认开启，但有总开关可关 |
| 用户可见的"加速"开关 | **没有** | 有（Settings → System → Use graphics acceleration when available）|
| 合成器架构 | macOS 系统级 **Core Animation** + Metal | Chrome 自家 compositor + Metal |
| 跨平台 | 仅 macOS / iOS / iPadOS | Windows / macOS / Linux / Android / iOS |
| 滚动路径 | 触控板事件 → WebKit → CA → GPU | 触控板事件 → Browser process → Compositor thread → GPU process |
| ProMotion 120Hz 支持 | 系统级深度集成 | 应用级适配 |
| 鬼畜的图形 bug 时怎么办 | 等 Apple 修 | 关掉总开关回退到软件路径 |

### 3. 为什么 Safari 没有"加速开关"

Safari 把渲染工作交给 macOS 的 **Core Animation (CA)** 框架。
关键事实：

- **CA 自 macOS 10.5 (2007) 起就是 GPU 加速的合成器**——它本身就跑在 GPU 上
- WebKit 把网页的 layer tree 直接映射成 CA layer tree
- CA layer tree 交给系统的 **WindowServer** 合成，使用 Metal（早年 OpenGL/Quartz）
- WebKit 自身不再实现一套独立的合成器

所以"在 Safari 里关闭 GPU 加速"在架构上**不存在**——等于要求 Safari 不用 Core Animation，
等于要求它不用 macOS 的图形栈，做不到。

Chrome 则相反：它要在 Windows/Linux/Android/macOS 上都能跑，**自己实现了一套跨平台的
compositor**（叫 `cc` ，chromium compositor）。这套 compositor 是可被替换的模块，所以保留了
"GPU / 软件" 两种渲染后端的切换能力，对应 Settings 里的那个开关。

### 4. 为什么 Safari 在 Mac 上通常滑得更顺

1. **滚动事件路径更短**：触控板 → WebKit → CA → GPU，环节少
2. **不需要跨进程的 IPC 同步**：Chrome 的 main / renderer / GPU 进程之间要频繁通信，
   Safari 大量工作直接在 WebKit + WindowServer 之间走
3. **Apple 自家先适配 ProMotion**：Safari 是 Apple 应用，120Hz 自适应刷新支持得最早最稳
4. **CA 是为低能耗设计的**：Chrome 的 compositor 历史上能耗更高
5. **整体内存压力低**：Safari 进程模型更轻量，GPU 进程占用也小

### 5. 怎么验证 Safari 在用 GPU

Safari 没有 `chrome://gpu` 这种自省页面。从外部看：

```bash
# 看 Safari 持有的 IOSurface（GPU 共享内存表面）
ioreg -l -w 0 | grep -i iosurface | head

# 实时看 GPU 功耗（Safari 滚动时数字会跳）
sudo powermetrics --samplers gpu_power -i 500 -n 4
```

或者最直观的视觉验证：

1. Safari → 设置 → 高级 → 勾选 "在菜单栏中显示开发菜单"
2. 开发菜单 → **Show Compositing Borders**

打开后，所有被合成器独立处理的 layer 会画上彩色边框。滚动任何网页区域，边框会闪烁
——说明那部分确实是 GPU 在合成。

### 6. Safari 里能调的少数 GPU 相关项

平常用户不需要碰，开发/诊断时可能用到：

- **开发菜单 → Experimental Features** —— 几十个 WebKit 实验开关，包含合成相关
- **开发菜单 → Flags / Internal Features** —— 更底层
- 命令行隐藏 pref，例如：
  ```bash
  defaults write com.apple.Safari WebKitCanvasUsesAcceleratedDrawingPreferenceKey -bool true
  ```

### 7. 对滚动测试的实际意义

用本仓库的 `scrollmeter` 测同一台 Mac：

| 应用 | 预期表现 |
|---|---|
| **Safari** | 这台 Mac 滚动流畅度的**物理上限** |
| **Chrome（GPU 加速开）** | 接近 Safari，hitch ratio 略高一点 |
| **Chrome（GPU 加速关）** | 显著退化，CPU 满载时差距 10× |
| **Electron 应用**（VS Code、Slack、Discord、Notion 等） | 接近 "Chrome 关 GPU" 那档，因为它们用 Chromium 内核但没用 Mac 原生合成器 |
| **原生 AppKit / SwiftUI 应用**（Finder、Notes、邮件等） | 接近 Safari，因为也用 Core Animation |

测试建议：**用 Safari 跑一次作为参考上限**，再测其它应用看它们离上限差多少。

---

## English version

### 1. Bottom line

**Safari runs fully GPU-accelerated by default, and there is no user-facing
toggle to turn it off.** This is an architectural fact, not a product choice.

### 2. Head-to-head comparison

| Aspect | Safari (WebKit) | Chrome (Blink) |
|---|---|---|
| GPU acceleration default | **Forced on** | On by default, with a toggle |
| User-visible "acceleration" toggle | **None** | Yes (Settings → System) |
| Compositor architecture | macOS system-level **Core Animation** + Metal | Chrome's own compositor + Metal |
| Cross-platform | macOS / iOS / iPadOS only | Windows / macOS / Linux / Android / iOS |
| Scroll path | Touchpad event → WebKit → CA → GPU | Touchpad event → Browser process → Compositor thread → GPU process |
| ProMotion 120 Hz | OS-level deep integration | App-level adaptation |
| GPU driver bug? | Wait for Apple to fix | Toggle off, fall back to software path |

### 3. Why Safari has no "acceleration toggle"

Safari hands rendering to macOS's **Core Animation (CA)** framework. Key facts:

- **CA has been a GPU-backed compositor since macOS 10.5 (2007)** — it
  *is* the GPU compositor
- WebKit maps the web page's layer tree directly to a CA layer tree
- The CA layer tree is composited by the system **WindowServer**, via Metal
  (formerly OpenGL/Quartz)
- WebKit does not implement a separate compositor

So "turning off GPU acceleration in Safari" doesn't exist architecturally —
it would mean telling Safari not to use Core Animation, which means not using
macOS's graphics stack. Impossible.

Chrome is the opposite: it has to run on Windows/Linux/Android/macOS, so it
**ships its own cross-platform compositor** (called `cc`). That compositor is
a swappable module, which is why it can fall back to a software rendering
path — that's the toggle in Settings.

### 4. Why Safari usually scrolls smoother on Mac

1. **Shorter scroll event path**: touchpad → WebKit → CA → GPU, fewer hops
2. **No cross-process IPC sync**: Chrome's main/renderer/GPU processes
   communicate frequently; Safari mostly stays within WebKit + WindowServer
3. **Apple ships ProMotion support first**: Safari adapts to 120 Hz adaptive
   refresh earliest and most reliably
4. **CA is designed for low energy**: Chrome's compositor has historically
   used more power
5. **Lower memory pressure overall**: lighter process model, smaller GPU
   process footprint

### 5. How to verify Safari is using GPU

No `chrome://gpu` equivalent. Observe externally:

```bash
# Inspect IOSurface (GPU shared-memory surfaces) Safari is holding
ioreg -l -w 0 | grep -i iosurface | head

# Live GPU power draw (numbers jump while Safari scrolls)
sudo powermetrics --samplers gpu_power -i 500 -n 4
```

The most visual verification:

1. Safari → Settings → Advanced → tick "Show Develop menu in menu bar"
2. Develop menu → **Show Compositing Borders**

Every layer the compositor handles independently gets a colored border. Scroll
any page area; borders flicker — that area is being GPU-composited.

### 6. The few GPU-related knobs Safari does expose

Not needed in normal use; for dev/debug only:

- **Develop → Experimental Features** — dozens of WebKit flags, some
  compositing-related
- **Develop → Flags / Internal Features** — lower-level
- Hidden defaults, e.g.:
  ```bash
  defaults write com.apple.Safari WebKitCanvasUsesAcceleratedDrawingPreferenceKey -bool true
  ```

### 7. What this means for scroll testing

Running `scrollmeter` from this folder on the same Mac:

| App | Expected behavior |
|---|---|
| **Safari** | The **physical ceiling** of this Mac's scroll smoothness |
| **Chrome (GPU on)** | Close to Safari, slightly higher hitch ratio |
| **Chrome (GPU off)** | Dramatic regression; gap widens to 10× under CPU load |
| **Electron apps** (VS Code, Slack, Discord, Notion…) | Similar to "Chrome GPU off" — they use Chromium but not the native macOS compositor |
| **Native AppKit / SwiftUI apps** (Finder, Notes, Mail…) | Close to Safari, because they also use Core Animation |

Suggested workflow: **run Safari once as your reference ceiling**, then test
other apps and see how far each falls below that ceiling.

### 8. Quick mental model

- **Safari** = the page draws straight onto macOS's native GPU compositor.
  Apple owns the whole stack end-to-end.
- **Chrome** = the page draws onto Chromium's own compositor, which then
  hands its output to macOS for final display. One extra layer of
  abstraction, with both the power and the cost that brings.
- **Electron** = a Chromium renderer process per app, but without the
  optimizations Chrome's Browser process does for its own UI. The
  worst-of-both: Chromium's overhead without Chrome's polish.

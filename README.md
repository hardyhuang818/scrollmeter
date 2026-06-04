# MacBook Scroll Smoothness Benchmark

Self-contained tool that quantifies touchpad scroll smoothness on macOS.
**No Xcode, no Instruments setup, no manual analysis required.** One double-click.

## Repository contents

| File | Purpose |
|---|---|
| **Tool** | |
| `scrollmeter.swift` | The measurement app (single-file Swift, ~500 LOC) |
| `run-bench.command` | Double-click launcher — installs CLT if needed, compiles, runs |
| `build-universal.command` | One-time helper to build a universal binary for distribution |
| **Documentation** | |
| `chrome-gpu-acceleration.md` | Deep dive on Chrome's GPU acceleration (bilingual) |
| `safari-vs-chrome-gpu.md` | Why Safari has no GPU toggle — architectural comparison |
| `chrome-rendering-demo.html` | Interactive visualization: GPU on vs off under CPU load |
| `three-way-comparison.html` | Side-by-side: Safari vs Chrome (GPU on) vs Chrome (GPU off) |
| **Analysis** | |
| `scrollmeter-analysis-20260604-v4.md` / `.html` | Latest analysis: 10 configurations across 4 connection types |
| `20260604 scrollmeter log/` | Raw measurement reports from a MacBook Pro M3 + HP PG27 4K |

---


## What it gives you

After 10 seconds of scrolling, a report like:

```
Display         : 120.0 Hz   (8.33 ms/frame budget)
Scroll duration : 10.02 s
Frames sampled  : 1201

-- Frame interval (ms) --
  mean / median : 8.34 / 8.33
  p95 / p99     : 8.40 / 9.10
  max           : 22.50
  effective FPS : 119.9

-- Hitches (interval > 1.5x budget) --
  count         : 4 / 1200   (0.33%)
  ratio         : 3.20 ms hitched per sec of scroll
  verdict       : smooth  (<5 smooth, 5-10 borderline, >10 felt)

-- Visual smoothness (per-frame position delta) --
  coef of var   : 0.18   excellent
  stuck frames  : 2 / 1200
```

The headline numbers:
- **Hitch ratio (ms/s)** — Apple's standard. <5 = smooth, >10 = you feel it.
- **Coef of variation (CV)** — how uniformly the content advances each frame.
  Low CV = the motion looks like a steady glide; high CV = stutters even when
  no individual frame is dropped.
- **Effective FPS** — average measured frame rate while scrolling.

## How to use

1. Copy this folder to your Mac (USB / iCloud / AirDrop).
2. **Double-click `run-bench.command`.**
   - First time only: macOS Gatekeeper blocks unsigned `.command` files.
     Right-click → **Open** → confirm. Future double-clicks work normally.
   - First time only: if Xcode Command Line Tools aren't installed, a system
     dialog appears. Click **Install**, wait ~5 minutes, re-run.
3. A window opens. **Scroll up/down on the touchpad inside it.**
   The title bar counts down 10 seconds from the first scroll.
4. Window closes. Report prints in Terminal and saves to
   `~/Documents/scroll-bench/report-<timestamp>.txt`.

> **If double-click does nothing** (Finder opens the file in TextEdit
> instead): the executable bit was stripped during transfer. Open Terminal,
> drag this folder onto its window to get the path, then:
> `cd "<that path>" && bash run-bench.command`
> The script self-fixes its own permissions on first run, so future
> double-clicks will work.

## How it works

`scrollmeter.swift` (compiled by `swiftc` on first run) opens an `NSScrollView`
over a 10 000-row colorful document, then:

1. Starts a `CVDisplayLink` — fires once per display refresh.
2. On every tick, records `(timestamp, documentVisibleRect.origin.y)`.
3. Captures every `scrollWheel` event with its precise touchpad delta.
4. When recording ends, computes:
   - **Frame interval stats** from consecutive display-link timestamps.
     Healthy intervals cluster tightly around `1000 / refreshHz`.
   - **Hitches** = intervals exceeding 1.5× budget. Their total over the scroll
     period gives Apple's *hitch time ratio*.
   - **Per-frame position delta** = how much the visible content moved between
     consecutive frames. Steady scrolling = consistent deltas (low CV).
     A "stuck frame" is one where the position didn't advance even though
     scroll events were arriving.

Because the test owns its own window and renders its own content, there's no
need for synthetic event injection (no Accessibility permission), no attaching
to other apps, and no Instruments. The only dependency is `swiftc` from Xcode
Command Line Tools.

## Comparing runs

For meaningful comparisons (this MacBook vs that one, before vs after a fix):

- Fix the window size and screen (same display, same Hz).
- Scroll at roughly the same pace for the same 10s — the script reports total
  pt scrolled, keep it in the same ballpark across runs.
- Repeat 5+ times per configuration. Inter-run variance is real; median across
  runs is more meaningful than a single number.
- Compare these three primary metrics in order:
  1. Hitch ratio (ms/s)
  2. Coef of variation
  3. p99 frame interval

## Files

- `run-bench.command` — double-click entry point. Uses prebuilt binary if
  present; otherwise installs CLT and compiles, then runs.
- `scrollmeter.swift` — single-file Swift source.
- `scrollmeter` — compiled binary (auto-created on first run, or shipped
  prebuilt — see "Distributing to many Macs" below).
- `build-universal.command` — one-time helper that produces a universal
  (Apple Silicon + Intel) `scrollmeter` binary for distribution.
- Reports save to `~/Documents/scroll-bench/`.

## Distributing to many Macs (no per-Mac CLT install)

Testing a fleet? You don't have to download Xcode CLT on every machine.

**Option A — ship a prebuilt binary (recommended, ~300 KB total):**

1. On one Mac that already has CLT, double-click `build-universal.command`.
   It compiles `scrollmeter` as a universal binary (arm64 + x86_64, min
   macOS 11).
2. Ship just these three files to every other Mac:
   - `scrollmeter`        (the binary)
   - `run-bench.command`  (launcher)
   - `README.md`
3. On target Macs: double-click `run-bench.command`. The script detects the
   prebuilt binary, skips the CLT/compile path entirely, and runs.
   **No Xcode CLT install needed.**

**Option B — ship the CLT installer .pkg (offline install, ~700 MB–1.5 GB):**

If you need to keep the source for tinkering and don't want each Mac to
download CLT from Apple, you can pre-download the installer once:

1. Sign in to <https://developer.apple.com/download/all/> (free Apple ID).
2. Search "Command Line Tools" and download the `.dmg` matching the macOS
   version of the target machines.
3. Mount the dmg, copy the inner `.pkg` into this folder. Filename should
   look like `Command Line Tools for Xcode 15.3.pkg`.
4. Ship the whole folder. On target Macs, `run-bench.command` detects the
   local `.pkg` and runs `sudo installer -pkg <pkg> -target /` (prompts for
   the user's password once, no network needed).

## Why not Instruments / Animation Hitches?

That path needs the full Xcode app (~10 GB from Mac App Store, requires Apple
ID + interactive download). The Animation Hitches template isn't in the
lightweight Command Line Tools install. For "I want a number to compare two
MacBooks" this script gets you the same headline metrics with a 50 MB CLT
install. If you later want deeper diagnosis (which thread, which commit
phase), open Xcode → Instruments → Animation Hitches manually:
<https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app>

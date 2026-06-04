// scrollmeter.swift
// Self-contained scroll smoothness benchmark for macOS.
// Build: swiftc -O scrollmeter.swift -o scrollmeter
// Run:   ./scrollmeter
//
// Opens a window with a tall scrollable view. User scrolls on the touchpad
// inside the window for ~10s. The tool records:
//   - CVDisplayLink ticks (refresh-rate clock)
//   - Scroll position of the document at each tick
//   - Each NSEvent.scrollWheel timestamp + delta
// and prints a quantified report (frame interval stats, hitch count + ratio,
// per-frame visual delta stats). Also writes the report to
// ~/Documents/scroll-bench/report-<timestamp>.txt.

import AppKit
import QuartzCore
import CoreVideo

// MARK: - Sampler ------------------------------------------------------------

final class FrameSampler {
    static let shared = FrameSampler()

    struct PosSample { let t: CFTimeInterval; let y: CGFloat }
    struct ScrollEvent { let t: CFTimeInterval; let delta: CGFloat }

    private(set) var samples: [PosSample] = []
    private(set) var scrollEvents: [ScrollEvent] = []
    private var displayLink: CVDisplayLink?
    private let lock = NSLock()
    weak var scrollView: NSScrollView?
    var refreshHz: Double = 60.0
    var isRecording = false
    // host-clock ticks per second; cached so the CVDisplayLink callback
    // doesn't pay for the call on every frame.
    fileprivate var hostFreq: Double = 1.0

    var scrollEventCount: Int {
        lock.lock(); defer { lock.unlock() }
        return scrollEvents.count
    }

    func start(window: NSWindow, scrollView: NSScrollView) {
        self.scrollView = scrollView
        self.hostFreq = Double(CVGetHostClockFrequency())

        // Detect the display this window is on + its refresh rate, and bind
        // the display link to that specific display (more accurate than
        // CreateWithActiveCGDisplays when multiple monitors are attached).
        var displayID: CGDirectDisplayID = CGMainDisplayID()
        if let screen = window.screen,
           let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            displayID = CGDirectDisplayID(num.uint32Value)
        }
        if let mode = CGDisplayCopyDisplayMode(displayID), mode.refreshRate > 0 {
            refreshHz = mode.refreshRate
        }

        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithCGDisplay(displayID, &dl)
        guard let dl = dl else { return }
        self.displayLink = dl

        let cb: CVDisplayLinkOutputCallback = { _, inNow, _, _, _, ctx in
            let me = Unmanaged<FrameSampler>.fromOpaque(ctx!).takeUnretainedValue()
            let t = Double(inNow.pointee.hostTime) / me.hostFreq
            DispatchQueue.main.async {
                guard me.isRecording, let sv = me.scrollView else { return }
                let y = sv.documentVisibleRect.origin.y
                me.lock.lock()
                me.samples.append(PosSample(t: t, y: y))
                me.lock.unlock()
            }
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(dl, cb, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(dl)
        isRecording = true
    }

    func recordScroll(delta: CGFloat) {
        let t = CACurrentMediaTime()
        lock.lock()
        scrollEvents.append(ScrollEvent(t: t, delta: delta))
        lock.unlock()
    }

    func stop() {
        isRecording = false
        if let dl = displayLink { CVDisplayLinkStop(dl) }
    }

    // MARK: Report

    func report() -> String {
        lock.lock()
        let samples = self.samples
        let scrolls = self.scrollEvents
        lock.unlock()

        guard scrolls.count > 5,
              let firstScroll = scrolls.first?.t,
              let lastScroll = scrolls.last?.t else {
            return "No (or too little) scroll activity recorded.\n" +
                   "Make sure to scroll INSIDE the window, not on it.\n"
        }

        let active = samples.filter { $0.t >= firstScroll && $0.t <= lastScroll + 0.1 }
        guard active.count > 5 else {
            return "Too few frames captured during scroll.\n"
        }

        let intervalsMs = zip(active, active.dropFirst()).map { ($1.t - $0.t) * 1000.0 }
        let expectedMs = 1000.0 / refreshHz

        let posDeltas = zip(active, active.dropFirst()).map { abs($1.y - $0.y) }
        let nonzeroDeltas = posDeltas.filter { $0 > 0.01 }
        let stuckFrames = posDeltas.filter { $0 < 0.01 }.count

        let scrollDur = lastScroll - firstScroll
        let totalScrolled = scrolls.reduce(0.0) { $0 + abs(Double($1.delta)) }
        let scrollRate = Double(scrolls.count) / scrollDur

        // Hitch = frame interval noticeably above budget.
        let hitchThresh = expectedMs * 1.5
        let hitchIntervals = intervalsMs.filter { $0 > hitchThresh }
        let hitchTimeMs = hitchIntervals.reduce(0, +)
        let hitchRatioMsPerS = hitchTimeMs / scrollDur

        func pct(_ a: [Double], _ q: Double) -> Double {
            guard !a.isEmpty else { return 0 }
            let s = a.sorted()
            return s[min(s.count - 1, Int(Double(s.count) * q))]
        }
        func mean(_ a: [Double]) -> Double {
            a.isEmpty ? 0 : a.reduce(0,+) / Double(a.count)
        }
        func stddev(_ a: [Double]) -> Double {
            let m = mean(a)
            return a.isEmpty ? 0 : (a.map { ($0-m)*($0-m) }.reduce(0,+) / Double(a.count)).squareRoot()
        }

        let avgInt = mean(intervalsMs)
        let stdInt = stddev(intervalsMs)
        let avgDelta = mean(nonzeroDeltas)
        let stdDelta = stddev(nonzeroDeltas)
        let cv = (avgDelta > 0) ? stdDelta / avgDelta : 0

        let hitchVerdict: String = {
            if hitchRatioMsPerS < 5  { return "smooth (Apple target)" }
            if hitchRatioMsPerS < 10 { return "borderline" }
            return "felt as jank"
        }()
        let cvVerdict: String = {
            if cv < 0.3 { return "excellent" }
            if cv < 0.5 { return "good" }
            if cv < 0.7 { return "noticeable jitter" }
            return "choppy"
        }()

        return """

        ============ Scroll Smoothness Report ============

        Display         : \(String(format: "%.1f", refreshHz)) Hz   (\(String(format: "%.2f", expectedMs)) ms/frame budget)
        Scroll duration : \(String(format: "%.2f", scrollDur)) s
        Scrolled        : \(String(format: "%.0f", totalScrolled)) pt
        Scroll events   : \(scrolls.count)  (\(String(format: "%.0f", scrollRate))/s)
        Frames sampled  : \(active.count)

        -- Frame interval (ms) --
          mean          : \(String(format: "%.2f", avgInt))
          median        : \(String(format: "%.2f", pct(intervalsMs, 0.5)))
          p95           : \(String(format: "%.2f", pct(intervalsMs, 0.95)))
          p99           : \(String(format: "%.2f", pct(intervalsMs, 0.99)))
          max           : \(String(format: "%.2f", intervalsMs.max() ?? 0))
          std dev       : \(String(format: "%.2f", stdInt))
          effective FPS : \(String(format: "%.1f", 1000.0 / avgInt))

        -- Hitches (interval > 1.5x budget) --
          count         : \(hitchIntervals.count) / \(intervalsMs.count)  (\(String(format: "%.2f", Double(hitchIntervals.count)/Double(intervalsMs.count)*100))%)
          total time    : \(String(format: "%.1f", hitchTimeMs)) ms
          ratio         : \(String(format: "%.2f", hitchRatioMsPerS)) ms hitched per sec of scroll
          verdict       : \(hitchVerdict)
                            (<5 smooth, 5-10 borderline, >10 felt)

        -- Visual smoothness (per-frame position delta) --
          mean          : \(String(format: "%.2f", avgDelta)) pt/frame
          std dev       : \(String(format: "%.2f", stdDelta)) pt/frame
          coef of var   : \(String(format: "%.2f", cv))   \(cvVerdict)
                            (lower = more uniform motion)
          stuck frames  : \(stuckFrames) / \(posDeltas.count)
                            (frames where view did not advance)

        ===================================================
        """
    }
}

// MARK: - Views --------------------------------------------------------------

final class MeterScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        FrameSampler.shared.recordScroll(delta: event.scrollingDeltaY)
    }
}

final class HeavyContentView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let rowH: CGFloat = 36
        let first = max(0, Int(dirtyRect.minY / rowH))
        let last  = Int(dirtyRect.maxY / rowH) + 1
        for i in first..<last {
            let r = NSRect(x: 0, y: CGFloat(i) * rowH, width: bounds.width, height: rowH)
            let hue = CGFloat(i % 360) / 360.0
            NSColor(hue: hue, saturation: 0.30, brightness: 0.97, alpha: 1).setFill()
            r.fill()
            let txt = "Row \(i)  -  Scroll up/down on the touchpad inside this window"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.black
            ]
            (txt as NSString).draw(at: NSPoint(x: 16, y: CGFloat(i) * rowH + 9), withAttributes: attrs)
        }
    }
}

// MARK: - App delegate -------------------------------------------------------

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var scrollView: MeterScrollView!
    var endAt: CFTimeInterval = 0
    var timer: Timer?
    var didFinish = false
    let recordSec: Double = 10.0

    // Quit when user closes the window (default for non-bundled apps is false).
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    // If user closes window or Cmd+Q's, still emit a report (if we have data).
    func windowWillClose(_ n: Notification)            { finish() }
    func applicationWillTerminate(_ n: Notification)   { finish() }

    func applicationDidFinishLaunching(_ n: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 760, height: 800)
        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "ScrollMeter — scroll inside this window to begin"

        scrollView = MeterScrollView(frame: frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false

        let totalRows = 10_000
        let docHeight = CGFloat(totalRows) * 36
        let doc = HeavyContentView(frame: NSRect(x: 0, y: 0, width: frame.width, height: docHeight))
        scrollView.documentView = doc

        window.contentView = scrollView
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        FrameSampler.shared.start(window: window, scrollView: scrollView)

        // Schedule in .common so it keeps firing during NSEvent tracking
        // (touchpad scroll can put the run loop in event-tracking mode).
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let n = FrameSampler.shared.scrollEventCount
            if n == 0 {
                self.window.title = "ScrollMeter — scroll inside this window to begin"
                return
            }
            if self.endAt == 0 {
                self.endAt = CACurrentMediaTime() + self.recordSec
            }
            let remain = self.endAt - CACurrentMediaTime()
            if remain > 0 {
                self.window.title = String(format: "ScrollMeter — keep scrolling…  %.1fs left", remain)
            } else {
                self.finish()
                NSApp.terminate(nil)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func finish() {
        // Idempotent: timer firing, window close, and Cmd+Q can all reach
        // here; emit at most one report. No NSAlert (would deadlock inside
        // a windowWillClose / applicationWillTerminate handler).
        if didFinish { return }
        didFinish = true
        timer?.invalidate()

        FrameSampler.shared.stop()
        let report = FrameSampler.shared.report()
        print(report)

        let home = FileManager.default.homeDirectoryForCurrentUser
        let outDir = home.appendingPathComponent("Documents/scroll-bench")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let path = outDir.appendingPathComponent("report-\(df.string(from: Date())).txt")
        try? report.write(to: path, atomically: true, encoding: .utf8)
        print("Saved: \(path.path)")
    }
}

// MARK: - Entry --------------------------------------------------------------

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

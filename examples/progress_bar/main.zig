const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const duration_ns: u64 = 3 * std.time.ns_per_s;

// This example shows a display-only ProgressBar component.
//
// ProgressBar only draws a bar for the progress value it receives. It does not
// own transition state, start timers, request frames, or decide when progress is
// complete. Those decisions stay in the app so reset/stop behavior remains
// explicit.
const App = struct {
    bar: ui.ProgressBar = ui.ProgressBar.init(.{}),
    // Elapsed time for this progress run. The app converts this to normalized
    // progress in progress().
    elapsed_ns: u64 = 0,
    // When false, the app stops requesting frame events and the bar stays at
    // its final value.
    running: bool = true,
    // Chasen frame deltas are measured from the previous delivered frame. After
    // init/reset, the first delta may include time before the new run started,
    // so this flag tells update() to use that frame only as a timing baseline.
    skip_next_frame_delta: bool = true,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        frame: chasen.Frame,
        reset,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        // Kick off the first frame. ProgressBar itself never calls
        // requestFrame(); the app owns the animation lifecycle.
        ctx.frame().request();
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .frame => |frame| .{ .frame = frame },
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches('r', .{})) return .reset;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .frame => |frame| {
                if (self.running) {
                    // The first frame after init/reset establishes a fresh
                    // timing baseline. Its delta may include time before the
                    // new run started, so do not count it as progress.
                    if (self.skip_next_frame_delta) {
                        self.skip_next_frame_delta = false;
                    } else {
                        self.elapsed_ns = @min(self.elapsed_ns + frame.delta_ns, duration_ns);
                    }
                    self.running = self.elapsed_ns < duration_ns;
                }
                // Keep requesting frames only until the progress reaches 1.0.
                // Once complete, the runtime can return to event-driven idle.
                if (self.running) ctx.frame().request();
            },
            .reset => {
                // Reset is just app state. Because ProgressBar owns no progress
                // state, there is nothing inside the component to synchronize.
                self.elapsed_ns = 0;
                self.running = true;
                self.skip_next_frame_delta = true;
                // Request a new frame so the run restarts even if it had
                // already completed and stopped requesting frames.
                ctx.frame().request();
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "ProgressBar Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "r: reset  Esc: quit", .{ .fg = .gray });

        const p = self.progress();
        // The child surface controls the visible bar width. With width 40,
        // each cell represents 2.5% progress.
        var bar_area = sfc.child(.{ .col = 0, .row = 3, .width = 40, .height = 1 });
        self.bar.view(&bar_area, .{
            .progress = p,
        });

        // Text around the bar is app-owned. ProgressBar intentionally does not
        // decide where labels, percentages, or status text should appear.
        const percent: u8 = @intFromFloat(@round(p * 100.0));
        const elapsed_seconds = @as(f64, @floatFromInt(self.elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
        const status = if (self.running) "running" else "done";
        // printAt formats into the frame arena before drawing, so this avoids
        // the short-lived buffer lifetime issue of allocPrint(...) + borrowTextAt(...).
        _ = try sfc.printAt(
            0,
            5,
            .{ .dim = true },
            "{d}%  elapsed: {d:.1}s  {s}",
            .{ percent, elapsed_seconds, status },
        );
    }

    fn progress(self: *const App) f32 {
        // ProgressBar expects normalized progress: 0.0 means empty, 1.0 means
        // full. The component clamps out-of-range values, but this example keeps
        // the app state inside that range.
        return @as(f32, @floatFromInt(self.elapsed_ns)) / @as(f32, @floatFromInt(duration_ns));
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const duration_ns: u64 = 4 * std.time.ns_per_s;

// This example shows Gauge as a compact display-only metric component.
//
// Gauge draws the label, bar, and already-formatted value text. The app still
// owns metric state, threshold meaning, formatting, and frame scheduling.
const App = struct {
    gauge: ui.Gauge = ui.Gauge.init(.{}),
    elapsed_ns: u64 = 0,
    running: bool = true,
    skip_next_frame_delta: bool = true,

    pub const Msg = union(enum) {
        frame: chasen.Frame,
        reset,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        // Gauge never asks for frames. This example animates by having the app
        // request frames while its metric is running.
        ctx.requestFrame();
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .frame => |frame| {
                if (self.running) {
                    // The first frame after init/reset establishes timing.
                    // Its delta may include time before the current run.
                    if (self.skip_next_frame_delta) {
                        self.skip_next_frame_delta = false;
                    } else {
                        self.elapsed_ns = @min(self.elapsed_ns + frame.delta_ns, duration_ns);
                    }
                    self.running = self.elapsed_ns < duration_ns;
                }

                if (self.running) ctx.requestFrame();
            },
            .reset => {
                self.elapsed_ns = 0;
                self.running = true;
                self.skip_next_frame_delta = true;
                ctx.requestFrame();
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Gauge Example - app-owned metrics", .{ .bold = true });
        _ = sfc.textAt(0, 1, "r: reset  Esc: quit", .{ .fg = .gray });

        const p = self.progress();
        const percent: u8 = @intFromFloat(@round(p * 100.0));

        // Gauge receives the formatted value as borrowed text. The app owns
        // whether this is percent, bytes, latency, health, or another metric.
        _ = try sfc.printAt(0, 3, .{ .fg = .gray }, "Upload progress: {d}%", .{percent});

        self.gauge.view(sfc, .{
            .col = 0,
            .row = 5,
            .width = 48,
            .label = "Upload",
            .progress = p,
            .value_text = if (self.running) "syncing" else "done",
            .label_width = 10,
            .value_width = 8,
            .filled_style = .{ .bold = true, .fg = .{ .index = 10 } },
            .empty_style = .{ .dim = true, .fg = .gray },
            .value_style = if (self.running) .{ .fg = .{ .index = 14 } } else .{ .fg = .{ .index = 2 } },
        });

        self.gauge.view(sfc, .{
            .col = 0,
            .row = 7,
            .width = 48,
            .label = "Memory",
            .progress = 0.68,
            .value_text = "68%",
            .label_width = 10,
            .value_width = 8,
            .filled = "#",
            .empty = "-",
            .filled_style = .{ .bold = true, .fg = .{ .index = 11 } },
            .empty_style = .{ .dim = true, .fg = .gray },
            .value_style = .{ .fg = .{ .index = 11 } },
        });

        self.gauge.view(sfc, .{
            .col = 0,
            .row = 9,
            .width = 48,
            .label = "Queue",
            .progress = 0.25,
            .value_text = "3 open",
            .label_width = 10,
            .value_width = 8,
            .left_delimiter = "<",
            .right_delimiter = ">",
            .filled = "=",
            .empty = " ",
            .filled_style = .{ .bold = true, .fg = .{ .index = 6 } },
            .value_style = .{ .fg = .{ .index = 6 } },
        });

        _ = sfc.textAt(0, 12, "Gauge owns presentation only; thresholds and labels stay in app.", .{ .dim = true });
    }

    fn progress(self: *const App) f32 {
        return @as(f32, @floatFromInt(self.elapsed_ns)) / @as(f32, @floatFromInt(duration_ns));
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
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

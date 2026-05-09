const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows a display-only Spinner component.
//
// Spinner does not schedule frames. The app requests frame events, stores the
// current frame index, and passes that index to Spinner.view. This keeps
// animation policy in the app while Spinner stays a small drawing component.
const App = struct {
    spinner: ui.Spinner = ui.Spinner.init(.{ .label = "Loading" }),
    // The Chasen runtime increments frame.index for each requested frame. The
    // spinner uses this as a simple animation position, not as elapsed time.
    frame_index: u64 = 0,
    // delta_ns is the time since the previous frame. Accumulating it gives a
    // human-readable elapsed time for the example UI.
    elapsed_ns: u64 = 0,
    running: bool = true,

    pub const Msg = union(enum) {
        frame: chasen.Frame,
        toggle,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        // Kick off the first frame. After this, update decides whether another
        // frame should be requested.
        ctx.requestFrame();
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .frame => |frame| {
                // Event.frame is delivered only after the app requested one.
                // The component does not see this event directly.
                self.frame_index = frame.index;
                self.elapsed_ns += frame.delta_ns;
                // Request one more frame only while running. Pausing stops the
                // animation and lets the runtime return to event-driven idle.
                if (self.running) ctx.requestFrame();
            },
            .toggle => {
                self.running = !self.running;
                // Resuming needs a new frame request because the spinner does
                // not keep a timer or frame future alive by itself.
                if (self.running) ctx.requestFrame();
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Spinner Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Space: pause/resume  Esc: quit", .{ .fg = .gray });

        // The app passes the current frame index into Spinner.view. Replacing
        // this with a value from chasen-anim.loopIndex later would not require
        // Spinner to own animation state.
        self.spinner.view(sfc, .{
            .col = 0,
            .row = 3,
            .width = 24,
            .frame_index = self.frame_index,
        });

        const status = if (self.running) "running" else "paused";
        // Show both the raw frame index and elapsed seconds so the frame count
        // is not mistaken for a timestamp.
        const elapsed_seconds = @as(f64, @floatFromInt(self.elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
        const info = try std.fmt.allocPrint(
            sfc.frameAllocator(),
            "frame index: {d}  elapsed: {d:.1}s  {s}",
            .{ self.frame_index, elapsed_seconds, status },
        );
        _ = sfc.textAt(0, 5, info, .{ .dim = true });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .frame => |frame| .{ .frame = frame },
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(' ', .{})) return .toggle;
                return null;
            },
            else => null,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

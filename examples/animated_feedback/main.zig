const std = @import("std");
const chasen = @import("chasen");
const anim = @import("chasen_anim");
const graphics = @import("chasen_graphics");
const ui = @import("chasen_ui");

const progress_frames: u64 = 120;

// This example wires chasen-anim and chasen-graphics through app code.
//
// chasen-anim computes the current spinner frame and normalized progress.
// chasen-graphics provides glyph/block presets. Spinner and ProgressBar still
// receive plain ViewOptions and stay display-only.
const App = struct {
    spinner: ui.Spinner = ui.Spinner.init(.{
        // chasen-graphics provides frame labels as plain borrowed data. The
        // Spinner component does not know where these frames came from.
        .frames = &graphics.glyph.spinner.dots,
        .label = "Synchronizing",
    }),
    bar: ui.ProgressBar = ui.ProgressBar.init(.{}),
    // Animation position is app state. The example deliberately uses
    // chasen-anim.FrameCounter instead of storing state inside Spinner or
    // ProgressBar, so pause/reset policy remains visible in update().
    frame_counter: anim.FrameCounter = .{},
    running: bool = true,

    pub const Msg = union(enum) {
        frame: chasen.Frame,
        toggle,
        reset,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        // Kick off the first frame. After that, update() decides whether the
        // app should keep animating or return to event-driven idle.
        ctx.requestFrame();
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .frame => {
                if (self.running) {
                    // A delivered frame advances the app-owned animation
                    // counter. Components only see computed values in view().
                    _ = self.frame_counter.step();
                    // Request another frame only while running. When paused,
                    // no frame request is kept alive by Spinner or ProgressBar.
                    ctx.requestFrame();
                }
            },
            .toggle => {
                self.running = !self.running;
                // Resuming needs an explicit frame request because pausing
                // intentionally stopped the app's animation loop.
                if (self.running) ctx.requestFrame();
            },
            .reset => {
                // Reset is app policy. There is no component animation state to
                // synchronize because the display components are stateless.
                self.frame_counter.reset();
                self.running = true;
                ctx.requestFrame();
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Animated Feedback Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Space: pause/resume  r: reset  Esc: quit", .{ .fg = .gray });

        // chasen-anim turns the app's monotonically increasing frame into an
        // index that wraps across the graphics preset's frame list. Spinner
        // still receives only a frame_index and draws the selected label.
        const spinner_frame = anim.loopIndex(self.frame_counter.frame, self.spinner.frames.len);
        var spinner_area = sfc.child(.{ .col = 0, .row = 3, .width = 32, .height = 1 });
        self.spinner.view(&spinner_area, .{
            .frame_index = spinner_frame,
            .frame_style = .{ .bold = true, .fg = .{ .index = 14 } },
        });

        const p = self.progress();
        var bar_area = sfc.child(.{ .col = 0, .row = 5, .width = 40, .height = 1 });
        self.bar.view(&bar_area, .{
            .progress = p,
            // The filled cell comes from chasen-graphics. The empty preset is
            // a space, so this demo uses the visible ASCII fallback to show
            // the whole bar width without relying on background styling.
            .filled = graphics.blocks.progress.filled,
            .empty = graphics.blocks.progress.empty_ascii,
            .filled_style = .{ .bold = true, .fg = .{ .index = 10 } },
            .empty_style = .{ .dim = true, .fg = .gray },
        });

        const percent: u8 = @intFromFloat(@round(p * 100.0));
        const status = if (self.running) "running" else "paused";
        // printAt formats into the frame arena before drawing, so this avoids
        // the short-lived buffer lifetime issue of allocPrint(...) + borrowTextAt(...).
        _ = try sfc.printAt(
            0,
            7,
            .{ .dim = true },
            "frame: {d}  progress: {d}%  {s}",
            .{ self.frame_counter.frame, percent, status },
        );
    }

    fn progress(self: *const App) f32 {
        // Loop the progress demo through 0.0 -> 1.0 -> 0.0 so the example
        // keeps showing motion. The looping and easing choices are app policy;
        // ProgressBar only receives the final normalized value.
        const frame = self.frame_counter.frame % (progress_frames + 1);
        return anim.ease.inOutQuad(anim.progress(frame, progress_frames));
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .frame => |frame| .{ .frame = frame },
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(' ', .{})) return .toggle;
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

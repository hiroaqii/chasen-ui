const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const lifetime_ns: u64 = 4 * std.time.ns_per_s;

// This example shows Toast as a display-only notification chrome.
//
// Toast does not manage queues or timers. The app owns visibility and lifetime,
// computes remaining progress, and decides where the toast is placed.
const App = struct {
    toast: ui.Toast = ui.Toast.init(.{}),
    elapsed_ns: u64 = 0,
    visible: bool = true,
    skip_next_frame_delta: bool = true,

    pub const Msg = union(enum) {
        frame: chasen.Frame,
        notify,
        dismiss,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        ctx.frame().request();
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .frame => |frame| .{ .frame = frame },
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches('n', .{})) return .notify;
                if (key.matches('d', .{})) return .dismiss;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .frame => |frame| {
                if (self.visible) {
                    // The app owns toast lifetime. The component only draws
                    // the progress value it receives in view().
                    if (self.skip_next_frame_delta) {
                        self.skip_next_frame_delta = false;
                    } else {
                        self.elapsed_ns = @min(self.elapsed_ns + frame.delta_ns, lifetime_ns);
                    }
                    self.visible = self.elapsed_ns < lifetime_ns;
                }

                if (self.visible) ctx.frame().request();
            },
            .notify => {
                // Restarting a toast is app policy. A real app could enqueue
                // messages here instead of replacing the current one.
                self.elapsed_ns = 0;
                self.visible = true;
                self.skip_next_frame_delta = true;
                ctx.frame().request();
            },
            .dismiss => {
                // Dismissal policy also stays outside Toast.
                self.visible = false;
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Toast Example - app-owned lifetime", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "n: notify  d: dismiss  Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(0, 3, "Main screen keeps rendering while the toast is visible.", .{});
        _ = sfc.borrowTextAt(0, 5, "Toast owns only the small notification chrome.", .{ .dim = true });
        _ = sfc.borrowTextAt(0, 6, "Visibility, queue, placement, and timer policy stay in app.", .{ .dim = true });

        if (self.visible) {
            const rect = toastRect(sfc, 36, 3);
            var toast_area = sfc.child(rect);
            self.toast.view(&toast_area, .{
                .marker = "!",
                .title = "Settings saved",
                .body = "Preferences were written",
                .progress = self.remainingProgress(),
                .fill_style = .{ .bg = .{ .index = 24 } },
                .marker_style = .{ .bold = true, .fg = .{ .index = 10 }, .bg = .{ .index = 24 } },
                .title_style = .{ .bold = true, .fg = .{ .index = 15 }, .bg = .{ .index = 24 } },
                .body_style = .{ .fg = .gray, .bg = .{ .index = 24 } },
                .progress_filled_style = .{ .fg = .{ .index = 10 }, .bg = .{ .index = 24 } },
                .progress_empty_style = .{ .dim = true, .fg = .gray, .bg = .{ .index = 24 } },
            });
        }
    }

    fn remainingProgress(self: *const App) f32 {
        const used = @as(f32, @floatFromInt(self.elapsed_ns)) / @as(f32, @floatFromInt(lifetime_ns));
        return 1.0 - used;
    }
};

fn toastRect(surface: *const chasen.Surface, width: u16, height: u16) chasen.Rect {
    const size = surface.size();
    return .{
        .col = size.width -| width,
        .row = 0,
        .width = @min(width, size.width),
        .height = @min(height, size.height),
    };
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const graphics = @import("chasen_graphics");
const ui = @import("chasen_ui");

// This example shows the display-only Badge component.
//
// Badge does not know whether its text is a status, count, mode, tag, or
// severity. The app chooses the text and optional marker, then passes both as
// plain borrowed labels for this view call.
const App = struct {
    badge: ui.Badge = ui.Badge.init(.{}),
    open_count: u16 = 12,

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Badge Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(0, 3, "Task", .{ .bold = true });
        // chasen-graphics provides the status glyph as data. Badge receives a
        // marker and text only; it does not know what "ready" means.
        var ready_area = sfc.child(.{ .col = 14, .row = 3, .width = 16, .height = 1 });
        self.badge.view(&ready_area, .{
            .marker = graphics.glyph.status.ok,
            .text = "READY",
            .marker_style = .{ .bold = true, .fg = .{ .index = 10 }, .bg = .{ .index = 22 } },
            .text_style = .{ .bold = true, .fg = .{ .index = 10 }, .bg = .{ .index = 22 } },
            .padding_style = .{ .bg = .{ .index = 22 } },
        });

        _ = sfc.borrowTextAt(0, 5, "Queue", .{ .bold = true });
        // Count formatting is app policy. Because Badge needs the formatted
        // value as a borrowed label, the app stores it in the frame arena
        // before passing it to the component. Direct formatted drawing should
        // use Surface.printAt instead.
        const count_text = try std.fmt.allocPrint(sfc.frameAllocator(), "{d} open", .{self.open_count});
        var queue_area = sfc.child(.{ .col = 14, .row = 5, .width = 16, .height = 1 });
        self.badge.view(&queue_area, .{
            .text = count_text,
            .text_style = .{ .bold = true, .fg = .{ .index = 14 }, .bg = .{ .index = 24 } },
            .padding_style = .{ .bg = .{ .index = 24 } },
        });

        _ = sfc.borrowTextAt(0, 7, "Mode", .{ .bold = true });
        // A badge can also be just a compact mode label. There is no marker
        // requirement and no status model hidden inside the component.
        var mode_area = sfc.child(.{ .col = 14, .row = 7, .width = 16, .height = 1 });
        self.badge.view(&mode_area, .{
            .text = "NORMAL",
            .text_style = .{ .bold = true, .fg = .{ .index = 15 }, .bg = .{ .index = 8 } },
            .padding_style = .{ .bg = .{ .index = 8 } },
        });

        _ = sfc.borrowTextAt(0, 9, "Fallback", .{ .bold = true });
        // ASCII status fallbacks use the same Badge API. The app decides which
        // glyph set fits the terminal or style it is targeting.
        var fallback_area = sfc.child(.{ .col = 14, .row = 9, .width = 16, .height = 1 });
        self.badge.view(&fallback_area, .{
            .marker = graphics.glyph.status.err_ascii,
            .text = "FAILED",
            .marker_style = .{ .bold = true, .fg = .{ .index = 9 } },
            .text_style = .{ .bold = true, .fg = .{ .index = 9 } },
        });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) .quit else null,
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        switch (msg) {
            .quit => ctx.quit(),
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

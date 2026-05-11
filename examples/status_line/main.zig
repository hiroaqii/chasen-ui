const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the display-only StatusLine component.
//
// StatusLine draws one row with left, center, and right text slots. It is useful
// for editor-style mode lines, footer hints, compact app state, or short command
// summaries. It does not own app state, focus, events, or layout policy.
const App = struct {
    top: ui.StatusLine = ui.StatusLine.init(.{
        .left = "NORMAL",
        .center = "status_line/main.zig",
        .right = "Esc: quit",
    }),
    footer: ui.StatusLine = ui.StatusLine.init(.{
        .left = "chasen-ui",
        .center = "display-only component",
        .right = "ready",
    }),
    narrow: ui.StatusLine = ui.StatusLine.init(.{
        .left = "left",
        .center = "center",
        .right = "right",
    }),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "StatusLine Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Esc: quit", .{ .fg = .gray });

        // A status line can be used near the top of an app to show mode,
        // current context, and a compact key hint.
        self.top.view(sfc, .{
            .col = 0,
            .row = 3,
            .width = 60,
            .style = .{ .bold = true },
            .fill_style = .{ .bg = .{ .index = 8 } },
        });

        _ = sfc.textAt(0, 5, "StatusLine only draws the supplied strings.", .{});
        _ = sfc.textAt(0, 6, "The app decides what each slot means.", .{ .dim = true });

        // When a narrow width causes slots to overlap, the component draws
        // left -> center -> right. The right slot is therefore the most likely
        // to remain visible for compact hints.
        _ = sfc.textAt(0, 9, "Narrow region", .{ .bold = true });
        self.narrow.view(sfc, .{
            .col = 0,
            .row = 10,
            .width = 12,
            .style = .{ .dim = true },
        });

        // A footer status line is the same component. The app chooses its row
        // and width; StatusLine does not know about the whole screen layout.
        self.footer.view(sfc, .{
            .col = 0,
            .row = 14,
            .width = 60,
            .style = .{ .fg = .gray },
            .fill_style = .{ .bg = .{ .index = 0 } },
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

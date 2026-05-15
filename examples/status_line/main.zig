const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const buffer_lines = [_][]const u8{
    "pub fn total(items: []const Item) u32 {",
    "    var sum: u32 = 0;",
    "    for (items) |item| sum += item.price;",
    "    return sum;",
    "}",
};

// This example shows StatusLine in an editor-like screen.
//
// StatusLine draws compact app state into left, center, and right slots. The
// app owns the editor state, cursor position, dirty flag, and keybindings.
const App = struct {
    title: ui.StatusLine = ui.StatusLine.init(.{
        .left = "NORMAL",
        .center = "src/invoice.zig",
        .right = "modified",
    }),
    footer: ui.StatusLine = ui.StatusLine.init(.{
        .left = "Ctrl+S save",
        .center = "Ln 12, Col 8",
        .right = "Esc quit",
    }),
    sidebar: ui.StatusLine = ui.StatusLine.init(.{
        .left = "git",
        .center = "+3 -1",
        .right = "main",
    }),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        // Top status line: editor mode, current file, and dirty state.
        self.title.view(sfc, .{
            .col = 0,
            .row = 0,
            .width = 60,
            .style = .{ .bold = true },
            .fill_style = .{ .bg = .{ .index = 8 } },
        });

        _ = sfc.textAt(0, 2, " 1  const std = @import(\"std\");", .{ .fg = .gray });
        for (buffer_lines, 0..) |line, index| {
            const row: u16 = @intCast(index + 3);
            _ = sfc.textAt(0, row, "    ", .{ .fg = .gray });
            _ = sfc.textAt(4, row, line, .{});
        }

        // A narrow status line can summarize a small panel.
        self.sidebar.view(sfc, .{
            .col = 0,
            .row = 10,
            .width = 24,
            .style = .{ .dim = true },
            .fill_style = .{ .bg = .{ .index = 0 } },
        });

        // Footer status line: command hints and cursor location.
        self.footer.view(sfc, .{
            .col = 0,
            .row = 14,
            .width = 60,
            .style = .{ .fg = .{ .index = 15 } },
            .fill_style = .{ .bg = .{ .index = 4 } },
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

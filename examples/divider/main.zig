const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the display-only Divider component.
//
// Divider is useful when an app wants to visually separate sections but does
// not need layout logic, focus, events, or retained state. The app still
// decides where each section begins and how long each line should be.
const App = struct {
    divider: ui.Divider = ui.Divider.init(.{}),

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        quit,
    };

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

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Divider Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(0, 3, "Account", .{ .bold = true });
        // A horizontal divider draws one glyph per cell on a single row. The
        // default glyph is "-", but callers can replace it with glyph option.
        var account_divider = sfc.child(.{ .col = 0, .row = 4, .width = 40, .height = 1 });
        self.divider.view(&account_divider, .{});
        _ = sfc.borrowTextAt(0, 5, "Username", .{});
        _ = sfc.borrowTextAt(14, 5, "hiro", .{ .dim = true });
        _ = sfc.borrowTextAt(0, 6, "Notifications", .{});
        _ = sfc.borrowTextAt(14, 6, "enabled", .{ .dim = true });

        _ = sfc.borrowTextAt(0, 9, "Two columns", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 11, "Left side", .{});
        _ = sfc.borrowTextAt(22, 11, "Right side", .{});
        // A vertical divider uses the same component with direction changed.
        // The default vertical glyph is "|".
        var column_divider = sfc.child(.{ .col = 18, .row = 10, .width = 1, .height = 4 });
        self.divider.view(&column_divider, .{
            .direction = .vertical,
        });

        _ = sfc.borrowTextAt(0, 16, "Custom glyph", .{ .bold = true });
        // The glyph is not fixed. Use a one-display-cell string when changing
        // it so each cell still lines up with the next one.
        var custom_divider = sfc.child(.{ .col = 0, .row = 17, .width = 40, .height = 1 });
        self.divider.view(&custom_divider, .{
            .glyph = "=",
            .style = .{ .bold = true },
        });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

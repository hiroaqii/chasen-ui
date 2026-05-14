const std = @import("std");
const chasen = @import("chasen");
const graphics = @import("chasen_graphics");
const ui = @import("chasen_ui");

// This example shows the display-only Alert component.
//
// Alert does not own severity, dismissal, or lifetime policy. The app chooses
// a marker, title, body, and styles for each alert, then decides whether the
// alert should be shown at all.
const App = struct {
    alert: ui.Alert = ui.Alert.init(.{}),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Alert Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Esc: quit", .{ .fg = .gray });

        // chasen-graphics provides severity-like glyphs as plain data. Alert
        // receives a marker and text only; it does not know what "warning"
        // means or when this message should disappear.
        self.alert.view(sfc, .{
            .col = 0,
            .row = 3,
            .width = 54,
            .marker = graphics.glyph.status.warn,
            .title = "Configuration warning",
            .body = "Theme file is missing; using defaults.",
            .marker_style = .{ .bold = true, .fg = .{ .index = 11 } },
            .title_style = .{ .bold = true, .fg = .{ .index = 11 } },
            .body_style = .{ .fg = .gray },
        });

        // Success and failure are app concepts. The component only draws the
        // marker/title/body selected by the app for this view.
        self.alert.view(sfc, .{
            .col = 0,
            .row = 7,
            .width = 54,
            .marker = graphics.glyph.status.ok,
            .title = "Saved",
            .body = "Profile changes were written.",
            .marker_style = .{ .bold = true, .fg = .{ .index = 10 } },
            .title_style = .{ .bold = true, .fg = .{ .index = 10 } },
            .body_style = .{ .fg = .gray },
        });

        // Body-only alerts are useful when the surrounding UI already supplies
        // the heading or severity. In that case the body starts at column zero.
        self.alert.view(sfc, .{
            .col = 0,
            .row = 11,
            .width = 54,
            .body = "Press Esc after reviewing these messages.",
            .body_style = .{ .dim = true },
        });

        // ASCII fallback glyphs use the same API. The app chooses the glyph
        // set that fits the terminal or style it is targeting.
        self.alert.view(sfc, .{
            .col = 0,
            .row = 14,
            .width = 54,
            .marker = graphics.glyph.status.err_ascii,
            .title = "Connection failed",
            .body = "Retry is managed by app state, not Alert.",
            .marker_style = .{ .bold = true, .fg = .{ .index = 9 } },
            .title_style = .{ .bold = true, .fg = .{ .index = 9 } },
            .body_style = .{ .fg = .gray },
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

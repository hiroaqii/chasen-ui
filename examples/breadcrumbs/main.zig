const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const path_items = [_][]const u8{
    "Home",
    "Projects",
    "Chasen",
    "UI",
};

// This example shows Breadcrumbs as a display-only navigation trail.
//
// Breadcrumbs borrows segment labels and draws the current location. The app
// owns route state, click/key navigation, and the content for the current path.
const App = struct {
    breadcrumbs: ui.Breadcrumbs = ui.Breadcrumbs.init(.{ .items = &path_items }),

    pub const Msg = union(enum) {
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
        _ = sfc.borrowTextAt(0, 0, "Breadcrumbs Example - app-owned route", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        // The component only draws the trail. The app decides what the route
        // means and which screen or document belongs to the current segment.
        var breadcrumbs_area = sfc.child(.{ .col = 0, .row = 3, .width = 48, .height = 1 });
        self.breadcrumbs.view(&breadcrumbs_area, .{
            .item_style = .{ .fg = .gray },
            .current_style = .{ .bold = true, .fg = .{ .index = 2 } },
        });

        _ = sfc.borrowTextAt(0, 5, "Current route", .{ .bold = true, .fg = .{ .index = 2 } });
        _ = sfc.borrowTextAt(0, 6, "package", .{ .fg = .gray });
        _ = sfc.borrowTextAt(12, 6, self.breadcrumbs.currentLabel() orelse "None", .{});
        _ = sfc.borrowTextAt(0, 8, "Breadcrumbs owns no navigation state", .{ .dim = true });
        _ = sfc.borrowTextAt(0, 9, "Route behavior stays in app", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

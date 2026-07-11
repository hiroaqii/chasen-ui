const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const menu_items = [_]ui.Menu.Item{
    .{ .label = "Dashboard", .shortcut = "overview" },
    .{ .label = "Projects", .shortcut = "work" },
    .{ .label = "Settings", .shortcut = "prefs" },
    .{ .label = "Help", .shortcut = "docs" },
};

// This example shows Menu with local focus and app-owned command policy.
//
// Menu owns only which command row is focused. The app decides what activation
// means; here it stores the activated index as the current screen.
const App = struct {
    menu: ui.Menu = ui.Menu.init(.{ .items = &menu_items }),
    active_index: ?usize = null,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        menu: ui.Menu.Msg,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) return .quit,
            else => {},
        }

        // App-level shortcuts get first chance. Remaining events are delegated
        // to Menu and wrapped in the app's Msg type.
        if (self.menu.handleEvent(event)) |msg| {
            return .{ .menu = msg };
        }
        return null;
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .menu => |menu_msg| switch (menu_msg) {
                // Movement is delegated to the component because focus is
                // local Menu state.
                .move_prev, .move_next => self.menu.update(menu_msg),
                // Activation is app policy. The app maps the index to a
                // screen, command, route, or side effect.
                .activate => |index| self.active_index = index,
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Menu Example - app-owned command policy", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down: move  Enter/Space: activate  Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(2, 3, "Command", .{ .fg = .gray });
        _ = sfc.borrowTextAt(20, 3, "Hint", .{ .fg = .gray });

        var menu_area = sfc.child(.{ .col = 0, .row = 4, .width = 34, .height = 6 });
        self.menu.view(&menu_area, .{
            .shortcut_col = 20,
            .focused_style = .{ .bold = true, .fg = .{ .index = 14 } },
        });

        _ = sfc.borrowTextAt(40, 4, "App screen", .{ .bold = true, .fg = .{ .index = 14 } });
        _ = sfc.borrowTextAt(40, 5, "active", .{ .fg = .gray });
        if (self.active_index) |index| {
            _ = sfc.borrowTextAt(50, 5, menu_items[index].label, .{ .fg = .{ .index = 14 } });
        } else {
            _ = sfc.borrowTextAt(50, 5, "None", .{ .dim = true });
        }

        _ = sfc.borrowTextAt(40, 7, "Menu owns focus only", .{ .dim = true });
        _ = sfc.borrowTextAt(40, 8, "Activation stays in app", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

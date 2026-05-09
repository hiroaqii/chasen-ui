const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const items = [_][]const u8{
    "Dashboard",
    "Projects",
    "Settings",
    "Help",
};

// This example shows a List component with local focus and app-owned
// selection policy.
//
// List owns only which item is focused. The app owns what activation means:
// here Enter/Space stores the focused index as the selected index.
const App = struct {
    list: ui.List = ui.List.init(.{ .items = &items }),
    selected_index: ?usize = null,

    pub const Msg = union(enum) {
        list: ui.List.Msg,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .list => |list_msg| switch (list_msg) {
                // Movement is delegated to the component because the focused
                // index is local List state.
                .move_prev, .move_next => self.list.update(list_msg),
                // Activation is app policy. The component reports the index;
                // the app decides to store it as the selected item.
                .activate => |index| self.selected_index = index,
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "List Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Up/Down: move  Enter/Space: select  Esc: quit", .{ .fg = .gray });

        self.list.view(sfc, .{
            .col = 0,
            .row = 3,
            .width = 24,
            .height = 6,
            .selected_index = self.selected_index,
        });

        _ = sfc.textAt(0, 10, "Selected:", .{ .fg = .gray });
        if (self.selected_index) |index| {
            _ = sfc.textAt(10, 10, items[index], .{});
        } else {
            _ = sfc.textAt(10, 10, "None", .{ .dim = true });
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) return .quit,
            else => {},
        }

        // App-level shortcuts get first chance. Remaining events are delegated
        // to List and wrapped in the app's Msg type.
        if (self.list.handleEvent(event)) |msg| {
            return .{ .list = msg };
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

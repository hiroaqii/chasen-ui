const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const items = [_][]const u8{
    "Dashboard",
    "Projects",
    "Settings",
    "Help",
};

// This example shows SelectableList with local focus and selected state.
//
// SelectableList owns the selected index after activation. The app still
// decides what the selected value means for the surrounding screen.
const App = struct {
    list: ui.SelectableList = ui.SelectableList.init(.{ .items = &items }),

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        list: ui.SelectableList.Msg,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) return .quit,
            else => {},
        }

        // App-level shortcuts get first chance. Remaining events are delegated
        // to SelectableList and wrapped in the app's Msg type.
        if (self.list.handleEvent(event)) |msg| {
            return .{ .list = msg };
        }
        return null;
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .list => |list_msg| self.list.update(list_msg),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "SelectableList Example - component-owned selection", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down: move  Enter/Space: select  Esc: quit", .{ .fg = .gray });

        // Selection storage is local to SelectableList. Meaning stays in the
        // app, which decides how to use the selected label below.
        var list_area = sfc.child(.{ .col = 0, .row = 3, .width = 24, .height = 6 });
        self.list.view(&list_area, .{
            .focused_style = .{ .bold = true },
            .selected_style = .{ .bold = true, .fg = .{ .index = 14 } },
            .focused_selected_style = .{ .bold = true, .fg = .{ .index = 14 } },
        });

        _ = sfc.borrowTextAt(30, 3, "Component state", .{ .bold = true, .fg = .{ .index = 14 } });
        _ = sfc.borrowTextAt(30, 4, "selected_index", .{ .fg = .gray });
        if (self.list.selectedLabel()) |label| {
            _ = sfc.borrowTextAt(45, 4, label, .{ .fg = .{ .index = 14 } });
        } else {
            _ = sfc.borrowTextAt(45, 4, "None", .{ .dim = true });
        }

        _ = sfc.borrowTextAt(30, 6, "SelectableList owns focus", .{ .dim = true });
        _ = sfc.borrowTextAt(30, 7, "and selected index", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

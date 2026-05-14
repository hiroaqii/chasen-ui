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
        list: ui.SelectableList.Msg,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .list => |list_msg| self.list.update(list_msg),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "SelectableList Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Up/Down: move  Enter/Space: select  Esc: quit", .{ .fg = .gray });

        // Selection storage is local to SelectableList. Meaning stays in the
        // app, which decides how to use the selected label below.
        self.list.view(sfc, .{
            .col = 0,
            .row = 3,
            .width = 24,
            .height = 6,
        });

        _ = sfc.textAt(0, 10, "Selected:", .{ .fg = .gray });
        if (self.list.selectedLabel()) |label| {
            _ = sfc.textAt(10, 10, label, .{});
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
        // to SelectableList and wrapped in the app's Msg type.
        if (self.list.handleEvent(event)) |msg| {
            return .{ .list = msg };
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

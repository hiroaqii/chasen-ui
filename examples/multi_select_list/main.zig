const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const items = [_][]const u8{
    "Keyboard",
    "Mouse",
    "Monitor",
    "Headphones",
};

// This example shows MultiSelectList with local focus and multi-selection.
//
// MultiSelectList owns which items are checked. The app still decides what the
// selected items mean and how to apply them to the surrounding workflow.
const App = struct {
    list: ui.MultiSelectList = ui.MultiSelectList.init(.{ .items = &items }),

    pub const Msg = union(enum) {
        list: ui.MultiSelectList.Msg,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .list => |list_msg| self.list.update(list_msg),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "MultiSelectList Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Up/Down: move  Enter/Space: toggle  Esc: quit", .{ .fg = .gray });

        // The component stores checked items locally. The app reads the count
        // and can decide what selected accessories mean.
        self.list.view(sfc, .{
            .col = 0,
            .row = 3,
            .width = 28,
            .height = 6,
        });

        _ = sfc.textAt(34, 3, "Selected accessories", .{ .bold = true, .fg = .{ .index = 2 } });
        _ = sfc.textAt(34, 4, "count", .{ .fg = .gray });
        // printAt formats into the frame arena before drawing, so this avoids
        // the short-lived buffer lifetime issue of allocPrint(...) + textAt(...).
        _ = try sfc.printAt(42, 4, .{ .fg = .{ .index = 2 } }, "{d}", .{self.list.selectedCount()});

        var row: u16 = 6;
        for (items, 0..) |item, index| {
            if (!self.list.isSelected(index)) continue;
            _ = sfc.textAt(34, row, item, .{});
            row += 1;
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) return .quit,
            else => {},
        }

        // App-level shortcuts get first chance. Remaining events are delegated
        // to MultiSelectList and wrapped in the app's Msg type.
        if (self.list.handleEvent(event)) |msg| {
            return .{ .list = msg };
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const theme_items = [_][]const u8{
    "System",
    "Light",
    "Dark",
};

const density_items = [_][]const u8{
    "Compact",
    "Comfortable",
    "Spacious",
};

// This example shows the one-line Select component.
//
// Select owns the selected index for a fixed set of borrowed labels. The app
// still owns focus routing and decides what activation means. In this example,
// Tab moves between two Select components, arrow keys change the focused
// Select, and Enter/Space copies the focused value into a saved preview.
const App = struct {
    theme: ui.Select = ui.Select.init(.{ .items = &theme_items }),
    density: ui.Select = ui.Select.init(.{ .items = &density_items, .selected_index = 1 }),
    focus: ui.FocusList = ui.FocusList.init(2),
    saved_theme: usize = 0,
    saved_density: usize = 1,

    pub const Msg = union(enum) {
        theme: ui.Select.Msg,
        density: ui.Select.Msg,
        move_focus,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .theme => |select_msg| switch (select_msg) {
                .move_prev, .move_next, .set_selected => self.theme.update(select_msg),
                .activate => |index| self.saved_theme = index,
            },
            .density => |select_msg| switch (select_msg) {
                .move_prev, .move_next, .set_selected => self.density.update(select_msg),
                .activate => |index| self.saved_density = index,
            },
            .move_focus => {
                if (self.focus.isFocused(0)) {
                    self.focus.moveNext();
                } else {
                    self.focus.movePrev();
                }
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Select Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Tab: focus  Left/Right/Up/Down: change  Enter/Space: save  Esc: quit", .{ .fg = .gray });

        _ = sfc.textAt(0, 3, "Theme", labelStyle(self.focus.isFocused(0)));
        self.theme.view(sfc, .{
            .col = 14,
            .row = 3,
            .width = 20,
            .item_style = itemStyle(self.focus.isFocused(0)),
            .show_cursor = self.focus.isFocused(0),
        });

        _ = sfc.textAt(0, 5, "Density", labelStyle(self.focus.isFocused(1)));
        self.density.view(sfc, .{
            .col = 14,
            .row = 5,
            .width = 20,
            .item_style = itemStyle(self.focus.isFocused(1)),
            .show_cursor = self.focus.isFocused(1),
        });

        _ = sfc.textAt(0, 8, "Saved values", .{ .bold = true });
        _ = sfc.textAt(0, 9, "Theme:", .{ .fg = .gray });
        _ = sfc.textAt(10, 9, theme_items[self.saved_theme], .{});
        _ = sfc.textAt(0, 10, "Density:", .{ .fg = .gray });
        _ = sfc.textAt(10, 10, density_items[self.saved_density], .{});
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.tab, .{})) return .move_focus;
            },
            else => {},
        }

        // The app owns focus routing. Only the focused Select receives events.
        if (self.focus.isFocused(0)) {
            if (self.theme.handleEvent(event)) |msg| return .{ .theme = msg };
        } else if (self.focus.isFocused(1)) {
            if (self.density.handleEvent(event)) |msg| return .{ .density = msg };
        }
        return null;
    }
};

fn labelStyle(focused: bool) chasen.TextStyle {
    return if (focused) .{ .bold = true } else .{ .fg = .gray };
}

fn itemStyle(focused: bool) chasen.TextStyle {
    return if (focused) .{ .bold = true } else .{};
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

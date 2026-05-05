const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const App = struct {
    // Checkbox does not allocate, so the app can store components directly in
    // its model without an init/deinit hook.
    checkboxes: [3]ui.Checkbox = .{
        ui.Checkbox.init(.{ .label = "Enable notifications" }),
        ui.Checkbox.init(.{ .label = "Use compact layout" }),
        ui.Checkbox.init(.{ .label = "Show timestamps" }),
    },
    // FocusList tracks which row is selected. Keep this length in sync with
    // checkboxes. The app still owns event routing.
    focus: ui.FocusList = ui.FocusList.init(3),

    pub const Msg = union(enum) {
        checkbox: ui.Checkbox.Msg,
        move_up,
        move_down,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            // Component messages still pass through the app update. The app
            // decides which checkbox receives the message.
            .checkbox => |checkbox_msg| self.checkboxes[self.focus.focused()].update(checkbox_msg),
            .move_up => self.focus.movePrev(),
            .move_down => self.focus.moveNext(),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Checkbox Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Up/Down: move  Space/Enter: toggle  Esc: quit", .{ .fg = .gray });

        for (&self.checkboxes, 0..) |*checkbox, i| {
            // Only the selected checkbox shows the terminal cursor. This keeps
            // focus behavior explicit in the app until a shared focus model
            // exists.
            checkbox.view(sfc, .{
                .col = 0,
                .row = @intCast(3 + i),
                .width = 40,
                .show_cursor = self.focus.isFocused(i),
            });
        }

        _ = sfc.textAt(0, 7, "Checked:", .{ .fg = .gray });
        for (self.checkboxes, 0..) |checkbox, i| {
            _ = sfc.textAt(@intCast(9 + i * 5), 7, if (checkbox.checked()) "yes" else "no", .{});
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts and navigation get first chance. Up/Down changes
        // the selected row instead of being forwarded to a checkbox.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{})) return .move_up;
                if (key.matches(chasen.Key.down, .{})) return .move_down;
            },
            else => {},
        }

        // Component-level key handling is delegated to the selected checkbox,
        // then wrapped in the app's Msg type so update remains the only
        // mutation point.
        if (self.checkboxes[self.focus.focused()].handleEvent(event)) |msg| {
            return .{ .checkbox = msg };
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

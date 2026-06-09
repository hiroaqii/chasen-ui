const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows two Button components sharing app-owned focus state.
// Buttons emit `.press`; the app decides what each press means.
const Action = enum {
    save,
    cancel,
};

const App = struct {
    focus: ui.FocusList = ui.FocusList.init(2),
    save_button: ui.Button = ui.Button.init(.{ .label = "Save" }),
    cancel_button: ui.Button = ui.Button.init(.{ .label = "Cancel" }),
    last_action: ?Action = null,

    pub const Msg = union(enum) {
        save: ui.Button.Msg,
        cancel: ui.Button.Msg,
        move_prev,
        move_next,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.left, .{}) or key.matches(chasen.Key.up, .{})) return .move_prev;
                if (key.matches(chasen.Key.right, .{}) or key.matches(chasen.Key.down, .{})) return .move_next;
            },
            else => {},
        }

        return switch (self.focus.focused()) {
            0 => if (self.save_button.handleEvent(event)) |msg| .{ .save = msg } else null,
            1 => if (self.cancel_button.handleEvent(event)) |msg| .{ .cancel = msg } else null,
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .save => |button_msg| switch (button_msg) {
                .press => self.last_action = .save,
            },
            .cancel => |button_msg| switch (button_msg) {
                .press => self.last_action = .cancel,
            },
            .move_prev => self.focus.movePrev(),
            .move_next => self.focus.moveNext(),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Button Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Arrows: move  Enter/Space: press  Esc: quit", .{ .fg = .gray });

        // The focused button gets both focused styling and the terminal cursor
        // in this example. The two options are separate so apps can split them
        // later if their focus and cursor policies differ.
        var save_area = sfc.child(.{ .col = 0, .row = 3, .width = 8, .height = 1 });
        self.save_button.view(&save_area, .{
            .focused = self.focus.isFocused(0),
            .show_cursor = self.focus.isFocused(0),
        });
        var cancel_area = sfc.child(.{ .col = 10, .row = 3, .width = 10, .height = 1 });
        self.cancel_button.view(&cancel_area, .{
            .focused = self.focus.isFocused(1),
            .show_cursor = self.focus.isFocused(1),
        });

        if (self.last_action) |action| {
            const label = switch (action) {
                .save => "Pressed: Save",
                .cancel => "Pressed: Cancel",
            };
            _ = sfc.borrowTextAt(0, 5, label, .{ .fg = .{ .index = 2 } });
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

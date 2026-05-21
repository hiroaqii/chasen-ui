const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const App = struct {
    // Radio does not allocate. The app owns group policy: when one option is
    // selected, the app clears the other options.
    radios: [3]ui.Radio = .{
        ui.Radio.init(.{ .selected = true, .label = "Small" }),
        ui.Radio.init(.{ .label = "Medium" }),
        ui.Radio.init(.{ .label = "Large" }),
    },
    // FocusList tracks which option receives input. Keep this length in sync
    // with radios.
    focus: ui.FocusList = ui.FocusList.init(3),

    pub const Msg = union(enum) {
        radio: ui.Radio.Msg,
        move_up,
        move_down,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .radio => |radio_msg| {
                if (radio_msg == .select) {
                    self.selectFocused();
                } else {
                    self.radios[self.focus.focused()].update(radio_msg);
                }
            },
            .move_up => self.focus.movePrev(),
            .move_down => self.focus.moveNext(),
            .quit => ctx.quit(),
        }
    }

    fn selectFocused(self: *App) void {
        for (&self.radios, 0..) |*radio, i| {
            radio.update(.{ .set_selected = self.focus.isFocused(i) });
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Radio Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down: move  Space/Enter: select  Esc: quit", .{ .fg = .gray });

        for (&self.radios, 0..) |*radio, i| {
            var radio_area = sfc.child(.{ .col = 0, .row = @intCast(3 + i), .width = 40, .height = 1 });
            radio.view(&radio_area, .{
                .show_cursor = self.focus.isFocused(i),
            });
        }

        _ = sfc.borrowTextAt(0, 7, "Selected:", .{ .fg = .gray });
        for (self.radios) |radio| {
            if (radio.selected()) {
                _ = sfc.borrowTextAt(10, 7, radio.label, .{});
                break;
            }
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts and navigation get first chance. Up/Down changes
        // which radio option receives input.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{})) return .move_up;
                if (key.matches(chasen.Key.down, .{})) return .move_down;
            },
            else => {},
        }

        // Component-level key handling is delegated to the focused radio, then
        // wrapped in the app's Msg type. The app update owns group policy.
        if (self.radios[self.focus.focused()].handleEvent(event)) |msg| {
            return .{ .radio = msg };
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

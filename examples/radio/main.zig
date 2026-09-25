const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows a Radio group built from independent Radio components.
//
// Radio owns the single option state. The app owns group policy: selecting one
// option clears the rest.
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
    marker: ui.Radio.Marker = .circle,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        radio: ui.Radio.Msg,
        move_up,
        move_down,
        set_marker: ui.Radio.Marker,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts and navigation get first chance. Up/Down changes
        // which radio option receives input.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{})) return .move_up;
                if (key.matches(chasen.Key.down, .{})) return .move_down;
                if (key.matches('1', .{})) return .{ .set_marker = .circle };
                if (key.matches('2', .{})) return .{ .set_marker = .ring };
                if (key.matches('3', .{})) return .{ .set_marker = .diamond };
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
            .set_marker => |marker| self.marker = marker,
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        // Keep keyboard focus separate from the selected radio marker.
        sfc.hideCursor();
        _ = sfc.borrowTextAt(0, 0, "Radio Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down: move  Space/Enter: select  Esc: quit", .{ .fg = .gray });
        _ = sfc.borrowTextAt(0, 2, "1: circle  2: ring  3: diamond", .{ .fg = .gray });

        for (&self.radios, 0..) |*radio, i| {
            const row: u16 = @intCast(4 + i);
            _ = sfc.borrowTextAt(0, row, if (self.focus.isFocused(i)) ">" else " ", .{ .bold = true });
            var radio_area = sfc.child(.{ .col = 2, .row = row, .width = 40, .height = 1 });
            radio.view(&radio_area, .{
                .marker = self.marker,
                .show_cursor = false,
            });
        }

        _ = sfc.borrowTextAt(0, 8, "Selected:", .{ .fg = .gray });
        for (self.radios) |radio| {
            if (radio.selected()) {
                _ = sfc.borrowTextAt(10, 8, radio.label, .{});
                break;
            }
        }
    }

    fn selectFocused(self: *App) void {
        for (&self.radios, 0..) |*radio, i| {
            radio.update(.{ .set_selected = self.focus.isFocused(i) });
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows Overlay as display-only foreground container chrome.
//
// Overlay resolves placement, optionally clears only its own rectangle, draws
// Panel chrome, and returns a content surface. The app still owns visibility,
// key routing, selected state, and confirmation/cancellation behavior.
const App = struct {
    picker_open: bool = false,
    focused_index: usize = 0,
    selected_index: usize = 0,

    const items = [_][]const u8{ "default", "blue", "orange", "mono", "matcha" };

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        open_picker,
        cancel_picker,
        confirm_picker,
        move_prev,
        move_next,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| {
                if (self.picker_open) {
                    if (key.matches(chasen.Key.escape, .{})) return .cancel_picker;
                    if (key.matches(chasen.Key.enter, .{})) return .confirm_picker;
                    if (key.matches(chasen.Key.up, .{}) or key.codepoint == 'k') return .move_prev;
                    if (key.matches(chasen.Key.down, .{}) or key.codepoint == 'j') return .move_next;
                    return null;
                }
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.enter, .{})) return .open_picker;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .open_picker => {
                self.focused_index = self.selected_index;
                self.picker_open = true;
            },
            .cancel_picker => self.picker_open = false,
            .confirm_picker => {
                self.selected_index = self.focused_index;
                self.picker_open = false;
            },
            .move_prev => {
                if (self.focused_index > 0) self.focused_index -= 1;
            },
            .move_next => {
                if (self.focused_index + 1 < items.len) self.focused_index += 1;
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        _ = sfc.borrowTextAt(0, 0, "Overlay Example - picker popup", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, if (self.picker_open) "Up/Down or j/k: choose  Enter: apply  Esc: cancel" else "Enter: change theme  Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(0, 3, "Settings", .{ .bold = true, .fg = .{ .index = 6 } });
        _ = sfc.borrowTextAt(0, 5, "Color Theme:", .{});
        _ = sfc.borrowTextAt(15, 5, items[self.selected_index], .{ .bold = true });
        _ = sfc.borrowTextAt(0, 7, "The app owns picker state, Enter/Esc behavior, and the selected value.", .{ .dim = true });
        _ = sfc.borrowTextAt(0, 8, "Overlay only provides the foreground frame and content surface.", .{ .dim = true });

        if (!self.picker_open) return;

        var overlay = ui.Overlay.frame(sfc, .{
            .size = .{ .width = @min(size.width, 32), .height = @min(size.height, 10) },
            .placement = .center,
            .clear_background = true,
            .panel = .{
                .title = "Color Theme",
                .border = .rounded,
                .border_style = .{ .fg = .gray },
                .title_style = .{ .bold = true, .fg = .{ .index = 6 } },
            },
        }) orelse return;
        overlay.view();

        var content = overlay.contentSurface();
        // The picker list is regular app-owned drawing. Overlay provides the
        // foreground frame but does not own item focus or selected state.
        for (items, 0..) |item, index| {
            const row: u16 = @intCast(index);
            if (row >= content.size().height) break;
            const focused = index == self.focused_index;
            const selected = index == self.selected_index;
            _ = content.borrowTextAt(0, row, if (focused) "> " else "  ", .{ .bold = focused });
            _ = content.borrowTextAt(2, row, if (selected) "*" else " ", if (selected) .{ .fg = .{ .index = 6 } } else .{ .fg = .gray });
            _ = content.borrowTextAt(4, row, item, if (focused) .{ .fg = .{ .index = 6 }, .bold = true } else .{});
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the display-only Help component.
//
// Help does not own keybindings or command policy. The app decides which
// shortcuts are active and passes the visible key/action labels for this view.
const App = struct {
    const main_help_items = [_]ui.Help.Item{
        .{ .key = "Up/Down", .action = "move" },
        .{ .key = "Enter", .action = "select" },
        .{ .key = "Esc", .action = "quit" },
    };

    const compact_help_items = [_]ui.Help.Item{
        .{ .key = "?", .action = "help" },
        .{ .key = "Ctrl+S", .action = "save" },
    };

    main_help: ui.Help = ui.Help.init(.{ .items = &main_help_items }),
    compact_help: ui.Help = ui.Help.init(.{ .items = &compact_help_items }),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Help Example", .{ .bold = true });

        // The app chooses the shortcuts and action wording. Help only draws a
        // compact one-line summary of the borrowed item list.
        var main_help_area = sfc.child(.{ .col = 0, .row = 3, .width = 56, .height = 1 });
        self.main_help.view(&main_help_area, .{});

        // Separators, gaps, and styles are view concerns. They do not change
        // the meaning of the shortcuts or how input is routed.
        var compact_help_area = sfc.child(.{ .col = 0, .row = 5, .width = 56, .height = 1 });
        self.compact_help.view(&compact_help_area, .{
            .separator = " ",
            .item_gap = 4,
            .key_style = .{ .bold = true, .fg = .{ .index = 14 } },
            .action_style = .{ .fg = .gray },
        });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) .quit else null,
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        switch (msg) {
            .quit => ctx.quit(),
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

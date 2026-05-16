const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows Box as borderless container space.
//
// Box can fill a rectangle and calculate padded content bounds. It does not
// draw a border, own children, route focus, or decide what the content means.
// Use Panel when the container needs visible chrome; use Box when the app only
// needs a filled or padded region for composition.
const App = struct {
    box: ui.Box = ui.Box.init(.{}),
    paragraph: ui.Paragraph = ui.Paragraph.init(.{
        .text = "Box is intentionally quieter than Panel. It gives app code a padded inner rectangle and optional background fill, then gets out of the way.",
    }),
    help: ui.Help = ui.Help.init(.{
        .items = &.{
            .{ .key = "Esc", .action = "quit" },
            .{ .key = "Box", .action = "padding + fill" },
        },
    }),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        const box_opts = ui.Box.ViewOptions{
            .col = 0,
            .row = 3,
            .width = @min(size.width, 62),
            .height = @min(size.height -| @min(size.height, 3), 10),
            .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
            .fill = true,
            .fill_style = .{ .bg = .{ .index = 236 } },
        };

        _ = sfc.textAt(0, 0, "Box Example - borderless composition", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Esc: quit", .{ .fg = .gray });

        self.box.view(sfc, box_opts);

        const content = ui.Box.contentRect(sfc, box_opts);
        if (content.width == 0 or content.height == 0) return;

        // The content is still normal app-owned drawing. Box does not know
        // that this area is a summary card, a form section, or a detail pane.
        _ = sfc.textAt(content.col, content.row, "Summary", .{ .bold = true, .fg = .{ .index = 6 } });
        _ = sfc.textAt(content.col, content.row + 1, "Container", .{ .fg = .gray });
        _ = sfc.textAt(content.col + 12, content.row + 1, "Box", .{});
        _ = sfc.textAt(content.col, content.row + 2, "Chrome", .{ .fg = .gray });
        _ = sfc.textAt(content.col + 12, content.row + 2, "none", .{});

        if (content.height > 5) {
            self.paragraph.view(sfc, .{
                .col = content.col,
                .row = content.row + 4,
                .width = content.width,
                .height = content.height - 5,
                .style = .{ .fg = .gray },
            });
        }

        if (content.height > 0) {
            var help_area = sfc.child(.{
                .col = content.col,
                .row = content.row + content.height - 1,
                .width = content.width,
                .height = 1,
            });
            self.help.view(&help_area, .{
                .key_style = .{ .bold = true, .fg = .{ .index = 6 } },
                .action_style = .{ .dim = true },
            });
        }
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

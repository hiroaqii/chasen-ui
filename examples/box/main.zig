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
    const help_items = [_]ui.key_hint.Item{
        ui.key_hint.item("Esc", "quit"),
        ui.key_hint.item("Box", "padding + fill"),
    };

    box: ui.Box = ui.Box.init(.{}),
    paragraph: ui.Paragraph = ui.Paragraph.init(.{
        .text = "Box is intentionally quieter than Panel. It gives app code a padded inner rectangle and optional background fill, then gets out of the way.",
    }),

    pub const Msg = union(enum) {
        quit,
    };

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

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        const box_opts = ui.Box.ViewOptions{
            .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
            .fill = true,
            .fill_style = .{ .bg = .{ .index = 236 } },
        };

        _ = sfc.borrowTextAt(0, 0, "Box Example - borderless composition", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        var box_area = sfc.child(.{
            .col = 0,
            .row = 3,
            .width = @min(size.width, 62),
            .height = @min(size.height -| @min(size.height, 3), 10),
        });
        self.box.view(&box_area, box_opts);

        const content = ui.Box.contentRect(&box_area, box_opts);
        if (content.width == 0 or content.height == 0) return;
        var content_area = box_area.child(content);

        // The content is still normal app-owned drawing. Box does not know
        // that this area is a summary card, a form section, or a detail pane.
        _ = content_area.borrowTextAt(0, 0, "Summary", .{ .bold = true, .fg = .{ .index = 6 } });
        _ = content_area.borrowTextAt(0, 1, "Container", .{ .fg = .gray });
        _ = content_area.borrowTextAt(12, 1, "Box", .{});
        _ = content_area.borrowTextAt(0, 2, "Chrome", .{ .fg = .gray });
        _ = content_area.borrowTextAt(12, 2, "none", .{});

        if (content.height > 5) {
            var paragraph_area = content_area.child(.{
                .col = 0,
                .row = 4,
                .width = content_area.size().width,
                .height = content.height - 5,
            });
            self.paragraph.view(&paragraph_area, .{
                .style = .{ .fg = .gray },
            });
        }

        if (content.height > 0) {
            var help_area = content_area.child(.{
                .col = 0,
                .row = content.height - 1,
                .width = content_area.size().width,
                .height = 1,
            });
            _ = try ui.key_hint.draw(&help_area, 0, 0, &help_items, .{
                .key_style = .{ .bold = true, .fg = .{ .index = 6 } },
                .action_style = .{ .dim = true },
            });
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows Panel as display-only container chrome.
//
// Panel draws a border and optional title. It does not own child components,
// focus, scrolling, or the meaning of the content inside the rectangle. The
// app asks Panel for a content rect, then composes regular drawing and other
// chasen-ui components inside that area.
const App = struct {
    panel: ui.Panel = ui.Panel.init(.{}),
    status: ui.StatusLine = ui.StatusLine.init(.{
        .left = "Panel",
        .center = "display-only",
        .right = "content is app-owned",
    }),
    paragraph: ui.Paragraph = ui.Paragraph.init(.{
        .text = "The panel owns border chrome only. App code still decides what content belongs inside, how it is updated, and which child components are drawn.",
    }),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        const panel_width = @min(size.width, 64);
        const panel_height = @min(size.height -| @min(size.height, 3), 12);
        const panel_opts = ui.Panel.ViewOptions{
            .col = 0,
            .row = 3,
            .width = panel_width,
            .height = panel_height,
            .title = "Project Summary",
            .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
            .border = .rounded,
            .border_style = .{ .fg = .gray },
            .title_style = .{ .bold = true, .fg = .{ .index = 6 } },
        };

        _ = sfc.textAt(0, 0, "Panel Example - app-composed content", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Esc: quit", .{ .fg = .gray });

        self.panel.view(sfc, panel_opts);

        const content = ui.Panel.contentRect(sfc, panel_opts);
        if (content.width == 0 or content.height == 0) return;

        // The content rectangle is normal app-owned space. Panel does not draw
        // these labels, the paragraph, or the status line; it only gives the app
        // a predictable inner area after border and padding are removed.
        _ = sfc.textAt(content.col, content.row, "Name", .{ .fg = .gray });
        _ = sfc.textAt(content.col + 12, content.row, "chasen-ui", .{});
        _ = sfc.textAt(content.col, content.row + 1, "Scope", .{ .fg = .gray });
        _ = sfc.textAt(content.col + 12, content.row + 1, "structure component", .{});

        if (content.height > 4) {
            self.paragraph.view(sfc, .{
                .col = content.col,
                .row = content.row + 3,
                .width = content.width,
                .height = content.height - 4,
                .style = .{ .fg = .gray },
            });
        }

        if (content.height > 0) {
            self.status.view(sfc, .{
                .col = content.col,
                .row = content.row + content.height - 1,
                .width = content.width,
                .style = .{ .dim = true },
                .fill_style = .{ .dim = true },
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

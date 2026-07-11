const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows Panel as display-only container chrome.
//
// Panel draws a border and optional title. It does not own child components,
// focus, scrolling, or the meaning of the content inside the rectangle. The
// app asks Panel for a frame, then composes regular drawing and other
// chasen-ui components inside that frame's content surface.
const App = struct {
    status: ui.StatusLine = ui.StatusLine.init(.{
        .left = "Panel",
        .center = "display-only",
        .right = "content is app-owned",
    }),
    paragraph: ui.Paragraph = ui.Paragraph.init(.{
        .text = "The panel owns border chrome only. App code still decides what content belongs inside, how it is updated, and which child components are drawn.",
    }),

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

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
        const panel_width = @min(size.width, 64);
        const panel_height = @min(size.height -| @min(size.height, 3), 12);
        const panel_opts = ui.Panel.ViewOptions{
            .title = "Project Summary",
            .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
            .border = .rounded,
            .border_style = .{ .fg = .gray },
            .title_style = .{ .bold = true, .fg = .{ .index = 6 } },
        };

        _ = sfc.borrowTextAt(0, 0, "Panel Example - app-composed content", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        var panel_area = sfc.child(.{ .col = 0, .row = 3, .width = panel_width, .height = panel_height });
        const frame = ui.Panel.frame(&panel_area, panel_opts);
        frame.view();

        const content = frame.contentSize();
        if (content.width == 0 or content.height == 0) return;
        var content_area = frame.contentSurface();

        // The content surface is normal app-owned space. Panel does not draw
        // these labels, the paragraph, or the status line; it only gives the app
        // a predictable inner area after border and padding are removed.
        _ = content_area.borrowTextAt(0, 0, "Name", .{ .fg = .gray });
        _ = content_area.borrowTextAt(12, 0, "chasen-ui", .{});
        _ = content_area.borrowTextAt(0, 1, "Scope", .{ .fg = .gray });
        _ = content_area.borrowTextAt(12, 1, "structure component", .{});

        if (content.height > 4) {
            var paragraph_area = content_area.child(.{
                .col = 0,
                .row = 3,
                .width = content_area.size().width,
                .height = content.height - 4,
            });
            self.paragraph.view(&paragraph_area, .{
                .style = .{ .fg = .gray },
            });
        }

        if (content.height > 0) {
            var status_area = content_area.child(.{
                .col = 0,
                .row = content.height - 1,
                .width = content_area.size().width,
                .height = 1,
            });
            self.status.view(&status_area, .{
                .style = .{ .dim = true },
                .fill_style = .{ .dim = true },
            });
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const sections = [_]ui.Accordion.Section{
    .{ .title = "Project", .expanded = true, .body_height = 3 },
    .{ .title = "Filters", .expanded = false, .body_height = 2 },
    .{ .title = "Activity", .expanded = true, .body_height = 4 },
};

// This example shows Accordion as display-only section chrome.
//
// Accordion draws header rows and reserves body rectangles for expanded
// sections. The app owns expansion state, focus, keyboard handling, and all
// content drawn inside those body rectangles.
const App = struct {
    accordion: ui.Accordion = ui.Accordion.init(.{ .sections = &sections }),
    project_summary: ui.Paragraph = ui.Paragraph.init(.{
        .text = "Accordion owns the header stack only. Body content remains ordinary app drawing, so each section can contain labels, lists, forms, or other components.",
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
        const width = @min(size.width, 72);
        const height = size.height -| @min(size.height, 4);
        const opts = ui.Accordion.ViewOptions{
            .glyphs = .rounded,
            .expanded_marker_style = .{ .bold = true, .fg = .{ .index = 2 } },
            .collapsed_marker_style = .{ .fg = .gray },
            .expanded_title_style = .{ .bold = true },
            .collapsed_title_style = .{ .fg = .gray },
        };

        _ = sfc.borrowTextAt(0, 0, "Accordion Example - app-owned sections", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        var accordion_area = sfc.child(.{ .col = 0, .row = 3, .width = width, .height = height });
        self.accordion.view(&accordion_area, opts);

        // The app asks Accordion where each expanded body lives, then composes
        // regular drawing and other components inside those rectangles. The
        // component does not know what the body content means.
        const project_body = self.accordion.bodyRect(&accordion_area, 0);
        if (project_body.height > 0) {
            var project_body_area = accordion_area.child(.{
                .col = project_body.col + 2,
                .row = project_body.row,
                .width = project_body.width -| 2,
                .height = project_body.height,
            });
            self.project_summary.view(&project_body_area, .{
                .style = .{ .fg = .gray },
            });
        }

        const activity_body = self.accordion.bodyRect(&accordion_area, 2);
        if (activity_body.height > 0) {
            var activity_body_area = accordion_area.child(.{
                .col = activity_body.col + 2,
                .row = activity_body.row,
                .width = activity_body.width -| 2,
                .height = activity_body.height,
            });
            _ = activity_body_area.borrowTextAt(0, 0, "09:41  Added Accordion component", .{});
            if (activity_body.height > 1) {
                _ = activity_body_area.borrowTextAt(0, 1, "09:43  Wrote app-composed example", .{ .fg = .gray });
            }
            if (activity_body.height > 2) {
                _ = activity_body_area.borrowTextAt(0, 2, "09:45  Kept expansion state outside UI", .{ .fg = .gray });
            }
        }

        const footer_row = size.height -| 1;
        _ = sfc.borrowTextAt(0, footer_row, "Collapsed sections still reserve no body rows; the app decides when that changes.", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

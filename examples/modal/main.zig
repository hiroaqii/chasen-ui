const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows Modal as display-only overlay chrome.
//
// Modal draws an optional backdrop and a centered Panel-like dialog. It does
// not decide whether the dialog is visible, what Esc means, where focus goes,
// or what child content belongs inside. Those decisions remain app state.
const App = struct {
    const help_items = [_]ui.key_hint.Item{
        ui.key_hint.item("m", "toggle modal"),
        ui.key_hint.item("Esc", "quit"),
    };

    show_modal: bool = true,
    modal: ui.Modal = ui.Modal.init(.{}),
    paragraph: ui.Paragraph = ui.Paragraph.init(.{
        .text = "Visibility, dismissal, focus, and action semantics are owned by the app. Modal only draws the backdrop and dialog chrome.",
    }),

    pub const Msg = union(enum) {
        toggle_modal,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches('m', .{})) return .toggle_modal;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .toggle_modal => self.show_modal = !self.show_modal,
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        _ = sfc.borrowTextAt(0, 0, "Modal Example - app-owned visibility", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "m: toggle modal  Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(0, 3, "Underlying screen", .{ .bold = true, .fg = .{ .index = 6 } });
        _ = sfc.borrowTextAt(0, 4, "The app keeps rendering normally behind the modal.", .{ .fg = .gray });
        _ = sfc.borrowTextAt(0, 6, if (self.show_modal) "Modal visible" else "Modal hidden", .{ .dim = true });

        if (!self.show_modal) return;

        const modal_opts = ui.Modal.ViewOptions{
            .dialog_width = @min(size.width, 56),
            .dialog_height = @min(size.height, 11),
            .title = "Confirm Action",
            .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
            .backdrop = true,
            .backdrop_style = .{ .bg = .{ .index = 235 } },
            .border = .rounded,
            .border_style = .{ .fg = .gray },
            .title_style = .{ .bold = true, .fg = .{ .index = 6 } },
        };

        var modal_area = sfc.child(.{ .col = 0, .row = 0, .width = size.width, .height = size.height });
        self.modal.view(&modal_area, modal_opts);

        const content = ui.Modal.contentRect(&modal_area, modal_opts);
        if (content.width == 0 or content.height == 0) return;
        var content_area = modal_area.child(content);

        // The dialog content is regular app-owned drawing. Modal gives the app
        // a centered, padded rectangle but does not own the buttons, focus, or
        // the meaning of confirmation.
        _ = content_area.borrowTextAt(0, 0, "Delete saved filter?", .{ .bold = true });
        if (content.height > 3) {
            var paragraph_area = content_area.child(.{
                .col = 0,
                .row = 2,
                .width = content_area.size().width,
                .height = content.height - 4,
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

const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows Modal as display-only overlay chrome.
//
// Modal draws an optional backdrop and a centered Panel-like dialog. It does
// not decide whether the dialog is visible, what Esc means, where focus goes,
// or what child content belongs inside. Those decisions remain app state.
const App = struct {
    show_modal: bool = true,
    modal: ui.Modal = ui.Modal.init(.{}),
    paragraph: ui.Paragraph = ui.Paragraph.init(.{
        .text = "Visibility, dismissal, focus, and action semantics are owned by the app. Modal only draws the backdrop and dialog chrome.",
    }),
    help: ui.Help = ui.Help.init(.{
        .items = &.{
            .{ .key = "m", .action = "toggle modal" },
            .{ .key = "Esc", .action = "quit" },
        },
    }),

    pub const Msg = union(enum) {
        toggle_modal,
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        _ = sfc.textAt(0, 0, "Modal Example - app-owned visibility", .{ .bold = true });
        _ = sfc.textAt(0, 1, "m: toggle modal  Esc: quit", .{ .fg = .gray });

        _ = sfc.textAt(0, 3, "Underlying screen", .{ .bold = true, .fg = .{ .index = 6 } });
        _ = sfc.textAt(0, 4, "The app keeps rendering normally behind the modal.", .{ .fg = .gray });
        _ = sfc.textAt(0, 6, if (self.show_modal) "Modal visible" else "Modal hidden", .{ .dim = true });

        if (!self.show_modal) return;

        const modal_opts = ui.Modal.ViewOptions{
            .width = size.width,
            .height = size.height,
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

        self.modal.view(sfc, modal_opts);

        const content = ui.Modal.contentRect(sfc, modal_opts);
        if (content.width == 0 or content.height == 0) return;

        // The dialog content is regular app-owned drawing. Modal gives the app
        // a centered, padded rectangle but does not own the buttons, focus, or
        // the meaning of confirmation.
        _ = sfc.textAt(content.col, content.row, "Delete saved filter?", .{ .bold = true });
        if (content.height > 3) {
            self.paragraph.view(sfc, .{
                .col = content.col,
                .row = content.row + 2,
                .width = content.width,
                .height = content.height - 4,
                .style = .{ .fg = .gray },
            });
        }

        if (content.height > 0) {
            self.help.view(sfc, .{
                .col = content.col,
                .row = content.row + content.height - 1,
                .width = content.width,
                .key_style = .{ .bold = true, .fg = .{ .index = 6 } },
                .action_style = .{ .dim = true },
            });
        }
    }

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
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

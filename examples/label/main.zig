const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the display-only Label component.
//
// Label is useful when an app wants to reuse single-line text rendering with a
// consistent API. It does not own layout, focus, events, or validation. The app
// decides whether a label is a field name, heading, hint, or status message.
const App = struct {
    title: ui.Label = ui.Label.init(.{ .text = "Profile" }),
    username: ui.Label = ui.Label.init(.{ .text = "Username" }),
    username_hint: ui.Label = ui.Label.init(.{ .text = "Shown in activity logs" }),
    email: ui.Label = ui.Label.init(.{ .text = "Email" }),
    email_hint: ui.Label = ui.Label.init(.{ .text = "Used for notifications" }),
    status: ui.Label = ui.Label.init(.{ .text = "Unsaved changes" }),

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
        _ = sfc.borrowTextAt(0, 0, "Label Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        // The same Label component can be styled as a section heading.
        var title_area = sfc.child(.{ .col = 0, .row = 3, .width = 30, .height = 1 });
        self.title.view(&title_area, .{
            .style = .{ .bold = true },
        });

        // Field labels are ordinary labels. The app decides column placement
        // and draws the value or input next to them.
        var username_area = sfc.child(.{ .col = 0, .row = 5, .width = 12, .height = 1 });
        self.username.view(&username_area, .{
            .style = .{ .bold = true },
        });
        _ = sfc.borrowTextAt(14, 5, "hiro", .{});
        var username_hint_area = sfc.child(.{ .col = 14, .row = 6, .width = 40, .height = 1 });
        self.username_hint.view(&username_hint_area, .{
            .style = .{ .dim = true },
        });

        var email_area = sfc.child(.{ .col = 0, .row = 8, .width = 12, .height = 1 });
        self.email.view(&email_area, .{
            .style = .{ .bold = true },
        });
        _ = sfc.borrowTextAt(14, 8, "hiro@example.com", .{});
        var email_hint_area = sfc.child(.{ .col = 14, .row = 9, .width = 40, .height = 1 });
        self.email_hint.view(&email_hint_area, .{
            .style = .{ .dim = true },
        });

        // Status text is also app policy. Label only draws the provided text
        // into the requested one-line region.
        var status_area = sfc.child(.{ .col = 0, .row = 12, .width = 30, .height = 1 });
        self.status.view(&status_area, .{
            .style = .{ .italic = true },
        });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

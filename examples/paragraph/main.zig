const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the display-only Paragraph component.
//
// Paragraph is useful when an app wants to draw borrowed multi-line text inside
// a fixed rectangle. It wraps by terminal display width, keeps explicit line
// breaks, and clips to the requested height. This is intentionally not a rich
// text layout engine; app code should insert line breaks itself when it needs
// word-aware copy. Paragraph also does not own scroll state, focus, events,
// validation, or layout policy.
const App = struct {
    intro: ui.Paragraph = ui.Paragraph.init(.{ .text =
        \\Paragraph draws borrowed text into a rectangular region. The app owns
        \\the text and decides where the region belongs.
    }),
    note: ui.Paragraph = ui.Paragraph.init(.{ .text =
        \\Explicit line breaks are preserved.
        \\
        \\Long lines wrap by grapheme display width, so wide characters such as あ
        \\take the terminal cell width reported by chasen.text.
    }),
    clipped: ui.Paragraph = ui.Paragraph.init(.{ .text =
        \\This paragraph intentionally has more content than the view height.
        \\Only the first few wrapped rows are drawn. The app can later combine
        \\Paragraph with scroll state if it needs a scrollable text view.
    }),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Paragraph Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        _ = sfc.borrowTextAt(0, 3, "Basic wrapped text", .{ .bold = true });
        var intro_area = sfc.child(.{ .col = 0, .row = 4, .width = 44, .height = 4 });
        self.intro.view(&intro_area, .{});

        _ = sfc.borrowTextAt(0, 9, "Line breaks and wide characters", .{ .bold = true });
        var note_area = sfc.child(.{ .col = 0, .row = 10, .width = 48, .height = 5 });
        self.note.view(&note_area, .{
            .style = .{ .dim = true },
        });

        _ = sfc.borrowTextAt(0, 16, "Clipped region", .{ .bold = true });
        var clipped_area = sfc.child(.{ .col = 0, .row = 17, .width = 42, .height = 3 });
        self.clipped.view(&clipped_area, .{
            .style = .{ .italic = true },
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

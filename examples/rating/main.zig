const std = @import("std");
const chasen = @import("chasen");
const graphics = @import("chasen_graphics");
const ui = @import("chasen_ui");

// This example shows the display-only Rating component.
//
// Rating does not own the meaning of a score. The app decides the scale,
// validation, labels, and whether a rating is editable or saved. The component
// only draws the filled and empty item counts it receives.
const App = struct {
    rating: ui.Rating = ui.Rating.init(.{}),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Rating Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Esc: quit", .{ .fg = .gray });

        _ = sfc.textAt(0, 3, "Movie", .{ .bold = true });
        // The app decides this is a 4-out-of-5 score. chasen-graphics only
        // provides glyph presets; Rating receives them as plain borrowed
        // labels and does not depend on the graphics package itself.
        self.rating.view(sfc, .{
            .col = 14,
            .row = 3,
            .filled_count = 4,
            .total_count = 5,
            .filled_glyph = graphics.glyph.rating.filled,
            .empty_glyph = graphics.glyph.rating.empty,
            .filled_style = .{ .bold = true, .fg = .{ .index = 11 } },
            .empty_style = .{ .dim = true, .fg = .gray },
        });

        _ = sfc.textAt(0, 5, "Service", .{ .bold = true });
        // The scale is not fixed to five items. Passing counts keeps validation
        // and domain meaning in the app instead of inside the component.
        self.rating.view(sfc, .{
            .col = 14,
            .row = 5,
            .filled_count = 2,
            .total_count = 3,
            .filled_glyph = graphics.glyph.rating.filled,
            .empty_glyph = graphics.glyph.rating.empty,
            .gap = 1,
            .filled_style = .{ .bold = true, .fg = .{ .index = 10 } },
            .empty_style = .{ .dim = true, .fg = .gray },
        });

        _ = sfc.textAt(0, 7, "Fallback", .{ .bold = true });
        // ASCII fallback glyphs are useful for terminals or fonts where star
        // glyphs are not desirable. The component API is the same either way.
        self.rating.view(sfc, .{
            .col = 14,
            .row = 7,
            .filled_count = 3,
            .total_count = 5,
            .filled_glyph = graphics.glyph.rating.filled_ascii,
            .empty_glyph = graphics.glyph.rating.empty_ascii,
            .gap = 1,
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

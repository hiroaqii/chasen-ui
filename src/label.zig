const std = @import("std");
const chasen = @import("chasen");

/// A small single-line text label component.
///
/// `Label` is display-only and allocation-free. It borrows its text and draws
/// it into a one-line region. Applications decide what the label means, where
/// it belongs, and whether it is used as a field label, section title, hint, or
/// status text.
pub const Label = struct {
    /// Text borrowed by the component.
    text: []const u8 = "",

    /// Initial values used when constructing a `Label`.
    pub const Options = struct {
        /// Text borrowed by the component for its lifetime.
        text: []const u8 = "",
    };

    /// Rendering options for `Label.view`.
    pub const ViewOptions = struct {
        /// Surface column where the label should be drawn.
        col: u16 = 0,
        /// Surface row where the label should be drawn.
        row: u16 = 0,
        /// Optional width of the clipped one-line label region.
        width: ?u16 = null,
        /// Style used for the label text.
        style: chasen.TextStyle = .{},
    };

    /// Create a label.
    pub fn init(opts: Options) Label {
        return .{ .text = opts.text };
    }

    /// Draw the label into a one-line region.
    pub fn view(self: *const Label, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = opts.width orelse availableWidth(surface, opts.col);
        if (width == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = width,
            .height = 1,
        });
        _ = child.textAt(0, 0, self.text, opts.style);
    }
};

fn availableWidth(surface: *chasen.Surface, col: u16) u16 {
    const size = surface.size();
    if (col >= size.width) return 0;
    return size.width - col;
}

test "Label initializes from options" {
    const label = Label.init(.{ .text = "Username" });

    try std.testing.expectEqualStrings("Username", label.text);
}

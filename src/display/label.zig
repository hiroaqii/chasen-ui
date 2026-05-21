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
        /// Style used for the label text.
        style: chasen.TextStyle = .{},
    };

    /// Create a label.
    pub fn init(opts: Options) Label {
        return .{ .text = opts.text };
    }

    /// Draw the label into the provided one-line surface region.
    pub fn view(self: *const Label, surface: *chasen.Surface, opts: ViewOptions) void {
        if (surface.size().width == 0) return;
        _ = surface.borrowTextAt(0, 0, self.text, opts.style);
    }
};

test "Label initializes from options" {
    const label = Label.init(.{ .text = "Username" });

    try std.testing.expectEqualStrings("Username", label.text);
}

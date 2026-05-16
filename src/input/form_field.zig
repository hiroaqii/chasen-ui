const std = @import("std");
const chasen = @import("chasen");

/// Display-only form field chrome.
///
/// `FormField` draws a label, optional required marker, and one help/error
/// message row around an app-owned content rectangle. It does not own input
/// state, validation, focus routing, or submission policy; applications render
/// the actual input component inside the rectangle returned by `contentRect`.
pub const FormField = struct {
    /// Initial values used when constructing a `FormField`.
    pub const Options = struct {
        /// Field label borrowed by the component for its lifetime.
        label: []const u8 = "",
        /// Default help text borrowed by the component for its lifetime.
        help: []const u8 = "",
    };

    /// Rendering options for `FormField.view`.
    pub const ViewOptions = struct {
        /// Whether to draw `required_marker` after the label.
        required: bool = false,
        /// Marker drawn after required labels.
        required_marker: []const u8 = "*",
        /// Error text borrowed for this view call.
        ///
        /// When non-empty, error text replaces help text in the message row.
        error_text: ?[]const u8 = null,
        /// Style used for the label text.
        label_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the required marker.
        required_style: chasen.TextStyle = .{ .bold = true, .fg = .{ .index = 9 } },
        /// Style used for help text.
        help_style: chasen.TextStyle = .{ .fg = .gray },
        /// Style used for error text.
        error_style: chasen.TextStyle = .{ .fg = .{ .index = 9 } },
    };

    /// Field label borrowed by the component.
    label: []const u8 = "",
    /// Default help text borrowed by the component.
    help: []const u8 = "",

    /// Create a form field chrome component.
    pub fn init(opts: Options) FormField {
        return .{
            .label = opts.label,
            .help = opts.help,
        };
    }

    /// Return the app-owned content rectangle inside the provided field surface.
    ///
    /// The returned rectangle is relative to the field surface. Pass it to
    /// `surface.child(rect)` before drawing the input component.
    pub fn contentRect(self: *const FormField, surface: *chasen.Surface, opts: ViewOptions) chasen.Rect {
        return self.contentRectFor(.{ .col = 0, .row = 0, .width = surface.size().width, .height = surface.size().height }, opts);
    }

    /// Return the app-owned content rectangle for an already resolved field.
    pub fn contentRectFor(self: *const FormField, field_rect: chasen.Rect, opts: ViewOptions) chasen.Rect {
        const label_rows: u16 = if (field_rect.height > 0) 1 else 0;
        const message_rows = self.messageRowsForHeight(opts, field_rect.height);
        const used_rows = label_rows +| message_rows;
        const content_height = field_rect.height -| used_rows;
        return .{
            .col = field_rect.col,
            .row = field_rect.row +| label_rows,
            .width = field_rect.width,
            .height = content_height,
        };
    }

    /// Draw label and help/error chrome. The app draws the input content.
    pub fn view(self: *const FormField, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        var label_cursor: u16 = 0;
        drawText(surface, &label_cursor, 0, self.label, opts.label_style, width);
        if (opts.required) {
            drawText(surface, &label_cursor, 0, " ", opts.label_style, width);
            drawText(surface, &label_cursor, 0, opts.required_marker, opts.required_style, width);
        }

        const message_row = self.message(opts);
        if (message_row.text.len > 0 and height >= 3) {
            var message_cursor: u16 = 0;
            drawText(surface, &message_cursor, height - 1, message_row.text, message_row.style, width);
        }
    }

    fn messageRowsForHeight(self: *const FormField, opts: ViewOptions, height: u16) u16 {
        return if (self.message(opts).text.len > 0 and height >= 3) 1 else 0;
    }

    fn message(self: *const FormField, opts: ViewOptions) struct { text: []const u8, style: chasen.TextStyle } {
        if (opts.error_text) |error_text| {
            if (error_text.len > 0) return .{ .text = error_text, .style = opts.error_style };
        }
        return .{ .text = self.help, .style = opts.help_style };
    }
};

fn drawText(surface: *chasen.Surface, cursor: *u16, row: u16, text: []const u8, style: chasen.TextStyle, width: u16) void {
    if (text.len == 0 or cursor.* >= width) return;
    _ = surface.textAt(cursor.*, row, text, style);
    cursor.* +|= chasen.text.displayWidth(text);
}

test "FormField initializes from options" {
    const field = FormField.init(.{
        .label = "Username",
        .help = "Required for sync",
    });

    try std.testing.expectEqualStrings("Username", field.label);
    try std.testing.expectEqualStrings("Required for sync", field.help);
}

test "FormField contentRect leaves label and message rows" {
    const field = FormField.init(.{
        .label = "Username",
        .help = "Required for sync",
    });

    const rect = field.contentRectFor(.{
        .col = 2,
        .row = 3,
        .width = 30,
        .height = 3,
    }, .{});

    try std.testing.expectEqual(@as(u16, 2), rect.col);
    try std.testing.expectEqual(@as(u16, 4), rect.row);
    try std.testing.expectEqual(@as(u16, 30), rect.width);
    try std.testing.expectEqual(@as(u16, 1), rect.height);
}

test "FormField contentRect grows when no message row is present" {
    const field = FormField.init(.{ .label = "Nickname" });

    const rect = field.contentRectFor(.{
        .col = 0,
        .row = 0,
        .width = 20,
        .height = 3,
    }, .{});

    try std.testing.expectEqual(@as(u16, 0), rect.col);
    try std.testing.expectEqual(@as(u16, 1), rect.row);
    try std.testing.expectEqual(@as(u16, 20), rect.width);
    try std.testing.expectEqual(@as(u16, 2), rect.height);
}

test "FormField contentRectFor uses resolved height for message row" {
    const field = FormField.init(.{
        .label = "Username",
        .help = "Required for sync",
    });

    const short_rect = field.contentRectFor(.{
        .col = 0,
        .row = 0,
        .width = 20,
        .height = 2,
    }, .{});

    try std.testing.expectEqual(@as(u16, 1), short_rect.row);
    try std.testing.expectEqual(@as(u16, 1), short_rect.height);

    const tall_rect = field.contentRectFor(.{
        .col = 0,
        .row = 0,
        .width = 20,
        .height = 4,
    }, .{});

    try std.testing.expectEqual(@as(u16, 1), tall_rect.row);
    try std.testing.expectEqual(@as(u16, 2), tall_rect.height);
}

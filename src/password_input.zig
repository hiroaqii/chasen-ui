const std = @import("std");
const chasen = @import("chasen");
const TextInput = @import("text_input.zig").TextInput;

/// A single-line password input component.
///
/// `PasswordInput` owns editable UTF-8 text through an internal `TextInput`,
/// but draws a mask glyph instead of the real value. Applications still decide
/// what submit means, how to validate the secret, and when to clear it.
pub const PasswordInput = struct {
    /// Internal text editing state.
    input: TextInput,

    /// Initial values used when constructing a `PasswordInput`.
    pub const Options = struct {
        /// Initial input contents. The bytes are copied into the component.
        value: []const u8 = "",
        /// Placeholder text borrowed by the component for its lifetime.
        placeholder: []const u8 = "",
    };

    /// Messages understood by `PasswordInput.update`.
    pub const Msg = TextInput.Msg;

    /// Rendering options for `PasswordInput.view`.
    pub const ViewOptions = struct {
        /// Surface column where the input should be drawn.
        col: u16 = 0,
        /// Surface row where the input should be drawn.
        row: u16 = 0,
        /// Width of the clipped one-line input region.
        width: u16,
        /// Mask glyph drawn once per visible scalar.
        mask: []const u8 = "*",
        /// Style used for mask glyphs.
        style: chasen.TextStyle = .{},
        /// Style used when drawing the placeholder.
        placeholder_style: chasen.TextStyle = .{ .fg = .gray },
        /// Whether `view` should place the terminal cursor inside the input.
        show_cursor: bool = true,
    };

    /// Create a password input with copied initial contents.
    ///
    /// The caller owns the returned component and must call `deinit` exactly
    /// once when the component is no longer needed.
    pub fn init(allocator: std.mem.Allocator, opts: Options) !PasswordInput {
        return .{ .input = try TextInput.init(allocator, .{
            .value = opts.value,
            .placeholder = opts.placeholder,
        }) };
    }

    /// Release memory owned by this component.
    pub fn deinit(self: *PasswordInput) void {
        self.input.deinit();
        self.* = undefined;
    }

    /// Return the current secret contents.
    ///
    /// The returned slice is borrowed from the component and becomes invalid
    /// after the next mutating `update` call or `deinit`.
    pub fn text(self: *const PasswordInput) []const u8 {
        return self.input.text();
    }

    /// Apply a component message.
    pub fn update(self: *PasswordInput, msg: Msg) !void {
        try self.input.update(msg);
    }

    /// Convert a Chasen event into a `PasswordInput` message when applicable.
    pub fn handleEvent(self: *const PasswordInput, event: chasen.Event) ?Msg {
        return self.input.handleEvent(event);
    }

    /// Draw the password input into a one-line clipped child surface.
    ///
    /// The real value is never drawn. When the input is empty, the placeholder
    /// is shown with `placeholder_style`.
    pub fn view(self: *const PasswordInput, surface: *chasen.Surface, opts: ViewOptions) void {
        if (opts.width == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = opts.width,
            .height = 1,
        });

        if (self.input.value.items.len == 0) {
            if (self.input.placeholder.len > 0) {
                _ = child.textAt(0, 0, self.input.placeholder, opts.placeholder_style);
            }
        } else {
            drawMask(&child, visibleSecretCount(self.input.value.items, self.input.cursor, opts.width), opts.mask, opts.style, opts.width);
        }

        if (opts.show_cursor) {
            child.showCursor(visibleCursorCol(self.input.value.items, self.input.cursor, opts.width, opts.mask), 0);
        }
    }
};

fn drawMask(surface: *chasen.Surface, count: u16, mask: []const u8, style: chasen.TextStyle, width: u16) void {
    const mask_width = chasen.text.displayWidth(mask);
    if (mask.len == 0 or mask_width == 0) return;

    var col: u16 = 0;
    var index: u16 = 0;
    while (index < count and col < width) : (index += 1) {
        _ = surface.textAt(col, 0, mask, style);
        col +|= mask_width;
    }
}

fn visibleSecretCount(bytes: []const u8, cursor: usize, width: u16) u16 {
    if (width == 0 or bytes.len == 0) return 0;

    const start = visibleStart(bytes, cursor, width);
    var count: u16 = 0;
    var iter = chasen.text.graphemeIterator(bytes[start..]);
    while (iter.next()) |_| {
        count +|= 1;
        if (count >= width) break;
    }
    return count;
}

fn visibleCursorCol(bytes: []const u8, cursor: usize, width: u16, mask: []const u8) u16 {
    if (width == 0) return 0;

    const start = visibleStart(bytes, cursor, width);
    const mask_width = chasen.text.displayWidth(mask);
    if (mask_width == 0) return 0;

    var col: u16 = 0;
    var iter = chasen.text.graphemeIterator(bytes[start..cursor]);
    while (iter.next()) |_| {
        col +|= mask_width;
    }
    return @min(width - 1, col);
}

fn visibleStart(bytes: []const u8, cursor: usize, width: u16) usize {
    if (width == 0) return cursor;

    const max_width_before_cursor = width - 1;
    var iter = chasen.text.graphemeIterator(bytes);

    while (iter.next()) |grapheme| {
        const grapheme_end = grapheme.start + grapheme.len;
        if (grapheme_end > cursor) break;

        if (maskedWidth(bytes[grapheme.start..cursor]) <= max_width_before_cursor) {
            return grapheme.start;
        }
    }

    return cursor;
}

fn maskedWidth(bytes: []const u8) u16 {
    var width: u16 = 0;
    var iter = chasen.text.graphemeIterator(bytes);
    while (iter.next()) |_| {
        width +|= 1;
    }
    return width;
}

test "PasswordInput initializes and delegates editing" {
    var input = try PasswordInput.init(std.testing.allocator, .{
        .value = "abc",
        .placeholder = "password",
    });
    defer input.deinit();

    try std.testing.expectEqualStrings("abc", input.text());
    try input.update(.backspace);
    try std.testing.expectEqualStrings("ab", input.text());
    try input.update(.{ .insert = 'Z' });
    try std.testing.expectEqualStrings("abZ", input.text());
}

test "PasswordInput maps key events through TextInput" {
    var input = try PasswordInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try std.testing.expectEqual(PasswordInput.Msg{ .insert = 'x' }, input.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }).?);
    try std.testing.expectEqual(PasswordInput.Msg.submit, input.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "PasswordInput visible mask count keeps cursor in view" {
    try std.testing.expectEqual(@as(u16, 4), visibleSecretCount("abcdef", 6, 5));
    try std.testing.expectEqual(@as(u16, 5), visibleSecretCount("abcdef", 2, 5));
    try std.testing.expectEqual(@as(u16, 3), visibleSecretCount("aあb", "aあb".len, 5));
}

test "PasswordInput visible cursor column uses mask width" {
    try std.testing.expectEqual(@as(u16, 4), visibleCursorCol("abcdef", 6, 5, "*"));
    try std.testing.expectEqual(@as(u16, 6), visibleCursorCol("abcdef", 3, 8, "**"));
    try std.testing.expectEqual(@as(u16, 0), visibleCursorCol("abcdef", 3, 8, ""));
}

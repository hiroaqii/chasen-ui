const std = @import("std");
const chasen = @import("chasen");

/// A small multi-line text paragraph component.
///
/// `Paragraph` is display-only and allocation-free. It borrows its text and
/// draws it into a clipped rectangular region. The component wraps text by
/// grapheme cluster display width, honors explicit `\n` line breaks, and stops
/// drawing when the requested height is filled. It does not perform word-aware
/// layout; callers that need richer text layout should prepare line breaks in
/// app code before passing text to the component.
pub const Paragraph = struct {
    /// Text borrowed by the component.
    text: []const u8 = "",

    /// Initial values used when constructing a `Paragraph`.
    pub const Options = struct {
        /// Text borrowed by the component for its lifetime.
        text: []const u8 = "",
    };

    /// Rendering options for `Paragraph.view`.
    pub const ViewOptions = struct {
        /// Style used for paragraph text.
        style: chasen.TextStyle = .{},
    };

    /// Create a paragraph.
    pub fn init(opts: Options) Paragraph {
        return .{ .text = opts.text };
    }

    /// Return how many rows the paragraph would occupy for `width`.
    ///
    /// This helper is independent from a live `Surface`, so examples and tests
    /// can reason about wrapping without rendering. The result uses `usize` so
    /// callers can safely measure long borrowed text. Width `0` returns `0`.
    pub fn lineCount(self: *const Paragraph, width: u16) usize {
        return countWrappedLines(self.text, width);
    }

    /// Draw the paragraph into the provided clipped surface region.
    pub fn view(self: *const Paragraph, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        drawWrappedText(surface, self.text, width, height, opts.style);
    }
};

fn drawWrappedText(surface: *chasen.Surface, text: []const u8, width: u16, height: u16, style: chasen.TextStyle) void {
    var row: u16 = 0;

    // `line_start` and `line_end` are byte indexes into the original UTF-8
    // string. We only move them at grapheme boundaries, so rendered slices never
    // cut through a multi-byte codepoint or grapheme cluster.
    var line_start: usize = 0;
    var line_end: usize = 0;
    var line_width: u32 = 0;

    var iter = chasen.text.graphemeIterator(text);
    while (iter.next()) |grapheme| {
        const bytes = grapheme.bytes(text);

        if (isLineBreak(bytes)) {
            // Explicit newlines are committed immediately. The newline byte is
            // not drawn; it only advances the output row and starts a new slice.
            drawLine(surface, row, text[line_start..line_end], style);
            row += 1;
            if (row >= height) return;

            line_start = grapheme.start + grapheme.len;
            line_end = line_start;
            line_width = 0;
            continue;
        }

        const grapheme_width: u32 = chasen.text.displayWidth(bytes);
        if (line_width > 0 and line_width + grapheme_width > width) {
            // Wrap before the current grapheme. The `line_width > 0` guard
            // ensures that a single wide grapheme still gets a chance to draw
            // at the start of an otherwise too-narrow line.
            drawLine(surface, row, text[line_start..line_end], style);
            row += 1;
            if (row >= height) return;

            line_start = grapheme.start;
            line_end = grapheme.start;
            line_width = 0;
        }

        line_end = grapheme.start + grapheme.len;
        line_width += grapheme_width;
    }

    if (row < height) {
        // Draw the final buffered line after the iterator is exhausted. For an
        // empty string this draws an empty line, which makes `lineCount("")`
        // and `view` agree that an empty paragraph still occupies one row.
        drawLine(surface, row, text[line_start..line_end], style);
    }
}

fn countWrappedLines(text: []const u8, width: u16) usize {
    if (width == 0) return 0;

    // Keep this wrapping logic intentionally parallel to `drawWrappedText`.
    // `lineCount` is used by apps before rendering, so it must answer the same
    // "how many rows would this occupy?" question that `view` uses to draw.
    var rows: usize = 1;
    var line_width: u32 = 0;

    var iter = chasen.text.graphemeIterator(text);
    while (iter.next()) |grapheme| {
        const bytes = grapheme.bytes(text);

        if (isLineBreak(bytes)) {
            // A newline creates a new row even when the current line is empty.
            // This preserves blank lines in strings such as "a\n\nb".
            rows += 1;
            line_width = 0;
            continue;
        }

        const grapheme_width: u32 = chasen.text.displayWidth(bytes);
        if (line_width > 0 and line_width + grapheme_width > width) {
            rows += 1;
            line_width = 0;
        }
        line_width += grapheme_width;
    }

    return rows;
}

fn drawLine(surface: *chasen.Surface, row: u16, line: []const u8, style: chasen.TextStyle) void {
    _ = surface.borrowTextAt(0, row, line, style);
}

fn isLineBreak(bytes: []const u8) bool {
    return bytes.len == 1 and bytes[0] == '\n';
}

test "Paragraph initializes from options" {
    const paragraph = Paragraph.init(.{ .text = "Hello\nworld" });

    try std.testing.expectEqualStrings("Hello\nworld", paragraph.text);
}

test "Paragraph lineCount wraps by display width" {
    const paragraph = Paragraph.init(.{ .text = "abcdef" });

    try std.testing.expectEqual(@as(usize, 1), paragraph.lineCount(6));
    try std.testing.expectEqual(@as(usize, 2), paragraph.lineCount(3));
    try std.testing.expectEqual(@as(usize, 3), paragraph.lineCount(2));
}

test "Paragraph lineCount honors explicit line breaks" {
    const paragraph = Paragraph.init(.{ .text = "one\ntwo\nthree" });

    try std.testing.expectEqual(@as(usize, 3), paragraph.lineCount(20));
}

test "Paragraph lineCount uses grapheme display width" {
    const paragraph = Paragraph.init(.{ .text = "あい" });

    try std.testing.expectEqual(@as(usize, 1), paragraph.lineCount(4));
    try std.testing.expectEqual(@as(usize, 2), paragraph.lineCount(2));
}

test "Paragraph lineCount handles zero width" {
    const paragraph = Paragraph.init(.{ .text = "abc" });

    try std.testing.expectEqual(@as(usize, 0), paragraph.lineCount(0));
}

test "Paragraph lineCount handles long text and maximum width" {
    const text = try std.testing.allocator.alloc(u8, 4096);
    defer std.testing.allocator.free(text);
    @memset(text, 'x');

    const paragraph = Paragraph.init(.{ .text = text });

    try std.testing.expectEqual(@as(usize, 4096), paragraph.lineCount(1));
    try std.testing.expectEqual(@as(usize, 1), paragraph.lineCount(std.math.maxInt(u16)));
}

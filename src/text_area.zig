const std = @import("std");
const chasen = @import("chasen");

/// A small multi-line text input component.
///
/// `TextArea` owns an editable UTF-8 buffer and cursor position. It supports
/// explicit newline editing and simple line-based cursor movement, but it does
/// not own wrapping policy, scroll state, validation, or submit behavior.
/// Applications decide how large the visible region is, which explicit line is
/// first visible, and what the edited text means.
pub const TextArea = struct {
    /// Allocator used for the owned text buffer.
    allocator: std.mem.Allocator,
    /// Current UTF-8 text buffer.
    value: std.ArrayList(u8) = .empty,
    /// Cursor byte offset into `value`.
    cursor: usize = 0,
    /// Text shown when the area is empty. Borrowed; must outlive the component.
    placeholder: []const u8 = "",

    /// Initial values used when constructing a `TextArea`.
    pub const Options = struct {
        /// Initial contents. The bytes are copied into the component.
        value: []const u8 = "",
        /// Placeholder text borrowed by the component for its lifetime.
        placeholder: []const u8 = "",
    };

    /// Messages understood by `TextArea.update`.
    pub const Msg = union(enum) {
        /// Insert one Unicode scalar at the current cursor position.
        insert: u21,
        /// Insert an explicit line break at the current cursor position.
        insert_newline,
        /// Remove the scalar before the cursor.
        backspace,
        /// Remove the scalar at the cursor.
        delete,
        /// Move the cursor one scalar to the left.
        move_left,
        /// Move the cursor one scalar to the right.
        move_right,
        /// Move the cursor to the nearest column on the previous explicit line.
        move_up,
        /// Move the cursor to the nearest column on the next explicit line.
        move_down,
        /// Move the cursor to the start of the current explicit line.
        home,
        /// Move the cursor to the end of the current explicit line.
        end,
        /// Remove all text and move the cursor to the start.
        clear,
    };

    /// Rendering options for `TextArea.view`.
    pub const ViewOptions = struct {
        /// Surface column where the text area should be drawn.
        col: u16 = 0,
        /// Surface row where the text area should be drawn.
        row: u16 = 0,
        /// Width of the clipped text area region.
        width: u16,
        /// Height of the clipped text area region.
        height: u16,
        /// First explicit line index to draw.
        scroll_line: usize = 0,
        /// Style used for the current value.
        style: chasen.TextStyle = .{},
        /// Style used when drawing the placeholder.
        placeholder_style: chasen.TextStyle = .{ .fg = .gray },
        /// Whether `view` should place the terminal cursor inside the area.
        show_cursor: bool = true,
    };

    /// Create a text area with copied initial contents.
    ///
    /// The caller owns the returned component and must call `deinit` exactly
    /// once when the component is no longer needed.
    pub fn init(allocator: std.mem.Allocator, opts: Options) !TextArea {
        var area: TextArea = .{
            .allocator = allocator,
            .placeholder = opts.placeholder,
        };
        try area.value.appendSlice(allocator, opts.value);
        area.cursor = area.value.items.len;
        return area;
    }

    /// Release memory owned by this component.
    pub fn deinit(self: *TextArea) void {
        self.value.deinit(self.allocator);
        self.* = undefined;
    }

    /// Return the current text contents.
    ///
    /// The returned slice is borrowed from the component and becomes invalid
    /// after the next mutating `update` call or `deinit`.
    pub fn text(self: *const TextArea) []const u8 {
        return self.value.items;
    }

    /// Return the zero-based explicit line index containing the cursor.
    pub fn cursorLine(self: *const TextArea) usize {
        return lineIndexAt(self.value.items, self.cursor);
    }

    /// Return the zero-based terminal display-cell column of the cursor within
    /// its explicit line.
    pub fn cursorColumn(self: *const TextArea) u16 {
        const start = lineStart(self.value.items, self.cursor);
        return chasen.text.displayWidth(self.value.items[start..self.cursor]);
    }

    /// Return the number of grapheme clusters before the cursor within its
    /// explicit line.
    ///
    /// This differs from `cursorColumn` for wide characters. For example, "あ"
    /// is one grapheme cluster but occupies two terminal display cells.
    pub fn cursorGraphemeColumn(self: *const TextArea) usize {
        const start = lineStart(self.value.items, self.cursor);
        var count: usize = 0;
        var iter = chasen.text.graphemeIterator(self.value.items[start..self.cursor]);
        while (iter.next()) |_| {
            count += 1;
        }
        return count;
    }

    /// Apply a component message.
    pub fn update(self: *TextArea, msg: Msg) !void {
        switch (msg) {
            .insert => |codepoint| try self.insertCodepoint(codepoint),
            .insert_newline => try self.insertBytes("\n"),
            .backspace => self.backspace(),
            .delete => self.delete(),
            .move_left => self.cursor = previousScalarStart(self.value.items, self.cursor),
            .move_right => self.cursor = nextScalarEnd(self.value.items, self.cursor),
            .move_up => self.moveVertical(.up),
            .move_down => self.moveVertical(.down),
            .home => self.cursor = lineStart(self.value.items, self.cursor),
            .end => self.cursor = lineEnd(self.value.items, self.cursor),
            .clear => {
                self.value.clearRetainingCapacity();
                self.cursor = 0;
            },
        }
    }

    /// Convert a Chasen event into a `TextArea` message when applicable.
    ///
    /// Printable key text without command-style modifiers maps to `.insert`.
    /// Enter inserts a newline. Backspace, Delete, arrows, Home, and End map to
    /// editing/navigation messages. Modified text input is ignored so apps can
    /// reserve those bindings for higher-level commands.
    pub fn handleEvent(self: *const TextArea, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| keyToMsg(key),
            else => null,
        };
    }

    /// Draw explicit lines into a clipped rectangular region.
    ///
    /// `TextArea` does not soft-wrap or own scroll state. It draws explicit
    /// lines from `opts.scroll_line`, clips to the provided rectangle, and only
    /// shows the cursor when the cursor position is inside that rectangle.
    pub fn view(self: *const TextArea, surface: *chasen.Surface, opts: ViewOptions) void {
        if (opts.width == 0 or opts.height == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = opts.width,
            .height = opts.height,
        });

        if (self.value.items.len == 0 and self.placeholder.len > 0) {
            _ = child.textAt(0, 0, self.placeholder, opts.placeholder_style);
        } else {
            drawLines(&child, self.value.items, opts.scroll_line, opts.height, opts.style);
        }

        if (opts.show_cursor) {
            const cursor = cursorPoint(self.value.items, self.cursor);
            if (cursor.row >= opts.scroll_line) {
                const visible_row = cursor.row - opts.scroll_line;
                if (visible_row < opts.height and cursor.col < opts.width) {
                    child.showCursor(cursor.col, @intCast(visible_row));
                }
            }
        }
    }

    fn insertCodepoint(self: *TextArea, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(codepoint, &buf);
        try self.insertBytes(buf[0..len]);
    }

    fn insertBytes(self: *TextArea, bytes: []const u8) !void {
        try self.value.insertSlice(self.allocator, self.cursor, bytes);
        self.cursor += bytes.len;
    }

    fn backspace(self: *TextArea) void {
        if (self.cursor == 0) return;
        const start = previousScalarStart(self.value.items, self.cursor);
        self.value.replaceRangeAssumeCapacity(start, self.cursor - start, "");
        self.cursor = start;
    }

    fn delete(self: *TextArea) void {
        if (self.cursor >= self.value.items.len) return;
        const end = nextScalarEnd(self.value.items, self.cursor);
        self.value.replaceRangeAssumeCapacity(self.cursor, end - self.cursor, "");
    }

    fn moveVertical(self: *TextArea, direction: enum { up, down }) void {
        const bytes = self.value.items;
        const current_start = lineStart(bytes, self.cursor);
        const current_end = lineEnd(bytes, self.cursor);
        const desired_col = chasen.text.displayWidth(bytes[current_start..self.cursor]);

        const target = switch (direction) {
            .up => previousLineBounds(bytes, current_start) orelse return,
            .down => nextLineBounds(bytes, current_end) orelse return,
        };
        self.cursor = byteOffsetForDisplayColumn(bytes[target.start..target.end], target.start, desired_col);
    }
};

const LineBounds = struct {
    start: usize,
    end: usize,
};

const CursorPoint = struct {
    col: u16,
    row: usize,
};

fn keyToMsg(key: chasen.Key) ?TextArea.Msg {
    if (key.matches(chasen.Key.enter, .{})) return .insert_newline;
    if (key.matches(chasen.Key.backspace, .{})) return .backspace;
    if (key.matches(chasen.Key.delete, .{})) return .delete;
    if (key.matches(chasen.Key.left, .{})) return .move_left;
    if (key.matches(chasen.Key.right, .{})) return .move_right;
    if (key.matches(chasen.Key.up, .{})) return .move_up;
    if (key.matches(chasen.Key.down, .{})) return .move_down;
    if (key.matches(chasen.Key.home, .{})) return .home;
    if (key.matches(chasen.Key.end, .{})) return .end;

    if (keyTextCodepoint(key)) |codepoint| {
        return .{ .insert = codepoint };
    }
    return null;
}

fn keyTextCodepoint(key: chasen.Key) ?u21 {
    if (key.mods.ctrl or key.mods.alt or key.mods.super or key.mods.hyper or key.mods.meta) {
        return null;
    }

    const text = key.text orelse return null;
    if (text.len == 0) return null;

    const len = std.unicode.utf8ByteSequenceLength(text[0]) catch return null;
    if (len != text.len) return null;

    const codepoint = std.unicode.utf8Decode(text) catch return null;
    if (!isPrintable(codepoint)) return null;
    return codepoint;
}

fn isPrintable(codepoint: u21) bool {
    return codepoint >= 0x20 and codepoint != 0x7f and !(codepoint >= 0x80 and codepoint <= 0x9f);
}

fn previousScalarStart(bytes: []const u8, index: usize) usize {
    if (index == 0) return 0;
    var i = index - 1;
    while (i > 0 and (bytes[i] & 0b1100_0000) == 0b1000_0000) : (i -= 1) {}
    return i;
}

fn nextScalarEnd(bytes: []const u8, index: usize) usize {
    if (index >= bytes.len) return bytes.len;
    const len = std.unicode.utf8ByteSequenceLength(bytes[index]) catch 1;
    return @min(bytes.len, index + len);
}

fn lineStart(bytes: []const u8, index: usize) usize {
    var i = @min(index, bytes.len);
    while (i > 0) {
        if (bytes[i - 1] == '\n') break;
        i -= 1;
    }
    return i;
}

fn lineEnd(bytes: []const u8, index: usize) usize {
    var i = @min(index, bytes.len);
    while (i < bytes.len and bytes[i] != '\n') : (i += 1) {}
    return i;
}

fn previousLineBounds(bytes: []const u8, current_start: usize) ?LineBounds {
    if (current_start == 0) return null;
    const end = current_start - 1;
    const start = lineStart(bytes, end);
    return .{ .start = start, .end = end };
}

fn nextLineBounds(bytes: []const u8, current_end: usize) ?LineBounds {
    if (current_end >= bytes.len) return null;
    const start = current_end + 1;
    const end = lineEnd(bytes, start);
    return .{ .start = start, .end = end };
}

fn byteOffsetForDisplayColumn(line: []const u8, base: usize, desired_col: u16) usize {
    var col: u32 = 0;
    var iter = chasen.text.graphemeIterator(line);
    while (iter.next()) |grapheme| {
        const width = chasen.text.displayWidth(grapheme.bytes(line));
        if (col + width > desired_col) return base + grapheme.start;
        col += width;
    }
    return base + line.len;
}

fn lineIndexAt(bytes: []const u8, index: usize) usize {
    var line: usize = 0;
    var i: usize = 0;
    const end = @min(index, bytes.len);
    while (i < end) : (i += 1) {
        if (bytes[i] == '\n') line += 1;
    }
    return line;
}

fn cursorPoint(bytes: []const u8, cursor: usize) CursorPoint {
    const start = lineStart(bytes, cursor);
    return .{
        .row = lineIndexAt(bytes, cursor),
        .col = chasen.text.displayWidth(bytes[start..cursor]),
    };
}

fn drawLines(surface: *chasen.Surface, text: []const u8, scroll_line: usize, height: u16, style: chasen.TextStyle) void {
    var source_line: usize = 0;
    var row: u16 = 0;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i <= text.len) : (i += 1) {
        if (i == text.len or text[i] == '\n') {
            if (source_line >= scroll_line) {
                _ = surface.textAt(0, row, text[line_start..i], style);
                row += 1;
                if (row >= height) return;
            }
            source_line += 1;
            line_start = i + 1;
        }
    }
}

test "TextArea inserts text and explicit newlines" {
    var area = try TextArea.init(std.testing.allocator, .{});
    defer area.deinit();

    try area.update(.{ .insert = 'a' });
    try area.update(.insert_newline);
    try area.update(.{ .insert = 'b' });

    try std.testing.expectEqualStrings("a\nb", area.text());
    try std.testing.expectEqual(@as(usize, "a\nb".len), area.cursor);
}

test "TextArea backspace and delete remove utf8 scalars and newlines" {
    var area = try TextArea.init(std.testing.allocator, .{ .value = "a\nあb" });
    defer area.deinit();

    area.cursor = "a\nあ".len;
    try area.update(.backspace);
    try std.testing.expectEqualStrings("a\nb", area.text());
    try std.testing.expectEqual(@as(usize, "a\n".len), area.cursor);

    area.cursor = 1;
    try area.update(.delete);
    try std.testing.expectEqualStrings("ab", area.text());
}

test "TextArea home end and cursor position use explicit lines" {
    var area = try TextArea.init(std.testing.allocator, .{ .value = "abc\nde" });
    defer area.deinit();

    area.cursor = "abc\nd".len;
    try std.testing.expectEqual(@as(usize, 1), area.cursorLine());
    try std.testing.expectEqual(@as(u16, 1), area.cursorColumn());

    try area.update(.home);
    try std.testing.expectEqual(@as(usize, "abc\n".len), area.cursor);

    try area.update(.end);
    try std.testing.expectEqual(@as(usize, "abc\nde".len), area.cursor);
}

test "TextArea reports grapheme and display-cell cursor columns separately" {
    var area = try TextArea.init(std.testing.allocator, .{ .value = "あ" });
    defer area.deinit();

    try std.testing.expectEqual(@as(usize, 1), area.cursorGraphemeColumn());
    try std.testing.expectEqual(@as(u16, 2), area.cursorColumn());
}

test "TextArea moves vertically to nearest display column" {
    var area = try TextArea.init(std.testing.allocator, .{ .value = "abcd\nあい\nxy" });
    defer area.deinit();

    area.cursor = 3;
    try area.update(.move_down);
    try std.testing.expectEqual(@as(usize, "abcd\nあ".len), area.cursor);

    try area.update(.move_down);
    try std.testing.expectEqual(@as(usize, "abcd\nあい\nxy".len), area.cursor);

    try area.update(.move_up);
    try std.testing.expectEqual(@as(usize, "abcd\nあ".len), area.cursor);
}

test "TextArea maps key events to editing messages" {
    var area = try TextArea.init(std.testing.allocator, .{});
    defer area.deinit();

    try std.testing.expectEqual(TextArea.Msg.insert_newline, area.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
    try std.testing.expectEqual(TextArea.Msg.move_up, area.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.up },
    }).?);
    try std.testing.expectEqual(TextArea.Msg.move_down, area.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.down },
    }).?);
    try std.testing.expectEqual(TextArea.Msg{ .insert = 'x' }, area.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }).?);
}

test "TextArea ignores modified text input" {
    var area = try TextArea.init(std.testing.allocator, .{});
    defer area.deinit();

    try std.testing.expect(area.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x", .mods = .{ .ctrl = true } },
    }) == null);
}

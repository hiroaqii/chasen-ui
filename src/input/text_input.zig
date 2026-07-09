const std = @import("std");
const chasen = @import("chasen");
const text_edit = @import("text_edit.zig");

/// A single-line text input component.
///
/// `TextInput` owns its editable UTF-8 buffer and cursor position. Applications
/// normally keep one instance in their model, call `handleEvent` from their app
/// event handler, forward returned messages to `update`, and call `view` from
/// their app view.
///
/// The component emits `.submit` for Enter but does not clear itself. This lets
/// the application decide whether submit means form submission, search,
/// validation, or some other action.
pub const TextInput = struct {
    /// Allocator used for the owned text buffer.
    allocator: std.mem.Allocator,
    /// Current UTF-8 text buffer.
    value: std.ArrayList(u8) = .empty,
    /// Cursor byte offset into `value`.
    ///
    /// Editing keeps this offset on a grapheme boundary. Terminal cursor
    /// columns are derived from display width instead of byte count. If caller
    /// code sets this public field inside a grapheme cluster, movement and
    /// deletion repair the position to a surrounding grapheme boundary.
    cursor: usize = 0,
    /// Text shown when the input is empty. Borrowed; must outlive the component.
    placeholder: []const u8 = "",

    /// Initial values used when constructing a `TextInput`.
    pub const Options = struct {
        /// Initial input contents. The bytes are copied into the component.
        value: []const u8 = "",
        /// Placeholder text borrowed by the component for its lifetime.
        placeholder: []const u8 = "",
    };

    /// Messages understood by `TextInput.update`.
    ///
    /// Applications can either use `handleEvent` to create these messages from
    /// Chasen key events, or construct them directly for custom bindings.
    pub const Msg = union(enum) {
        /// Insert one Unicode scalar at the current cursor position.
        insert: u21,
        /// Remove the grapheme cluster before the cursor.
        backspace,
        /// Remove the grapheme cluster at the cursor.
        delete,
        /// Move the cursor one grapheme cluster to the left.
        move_left,
        /// Move the cursor one grapheme cluster to the right.
        move_right,
        /// Move the cursor to the start of the buffer.
        home,
        /// Move the cursor to the end of the buffer.
        end,
        /// Remove all text and move the cursor to the start.
        clear,
        /// Enter was pressed. `update` treats this as a no-op.
        submit,
    };

    /// Rendering options for `TextInput.view`.
    pub const ViewOptions = struct {
        /// Style used for the current value.
        style: chasen.TextStyle = .{},
        /// Style used when drawing the placeholder.
        placeholder_style: chasen.TextStyle = .{ .fg = .gray },
        /// Whether `view` should place the terminal cursor inside the input.
        show_cursor: bool = true,
    };

    /// Create a text input with copied initial contents.
    ///
    /// The caller owns the returned component and must call `deinit` exactly
    /// once when the component is no longer needed.
    pub fn init(allocator: std.mem.Allocator, opts: Options) !TextInput {
        var input: TextInput = .{
            .allocator = allocator,
            .placeholder = opts.placeholder,
        };
        try input.value.appendSlice(allocator, opts.value);
        input.cursor = input.value.items.len;
        return input;
    }

    /// Release memory owned by this component.
    pub fn deinit(self: *TextInput) void {
        self.value.deinit(self.allocator);
        self.* = undefined;
    }

    /// Return the current input contents.
    ///
    /// The returned slice is borrowed from the component and becomes invalid
    /// after the next mutating `update` call or `deinit`.
    pub fn text(self: *const TextInput) []const u8 {
        return self.value.items;
    }

    /// Apply a component message.
    ///
    /// Text editing messages mutate the owned buffer and cursor. `.submit` is
    /// intentionally a no-op so the parent application can handle submission
    /// policy itself.
    pub fn update(self: *TextInput, msg: Msg) !void {
        switch (msg) {
            .insert => |codepoint| try self.insertCodepoint(codepoint),
            .backspace => self.backspace(),
            .delete => self.delete(),
            .move_left => self.moveLeft(),
            .move_right => self.moveRight(),
            .home => self.cursor = 0,
            .end => self.cursor = self.value.items.len,
            .clear => {
                self.value.clearRetainingCapacity();
                self.cursor = 0;
            },
            .submit => {},
        }
    }

    /// Convert a Chasen event into a `TextInput` message when the event belongs
    /// to the component.
    ///
    /// Printable key text without command-style modifiers maps to `.insert`.
    /// Enter, Backspace, Delete, Left, Right, Home, and End map to their
    /// editing messages. Ctrl, Alt, Super, Hyper, and Meta text input is
    /// ignored so applications can reserve those bindings for app-level
    /// shortcuts.
    pub fn handleEvent(self: *const TextInput, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| keyToMsg(key),
            else => null,
        };
    }

    /// Draw the input into the provided one-line surface region.
    ///
    /// `view` does not mutate component state. When the input is empty, it draws
    /// the placeholder if one was provided. The visible text is clipped so the
    /// cursor remains inside the surface width.
    pub fn view(self: *const TextInput, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        const visible = self.visibleText(width);
        if (visible.len == 0 and self.value.items.len == 0 and self.placeholder.len > 0) {
            _ = surface.borrowTextAt(0, 0, self.placeholder, opts.placeholder_style);
        } else {
            _ = surface.borrowTextAt(0, 0, visible, opts.style);
        }

        if (opts.show_cursor) {
            surface.showCursor(self.visibleCursorCol(width), 0);
        }
    }

    fn insertCodepoint(self: *TextInput, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(codepoint, &buf);
        self.cursor = text_edit.insertionBoundary(self.value.items, self.cursor);
        try self.value.insertSlice(self.allocator, self.cursor, buf[0..len]);
        self.cursor += len;
    }

    fn backspace(self: *TextInput) void {
        if (self.cursor == 0) return;
        const range = text_edit.graphemeBeforeOrContaining(self.value.items, self.cursor);
        self.value.replaceRangeAssumeCapacity(range.start, range.end - range.start, "");
        self.cursor = range.start;
    }

    fn delete(self: *TextInput) void {
        if (self.cursor >= self.value.items.len) return;
        const range = text_edit.graphemeAtOrContaining(self.value.items, self.cursor);
        self.value.replaceRangeAssumeCapacity(range.start, range.end - range.start, "");
        self.cursor = range.start;
    }

    fn moveLeft(self: *TextInput) void {
        self.cursor = text_edit.previousGraphemeStart(self.value.items, self.cursor);
    }

    fn moveRight(self: *TextInput) void {
        self.cursor = text_edit.nextGraphemeEnd(self.value.items, self.cursor);
    }

    fn visibleText(self: *const TextInput, width: u16) []const u8 {
        if (width == 0) return "";
        if (self.value.items.len == 0) return "";
        const start = visibleStart(self.value.items, self.cursor, width);
        return self.value.items[start..];
    }

    fn visibleCursorCol(self: *const TextInput, width: u16) u16 {
        if (width == 0) return 0;
        const start = visibleStart(self.value.items, self.cursor, width);
        const bytes = self.value.items[start..self.cursor];
        return @min(width - 1, chasen.text.displayWidth(bytes));
    }
};

fn keyToMsg(key: chasen.Key) ?TextInput.Msg {
    if (key.matches(chasen.Key.enter, .{})) return .submit;
    if (key.matches(chasen.Key.backspace, .{})) return .backspace;
    if (key.matches(chasen.Key.delete, .{})) return .delete;
    if (key.matches(chasen.Key.left, .{})) return .move_left;
    if (key.matches(chasen.Key.right, .{})) return .move_right;
    if (key.matches(chasen.Key.home, .{})) return .home;
    if (key.matches(chasen.Key.end, .{})) return .end;

    if (text_edit.keyTextCodepoint(key)) |codepoint| {
        return .{ .insert = codepoint };
    }
    return null;
}

fn visibleStart(bytes: []const u8, cursor: usize, width: u16) usize {
    if (width == 0) return cursor;

    const max_width_before_cursor = width - 1;
    var iter = chasen.text.graphemeIterator(bytes);

    while (iter.next()) |grapheme| {
        const grapheme_end = grapheme.start + grapheme.len;
        if (grapheme_end > cursor) break;

        if (chasen.text.displayWidth(bytes[grapheme.start..cursor]) <= max_width_before_cursor) {
            return grapheme.start;
        }
    }

    return cursor;
}

test "TextInput inserts codepoints at the cursor" {
    var input = try TextInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try input.update(.{ .insert = 'a' });
    try input.update(.{ .insert = 'b' });
    input.cursor = 1;
    try input.update(.{ .insert = 'Z' });

    try std.testing.expectEqualStrings("aZb", input.text());
    try std.testing.expectEqual(@as(usize, 2), input.cursor);
}

test "TextInput backspace and delete remove full grapheme clusters" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "aあb" });
    defer input.deinit();

    input.cursor = "aあ".len;
    try input.update(.backspace);
    try std.testing.expectEqualStrings("ab", input.text());
    try std.testing.expectEqual(@as(usize, 1), input.cursor);

    try input.update(.delete);
    try std.testing.expectEqualStrings("a", input.text());
    try std.testing.expectEqual(@as(usize, 1), input.cursor);
}

test "TextInput moves cursor by grapheme cluster" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "aあb" });
    defer input.deinit();

    try input.update(.move_left);
    try std.testing.expectEqual(@as(usize, "aあ".len), input.cursor);

    try input.update(.move_left);
    try std.testing.expectEqual(@as(usize, 1), input.cursor);

    try input.update(.move_right);
    try std.testing.expectEqual(@as(usize, "aあ".len), input.cursor);
}

test "TextInput does not split combining grapheme clusters" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "ae\u{301}b" });
    defer input.deinit();

    try input.update(.move_left);
    try std.testing.expectEqual(@as(usize, "ae\u{301}".len), input.cursor);

    try input.update(.move_left);
    try std.testing.expectEqual(@as(usize, "a".len), input.cursor);

    try input.update(.move_right);
    try std.testing.expectEqual(@as(usize, "ae\u{301}".len), input.cursor);

    try input.update(.backspace);
    try std.testing.expectEqualStrings("ab", input.text());
    try std.testing.expectEqual(@as(usize, "a".len), input.cursor);
}

test "TextInput delete removes emoji grapheme clusters" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "a👩‍🚀b" });
    defer input.deinit();

    input.cursor = "a".len;
    try input.update(.delete);
    try std.testing.expectEqualStrings("ab", input.text());
    try std.testing.expectEqual(@as(usize, "a".len), input.cursor);
}

test "TextInput deletion repairs cursor placed inside grapheme cluster" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "ae\u{301}b" });
    defer input.deinit();

    input.cursor = "ae".len;
    try input.update(.backspace);
    try std.testing.expectEqualStrings("ab", input.text());
    try std.testing.expectEqual(@as(usize, "a".len), input.cursor);

    var delete_input = try TextInput.init(std.testing.allocator, .{ .value = "ae\u{301}b" });
    defer delete_input.deinit();

    delete_input.cursor = "ae".len;
    try delete_input.update(.delete);
    try std.testing.expectEqualStrings("ab", delete_input.text());
    try std.testing.expectEqual(@as(usize, "a".len), delete_input.cursor);
}

test "TextInput insertion repairs cursor placed inside grapheme cluster" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "ae\u{301}b" });
    defer input.deinit();

    input.cursor = "ae".len;
    try input.update(.{ .insert = 'X' });
    try std.testing.expectEqualStrings("aXe\u{301}b", input.text());
    try std.testing.expectEqual(@as(usize, "aX".len), input.cursor);
}

test "TextInput maps printable key events to messages" {
    var input = try TextInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try std.testing.expectEqual(TextInput.Msg{ .insert = 'x' }, input.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }).?);
    try std.testing.expectEqual(TextInput.Msg.backspace, input.handleEvent(.{
        .key_press = .{ .codepoint = 127 },
    }).?);
    try std.testing.expectEqual(TextInput.Msg.submit, input.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "TextInput ignores special keys and modified text input" {
    var input = try TextInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try std.testing.expect(input.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.up },
    }) == null);
    try std.testing.expect(input.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x", .mods = .{ .ctrl = true } },
    }) == null);
    try std.testing.expect(input.handleEvent(.{
        .key_press = .{ .codepoint = 0x80, .text = "\xc2\x80" },
    }) == null);
}

test "TextInput maps navigation key events to messages" {
    var input = try TextInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try std.testing.expectEqual(TextInput.Msg.delete, input.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.delete },
    }).?);
    try std.testing.expectEqual(TextInput.Msg.move_left, input.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.left },
    }).?);
    try std.testing.expectEqual(TextInput.Msg.move_right, input.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.right },
    }).?);
    try std.testing.expectEqual(TextInput.Msg.home, input.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.home },
    }).?);
    try std.testing.expectEqual(TextInput.Msg.end, input.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.end },
    }).?);
}

test "TextInput visible cursor column stays inside width" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "abcde" });
    defer input.deinit();

    try std.testing.expectEqual(@as(u16, 0), input.visibleCursorCol(0));
    try std.testing.expectEqual(@as(u16, 4), input.visibleCursorCol(5));
    try std.testing.expectEqualStrings("bcde", input.visibleText(5));
    input.cursor = 2;
    try std.testing.expectEqual(@as(u16, 2), input.visibleCursorCol(5));
    try std.testing.expectEqualStrings("abcde", input.visibleText(5));
}

test "TextInput visible start counts grapheme display width" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "aあいう" });
    defer input.deinit();

    try std.testing.expectEqualStrings("いう", input.visibleText(5));
    try std.testing.expectEqual(@as(u16, 4), input.visibleCursorCol(5));
}

test "TextInput visible helpers handle narrow and maximum widths" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "abcdef" });
    defer input.deinit();

    try std.testing.expectEqual(@as(u16, 0), input.visibleCursorCol(1));
    try std.testing.expectEqualStrings("", input.visibleText(1));

    const long_value = try std.testing.allocator.alloc(u8, @as(usize, std.math.maxInt(u16)) + 1);
    defer std.testing.allocator.free(long_value);
    @memset(long_value, 'x');

    var long_input = try TextInput.init(std.testing.allocator, .{ .value = long_value });
    defer long_input.deinit();

    try std.testing.expectEqual(std.math.maxInt(u16) - 1, long_input.visibleCursorCol(std.math.maxInt(u16)));
}

test {
    _ = text_edit;
}

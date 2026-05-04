const std = @import("std");
const chasen = @import("chasen");

pub const TextInput = struct {
    allocator: std.mem.Allocator,
    value: std.ArrayList(u8) = .empty,
    cursor: usize = 0,
    placeholder: []const u8 = "",

    pub const Options = struct {
        value: []const u8 = "",
        placeholder: []const u8 = "",
    };

    pub const Msg = union(enum) {
        insert: u21,
        backspace,
        delete,
        move_left,
        move_right,
        home,
        end,
        clear,
        submit,
    };

    pub const ViewOptions = struct {
        col: u16 = 0,
        row: u16 = 0,
        width: u16,
        style: chasen.TextStyle = .{},
        placeholder_style: chasen.TextStyle = .{ .fg = .gray },
        show_cursor: bool = true,
    };

    pub fn init(allocator: std.mem.Allocator, opts: Options) !TextInput {
        var input: TextInput = .{
            .allocator = allocator,
            .placeholder = opts.placeholder,
        };
        try input.value.appendSlice(allocator, opts.value);
        input.cursor = input.value.items.len;
        return input;
    }

    pub fn deinit(self: *TextInput) void {
        self.value.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn text(self: *const TextInput) []const u8 {
        return self.value.items;
    }

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

    pub fn handleEvent(self: *const TextInput, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| keyToMsg(key),
            else => null,
        };
    }

    pub fn view(self: *const TextInput, surface: *chasen.Surface, opts: ViewOptions) void {
        if (opts.width == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = opts.width,
            .height = 1,
        });
        const visible = self.visibleText(opts.width);
        if (visible.len == 0 and self.value.items.len == 0 and self.placeholder.len > 0) {
            _ = child.textAt(0, 0, self.placeholder, opts.placeholder_style);
        } else {
            _ = child.textAt(0, 0, visible, opts.style);
        }

        if (opts.show_cursor) {
            child.showCursor(self.visibleCursorCol(opts.width), 0);
        }
    }

    fn insertCodepoint(self: *TextInput, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(codepoint, &buf);
        try self.value.insertSlice(self.allocator, self.cursor, buf[0..len]);
        self.cursor += len;
    }

    fn backspace(self: *TextInput) void {
        if (self.cursor == 0) return;
        const start = previousScalarStart(self.value.items, self.cursor);
        self.value.replaceRangeAssumeCapacity(start, self.cursor - start, "");
        self.cursor = start;
    }

    fn delete(self: *TextInput) void {
        if (self.cursor >= self.value.items.len) return;
        const end = nextScalarEnd(self.value.items, self.cursor);
        self.value.replaceRangeAssumeCapacity(self.cursor, end - self.cursor, "");
    }

    fn moveLeft(self: *TextInput) void {
        self.cursor = previousScalarStart(self.value.items, self.cursor);
    }

    fn moveRight(self: *TextInput) void {
        self.cursor = nextScalarEnd(self.value.items, self.cursor);
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

test "TextInput backspace and delete remove full utf8 scalars" {
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

test "TextInput moves cursor by utf8 scalar" {
    var input = try TextInput.init(std.testing.allocator, .{ .value = "aあb" });
    defer input.deinit();

    try input.update(.move_left);
    try std.testing.expectEqual(@as(usize, "aあ".len), input.cursor);

    try input.update(.move_left);
    try std.testing.expectEqual(@as(usize, 1), input.cursor);

    try input.update(.move_right);
    try std.testing.expectEqual(@as(usize, "aあ".len), input.cursor);
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

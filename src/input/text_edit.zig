const std = @import("std");
const chasen = @import("chasen");

pub const GraphemeRange = struct {
    start: usize,
    end: usize,
};

pub fn keyTextCodepoint(key: chasen.Key) ?u21 {
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

pub fn isPrintable(codepoint: u21) bool {
    return codepoint >= 0x20 and codepoint != 0x7f and !(codepoint >= 0x80 and codepoint <= 0x9f);
}

pub fn previousGraphemeStart(bytes: []const u8, index: usize) usize {
    const target = @min(index, bytes.len);
    if (target == 0) return 0;

    var previous: usize = 0;
    var iter = chasen.text.graphemeIterator(bytes);
    while (iter.next()) |grapheme| {
        if (grapheme.start >= target) break;
        const end = grapheme.start + grapheme.len;
        if (end >= target) return grapheme.start;
        previous = grapheme.start;
    }
    return previous;
}

pub fn nextGraphemeEnd(bytes: []const u8, index: usize) usize {
    const target = @min(index, bytes.len);
    if (target >= bytes.len) return bytes.len;

    var iter = chasen.text.graphemeIterator(bytes);
    while (iter.next()) |grapheme| {
        const end = grapheme.start + grapheme.len;
        if (grapheme.start <= target and target < end) return end;
        if (grapheme.start > target) return end;
    }
    return bytes.len;
}

pub fn graphemeBeforeOrContaining(bytes: []const u8, index: usize) GraphemeRange {
    const target = @min(index, bytes.len);
    var previous: GraphemeRange = .{ .start = 0, .end = 0 };
    var iter = chasen.text.graphemeIterator(bytes);
    while (iter.next()) |grapheme| {
        const range: GraphemeRange = .{
            .start = grapheme.start,
            .end = grapheme.start + grapheme.len,
        };
        if (range.start < target and target <= range.end) return range;
        if (range.end >= target) return previous;
        previous = range;
    }
    return previous;
}

pub fn graphemeAtOrContaining(bytes: []const u8, index: usize) GraphemeRange {
    const target = @min(index, bytes.len);
    var iter = chasen.text.graphemeIterator(bytes);
    while (iter.next()) |grapheme| {
        const range: GraphemeRange = .{
            .start = grapheme.start,
            .end = grapheme.start + grapheme.len,
        };
        if (range.start <= target and target < range.end) return range;
        if (range.start > target) return range;
    }
    return .{ .start = bytes.len, .end = bytes.len };
}

pub fn insertionBoundary(bytes: []const u8, index: usize) usize {
    const target = @min(index, bytes.len);
    var iter = chasen.text.graphemeIterator(bytes);
    while (iter.next()) |grapheme| {
        const end = grapheme.start + grapheme.len;
        if (target == grapheme.start or target == end) return target;
        if (grapheme.start < target and target < end) return grapheme.start;
        if (grapheme.start > target) return grapheme.start;
    }
    return bytes.len;
}

test "text edit grapheme movement handles wide combining and emoji clusters" {
    const text = "aあe\u{301}👩‍🚀b";

    try std.testing.expectEqual(@as(usize, "aあe\u{301}".len), previousGraphemeStart(text, "aあe\u{301}👩‍🚀".len));
    try std.testing.expectEqual(@as(usize, "a".len), previousGraphemeStart(text, "aあ".len));
    try std.testing.expectEqual(@as(usize, "aあ".len), nextGraphemeEnd(text, "a".len));
    try std.testing.expectEqual(@as(usize, "aあe\u{301}👩‍🚀".len), nextGraphemeEnd(text, "aあe\u{301}".len));
}

test "text edit range helpers repair indexes inside grapheme clusters" {
    const text = "ae\u{301}b";

    const before = graphemeBeforeOrContaining(text, "ae".len);
    try std.testing.expectEqual(@as(usize, "a".len), before.start);
    try std.testing.expectEqual(@as(usize, "ae\u{301}".len), before.end);

    const at = graphemeAtOrContaining(text, "ae".len);
    try std.testing.expectEqual(@as(usize, "a".len), at.start);
    try std.testing.expectEqual(@as(usize, "ae\u{301}".len), at.end);
}

test "text edit insertion boundary snaps inside grapheme to start" {
    const text = "ae\u{301}b";

    try std.testing.expectEqual(@as(usize, "a".len), insertionBoundary(text, "ae".len));
    try std.testing.expectEqual(@as(usize, "ae\u{301}".len), insertionBoundary(text, "ae\u{301}".len));
}

test "text edit printable predicate covers control boundaries" {
    try std.testing.expect(isPrintable(0x20));
    try std.testing.expect(isPrintable('あ'));
    try std.testing.expect(!isPrintable(0x1f));
    try std.testing.expect(!isPrintable(0x7f));
    try std.testing.expect(!isPrintable(0x80));
    try std.testing.expect(!isPrintable(0x9f));
}

test "text edit key text codepoint accepts exactly one printable scalar" {
    try std.testing.expectEqual(@as(?u21, 'x'), keyTextCodepoint(.{ .codepoint = 'x', .text = "x" }));
    try std.testing.expectEqual(@as(?u21, 'あ'), keyTextCodepoint(.{ .codepoint = 'あ', .text = "あ" }));

    try std.testing.expect(keyTextCodepoint(.{ .codepoint = 'x', .text = "x", .mods = .{ .ctrl = true } }) == null);
    try std.testing.expect(keyTextCodepoint(.{ .codepoint = 'a', .text = "ab" }) == null);
    try std.testing.expect(keyTextCodepoint(.{ .codepoint = 0x7f, .text = "\x7f" }) == null);
    try std.testing.expect(keyTextCodepoint(.{ .codepoint = 'x', .text = "\xff" }) == null);
}

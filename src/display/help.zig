const std = @import("std");
const chasen = @import("chasen");

/// A compact one-line help hint component.
///
/// `Help` is display-only and allocation-free. It borrows a list of key/action
/// pairs and draws them left to right. Applications decide which shortcuts are
/// active, what each action means, and where the help row belongs.
pub const Help = struct {
    /// One shortcut hint.
    pub const Item = struct {
        /// Key label, such as "Esc", "Enter", or "Ctrl+S".
        key: []const u8,
        /// Action label shown after the separator.
        action: []const u8,
    };

    /// Initial values used when constructing a `Help`.
    pub const Options = struct {
        /// Items borrowed by the component for its lifetime.
        items: []const Item = &.{},
    };

    /// Rendering options for `Help.view`.
    pub const ViewOptions = struct {
        /// Text between each key and action.
        separator: []const u8 = ": ",
        /// Spaces between help items.
        item_gap: u16 = 2,
        /// Style used for key labels.
        key_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for separators.
        separator_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for action labels.
        action_style: chasen.TextStyle = .{ .fg = .gray },
    };

    /// Shortcut hints borrowed by the component.
    items: []const Item = &.{},

    /// Create a help component.
    pub fn init(opts: Options) Help {
        return .{ .items = opts.items };
    }

    /// Return the display width of one item using `separator`.
    pub fn itemWidth(item: Item, separator: []const u8) u16 {
        var width: u16 = chasen.text.displayWidth(item.key);
        width +|= chasen.text.displayWidth(separator);
        width +|= chasen.text.displayWidth(item.action);
        return width;
    }

    /// Return the display width of all items before clipping.
    pub fn contentWidth(items: []const Item, separator: []const u8, item_gap: u16) u16 {
        var width: u16 = 0;
        for (items, 0..) |item, i| {
            if (i > 0) width +|= item_gap;
            width +|= itemWidth(item, separator);
        }
        return width;
    }

    /// Draw the help hints into the provided clipped one-line surface region.
    pub fn view(self: *const Help, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        var cursor: u16 = 0;
        for (self.items, 0..) |item, i| {
            if (i > 0) drawSpaces(surface, &cursor, opts.item_gap, .{}, width);
            drawText(surface, &cursor, item.key, opts.key_style, width);
            drawText(surface, &cursor, opts.separator, opts.separator_style, width);
            drawText(surface, &cursor, item.action, opts.action_style, width);
        }
    }
};

fn drawText(surface: *chasen.Surface, cursor: *u16, text: []const u8, style: chasen.TextStyle, width: u16) void {
    if (text.len == 0 or cursor.* >= width) return;
    _ = surface.textAt(cursor.*, 0, text, style);
    cursor.* +|= chasen.text.displayWidth(text);
}

fn drawSpaces(surface: *chasen.Surface, cursor: *u16, count: u16, style: chasen.TextStyle, width: u16) void {
    var index: u16 = 0;
    while (index < count and cursor.* < width) : (index += 1) {
        _ = surface.textAt(cursor.*, 0, " ", style);
        cursor.* +|= 1;
    }
}

test "Help initializes from options" {
    const items = [_]Help.Item{
        .{ .key = "Enter", .action = "save" },
        .{ .key = "Esc", .action = "quit" },
    };
    const help = Help.init(.{ .items = &items });

    try std.testing.expectEqual(@as(usize, 2), help.items.len);
    try std.testing.expectEqualStrings("Enter", help.items[0].key);
    try std.testing.expectEqualStrings("quit", help.items[1].action);
}

test "Help width helpers use display width" {
    const items = [_]Help.Item{
        .{ .key = "Enter", .action = "save" },
        .{ .key = "あ", .action = "戻る" },
    };

    try std.testing.expectEqual(@as(u16, 11), Help.itemWidth(items[0], ": "));
    try std.testing.expectEqual(@as(u16, 8), Help.itemWidth(items[1], ": "));
    try std.testing.expectEqual(@as(u16, 22), Help.contentWidth(&items, ": ", 3));
}

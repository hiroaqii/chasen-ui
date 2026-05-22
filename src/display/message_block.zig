const std = @import("std");
const chasen = @import("chasen");

/// A centered two-line message block for loading, empty, error, and guidance states.
///
/// `MessageBlock` is display-only and allocation-free. It borrows title/body
/// text, centers the block in the provided surface, and optionally hides the
/// terminal cursor for non-input transient states.
pub const MessageBlock = struct {
    /// Text borrowed by the component.
    title: []const u8 = "",
    /// Optional second line borrowed by the component.
    message: []const u8 = "",

    /// Initial values used when constructing a `MessageBlock`.
    pub const Options = struct {
        /// Title line borrowed by the component for its lifetime.
        title: []const u8 = "",
        /// Message line borrowed by the component for its lifetime.
        message: []const u8 = "",
    };

    /// Rendering options for `MessageBlock.view`.
    pub const ViewOptions = struct {
        /// Style used for the title line.
        title_style: chasen.TextStyle = .{ .bold = true, .fg = .gray },
        /// Style used for the message line.
        message_style: chasen.TextStyle = .{ .fg = .gray },
        /// Hide the terminal cursor before drawing.
        ///
        /// Use `false` when a nearby input widget remains active.
        hide_cursor: bool = true,
    };

    /// Centered coordinates for each visible line.
    ///
    /// Use this when an app wants `MessageBlock` placement but needs to draw one
    /// line with a custom renderer, such as a loading animation.
    pub const Layout = struct {
        title: ?Point = null,
        message: ?Point = null,
    };

    /// A terminal cell coordinate inside the message block's surface.
    pub const Point = struct {
        col: u16,
        row: u16,
    };

    /// Create a message block.
    pub fn init(opts: Options) MessageBlock {
        return .{ .title = opts.title, .message = opts.message };
    }

    /// Draw the message block centered within the provided surface.
    pub fn view(self: *const MessageBlock, surface: *chasen.Surface, opts: ViewOptions) void {
        if (opts.hide_cursor) surface.hideCursor();
        const layout_result = self.layout(surface.size());
        if (layout_result.title) |point| _ = surface.borrowTextAt(point.col, point.row, self.title, opts.title_style);
        if (layout_result.message) |point| _ = surface.borrowTextAt(point.col, point.row, self.message, opts.message_style);
    }

    /// Return how many rows this message occupies before clipping.
    pub fn contentHeight(self: MessageBlock) u16 {
        if (self.title.len > 0 and self.message.len > 0) return 2;
        if (self.title.len > 0 or self.message.len > 0) return 1;
        return 0;
    }

    /// Return centered line coordinates for a given available size.
    pub fn layout(self: MessageBlock, size: chasen.Size) Layout {
        if (size.width == 0 or size.height == 0) return .{};

        const rows = self.contentHeight();
        if (rows == 0) return .{};

        var result: Layout = .{};
        var row: u16 = if (size.height > rows) (size.height - rows) / 2 else 0;
        if (self.title.len > 0) {
            result.title = .{ .col = centeredCol(size.width, self.title), .row = row };
            row += 1;
        }
        if (self.message.len > 0 and row < size.height) {
            result.message = .{ .col = centeredCol(size.width, self.message), .row = row };
        }
        return result;
    }
};

/// Draw one line horizontally centered within `surface`.
pub fn drawCenteredText(surface: *chasen.Surface, row: u16, text: []const u8, style: chasen.TextStyle) void {
    if (row >= surface.size().height) return;
    const col = centeredCol(surface.size().width, text);
    _ = surface.borrowTextAt(col, row, text, style);
}

fn centeredCol(width: u16, text: []const u8) u16 {
    const text_width = chasen.text.displayWidth(text);
    return if (text_width >= width) 0 else @intCast((width - text_width) / 2);
}

test "MessageBlock initializes from options" {
    const block = MessageBlock.init(.{ .title = "Loading", .message = "Please wait" });

    try std.testing.expectEqualStrings("Loading", block.title);
    try std.testing.expectEqualStrings("Please wait", block.message);
}

test "MessageBlock content height follows present lines" {
    try std.testing.expectEqual(@as(u16, 0), MessageBlock.init(.{}).contentHeight());
    try std.testing.expectEqual(@as(u16, 1), MessageBlock.init(.{ .title = "Only title" }).contentHeight());
    try std.testing.expectEqual(@as(u16, 1), MessageBlock.init(.{ .message = "Only message" }).contentHeight());
    try std.testing.expectEqual(@as(u16, 2), MessageBlock.init(.{ .title = "Title", .message = "Message" }).contentHeight());
}

test "MessageBlock layout exposes centered title and message points" {
    const block = MessageBlock.init(.{ .title = "Title", .message = "Message" });
    const layout = block.layout(.{ .width = 20, .height = 6 });

    try std.testing.expectEqual(MessageBlock.Point{ .col = 7, .row = 2 }, layout.title.?);
    try std.testing.expectEqual(MessageBlock.Point{ .col = 6, .row = 3 }, layout.message.?);
}

test "MessageBlock layout clips message when surface has one row" {
    const block = MessageBlock.init(.{ .title = "Title", .message = "Message" });
    const layout = block.layout(.{ .width = 20, .height = 1 });

    try std.testing.expect(layout.title != null);
    try std.testing.expect(layout.message == null);
}

test "MessageBlock centers message-only content on its single row" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(20, 5);
    defer ts.deinit();

    const block = MessageBlock.init(.{ .message = "Only" });
    block.view(&ts.surface, .{ .hide_cursor = false });

    try ts.expectCellText(8, 2, "O");
}

test "MessageBlock draws message-only content in one-row surfaces" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(20, 1);
    defer ts.deinit();

    const block = MessageBlock.init(.{ .message = "Only" });
    block.view(&ts.surface, .{ .hide_cursor = false });

    try ts.expectCellText(8, 0, "O");
}

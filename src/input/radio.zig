const std = @import("std");
const chasen = @import("chasen");
const selectable = @import("../navigation/selectable.zig");

/// A single radio option component.
///
/// `Radio` owns whether this option is selected and borrows its label. A radio
/// group policy, such as clearing the other options when one is selected, stays
/// in the parent application for now.
pub const Radio = struct {
    /// Current selected state.
    selected_value: bool = false,
    /// Text shown after the radio marker. Borrowed; must outlive the component.
    label: []const u8 = "",

    /// Initial values used when constructing a `Radio`.
    pub const Options = struct {
        /// Initial selected state.
        selected: bool = false,
        /// Label text borrowed by the component for its lifetime.
        label: []const u8 = "",
    };

    /// Messages understood by `Radio.update`.
    ///
    /// Applications can either use `handleEvent` to create these messages from
    /// Chasen key events, or construct them directly for custom bindings.
    pub const Msg = union(enum) {
        /// Select this radio option. This is idempotent.
        select,
        /// Set the selected state explicitly.
        set_selected: bool,
    };

    /// Marker shapes available when drawing a radio option.
    pub const Marker = enum {
        /// Filled and empty circles: ● / ○. The default.
        circle,
        /// A circle with a center dot, or an empty circle: ◉ / ○.
        ring,
        /// Filled and empty diamonds: ◆ / ◇.
        diamond,

        fn glyph(self: Marker, is_selected: bool) []const u8 {
            return switch (self) {
                .circle => if (is_selected) "●" else "○",
                .ring => if (is_selected) "◉" else "○",
                .diamond => if (is_selected) "◆" else "◇",
            };
        }
    };

    /// Rendering options for `Radio.view`.
    pub const ViewOptions = struct {
        /// Shape used for the selected and unselected markers.
        marker: Marker = .circle,
        /// Style used for the radio marker.
        style: chasen.TextStyle = .{},
        /// Style used for the selected marker.
        selected_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the label.
        ///
        /// The label follows the marker's display width and a one-column gap.
        label_style: chasen.TextStyle = .{},
        /// Whether `view` should place the terminal cursor on the marker.
        show_cursor: bool = true,
    };

    /// Create a radio option.
    pub fn init(opts: Options) Radio {
        return .{
            .selected_value = opts.selected,
            .label = opts.label,
        };
    }

    /// Return whether this radio option is currently selected.
    pub fn selected(self: *const Radio) bool {
        return self.selected_value;
    }

    /// Apply a component message.
    pub fn update(self: *Radio, msg: Msg) void {
        switch (msg) {
            .select => self.selected_value = true,
            .set_selected => |selected_value| self.selected_value = selected_value,
        }
    }

    /// Convert a Chasen event into a `Radio` message when the event belongs to
    /// the component.
    ///
    /// Space without command-style modifiers and Enter both map to `.select`.
    /// Ctrl, Alt, Super, Hyper, and Meta Space are ignored so applications can
    /// reserve those bindings for app-level shortcuts.
    pub fn handleEvent(self: *const Radio, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| keyToMsg(key),
            else => null,
        };
    }

    /// Draw the radio option into the provided one-line surface region.
    pub fn view(self: *const Radio, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        if (size.width == 0 or size.height == 0) return;

        const marker = opts.marker.glyph(self.selected_value);
        const marker_style = if (self.selected_value) opts.selected_style else opts.style;
        _ = surface.borrowTextAt(0, 0, marker, marker_style);
        if (self.label.len > 0) {
            _ = surface.borrowTextAt(surface.displayWidth(marker) + 1, 0, self.label, opts.label_style);
        }

        if (opts.show_cursor) {
            surface.showCursor(0, 0);
        }
    }
};

fn keyToMsg(key: chasen.Key) ?Radio.Msg {
    if (selectable.isActivationKey(key)) return .select;
    return null;
}

test "Radio initializes from options" {
    const radio = Radio.init(.{
        .selected = true,
        .label = "Small",
    });

    try std.testing.expect(radio.selected());
    try std.testing.expectEqualStrings("Small", radio.label);
}

test "Radio update selects and sets selected state" {
    var radio = Radio.init(.{});

    radio.update(.select);
    try std.testing.expect(radio.selected());

    radio.update(.{ .set_selected = false });
    try std.testing.expect(!radio.selected());
}

test "Radio maps Space without command modifiers and Enter to select" {
    var radio = Radio.init(.{});

    try std.testing.expectEqual(Radio.Msg.select, radio.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " " },
    }).?);
    try std.testing.expectEqual(Radio.Msg.select, radio.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .shift = true } },
    }).?);
    try std.testing.expectEqual(Radio.Msg.select, radio.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "Radio ignores modified Space and unrelated events" {
    var radio = Radio.init(.{});

    try std.testing.expect(radio.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);
    try std.testing.expect(radio.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }) == null);
}

test "Radio default rendering uses circles with a compact label and cursor on the marker" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(7, 1);
    defer ts.deinit();

    var radio = Radio.init(.{ .selected = true, .label = "Small" });
    radio.view(&ts.surface, .{});
    try ts.expectSnapshot("● Small");
    try std.testing.expect(ts.screen.cursor_vis);
    try std.testing.expectEqual(@as(u16, 0), ts.screen.cursor.col);
    try std.testing.expectEqual(@as(u16, 0), ts.screen.cursor.row);

    radio.update(.{ .set_selected = false });
    radio.view(&ts.surface, .{});
    try ts.expectSnapshot("○ Small");
}

test "Radio marker choices preserve caller styles and label alignment in either state" {
    const cases = [_]struct { marker: Radio.Marker, selected: []const u8, unselected: []const u8 }{
        .{ .marker = .circle, .selected = "●", .unselected = "○" },
        .{ .marker = .ring, .selected = "◉", .unselected = "○" },
        .{ .marker = .diamond, .selected = "◆", .unselected = "◇" },
    };
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(7, 1);
    defer ts.deinit();

    for (cases) |case| {
        for ([_]bool{ true, false }) |is_selected| {
            ts.surface.clearAll();
            const radio = Radio.init(.{ .selected = is_selected, .label = "Small" });
            radio.view(&ts.surface, .{
                .marker = case.marker,
                .style = .{ .fg = .gray },
                .selected_style = .{ .fg = .{ .index = 14 }, .bold = true },
                .label_style = .{ .fg = .{ .index = 11 } },
                .show_cursor = false,
            });
            try ts.expectCellText(0, 0, if (is_selected) case.selected else case.unselected);
            try ts.expectCellText(1, 0, " ");
            try ts.expectCellText(2, 0, "S");
            try ts.expectCellText(6, 0, "l");
            const marker_cell = ts.surface.readCell(0, 0).?;
            const expected_color: chasen.Color = if (is_selected) .{ .index = 14 } else .gray;
            try std.testing.expect(marker_cell.style.fg.eql(expected_color));
            try std.testing.expectEqual(is_selected, marker_cell.style.bold);
            try std.testing.expect(ts.surface.readCell(2, 0).?.style.fg.eql(.{ .index = 11 }));
            try std.testing.expect(!ts.screen.cursor_vis);
        }
    }
}

test "Radio rendering clips narrow child surfaces and leaves empty regions inert" {
    const regions = [_]chasen.Rect{
        .{ .col = 1, .row = 1, .width = 0, .height = 1 },
        .{ .col = 1, .row = 1, .width = 3, .height = 0 },
        .{ .col = 1, .row = 1, .width = 1, .height = 1 },
        .{ .col = 1, .row = 1, .width = 2, .height = 1 },
        .{ .col = 1, .row = 1, .width = 3, .height = 1 },
    };
    for (regions) |region| {
        var ts: chasen.testing.TestSurface = undefined;
        try ts.init(5, 3);
        defer ts.deinit();
        var area = ts.surface.child(region);
        const radio = Radio.init(.{ .selected = true, .label = "Small" });
        radio.view(&area, .{ .marker = .diamond });

        try ts.expectCellText(0, 1, " ");
        try ts.expectCellText(4, 1, " ");
        try ts.expectCellText(1, 0, " ");
        try ts.expectCellText(1, 2, " ");
        if (region.width == 0 or region.height == 0) {
            try ts.expectCellText(1, 1, " ");
            try std.testing.expect(!ts.screen.cursor_vis);
        } else {
            try ts.expectCellText(1, 1, "◆");
            try ts.expectCellText(2, 1, " ");
            try ts.expectCellText(3, 1, if (region.width == 3) "S" else " ");
            try std.testing.expect(ts.screen.cursor_vis);
            try std.testing.expectEqual(@as(u16, 1), ts.screen.cursor.col);
            try std.testing.expectEqual(@as(u16, 1), ts.screen.cursor.row);
        }
    }
}

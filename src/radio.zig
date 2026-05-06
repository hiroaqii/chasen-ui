const std = @import("std");
const chasen = @import("chasen");
const selectable = @import("selectable.zig");

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

    /// Rendering options for `Radio.view`.
    pub const ViewOptions = struct {
        /// Surface column where the radio option should be drawn.
        col: u16 = 0,
        /// Surface row where the radio option should be drawn.
        row: u16 = 0,
        /// Optional width of the clipped one-line radio region.
        width: ?u16 = null,
        /// Style used for the radio marker.
        style: chasen.TextStyle = .{},
        /// Style used for the selected marker.
        selected_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the label.
        ///
        /// The label starts at column 4, after the three-column marker and a
        /// one-column gap.
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

    /// Draw the radio option into a one-line region.
    pub fn view(self: *const Radio, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = opts.width orelse availableWidth(surface, opts.col);
        if (width == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = width,
            .height = 1,
        });

        const marker = if (self.selected_value) "(o)" else "( )";
        const marker_style = if (self.selected_value) opts.selected_style else opts.style;
        _ = child.textAt(0, 0, marker, marker_style);
        if (self.label.len > 0) {
            _ = child.textAt(4, 0, self.label, opts.label_style);
        }

        if (opts.show_cursor) {
            child.showCursor(@min(@as(u16, 1), width - 1), 0);
        }
    }
};

fn keyToMsg(key: chasen.Key) ?Radio.Msg {
    if (selectable.isActivationKey(key)) return .select;
    return null;
}

fn availableWidth(surface: *chasen.Surface, col: u16) u16 {
    const size = surface.size();
    if (col >= size.width) return 0;
    return size.width - col;
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

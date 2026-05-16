const std = @import("std");
const chasen = @import("chasen");
const selectable = @import("../navigation/selectable.zig");

/// A single boolean checkbox component.
///
/// `Checkbox` owns its checked state and borrows its label. Applications
/// normally keep one instance in their model, call `handleEvent` from their app
/// event handler, forward returned messages to `update`, and call `view` from
/// their app view.
pub const Checkbox = struct {
    /// Current checked state.
    checked_value: bool = false,
    /// Text shown after the checkbox marker. Borrowed; must outlive the component.
    label: []const u8 = "",

    /// Initial values used when constructing a `Checkbox`.
    pub const Options = struct {
        /// Initial checked state.
        checked: bool = false,
        /// Label text borrowed by the component for its lifetime.
        label: []const u8 = "",
    };

    /// Messages understood by `Checkbox.update`.
    ///
    /// Applications can either use `handleEvent` to create these messages from
    /// Chasen key events, or construct them directly for custom bindings.
    pub const Msg = union(enum) {
        /// Toggle the checked state.
        toggle,
        /// Set the checked state explicitly.
        set_checked: bool,
    };

    /// Rendering options for `Checkbox.view`.
    pub const ViewOptions = struct {
        /// Style used for the checkbox marker.
        style: chasen.TextStyle = .{},
        /// Style used for the checked marker.
        checked_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the label.
        ///
        /// The label starts at column 4, after the three-column marker and a
        /// one-column gap.
        label_style: chasen.TextStyle = .{},
        /// Whether `view` should place the terminal cursor on the marker.
        show_cursor: bool = true,
    };

    /// Create a checkbox.
    pub fn init(opts: Options) Checkbox {
        return .{
            .checked_value = opts.checked,
            .label = opts.label,
        };
    }

    /// Return whether the checkbox is currently checked.
    pub fn checked(self: *const Checkbox) bool {
        return self.checked_value;
    }

    /// Apply a component message.
    pub fn update(self: *Checkbox, msg: Msg) void {
        switch (msg) {
            .toggle => self.checked_value = !self.checked_value,
            .set_checked => |checked_value| self.checked_value = checked_value,
        }
    }

    /// Convert a Chasen event into a `Checkbox` message when the event belongs
    /// to the component.
    ///
    /// Space without command-style modifiers and Enter both map to `.toggle`.
    /// Ctrl, Alt, Super, Hyper, and Meta Space are ignored so applications can
    /// reserve those bindings for app-level shortcuts.
    pub fn handleEvent(self: *const Checkbox, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| keyToMsg(key),
            else => null,
        };
    }

    /// Draw the checkbox into the provided one-line surface region.
    pub fn view(self: *const Checkbox, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        const marker = if (self.checked_value) "[x]" else "[ ]";
        const marker_style = if (self.checked_value) opts.checked_style else opts.style;
        _ = surface.textAt(0, 0, marker, marker_style);
        if (self.label.len > 0) {
            _ = surface.textAt(4, 0, self.label, opts.label_style);
        }

        if (opts.show_cursor) {
            surface.showCursor(@min(@as(u16, 1), width - 1), 0);
        }
    }
};

fn keyToMsg(key: chasen.Key) ?Checkbox.Msg {
    if (selectable.isActivationKey(key)) return .toggle;
    return null;
}

test "Checkbox initializes from options" {
    const checkbox = Checkbox.init(.{
        .checked = true,
        .label = "Enable feature",
    });

    try std.testing.expect(checkbox.checked());
    try std.testing.expectEqualStrings("Enable feature", checkbox.label);
}

test "Checkbox update toggles and sets checked state" {
    var checkbox = Checkbox.init(.{});

    checkbox.update(.toggle);
    try std.testing.expect(checkbox.checked());

    checkbox.update(.{ .set_checked = false });
    try std.testing.expect(!checkbox.checked());
}

test "Checkbox maps Space without command modifiers and Enter to toggle" {
    var checkbox = Checkbox.init(.{});

    try std.testing.expectEqual(Checkbox.Msg.toggle, checkbox.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " " },
    }).?);
    try std.testing.expectEqual(Checkbox.Msg.toggle, checkbox.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .shift = true } },
    }).?);
    try std.testing.expectEqual(Checkbox.Msg.toggle, checkbox.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "Checkbox ignores modified Space and unrelated events" {
    var checkbox = Checkbox.init(.{});

    try std.testing.expect(checkbox.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);
    try std.testing.expect(checkbox.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }) == null);
}

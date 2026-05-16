const std = @import("std");
const chasen = @import("chasen");
const selectable = @import("../navigation/selectable.zig");

/// A single action button component.
///
/// `Button` is allocation-free and borrows its label. It owns no mutable state:
/// applications normally keep one instance in their model, call `handleEvent`
/// only when the button is focused, handle `.press` in app `update`, and call
/// `view` from app `view`.
///
/// Button activation is policy-free. The component reports that it was pressed,
/// while the application decides whether that means submit, cancel, save,
/// navigation, or another action.
pub const Button = struct {
    /// Text shown inside the button marker. Borrowed; must outlive the component.
    label: []const u8 = "",

    /// Initial values used when constructing a `Button`.
    pub const Options = struct {
        /// Label text borrowed by the component for its lifetime.
        label: []const u8 = "",
    };

    /// Messages emitted by `Button.handleEvent`.
    pub const Msg = union(enum) {
        /// The button was activated with Enter or Space.
        press,
    };

    /// Rendering options for `Button.view`.
    pub const ViewOptions = struct {
        /// Style used for the button border markers.
        style: chasen.TextStyle = .{},
        /// Style used for the label.
        label_style: chasen.TextStyle = .{},
        /// Style used for the label when focused.
        focused_label_style: chasen.TextStyle = .{ .bold = true },
        /// Whether this button should be rendered as focused.
        focused: bool = false,
        /// Whether `view` should place the terminal cursor on the label.
        show_cursor: bool = true,
    };

    /// Create a button.
    pub fn init(opts: Options) Button {
        return .{ .label = opts.label };
    }

    /// Convert a Chasen event into a `Button` message when the event belongs to
    /// the component.
    ///
    /// Space without command-style modifiers and Enter both map to `.press`.
    /// Ctrl, Alt, Super, Hyper, and Meta Space are ignored so applications can
    /// reserve those bindings for app-level shortcuts.
    pub fn handleEvent(self: *const Button, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| if (selectable.isActivationKey(key)) .press else null,
            else => null,
        };
    }

    /// Draw the button into the provided one-line surface region.
    pub fn view(self: *const Button, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        _ = surface.textAt(0, 0, "[", opts.style);
        if (width > 1) {
            const label_style = if (opts.focused) opts.focused_label_style else opts.label_style;
            _ = surface.textAt(1, 0, self.label, label_style);
        }
        if (width > 2) {
            const close_col = @min(width - 1, @as(u16, 1) + chasen.text.displayWidth(self.label));
            _ = surface.textAt(close_col, 0, "]", opts.style);
        }

        if (opts.show_cursor) {
            surface.showCursor(@min(@as(u16, 1), width - 1), 0);
        }
    }
};

test "Button initializes from options" {
    const button = Button.init(.{ .label = "Save" });

    try std.testing.expectEqualStrings("Save", button.label);
}

test "Button maps Space without command modifiers and Enter to press" {
    var button = Button.init(.{});

    try std.testing.expectEqual(Button.Msg.press, button.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " " },
    }).?);
    try std.testing.expectEqual(Button.Msg.press, button.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .shift = true } },
    }).?);
    try std.testing.expectEqual(Button.Msg.press, button.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "Button ignores modified Space and unrelated events" {
    var button = Button.init(.{});

    try std.testing.expect(button.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);
    try std.testing.expect(button.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }) == null);
}

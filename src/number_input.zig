const std = @import("std");
const chasen = @import("chasen");
const TextInput = @import("text_input.zig").TextInput;

/// A single-line integer input component.
///
/// `NumberInput` owns editable UTF-8 text through an internal `TextInput`, but
/// only accepts ASCII digits and, when enabled, one leading minus sign.
/// Applications still decide submit policy, range validation, and whether an
/// empty or partial value is valid for their form.
pub const NumberInput = struct {
    /// Internal text editing state.
    input: TextInput,
    /// Whether a leading minus sign may be entered.
    allow_negative: bool = true,

    /// Initial values used when constructing a `NumberInput`.
    pub const Options = struct {
        /// Initial input contents. The bytes are copied into the component.
        value: []const u8 = "",
        /// Placeholder text borrowed by the component for its lifetime.
        placeholder: []const u8 = "",
        /// Whether to allow one leading minus sign.
        allow_negative: bool = true,
    };

    /// Messages understood by `NumberInput.update`.
    pub const Msg = TextInput.Msg;

    /// Rendering options for `NumberInput.view`.
    pub const ViewOptions = TextInput.ViewOptions;

    /// Create a number input with copied initial contents.
    ///
    /// The caller owns the returned component and must call `deinit` exactly
    /// once when the component is no longer needed.
    pub fn init(allocator: std.mem.Allocator, opts: Options) !NumberInput {
        var input = NumberInput{
            .input = try TextInput.init(allocator, .{
                .value = "",
                .placeholder = opts.placeholder,
            }),
            .allow_negative = opts.allow_negative,
        };
        errdefer input.deinit();

        for (opts.value) |byte| {
            try input.update(.{ .insert = byte });
        }
        return input;
    }

    /// Release memory owned by this component.
    pub fn deinit(self: *NumberInput) void {
        self.input.deinit();
        self.* = undefined;
    }

    /// Return the current input contents.
    ///
    /// The returned slice is borrowed from the component and becomes invalid
    /// after the next mutating `update` call or `deinit`.
    pub fn text(self: *const NumberInput) []const u8 {
        return self.input.text();
    }

    /// Return the parsed integer value, or null for empty/partial/invalid text.
    pub fn intValue(self: *const NumberInput) ?i64 {
        const current = self.text();
        if (current.len == 0 or std.mem.eql(u8, current, "-")) return null;
        return std.fmt.parseInt(i64, current, 10) catch null;
    }

    /// Apply a component message.
    ///
    /// Non-numeric insert messages are ignored. Range and required-field
    /// validation are app policy and should happen outside the component.
    pub fn update(self: *NumberInput, msg: Msg) !void {
        switch (msg) {
            .insert => |codepoint| {
                if (self.acceptsInsert(codepoint)) {
                    try self.input.update(.{ .insert = codepoint });
                }
            },
            else => try self.input.update(msg),
        }
    }

    /// Convert a Chasen event into a `NumberInput` message when applicable.
    pub fn handleEvent(self: *const NumberInput, event: chasen.Event) ?Msg {
        return self.input.handleEvent(event);
    }

    /// Draw the input into a one-line clipped child surface.
    pub fn view(self: *const NumberInput, surface: *chasen.Surface, opts: ViewOptions) void {
        self.input.view(surface, opts);
    }

    fn acceptsInsert(self: *const NumberInput, codepoint: u21) bool {
        if (codepoint >= '0' and codepoint <= '9') {
            return std.mem.indexOfScalar(u8, self.input.value.items, '-') == null or self.input.cursor > 0;
        }
        if (codepoint != '-') return false;
        if (!self.allow_negative) return false;
        if (self.input.cursor != 0) return false;
        return std.mem.indexOfScalar(u8, self.input.value.items, '-') == null;
    }
};

test "NumberInput initializes with accepted initial value" {
    var input = try NumberInput.init(std.testing.allocator, .{ .value = "-42" });
    defer input.deinit();

    try std.testing.expectEqualStrings("-42", input.text());
    try std.testing.expectEqual(@as(?i64, -42), input.intValue());
}

test "NumberInput filters inserted characters" {
    var input = try NumberInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try input.update(.{ .insert = '1' });
    try input.update(.{ .insert = 'x' });
    try input.update(.{ .insert = '2' });
    try std.testing.expectEqualStrings("12", input.text());
}

test "NumberInput allows one leading minus when enabled" {
    var input = try NumberInput.init(std.testing.allocator, .{ .allow_negative = true });
    defer input.deinit();

    try input.update(.{ .insert = '-' });
    try input.update(.{ .insert = '4' });
    try input.update(.{ .insert = '-' });
    try std.testing.expectEqualStrings("-4", input.text());
    try std.testing.expectEqual(@as(?i64, -4), input.intValue());
}

test "NumberInput preserves leading minus invariant when inserting digits" {
    var input = try NumberInput.init(std.testing.allocator, .{ .value = "-4" });
    defer input.deinit();

    try input.update(.home);
    try input.update(.{ .insert = '3' });
    try std.testing.expectEqualStrings("-4", input.text());
    try std.testing.expectEqual(@as(?i64, -4), input.intValue());
}

test "NumberInput rejects minus when negative values are disabled" {
    var input = try NumberInput.init(std.testing.allocator, .{ .allow_negative = false });
    defer input.deinit();

    try input.update(.{ .insert = '-' });
    try input.update(.{ .insert = '7' });
    try std.testing.expectEqualStrings("7", input.text());
}

test "NumberInput delegates navigation and deletion" {
    var input = try NumberInput.init(std.testing.allocator, .{ .value = "123" });
    defer input.deinit();

    try input.update(.move_left);
    try input.update(.backspace);
    try std.testing.expectEqualStrings("13", input.text());
}

test "NumberInput maps key events through TextInput" {
    var input = try NumberInput.init(std.testing.allocator, .{});
    defer input.deinit();

    try std.testing.expectEqual(NumberInput.Msg{ .insert = '8' }, input.handleEvent(.{
        .key_press = .{ .codepoint = '8', .text = "8" },
    }).?);
    try std.testing.expectEqual(NumberInput.Msg.submit, input.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

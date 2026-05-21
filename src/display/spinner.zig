const std = @import("std");
const chasen = @import("chasen");

const default_frames = [_][]const u8{ "|", "/", "-", "\\" };

/// A small frame-based spinner component.
///
/// `Spinner` is display-only and allocation-free. It borrows its frame labels
/// and optional label text. It does not own animation state, schedule frames,
/// or call `ctx.requestFrame()`. Applications pass the current frame index to
/// `view`, usually from a Chasen frame event or an animation helper.
pub const Spinner = struct {
    /// Frame labels borrowed by the component.
    frames: []const []const u8 = &default_frames,
    /// Optional label shown after the spinner frame. Borrowed.
    label: []const u8 = "",

    /// Initial values used when constructing a `Spinner`.
    pub const Options = struct {
        /// Frame labels borrowed by the component for its lifetime.
        frames: []const []const u8 = &default_frames,
        /// Optional label text borrowed by the component for its lifetime.
        label: []const u8 = "",
    };

    /// Rendering options for `Spinner.view`.
    pub const ViewOptions = struct {
        /// Current frame index. Values wrap across `frames`.
        frame_index: u64 = 0,
        /// Gap between the frame and label.
        ///
        /// Empty frame lists still apply this gap before the label.
        gap: u16 = 1,
        /// Style used for the current spinner frame.
        frame_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the label.
        label_style: chasen.TextStyle = .{},
    };

    /// Create a spinner.
    pub fn init(opts: Options) Spinner {
        return .{
            .frames = opts.frames,
            .label = opts.label,
        };
    }

    /// Return the frame label for the given frame index.
    ///
    /// Empty frame lists return an empty string. Non-empty frame lists wrap the
    /// index into the available frame labels.
    pub fn frameAt(self: *const Spinner, frame_index: u64) []const u8 {
        if (self.frames.len == 0) return "";

        const len: u64 = @intCast(self.frames.len);
        const index: usize = @intCast(frame_index % len);
        return self.frames[index];
    }

    /// Draw the spinner into the provided one-line surface region.
    pub fn view(self: *const Spinner, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        const frame = self.frameAt(opts.frame_index);
        _ = surface.borrowTextAt(0, 0, frame, opts.frame_style);

        const label_col = @as(usize, chasen.text.displayWidth(frame)) + @as(usize, opts.gap);
        if (self.label.len > 0 and label_col < width) {
            _ = surface.borrowTextAt(@intCast(label_col), 0, self.label, opts.label_style);
        }
    }
};

test "Spinner initializes with default frames" {
    const spinner = Spinner.init(.{ .label = "Loading" });

    try std.testing.expectEqual(@as(usize, 4), spinner.frames.len);
    try std.testing.expectEqualStrings("Loading", spinner.label);
    try std.testing.expectEqualStrings("|", spinner.frameAt(0));
}

test "Spinner initializes with custom frames" {
    const frames = [_][]const u8{ ".", "o", "O" };
    const spinner = Spinner.init(.{ .frames = &frames });

    try std.testing.expectEqualStrings(".", spinner.frameAt(0));
    try std.testing.expectEqualStrings("o", spinner.frameAt(1));
    try std.testing.expectEqualStrings("O", spinner.frameAt(2));
}

test "Spinner wraps frame indices" {
    const frames = [_][]const u8{ "a", "b" };
    const spinner = Spinner.init(.{ .frames = &frames });

    try std.testing.expectEqualStrings("a", spinner.frameAt(0));
    try std.testing.expectEqualStrings("b", spinner.frameAt(1));
    try std.testing.expectEqualStrings("a", spinner.frameAt(2));
    try std.testing.expectEqualStrings("b", spinner.frameAt(3));
}

test "Spinner handles empty frame list" {
    const spinner = Spinner.init(.{ .frames = &.{} });

    try std.testing.expectEqualStrings("", spinner.frameAt(0));
    try std.testing.expectEqualStrings("", spinner.frameAt(99));
}

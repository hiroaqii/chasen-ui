const std = @import("std");
const chasen = @import("chasen");
const loading = @import("chasen_graphics").loading;

/// Allocation-free loading display; the app owns time, layout and frame requests.
/// The provided Surface is dedicated to this component and cleared on every view.
/// Moving or shrinking that Surface requires the caller to clear the old region.
pub const LoadingIndicator = struct {
    pub const Kind = loading.Kind;
    pub const Size = loading.Size;

    kind: Kind,
    /// Borrowed for the component lifetime and through rendering.
    label: []const u8 = "",

    pub const Options = struct {
        kind: Kind,
        label: []const u8 = "",
    };
    pub const ViewOptions = struct {
        /// One complete cycle is 1. Finite values wrap; non-finite values select 0.
        phase: f32 = 0,
        size: Size = .medium,
        /// Also used when clearing. Low-intensity cells additionally set dim.
        style: chasen.TextStyle = .{},
        label_style: chasen.TextStyle = .{},
    };

    pub fn init(opts: Options) LoadingIndicator {
        return .{ .kind = opts.kind, .label = opts.label };
    }

    /// Draw at the top left, clipped to the Surface. Glyphs have static lifetime.
    /// The optional label occupies the row immediately below the nominal shape.
    pub fn view(self: *const LoadingIndicator, surface: *chasen.Surface, opts: ViewOptions) void {
        const available = surface.size();
        if (available.width == 0 or available.height == 0) return;
        surface.fillAll(.{ .char = .{ .grapheme = " ", .width = 1 }, .style = opts.style });
        const dims = loading.dimensions(self.kind, opts.size);
        for (0..@min(available.height, dims.height)) |row| {
            for (0..@min(available.width, dims.width)) |col| {
                const cell = loading.sample(self.kind, opts.size, opts.phase, @intCast(col), @intCast(row));
                if (cell.intensity == 0) continue;
                var style = opts.style;
                style.dim = style.dim or cell.intensity < 0.5;
                surface.writeCell(@intCast(col), @intCast(row), .{
                    .char = .{ .grapheme = cell.glyph, .width = 1 },
                    .style = style,
                });
            }
        }
        if (self.label.len > 0 and dims.height < available.height)
            _ = surface.borrowTextAt(0, dims.height, self.label, opts.label_style);
    }
};

test "LoadingIndicator clips graphics and labels without touching neighbors" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(8, 5);
    defer ts.deinit();
    ts.surface.fillAll(.{ .char = .{ .grapheme = ".", .width = 1 } });
    var child = ts.surface.child(.{ .col = 2, .row = 1, .width = 1, .height = 2 });
    const indicator = LoadingIndicator.init(.{ .kind = .blocks, .label = "Loading" });
    indicator.view(&child, .{ .size = .large });
    try ts.expectCellText(2, 1, "█");
    indicator.view(&child, .{ .size = .tiny });
    try ts.expectCellText(2, 1, "▘");
    try ts.expectCellText(2, 2, "L");
    for (0..5) |row| {
        for (0..8) |col| {
            if (col == 2 and row >= 1 and row < 3) continue;
            try ts.expectCellText(@intCast(col), @intCast(row), ".");
        }
    }
    var empty = ts.surface.child(.{ .col = 0, .row = 0, .width = 0, .height = 0 });
    indicator.view(&empty, .{});
    try ts.expectCellText(0, 0, ".");
}

test "LoadingIndicator clears former size and label while preserving requested styles" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(22, 13);
    defer ts.deinit();
    var indicator = LoadingIndicator.init(.{ .kind = .blocks, .label = "Working" });
    indicator.view(&ts.surface, .{ .size = .large });
    try ts.expectCellText(0, 11, "W");
    indicator.label = "OK";
    const style: chasen.TextStyle = .{ .fg = .{ .index = 14 }, .bg = .{ .index = 4 } };
    indicator.view(&ts.surface, .{ .size = .small, .style = style, .label_style = .{ .bold = true } });
    try ts.expectCellText(0, 5, "O");
    try ts.expectCellText(2, 5, " ");
    try ts.expectCellText(0, 11, " ");
    try ts.expectCellText(19, 10, " ");
    try std.testing.expect(ts.surface.readCell(0, 0).?.style.fg.eql(style.fg));
    try std.testing.expect(ts.surface.readCell(19, 10).?.style.bg.eql(style.bg));
    try std.testing.expect(ts.surface.readCell(3, 0).?.style.dim);
    try std.testing.expect(ts.surface.readCell(0, 5).?.style.bold);
    indicator.view(&ts.surface, .{ .size = .tiny });
    try ts.expectCellText(0, 1, "O");
    try ts.expectCellText(0, 4, " ");
    try ts.expectCellText(0, 5, " ");
    indicator.label = "";
    indicator.view(&ts.surface, .{ .size = .tiny });
    try ts.expectCellText(0, 1, " ");
}

test "LoadingIndicator redraw after phase change matches a fresh surface" {
    var reused: chasen.testing.TestSurface = undefined;
    try reused.init(12, 7);
    defer reused.deinit();
    var fresh: chasen.testing.TestSurface = undefined;
    try fresh.init(12, 7);
    defer fresh.deinit();
    const indicator = LoadingIndicator.init(.{ .kind = .arc });
    indicator.view(&reused.surface, .{ .phase = 0 });
    indicator.view(&reused.surface, .{ .phase = 0.5 });
    indicator.view(&fresh.surface, .{ .phase = 0.5 });
    for (0..7) |row| {
        for (0..12) |col| {
            try std.testing.expectEqualDeep(
                fresh.surface.readCell(@intCast(col), @intCast(row)).?,
                reused.surface.readCell(@intCast(col), @intCast(row)).?,
            );
        }
    }
}

const std = @import("std");
const chasen = @import("chasen");
const chasen_ui = @import("chasen_ui");
const vaxis = @import("vaxis");

const presentation = chasen_ui.text_presentation;
const projection = chasen_ui.text_projection;

const Fixture = struct {
    allocator: std.mem.Allocator,
    env_map: std.process.Environ.Map,
    lifecycle_writer: std.Io.Writer.Allocating,
    vx: vaxis.Vaxis,
    arena: std.heap.ArenaAllocator,
    surface: chasen.Surface,

    fn init(self: *Fixture, explicit_width: bool) !void {
        const allocator = std.testing.allocator;
        self.allocator = allocator;
        self.env_map = try std.testing.environ.createMap(allocator);
        errdefer self.env_map.deinit();

        self.lifecycle_writer = .init(allocator);
        errdefer self.lifecycle_writer.deinit();

        self.vx = try vaxis.Vaxis.init(std.testing.io, allocator, &self.env_map, .{});
        errdefer self.vx.deinit(allocator, &self.lifecycle_writer.writer);
        self.vx.caps.unicode = .unicode;
        self.vx.caps.explicit_width = explicit_width;
        try self.vx.resize(allocator, &self.lifecycle_writer.writer, .{
            .cols = 8,
            .rows = 1,
            .x_pixel = 0,
            .y_pixel = 0,
        });

        self.arena = .init(allocator);
        self.surface = .initVaxis(self.vx.window(), self.arena.allocator(), null);
    }

    fn deinit(self: *Fixture) void {
        self.arena.deinit();
        self.vx.deinit(self.allocator, &self.lifecycle_writer.writer);
        self.lifecycle_writer.deinit();
        self.env_map.deinit();
        self.* = undefined;
    }

    fn render(self: *Fixture) ![]u8 {
        var writer: std.Io.Writer.Allocating = .init(self.allocator);
        defer writer.deinit();
        self.vx.queueRefresh();
        try self.vx.render(&writer.writer);
        return writer.toOwnedSlice();
    }

    fn expectBlank(self: *const Fixture) !void {
        for (0..self.vx.screen.width) |col| {
            const cell = self.vx.screen.readCell(@intCast(col), 0).?;
            try std.testing.expectEqualStrings(" ", cell.char.grapheme);
        }
    }
};

test "safe final backing reaches raw and explicit-width Vaxis render paths" {
    for ([_]bool{ false, true }) |explicit_width| {
        var fixture: Fixture = undefined;
        try fixture.init(explicit_width);
        defer fixture.deinit();

        const source = try projection.Projection.init("界ABC", .{ .tab_width = 4 });
        const marker = try projection.Projection.init("…", .{ .tab_width = 4 });
        const value = try presentation.markedClip(
            presentation.Range.full(source),
            marker,
            3,
            .head,
        );
        try presentation.drawAt(&fixture.surface, 0, 0, value, .{});

        try std.testing.expectEqualStrings("界", fixture.vx.screen.readCell(0, 0).?.char.grapheme);
        try std.testing.expectEqualStrings("…", fixture.vx.screen.readCell(2, 0).?.char.grapheme);

        const output = try fixture.render();
        defer std.testing.allocator.free(output);
        const wide_at = std.mem.indexOf(u8, output, "界") orelse return error.MissingWidePayload;
        const marker_at = std.mem.indexOfPos(u8, output, wide_at + "界".len, "…") orelse
            return error.MissingMarkerPayload;
        try std.testing.expect(wide_at < marker_at);

        if (explicit_width) {
            const expected = try std.fmt.allocPrint(
                std.testing.allocator,
                vaxis.ctlseqs.explicit_width ++ "…",
                .{ @as(usize, 2), "界" },
            );
            defer std.testing.allocator.free(expected);
            try std.testing.expect(std.mem.indexOf(u8, output, expected) != null);
        } else {
            try std.testing.expect(std.mem.indexOf(u8, output, "界…") != null);
        }
    }
}

test "unsafe seam and zero-cell omission never reach Vaxis output" {
    for ([_]bool{ false, true }) |explicit_width| {
        {
            var fixture: Fixture = undefined;
            try fixture.init(explicit_width);
            defer fixture.deinit();

            const source = try projection.Projection.init("🇺XYZ", .{ .tab_width = 4 });
            const marker = try projection.Projection.init("🇸", .{ .tab_width = 4 });
            const value = try presentation.markedClip(
                presentation.Range.full(source),
                marker,
                4,
                .head,
            );
            try std.testing.expectError(
                error.UnstableTerminalSerialization,
                presentation.drawAt(&fixture.surface, 0, 0, value, .{}),
            );
            try fixture.expectBlank();

            const output = try fixture.render();
            defer std.testing.allocator.free(output);
            try std.testing.expect(std.mem.indexOf(u8, output, "🇺") == null);
            try std.testing.expect(std.mem.indexOf(u8, output, "🇸") == null);
        }

        {
            var fixture: Fixture = undefined;
            try fixture.init(explicit_width);
            defer fixture.deinit();

            const source = try projection.Projection.init("🇺\u{200b}🇸", .{ .tab_width = 4 });
            const value: presentation.Clip = .{
                .source = presentation.Range.full(source),
                .marker = null,
                .direction = .head,
                .clipped = false,
            };
            try std.testing.expectError(
                error.UnstableTerminalSerialization,
                presentation.drawAt(&fixture.surface, 0, 0, value, .{}),
            );
            try fixture.expectBlank();

            const output = try fixture.render();
            defer std.testing.allocator.free(output);
            try std.testing.expect(std.mem.indexOf(u8, output, "🇺") == null);
            try std.testing.expect(std.mem.indexOf(u8, output, "🇸") == null);
        }
    }
}

test "source and marker LF fail before screen or serialized output" {
    for ([_]bool{ false, true }) |explicit_width| {
        var fixture: Fixture = undefined;
        try fixture.init(explicit_width);
        defer fixture.deinit();

        try std.testing.expectError(error.UnstableTerminalSerialization, presentation.drawClippedAt(
            &fixture.surface,
            0,
            0,
            "pre-LF-payload\npost-LF-payload",
            .{},
            .{ .tab_width = 4, .marker = "…", .direction = .head },
        ));
        try std.testing.expectError(error.UnstableTerminalSerialization, presentation.drawClippedAt(
            &fixture.surface,
            0,
            0,
            "safe-source",
            .{},
            .{ .tab_width = 4, .marker = "partial-marker\nmarker-tail", .direction = .tail },
        ));
        try fixture.expectBlank();

        const output = try fixture.render();
        defer std.testing.allocator.free(output);
        try std.testing.expect(std.mem.indexOf(u8, output, "pre-LF-payload") == null);
        try std.testing.expect(std.mem.indexOf(u8, output, "post-LF-payload") == null);
        try std.testing.expect(std.mem.indexOf(u8, output, "partial-marker") == null);
        try std.testing.expect(std.mem.indexOf(u8, output, "marker-tail") == null);
    }
}

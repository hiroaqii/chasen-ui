const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");
const Indicator = @import("chasen_ui_graphics").LoadingIndicator;
const graphics = @import("chasen_graphics");
const anim = @import("chasen_anim");

const periods_ms = [_]u64{ 400, 800, 1200, 1600 };
const colors = [_]u8{ 14, 10, 13, 11 };
const dots = ui.Spinner.init(.{ .frames = &graphics.glyph.spinner.linear_dots, .label = "Dots 5x1" });
const wave = ui.Spinner.init(.{ .frames = &graphics.glyph.spinner.wave, .label = "Wave 5x1" });
const tiny_dots = ui.Spinner.init(.{ .frames = &graphics.glyph.spinner.linear_dots_tiny, .label = "Dots 1x1" });
const tiny_wave = ui.Spinner.init(.{ .frames = &graphics.glyph.spinner.wave_tiny, .label = "Wave 1x1" });

const App = struct {
    cycle_ns: u64 = 0,
    period_index: usize = 2,
    color_index: usize = 0,
    size: Indicator.Size = .tiny,
    running: bool = true,
    skip_delta: bool = true,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;
        frame: chasen.Frame,
        toggle,
        slower,
        faster,
        cycle_size,
        cycle_color,
        reset,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        if (self.running) ctx.frame().request();
    }

    pub fn handleEvent(_: *const App, event: chasen.Event) ?Msg {
        return switch (event) {
            .frame => |frame| .{ .frame = frame },
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(' ', .{})) return .toggle;
                if (key.matches('[', .{})) return .slower;
                if (key.matches(']', .{})) return .faster;
                if (key.matches('s', .{})) return .cycle_size;
                if (key.matches('c', .{})) return .cycle_color;
                if (key.matches('r', .{})) return .reset;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .frame => |frame| {
                if (!self.running) return;
                // The first delta after startup/resume may include idle time.
                if (self.skip_delta) {
                    self.skip_delta = false;
                } else {
                    const period = self.periodNs();
                    self.cycle_ns = (self.cycle_ns + frame.delta_ns % period) % period;
                }
                ctx.frame().request();
            },
            .toggle => {
                self.running = !self.running;
                if (self.running) {
                    self.skip_delta = true;
                    ctx.frame().request();
                }
            },
            .slower => self.setPeriod(@min(self.period_index + 1, periods_ms.len - 1)),
            .faster => self.setPeriod(self.period_index -| 1),
            .cycle_size => self.size = switch (self.size) {
                .tiny => .small,
                .small => .medium,
                .medium => .large,
                .large => .tiny,
            },
            .cycle_color => self.color_index = (self.color_index + 1) % colors.len,
            .reset => self.cycle_ns = 0,
            .quit => ctx.quit(),
        }
    }

    fn periodNs(self: *const App) u64 {
        return periods_ms[self.period_index] * 1_000_000;
    }

    fn setPeriod(self: *App, index: usize) void {
        const old_period = self.periodNs();
        self.period_index = index;
        // Preserve phase. The largest product is below (1.6e9)^2, within u64.
        self.cycle_ns = self.cycle_ns * self.periodNs() / old_period;
    }

    fn phase(self: *const App) f32 {
        // Both arguments use nanoseconds, not rendered frame counts.
        return anim.blink.phase(self.cycle_ns, self.periodNs());
    }

    fn frameIndex(self: *const App, count: usize) u64 {
        return self.cycle_ns * @as(u64, @intCast(count)) / self.periodNs();
    }

    pub fn view(self: *const App, surface: *chasen.Surface) !void {
        surface.clearAll();
        const area = surface.size();
        if (area.width < 64 or area.height < 24) {
            _ = surface.borrowTextAt(0, 0, "Resize to at least 64x24. Esc: quit", .{});
            return;
        }
        _ = surface.borrowTextAt(1, 0, "Loading Indicators", .{ .bold = true });
        _ = surface.borrowTextAt(1, 1, "Space: pause/resume  [: slower  ]: faster  Esc: quit", .{ .fg = .gray });
        _ = surface.borrowTextAt(1, 2, "s: size (all five)  c: color  r: reset", .{ .fg = .gray });
        _ = try surface.printAt(1, 4, .{}, "{s} | {d} ms/cycle | {s} | color {d}", .{
            if (self.running) "running" else "paused", periods_ms[self.period_index], @tagName(self.size), colors[self.color_index],
        });
        const style: chasen.TextStyle = .{ .fg = .{ .index = colors[self.color_index] } };
        const dots_spinner = if (self.size == .tiny) tiny_dots else dots;
        const wave_spinner = if (self.size == .tiny) tiny_wave else wave;
        var dots_area = surface.child(.{ .col = 1, .row = 7, .width = 30, .height = 1 });
        dots_spinner.view(&dots_area, .{ .frame_index = self.frameIndex(dots_spinner.frames.len), .frame_style = style });
        var wave_area = surface.child(.{ .col = 1, .row = 8, .width = 30, .height = 1 });
        wave_spinner.view(&wave_area, .{ .frame_index = self.frameIndex(wave_spinner.frames.len), .frame_style = style });
        const column_width = (area.width - 4) / 3;
        inline for (.{ .blocks, .arc, .ripple }, .{ "Blocks", "Arc", "Ripple" }, 0..) |kind, title, index| {
            const col = 1 + @as(u16, @intCast(index)) * (column_width + 1);
            const dims = graphics.loading.dimensions(kind, self.size);
            _ = try surface.printAt(col, 10, .{ .bold = true }, "{s} {d}x{d}", .{ title, dims.width, dims.height });
            var region = surface.child(.{ .col = col, .row = 12, .width = column_width, .height = 12 });
            const indicator = Indicator.init(.{ .kind = kind, .label = "Loading" });
            indicator.view(&region, .{ .phase = self.phase(), .size = self.size, .style = style });
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

fn testFrame(delta_ns: u64) App.Msg {
    return .{ .frame = .{ .now_ns = delta_ns, .delta_ns = delta_ns, .index = 0 } };
}

test "gallery pauses requests and ignores paused time on resume" {
    var app: App = .{};
    var tc: chasen.testing.TestCtx(App.Msg) = .{};
    try app.init(&tc.ctx);
    try std.testing.expect(tc.frameRequested());
    tc.resetTransient();
    try app.update(testFrame(9_000_000_000), &tc.ctx);
    try std.testing.expectEqual(@as(u64, 0), app.cycle_ns);
    try app.update(testFrame(300_000_000), &tc.ctx);
    try std.testing.expect(tc.frameRequested());
    try app.update(.toggle, &tc.ctx);
    tc.resetTransient();
    try app.update(testFrame(8_000_000_000), &tc.ctx);
    try std.testing.expectEqual(@as(u64, 300_000_000), app.cycle_ns);
    try std.testing.expect(!tc.frameRequested());
    try app.update(.toggle, &tc.ctx);
    try std.testing.expect(tc.frameRequested());
    tc.resetTransient();
    try app.update(testFrame(8_000_000_000), &tc.ctx);
    try std.testing.expectEqual(@as(u64, 300_000_000), app.cycle_ns);
    try app.update(testFrame(1_000_000_000), &tc.ctx);
    try std.testing.expectEqual(@as(u64, 100_000_000), app.cycle_ns);
    try std.testing.expect(tc.frameRequested());
}

test "gallery speed changes preserve phase and paused controls stay idle" {
    var app: App = .{ .cycle_ns = 300_000_000, .running = false };
    var tc: chasen.testing.TestCtx(App.Msg) = .{};
    try app.update(.faster, &tc.ctx);
    try std.testing.expectEqual(@as(u64, 800_000_000), app.periodNs());
    try std.testing.expectEqual(@as(f32, 0.25), app.phase());
    try app.update(.slower, &tc.ctx);
    try std.testing.expectEqual(@as(f32, 0.25), app.phase());
    try app.update(.cycle_size, &tc.ctx);
    try app.update(.cycle_color, &tc.ctx);
    try std.testing.expectEqual(Indicator.Size.small, app.size);
    try std.testing.expectEqual(@as(usize, 1), app.color_index);
    try app.update(.reset, &tc.ctx);
    try std.testing.expectEqual(@as(u64, 0), app.cycle_ns);
    try std.testing.expect(!app.running);
    try std.testing.expect(!tc.frameRequested());
    try app.update(.quit, &tc.ctx);
    try std.testing.expect(tc.shouldQuit());
}

test "gallery cycles from tiny through all sizes and redraws after resize" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(64, 24);
    defer ts.deinit();
    var app: App = .{};
    var tc: chasen.testing.TestCtx(App.Msg) = .{};
    try app.view(&ts.surface);
    try std.testing.expectEqual(Indicator.Size.tiny, app.size);
    try ts.expectCellText(1, 7, "⠁");
    try ts.expectCellText(3, 8, "W");
    try ts.expectCellText(1, 12, "▘");
    try ts.expectCellText(22, 12, "⠇");
    try ts.expectCellText(43, 12, "⠶");
    for ([_]Indicator.Size{ .small, .medium, .large, .tiny }) |size| {
        try app.update(.cycle_size, &tc.ctx);
        try std.testing.expectEqual(size, app.size);
        try app.view(&ts.surface);
        try ts.expectCellText(if (size == .tiny) 3 else 7, 7, "D");
        if (size == .large) try ts.expectCellText(1, 23, "L");
    }
    try ts.expectCellText(1, 10, "B");
    try ts.expectCellText(22, 10, "A");
    try ts.expectCellText(43, 10, "R");
    try ts.expectCellText(8, 10, "1");
    try ts.expectCellText(1, 13, "L");
    try ts.expectCellText(1, 23, " ");
    var narrow = ts.surface.child(.{ .col = 0, .row = 0, .width = 40, .height = 24 });
    try app.view(&narrow);
    try ts.expectCellText(0, 0, "R");
    try ts.expectCellText(1, 10, " ");
    try app.view(&ts.surface);
    try ts.expectCellText(1, 10, "B");
}

test "all tiny presets and samples occupy one terminal cell" {
    for (graphics.glyph.spinner.linear_dots_tiny ++ graphics.glyph.spinner.wave_tiny) |glyph| {
        try std.testing.expectEqual(@as(u16, 1), chasen.text.displayWidth(glyph));
    }
    for ([_]Indicator.Kind{ .blocks, .arc, .ripple }) |kind| {
        for (0..8) |frame| {
            const cell = graphics.loading.sample(kind, .tiny, @as(f32, @floatFromInt(frame)) / 8, 0, 0);
            try std.testing.expectEqual(@as(u16, 1), chasen.text.displayWidth(cell.glyph));
        }
    }
}

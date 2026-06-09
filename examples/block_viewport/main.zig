const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const blocks = [_]Block{
    .{ .title = "Summary", .lines = &summary_lines },
    .{ .title = "Player Poll", .lines = &poll_lines },
    .{ .title = "Description", .lines = &description_lines },
    .{ .title = "Forum Notes", .lines = &forum_lines },
    .{ .title = "Implementation Notes", .lines = &implementation_lines },
    .{ .title = "Change Log", .lines = &change_lines },
    .{ .title = "Long Appendix", .lines = &appendix_lines },
};

const summary_lines = [_][]const u8{
    "A compact metadata block.",
    "Height is known before rendering.",
};

const poll_lines = [_][]const u8{
    "Players  Best  Rec  Not Rec",
    "2        10    25   3",
    "3        45    21   2",
    "4        90    12   1",
};

const description_lines = [_][]const u8{
    "Long blocks can start above the viewport.",
    "BlockViewport returns skip_rows so the app can render",
    "only the visible rows from that block.",
    "",
    "The helper does not own text, wrapping, state, or styles.",
    "It only maps a global scroll offset into block-local slices.",
};

const forum_lines = [_][]const u8{
    "Thread: Rules questions",
    "Thread: Strategy notes",
    "Thread: Component upgrades",
    "Thread: Solo variants",
    "Thread: Expansion ranking",
    "Thread: Storage ideas",
    "Thread: House rules",
    "Thread: Session reports",
};

const implementation_lines = [_][]const u8{
    "1. Compute each block height before rendering.",
    "2. Clamp the scroll offset against the total height.",
    "3. Ask BlockViewport for the visible slices.",
    "4. Render each slice with app-specific styling.",
    "",
    "The repeated lines below intentionally make this example scrollable",
    "on normal terminal sizes.",
    "",
    "Extra row 01",
    "Extra row 02",
    "Extra row 03",
    "Extra row 04",
    "Extra row 05",
    "Extra row 06",
    "Extra row 07",
    "Extra row 08",
    "Extra row 09",
    "Extra row 10",
    "Extra row 11",
    "Extra row 12",
};

const change_lines = [_][]const u8{
    "2026-06-01 Added block height calculation.",
    "2026-06-02 Added clamped scroll offsets.",
    "2026-06-03 Added visible slice iteration.",
    "2026-06-04 Added zero-height block tests.",
    "2026-06-05 Added example rendering.",
    "2026-06-06 Added page scrolling.",
    "2026-06-07 Added review notes.",
    "2026-06-08 Added bgg-tui adoption plan.",
    "2026-06-09 Added extra scrollable data.",
};

const appendix_lines = [_][]const u8{
    "Appendix row 01",
    "Appendix row 02",
    "Appendix row 03",
    "Appendix row 04",
    "Appendix row 05",
    "Appendix row 06",
    "Appendix row 07",
    "Appendix row 08",
    "Appendix row 09",
    "Appendix row 10",
    "Appendix row 11",
    "Appendix row 12",
    "Appendix row 13",
    "Appendix row 14",
    "Appendix row 15",
    "Appendix row 16",
    "Appendix row 17",
    "Appendix row 18",
    "Appendix row 19",
    "Appendix row 20",
    "Appendix row 21",
    "Appendix row 22",
    "Appendix row 23",
    "Appendix row 24",
    "Appendix row 25",
    "Appendix row 26",
    "Appendix row 27",
    "Appendix row 28",
    "Appendix row 29",
    "Appendix row 30",
    "Appendix row 31",
    "Appendix row 32",
    "Appendix row 33",
    "Appendix row 34",
    "Appendix row 35",
    "Appendix row 36",
    "Appendix row 37",
    "Appendix row 38",
    "Appendix row 39",
    "Appendix row 40",
    "Appendix row 41",
    "Appendix row 42",
    "Appendix row 43",
    "Appendix row 44",
    "Appendix row 45",
    "Appendix row 46",
    "Appendix row 47",
    "Appendix row 48",
    "Appendix row 49",
    "Appendix row 50",
};

const Block = struct {
    title: []const u8,
    lines: []const []const u8,

    fn height(self: Block) usize {
        // One title row plus one row for every line in the block body.
        return 1 + self.lines.len;
    }
};

// This example shows BlockViewport for scrollable content made from blocks with
// different heights.
//
// The app owns the real block data, scroll offset, and rendering. BlockViewport
// only answers: which block slices are visible for this scroll offset?
const App = struct {
    viewport: ui.BlockViewport.State = .{},
    terminal_size: chasen.Size = .{ .width = 80, .height = 24 },

    pub const Msg = union(enum) {
        terminal_resized: chasen.Size,
        scroll_up,
        scroll_down,
        page_up,
        page_down,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .winsize => |winsize| .{ .terminal_resized = .{ .width = winsize.cols, .height = winsize.rows } },
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{}) or key.codepoint == 'k') return .scroll_up;
                if (key.matches(chasen.Key.down, .{}) or key.codepoint == 'j') return .scroll_down;
                if (key.matches(chasen.Key.page_up, .{})) return .page_up;
                if (key.matches(chasen.Key.page_down, .{})) return .page_down;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        const block_defs = blockDefs();
        const body_height = bodyHeightFor(self.terminal_size);

        switch (msg) {
            .terminal_resized => |size| {
                self.terminal_size = size;
                self.viewport.clamp(&block_defs, bodyHeightFor(size));
            },
            .scroll_up => self.viewport.scrollBy(&block_defs, body_height, -1),
            .scroll_down => self.viewport.scrollBy(&block_defs, body_height, 1),
            .page_up => self.viewport.pageBy(&block_defs, body_height, -1),
            .page_down => self.viewport.pageBy(&block_defs, body_height, 1),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const body_row: u16 = 3;
        const body_height = bodyHeightFor(sfc.size());

        _ = sfc.borrowTextAt(0, 0, "BlockViewport Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down/j/k: scroll  PageUp/PageDown: page  Esc: quit", .{ .fg = .gray });

        const block_defs = blockDefs();

        const range = self.viewport.range(&block_defs, body_height);
        const clamped_scroll = range.clamped_offset;

        _ = try sfc.printAt(0, 2, .{ .fg = .gray }, "scroll {d}/{d}  total rows {d}", .{
            clamped_scroll,
            ui.BlockViewport.maxOffset(&block_defs, body_height),
            range.total_height,
        });

        var body = sfc.child(.{
            .col = 0,
            .row = body_row,
            .width = sfc.size().width,
            .height = @intCast(body_height),
        });

        var it = self.viewport.iterator(&block_defs, body_height);
        while (it.next()) |visible| {
            var block_surface = body.child(.{
                .col = 0,
                .row = visible.row,
                .width = body.size().width,
                .height = @intCast(visible.max_rows),
            });
            drawBlock(&block_surface, blocks[visible.index], visible.skip_rows, visible.max_rows);
        }
    }
};

fn bodyHeightFor(size: chasen.Size) usize {
    const body_row: u16 = 3;
    return size.height -| (body_row + 1);
}

fn blockDefs() [blocks.len]ui.BlockViewport.Block {
    var block_defs: [blocks.len]ui.BlockViewport.Block = undefined;
    for (&block_defs, blocks) |*def, block| {
        // BlockViewport only needs the precomputed height of each block.
        def.* = .{ .height = block.height() };
    }
    return block_defs;
}

fn drawBlock(surface: *chasen.Surface, block: Block, skip_rows: usize, max_rows: usize) void {
    for (0..max_rows) |local_row| {
        const block_row = skip_rows + local_row;
        const row: u16 = @intCast(local_row);

        if (block_row == 0) {
            _ = surface.borrowTextAt(0, row, block.title, .{ .bold = true, .fg = .{ .index = 14 } });
            continue;
        }

        const line_index = block_row - 1;
        if (line_index < block.lines.len) {
            _ = surface.borrowTextAt(2, row, block.lines[line_index], .{});
        }
    }
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

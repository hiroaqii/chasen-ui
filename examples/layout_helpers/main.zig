const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows layout helpers as small Rect calculators.
//
// The helpers do not own component state and they do not render by themselves.
// The app calculates regions, turns each region into a Surface.child(Rect),
// then draws text or components inside that clipped child surface.
const App = struct {
    panel: ui.Panel = ui.Panel.init(.{}),

    pub const Msg = union(enum) {
        quit,
    };

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const root = surfaceRect(sfc);
        const title = ui.layout.takeTop(root, 1);
        const help = ui.layout.takeTop(title.rest, 1);
        const footer = ui.layout.takeBottom(help.rest, 1);
        const page = ui.layout.inset(footer.rest, .{ .top = 1, .right = 0, .bottom = 1, .left = 0 });

        _ = sfc.borrowTextAt(title.taken.col, title.taken.row, "Layout Helpers Example", .{ .bold = true });
        _ = sfc.borrowTextAt(help.taken.col, help.taken.row, "Esc: quit  helpers return Rect values; Surface.child(Rect) scopes rendering", .{ .fg = .gray });
        _ = sfc.borrowTextAt(footer.taken.col, footer.taken.row, "takeTop/takeBottom reserve page chrome; inset adds breathing room.", .{ .dim = true });

        const left = ui.layout.takeLeft(page, @min(page.width, 24));
        const right = ui.layout.takeRight(left.rest, @min(left.rest.width, 28));
        const main_area = right.rest;

        var sidebar = sfc.child(left.taken);
        try self.drawSidebar(&sidebar);

        var main_surface = sfc.child(main_area);
        try self.drawMain(&main_surface);

        var inspector = sfc.child(right.taken);
        try self.drawInspector(&inspector);
    }

    fn drawSidebar(self: *const App, sfc: *chasen.Surface) !void {
        const opts = ui.Panel.ViewOptions{
            .title = "take*",
            .padding = .{ .top = 1, .right = 1, .bottom = 1, .left = 1 },
        };
        self.panel.view(sfc, opts);

        const content = ui.Panel.contentRect(sfc, opts);
        if (content.width == 0 or content.height == 0) return;
        var body = sfc.child(content);
        _ = body.borrowTextAt(0, 0, "Page bands:", .{ .bold = true });
        _ = body.borrowTextAt(0, 2, "takeTop: title/help", .{});
        _ = body.borrowTextAt(0, 3, "takeBottom: footer", .{});
        _ = body.borrowTextAt(0, 4, "takeLeft: sidebar", .{});
        _ = body.borrowTextAt(0, 5, "takeRight: inspector", .{});
        _ = try body.printAt(0, 7, .{ .fg = .gray }, "area {d}x{d}", .{ sfc.size().width, sfc.size().height });
    }

    fn drawMain(self: *const App, sfc: *chasen.Surface) !void {
        const root = surfaceRect(sfc);
        var rows_buf: [2]chasen.Rect = undefined;
        const rows = ui.layout.rows(&rows_buf, root, .{ .gap = 1 });

        if (rows.len > 0) {
            var columns_area = sfc.child(rows[0]);
            try self.drawColumns(&columns_area);
        }
        if (rows.len > 1) {
            var grid_area = sfc.child(rows[1]);
            try self.drawGrid(&grid_area);
        }
    }

    fn drawColumns(self: *const App, sfc: *chasen.Surface) !void {
        const opts = ui.Panel.ViewOptions{
            .title = "columns",
            .padding = .{ .top = 1, .right = 1, .bottom = 1, .left = 1 },
        };
        self.panel.view(sfc, opts);

        const content = ui.Panel.contentRect(sfc, opts);
        if (content.width == 0 or content.height == 0) return;
        var body = sfc.child(content);

        // columns splits the available body into equal-width child regions.
        // The app still decides what each region means.
        var cols_buf: [3]chasen.Rect = undefined;
        const cols = ui.layout.columns(&cols_buf, surfaceRect(&body), .{ .gap = 1 });
        const labels = [_][]const u8{ "nav", "content", "meta" };

        for (cols, labels) |col, label| {
            var col_surface = body.child(col);
            _ = col_surface.borrowTextAt(0, 0, label, .{ .bold = true, .fg = .{ .index = 6 } });
            _ = try col_surface.printAt(0, 1, .{ .fg = .gray }, "{d}x{d}", .{ col.width, col.height });
        }
    }

    fn drawGrid(self: *const App, sfc: *chasen.Surface) !void {
        const opts = ui.Panel.ViewOptions{
            .title = "fixedGrid",
            .padding = .{ .top = 1, .right = 1, .bottom = 1, .left = 1 },
        };
        self.panel.view(sfc, opts);

        const content = ui.Panel.contentRect(sfc, opts);
        if (content.width == 0 or content.height == 0) return;
        var body = sfc.child(content);

        // fixedGrid is useful when the row/column count is part of the design,
        // such as dashboard cards or thumbnail tiles.
        var cells_buf: [6]chasen.Rect = undefined;
        const cells = ui.layout.fixedGrid(&cells_buf, surfaceRect(&body), .{
            .columns = 3,
            .rows = 2,
            .column_gap = 1,
            .row_gap = 1,
        });

        for (cells, 0..) |cell, index| {
            var cell_surface = body.child(cell);
            _ = try cell_surface.printAt(0, 0, .{ .bold = true, .fg = .{ .index = 2 } }, "cell {d}", .{index + 1});
            if (cell.height > 1) {
                _ = try cell_surface.printAt(0, 1, .{ .fg = .gray }, "{d}x{d}", .{ cell.width, cell.height });
            }
        }
    }

    fn drawInspector(self: *const App, sfc: *chasen.Surface) !void {
        const opts = ui.Panel.ViewOptions{
            .title = "inspector",
            .padding = .{ .top = 1, .right = 1, .bottom = 1, .left = 1 },
        };
        self.panel.view(sfc, opts);

        const content = ui.Panel.contentRect(sfc, opts);
        if (content.width == 0 or content.height == 0) return;
        var body = sfc.child(content);

        const body_rect = surfaceRect(&body);
        const top = ui.layout.takeTop(body_rect, 1);
        const strip_rect = ui.layout.constrain(top.taken, .{ .width = 18, .height = 1 });
        var strip = body.child(strip_rect);
        _ = strip.borrowTextAt(0, 0, "constrain()", .{ .fg = .gray });

        // center already clamps the requested size to the parent rect. Passing
        // the desired maximum size is enough for a max-size centered area.
        const card_rect = ui.layout.center(top.rest, .{ .width = 18, .height = 5 });
        var card = body.child(card_rect);
        _ = card.borrowTextAt(0, 0, "center()", .{ .bold = true, .fg = .{ .index = 5 } });
        _ = card.borrowTextAt(0, 2, "clamps size", .{});
        _ = card.borrowTextAt(0, 3, "to parent", .{});
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) .quit else null,
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        _ = self;
        switch (msg) {
            .quit => ctx.quit(),
        }
    }
};

fn surfaceRect(surface: *const chasen.Surface) chasen.Rect {
    const size = surface.size();
    return .{
        .col = 0,
        .row = 0,
        .width = size.width,
        .height = size.height,
    };
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

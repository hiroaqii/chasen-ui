const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const columns = [_]ui.Table.Column{
    .{ .header = "Rank", .width = 4, .alignment = .right },
    .{ .header = "Title", .width = 26 },
    .{ .header = "Year", .width = 4, .alignment = .right },
    .{ .header = "Rating", .width = 6, .alignment = .right },
};

const rows = [_]ui.Table.Row{
    &.{ "1", "Brass: Birmingham", "2018", "8.6" },
    &.{ "2", "Pandemic Legacy: Season 1", "2015", "8.5" },
    &.{ "3", "Gloomhaven", "2017", "8.5" },
};

// This example shows Table as a display-only data grid with multiple chrome modes.
//
// Table borrows fixed-width columns and row text. It does not own sorting,
// selection, scrolling, loading, or row activation. The app prepares which rows
// are visible and passes those borrowed cells to the component. New display
// options can be added here as side-by-side patterns when the API grows.
const App = struct {
    table: ui.Table = ui.Table.init(.{
        .columns = &columns,
        .rows = &rows,
    }),

    pub const Msg = union(enum) {
        quit,
    };

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

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();

        _ = sfc.borrowTextAt(0, 0, "Table Example - display modes", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        // Minimal is the default and preserves the original sample shape:
        // columns and a header separator, without spreadsheet-style borders.
        _ = sfc.borrowTextAt(0, 3, "minimal grid", .{ .bold = true, .fg = .{ .index = 6 } });
        var minimal_area = sfc.child(.{ .col = 0, .row = 4, .width = @min(size.width, self.table.naturalWidthFor(2, .minimal)), .height = 5 });
        self.table.view(&minimal_area, .{
            .column_gap = 2,
            .grid = .minimal,
            .header_style = .{ .bold = true, .fg = .{ .index = 6 } },
            .separator_style = .{ .fg = .gray },
            .cell_style = .{},
        });

        // None is useful when surrounding layout already supplies grouping.
        _ = sfc.borrowTextAt(0, 10, "no grid", .{ .bold = true, .fg = .{ .index = 6 } });
        var no_grid_area = sfc.child(.{ .col = 0, .row = 11, .width = @min(size.width, self.table.naturalWidthFor(2, .none)), .height = 3 });
        self.table.view(&no_grid_area, .{
            .column_gap = 2,
            .grid = .none,
            .show_header = false,
            .cell_style = .{ .fg = .gray },
        });

        // Full draws spreadsheet-like borders and row/column separators. The
        // app still owns sorting, pagination, scrolling, and activation.
        _ = sfc.borrowTextAt(0, 15, "full grid", .{ .bold = true, .fg = .{ .index = 6 } });
        var full_area = sfc.child(.{ .col = 0, .row = 16, .width = @min(size.width, self.table.naturalWidthFor(0, .full)), .height = size.height -| @min(size.height, 16) });
        self.table.view(&full_area, .{
            .grid = .full,
            .grid_style = .rounded,
            .header_style = .{ .bold = true, .fg = .{ .index = 6 } },
            .separator_style = .{ .fg = .gray },
        });

        const footer_row = @min(size.height -| 1, 27);
        _ = sfc.borrowTextAt(0, footer_row, "Rows are borrowed; table owns no scroll or selection state.", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

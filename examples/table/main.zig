const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const columns = [_]ui.Table.Column{
    .{ .header = "Rank", .width = 6, .alignment = .right },
    .{ .header = "Title", .width = 28 },
    .{ .header = "Year", .width = 6, .alignment = .right },
    .{ .header = "Rating", .width = 8, .alignment = .right },
};

const rows = [_]ui.Table.Row{
    &.{ "1", "Brass: Birmingham", "2018", "8.6" },
    &.{ "2", "Pandemic Legacy: Season 1", "2015", "8.5" },
    &.{ "3", "Gloomhaven", "2017", "8.5" },
    &.{ "4", "Ark Nova", "2021", "8.5" },
    &.{ "5", "Twilight Imperium", "2017", "8.6" },
    &.{ "6", "Dune: Imperium", "2020", "8.4" },
    &.{ "7", "Terraforming Mars", "2016", "8.4" },
    &.{ "8", "Gaia Project", "2017", "8.4" },
    &.{ "9", "War of the Ring", "2011", "8.5" },
    &.{ "10", "Spirit Island", "2017", "8.4" },
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
    table_offset: usize = 0,

    pub const Msg = union(enum) {
        scroll_up,
        scroll_down,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        _ = self;
        return switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{}) or key.codepoint == 'k') return .scroll_up;
                if (key.matches(chasen.Key.down, .{}) or key.codepoint == 'j') return .scroll_down;
                return null;
            },
            else => null,
        };
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .scroll_up => self.table_offset -|= 1,
            .scroll_down => self.table_offset = @min(self.table_offset + 1, self.maxTableOffset()),
            .quit => ctx.quit(),
        }
    }

    fn maxTableOffset(self: *const App) usize {
        const partial_height: usize = 7;
        const rendered_rows = self.table.renderedRowCountForOptions(partialTableOptions());
        if (rendered_rows <= partial_height) return 0;
        return rendered_rows - partial_height;
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        const partial_height: u16 = 7;

        _ = sfc.borrowTextAt(0, 0, "Table Example - partial view", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down/j/k: scroll rendered rows  Esc: quit", .{ .fg = .gray });

        // Minimal is still the simplest table shape: columns and a header
        // separator, without spreadsheet-style borders.
        _ = sfc.borrowTextAt(0, 3, "minimal grid", .{ .bold = true, .fg = .{ .index = 6 } });
        var minimal_area = sfc.child(.{ .col = 0, .row = 4, .width = @min(size.width, self.table.naturalWidthFor(2, .minimal)), .height = 5 });
        self.table.view(&minimal_area, .{
            .column_gap = 2,
            .grid = .minimal,
            .header_style = .{ .bold = true, .fg = .{ .index = 6 } },
            .separator_style = .{ .fg = .gray },
            .cell_style = .{},
        });

        // viewSlice uses rendered-row units. The offset can land on the top
        // border, header, separator, body row, or bottom border. Table remains
        // display-only; the app owns the offset and clamps it in update().
        _ = sfc.borrowTextAt(0, 10, "full grid partial view with cell padding", .{ .bold = true, .fg = .{ .index = 6 } });
        var partial_area = sfc.child(.{ .col = 0, .row = 11, .width = @min(size.width, self.table.naturalWidthFor(0, .full)), .height = @min(partial_height, size.height -| @min(size.height, 11)) });
        self.table.viewSlice(&partial_area, partialTableOptions(), .{
            .skip_rows = self.table_offset,
            .max_rows = partial_height,
        });

        const rendered_rows = self.table.renderedRowCountForOptions(partialTableOptions());
        _ = try sfc.printAt(0, 19, .{ .fg = .gray }, "offset {d}/{d} rendered rows", .{ self.table_offset, self.maxTableOffset() });
        _ = try sfc.printAt(0, 20, .{ .dim = true }, "table renders {d} rows including borders/header/body/bottom", .{rendered_rows});

        const footer_row = @min(size.height -| 1, 27);
        _ = sfc.borrowTextAt(0, footer_row, "Rows are borrowed; table owns no scroll or selection state.", .{ .dim = true });
    }
};

fn partialTableOptions() ui.Table.ViewOptions {
    return .{
        .grid = .full,
        .grid_style = .rounded,
        .header_style = .{ .bold = true, .fg = .{ .index = 6 } },
        .separator_style = .{ .fg = .gray },
        .body_separators = false,
        .cell_padding = .{ .left = 1, .right = 1 },
    };
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

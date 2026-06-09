const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const language_accent = chasen.Color{ .index = 14 };
const score_accent = chasen.Color{ .index = 10 };

const columns = [_]ui.ColumnList.Column{
    .{
        .header = "Language",
        .width = .flex,
        .style = .{ .fg = language_accent },
    },
    .{
        .header = "Runtime",
        .width = .{ .fixed = 12 },
    },
    .{
        .header = "Score",
        .width = .{ .fixed = 6 },
        .alignment = .right,
        .style = .{ .fg = score_accent },
    },
};

const row_zig = [_]ui.ColumnList.Cell{
    .{ .text = "Zig" },
    .{ .text = "native" },
    .{ .text = "98" },
};

const row_go = [_]ui.ColumnList.Cell{
    .{ .text = "Go" },
    .{ .text = "native" },
    .{ .text = "91" },
};

const row_rust = [_]ui.ColumnList.Cell{
    .{ .text = "Rust" },
    .{ .text = "native" },
    .{ .text = "95" },
};

const row_python = [_]ui.ColumnList.Cell{
    .{ .text = "Python" },
    .{ .text = "interpreter" },
    .{ .text = "84" },
};

const rows = [_]ui.ColumnList.Row{
    &row_zig,
    &row_go,
    &row_rust,
    &row_python,
};

// ColumnList is for selectable list screens that need column layout.
//
// It owns focus state like List, but each row is split into cells. The app
// still owns what activation means; here Enter/Space copies the focused row
// into selected_index.
const App = struct {
    list: ui.ColumnList = ui.ColumnList.init(.{
        .columns = &columns,
        .rows = &rows,
    }),
    selected_index: ?usize = null,

    pub const Msg = union(enum) {
        list: ui.ColumnList.Msg,
        quit,
    };

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .list => |list_msg| switch (list_msg) {
                .move_prev, .move_next => self.list.update(list_msg),
                .activate => |index| self.selected_index = index,
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "ColumnList Example - selectable columns", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Up/Down: move  Enter/Space: select  Esc: quit", .{ .fg = .gray });

        var list_area = sfc.child(.{ .col = 0, .row = 3, .width = 34, .height = 6 });
        self.list.view(&list_area, .{
            .selected_index = self.selected_index,
            .show_header = true,
            .focused_style = .{ .bold = true, .reverse = true },
            .selected_style = .{ .bold = true },
            .focused_selected_style = .{ .bold = true, .reverse = true },
        });

        _ = sfc.borrowTextAt(40, 3, "App model", .{ .bold = true, .fg = language_accent });
        _ = sfc.borrowTextAt(40, 4, "focused", .{ .fg = .gray });
        _ = try sfc.printAt(51, 4, .{}, "{d}", .{self.list.focusedIndex()});

        _ = sfc.borrowTextAt(40, 5, "selected", .{ .fg = .gray });
        if (self.selected_index) |index| {
            _ = sfc.borrowTextAt(51, 5, rows[index][0].text, .{ .fg = language_accent });
        } else {
            _ = sfc.borrowTextAt(51, 5, "None", .{ .dim = true });
        }

        _ = sfc.borrowTextAt(40, 7, "List owns focus", .{ .dim = true });
        _ = sfc.borrowTextAt(40, 8, "Cells own display data", .{ .dim = true });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) return .quit,
            else => {},
        }

        // Delegate normal list navigation to ColumnList after app shortcuts.
        if (self.list.handleEvent(event)) |msg| {
            return .{ .list = msg };
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

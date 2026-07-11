const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const package_nodes = [_]ui.Tree.Node{
    .{ .label = "chasen-utsuwa", .has_children = true, .expanded = true },
    .{ .label = "chasen", .depth = 1, .has_children = true, .expanded = true },
    .{ .label = "src", .depth = 2 },
    .{ .label = "examples", .depth = 2 },
    .{ .label = "chasen-ui", .depth = 1, .has_children = true, .expanded = true },
    .{ .label = "src", .depth = 2, .has_children = true, .expanded = true },
    .{ .label = "table.zig", .depth = 3 },
    .{ .label = "tree.zig", .depth = 3 },
    .{ .label = "examples", .depth = 2, .has_children = true, .expanded = false },
    .{ .label = "bgg-tui", .depth = 1, .has_children = true, .expanded = false },
};

// This example shows Tree as a display-only outline.
//
// Tree borrows the already-visible nodes prepared by the app. It does not own
// expansion state, traversal, focus, selection, or scrolling. If a node is
// collapsed, the app simply omits its children from the visible node list.
const App = struct {
    tree: ui.Tree = ui.Tree.init(.{ .nodes = &package_nodes }),

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

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

        _ = sfc.borrowTextAt(0, 0, "Tree Example - app-owned visibility", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Esc: quit", .{ .fg = .gray });

        // The component draws depth guides, markers, and labels only. The app
        // decides which nodes are visible and what expand/collapse means.
        var tree_area = sfc.child(.{ .col = 0, .row = 3, .width = @min(size.width, 42), .height = size.height -| @min(size.height, 5) });
        self.tree.view(&tree_area, .{
            .indent_width = 3,
            .glyphs = .rounded,
            .guide_style = .{ .fg = .gray },
            .marker_style = .{ .bold = true, .fg = .{ .index = 6 } },
            .label_style = .{},
        });

        const footer_row = size.height -| 1;
        _ = sfc.borrowTextAt(0, footer_row, "Nodes are borrowed; tree owns no expansion or focus state.", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}

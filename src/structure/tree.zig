const std = @import("std");
const chasen = @import("chasen");

/// A small display-only tree component.
///
/// `Tree` borrows a flat list of visible nodes. It draws indentation, optional
/// guide glyphs, optional expand/collapse markers, and labels. It does not own
/// expansion state, selection, focus, scrolling, or tree traversal. Applications
/// decide which nodes are visible and what each node represents.
pub const Tree = struct {
    /// One visible tree node.
    pub const Node = struct {
        /// Label borrowed by the component.
        label: []const u8,
        /// Display depth. Root nodes usually use depth `0`.
        depth: u16 = 0,
        /// Whether the node can have children.
        has_children: bool = false,
        /// Whether the node is currently expanded.
        ///
        /// `Tree` only uses this to choose the marker. Applications still own
        /// expansion state and decide which child nodes are present in `nodes`.
        expanded: bool = false,
    };

    /// Glyphs used for guide lines and markers.
    ///
    /// Glyphs are expected to occupy one terminal cell.
    pub const Glyphs = struct {
        guide: []const u8 = "|",
        expanded: []const u8 = "v",
        collapsed: []const u8 = ">",
        leaf: []const u8 = " ",

        pub const ascii: Glyphs = .{};
        pub const rounded: Glyphs = .{
            .guide = "│",
            .expanded = "▾",
            .collapsed = "▸",
            .leaf = " ",
        };
    };

    /// Initial values used when constructing a `Tree`.
    pub const Options = struct {
        /// Visible nodes borrowed by the component for its lifetime.
        nodes: []const Node = &.{},
    };

    /// Rendering options for `Tree.view`.
    pub const ViewOptions = struct {
        /// Cells reserved for each depth level.
        indent_width: u16 = 2,
        /// Whether to draw ancestor guide glyphs.
        show_guides: bool = true,
        /// Whether to draw expand/collapse/leaf markers.
        show_markers: bool = true,
        /// Glyph set used for guides and markers.
        glyphs: Glyphs = .ascii,
        /// Style used for guide glyphs.
        guide_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for marker glyphs.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for node labels.
        label_style: chasen.TextStyle = .{},
    };

    /// Visible nodes borrowed by the component.
    nodes: []const Node = &.{},

    /// Create a tree.
    pub fn init(opts: Options) Tree {
        return .{ .nodes = opts.nodes };
    }

    /// Return how many nodes can be drawn for `height`.
    pub fn visibleNodeCapacity(self: *const Tree, height: u16) usize {
        _ = self;
        return height;
    }

    /// Return the label start column for a node depth and marker setting.
    pub fn labelCol(depth: u16, indent_width: u16, show_markers: bool) u16 {
        const indent = depth *| indent_width;
        return if (show_markers) indent +| 2 else indent;
    }

    /// Draw the visible tree nodes into the provided clipped surface region.
    pub fn view(self: *const Tree, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        for (self.nodes, 0..) |node, index| {
            if (index >= height) break;
            drawNode(surface, @intCast(index), node, opts, width);
        }
    }
};

fn drawNode(surface: *chasen.Surface, row: u16, node: Tree.Node, opts: Tree.ViewOptions, width: u16) void {
    const indent = node.depth *| opts.indent_width;

    if (opts.show_guides and opts.indent_width > 0) {
        var depth: u16 = 0;
        while (depth < node.depth) : (depth += 1) {
            const col = depth *| opts.indent_width;
            if (col >= width) return;
            _ = surface.borrowTextAt(col, row, opts.glyphs.guide, opts.guide_style);
        }
    }

    if (opts.show_markers) {
        if (indent >= width) return;
        _ = surface.borrowTextAt(indent, row, markerFor(node, opts.glyphs), opts.marker_style);
    }

    const label_col = Tree.labelCol(node.depth, opts.indent_width, opts.show_markers);
    if (label_col >= width) return;

    var label_surface = surface.child(.{
        .col = label_col,
        .row = row,
        .width = width - label_col,
        .height = 1,
    });
    _ = label_surface.borrowTextAt(0, 0, node.label, opts.label_style);
}

fn markerFor(node: Tree.Node, glyphs: Tree.Glyphs) []const u8 {
    if (!node.has_children) return glyphs.leaf;
    return if (node.expanded) glyphs.expanded else glyphs.collapsed;
}

test "Tree initializes from options" {
    const nodes = [_]Tree.Node{
        .{ .label = "root", .has_children = true, .expanded = true },
        .{ .label = "child", .depth = 1 },
    };
    const tree = Tree.init(.{ .nodes = &nodes });

    try std.testing.expectEqual(@as(usize, 2), tree.nodes.len);
    try std.testing.expectEqualStrings("child", tree.nodes[1].label);
}

test "Tree visibleNodeCapacity uses height" {
    const tree = Tree.init(.{});

    try std.testing.expectEqual(@as(usize, 0), tree.visibleNodeCapacity(0));
    try std.testing.expectEqual(@as(usize, 4), tree.visibleNodeCapacity(4));
}

test "Tree labelCol accounts for depth indent and marker" {
    try std.testing.expectEqual(@as(u16, 0), Tree.labelCol(0, 2, false));
    try std.testing.expectEqual(@as(u16, 2), Tree.labelCol(0, 2, true));
    try std.testing.expectEqual(@as(u16, 6), Tree.labelCol(2, 2, true));
    try std.testing.expectEqual(@as(u16, 6), Tree.labelCol(3, 2, false));
}

test "Tree markerFor chooses leaf collapsed and expanded glyphs" {
    try std.testing.expectEqualStrings(" ", markerFor(.{ .label = "leaf" }, .ascii));
    try std.testing.expectEqualStrings(">", markerFor(.{ .label = "closed", .has_children = true }, .ascii));
    try std.testing.expectEqualStrings("v", markerFor(.{ .label = "open", .has_children = true, .expanded = true }, .ascii));
}

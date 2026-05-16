const std = @import("std");
const chasen = @import("chasen");

/// A display-only accordion header stack.
///
/// `Accordion` borrows section labels and expansion flags prepared by the
/// application. It draws one header row per visible section and reserves body
/// rows for expanded sections. Applications still own expansion state, focus,
/// keyboard handling, body content rendering, scrolling, and section policy.
pub const Accordion = struct {
    /// One accordion section.
    pub const Section = struct {
        /// Header label borrowed by the component.
        title: []const u8,
        /// Whether the section body is currently visible.
        expanded: bool = false,
        /// Body rows reserved after the header when `expanded` is true.
        body_height: u16 = 0,
    };

    /// Glyphs used by header rows.
    ///
    /// Glyphs are expected to occupy one terminal cell.
    pub const Glyphs = struct {
        expanded: []const u8 = "v",
        collapsed: []const u8 = ">",

        pub const ascii: Glyphs = .{};
        pub const rounded: Glyphs = .{
            .expanded = "▾",
            .collapsed = "▸",
        };
    };

    /// Initial values used when constructing an `Accordion`.
    pub const Options = struct {
        /// Sections borrowed by the component for its lifetime.
        sections: []const Section = &.{},
    };

    /// Rendering options for `Accordion.view`.
    pub const ViewOptions = struct {
        /// Glyph set used for header markers.
        glyphs: Glyphs = .ascii,
        /// Text drawn between marker and title.
        marker_gap: []const u8 = " ",
        /// Style used for expanded section markers.
        expanded_marker_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for collapsed section markers.
        collapsed_marker_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for expanded section titles.
        expanded_title_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for collapsed section titles.
        collapsed_title_style: chasen.TextStyle = .{},
    };

    /// Sections borrowed by the component.
    sections: []const Section = &.{},

    /// Create an accordion.
    pub fn init(opts: Options) Accordion {
        return .{ .sections = opts.sections };
    }

    /// Return whether the accordion has no sections.
    pub fn empty(self: *const Accordion) bool {
        return self.sections.len == 0;
    }

    /// Return total rows requested by headers and expanded bodies.
    pub fn requestedHeight(self: *const Accordion) u16 {
        var height: u16 = 0;
        for (self.sections) |section| {
            height +|= 1;
            if (section.expanded) height +|= section.body_height;
        }
        return height;
    }

    /// Return the header row offset for a section, or null when out of range.
    pub fn headerRow(self: *const Accordion, index: usize) ?u16 {
        return headerRowFor(self.sections, index);
    }

    /// Return the app-owned body rectangle inside the provided accordion surface.
    ///
    /// Collapsed sections and out-of-range indexes return a zero-height
    /// rectangle. The returned rectangle is relative to the accordion surface.
    /// Pass it to `surface.child(rect)` before drawing section body content.
    pub fn bodyRect(self: *const Accordion, surface: *chasen.Surface, index: usize) chasen.Rect {
        return bodyRectFor(.{ .col = 0, .row = 0, .width = surface.size().width, .height = surface.size().height }, self.sections, index);
    }

    /// Return the body rectangle for an already resolved accordion region.
    ///
    /// This helper is useful for tests and for apps that calculate geometry
    /// separately from rendering.
    pub fn bodyRectFor(bounds: chasen.Rect, sections: []const Section, index: usize) chasen.Rect {
        if (index >= sections.len) return zeroBodyRect(bounds);

        var row_offset: u16 = 0;
        for (sections, 0..) |section, i| {
            if (i == index) {
                const body_offset = row_offset +| 1;
                if (!section.expanded or body_offset >= bounds.height) {
                    return .{
                        .col = bounds.col,
                        .row = bounds.row +| @min(body_offset, bounds.height),
                        .width = bounds.width,
                        .height = 0,
                    };
                }

                return .{
                    .col = bounds.col,
                    .row = bounds.row +| body_offset,
                    .width = bounds.width,
                    .height = @min(section.body_height, bounds.height - body_offset),
                };
            }

            row_offset +|= 1;
            if (section.expanded) row_offset +|= section.body_height;
        }

        return zeroBodyRect(bounds);
    }

    /// Draw accordion section headers into the provided clipped surface region.
    pub fn view(self: *const Accordion, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        var row: u16 = 0;
        for (self.sections) |section| {
            if (row >= height) break;
            drawHeader(surface, row, width, section, opts);

            row +|= 1;
            if (section.expanded) row +|= section.body_height;
        }
    }
};

fn drawHeader(surface: *chasen.Surface, row: u16, width: u16, section: Accordion.Section, opts: Accordion.ViewOptions) void {
    if (width == 0) return;

    const marker = if (section.expanded) opts.glyphs.expanded else opts.glyphs.collapsed;
    const marker_style = if (section.expanded) opts.expanded_marker_style else opts.collapsed_marker_style;
    const title_style = if (section.expanded) opts.expanded_title_style else opts.collapsed_title_style;

    var col: u16 = 0;
    _ = surface.textAt(col, row, marker, marker_style);
    col +|= chasen.text.displayWidth(marker);

    if (col < width and opts.marker_gap.len > 0) {
        _ = surface.textAt(col, row, opts.marker_gap, title_style);
        col +|= chasen.text.displayWidth(opts.marker_gap);
    }

    if (col >= width) return;
    var title_surface = surface.child(.{
        .col = col,
        .row = row,
        .width = width - col,
        .height = 1,
    });
    _ = title_surface.textAt(0, 0, section.title, title_style);
}

fn headerRowFor(sections: []const Accordion.Section, index: usize) ?u16 {
    if (index >= sections.len) return null;

    var row: u16 = 0;
    for (sections, 0..) |section, i| {
        if (i == index) return row;
        row +|= 1;
        if (section.expanded) row +|= section.body_height;
    }
    return null;
}

fn zeroBodyRect(bounds: chasen.Rect) chasen.Rect {
    return .{
        .col = bounds.col,
        .row = bounds.row,
        .width = bounds.width,
        .height = 0,
    };
}

test "Accordion initializes with borrowed sections" {
    const sections = [_]Accordion.Section{
        .{ .title = "Overview", .expanded = true, .body_height = 2 },
        .{ .title = "Details" },
    };
    const accordion = Accordion.init(.{ .sections = &sections });

    try std.testing.expect(!accordion.empty());
    try std.testing.expectEqual(@as(usize, 2), accordion.sections.len);
    try std.testing.expectEqualStrings("Overview", accordion.sections[0].title);
}

test "Accordion requestedHeight accounts for expanded bodies only" {
    const sections = [_]Accordion.Section{
        .{ .title = "Open", .expanded = true, .body_height = 3 },
        .{ .title = "Closed", .expanded = false, .body_height = 9 },
        .{ .title = "Also open", .expanded = true, .body_height = 2 },
    };
    const accordion = Accordion.init(.{ .sections = &sections });

    try std.testing.expectEqual(@as(u16, 8), accordion.requestedHeight());
}

test "Accordion headerRow includes expanded body reservations" {
    const sections = [_]Accordion.Section{
        .{ .title = "A", .expanded = true, .body_height = 2 },
        .{ .title = "B" },
        .{ .title = "C", .expanded = true, .body_height = 1 },
    };
    const accordion = Accordion.init(.{ .sections = &sections });

    try std.testing.expectEqual(@as(u16, 0), accordion.headerRow(0).?);
    try std.testing.expectEqual(@as(u16, 3), accordion.headerRow(1).?);
    try std.testing.expectEqual(@as(u16, 4), accordion.headerRow(2).?);
    try std.testing.expect(accordion.headerRow(3) == null);
}

test "Accordion bodyRectFor clips expanded body to bounds" {
    const sections = [_]Accordion.Section{
        .{ .title = "A", .expanded = true, .body_height = 4 },
        .{ .title = "B", .expanded = true, .body_height = 2 },
    };

    const rect = Accordion.bodyRectFor(.{
        .col = 2,
        .row = 3,
        .width = 20,
        .height = 4,
    }, &sections, 0);

    try std.testing.expectEqual(@as(u16, 2), rect.col);
    try std.testing.expectEqual(@as(u16, 4), rect.row);
    try std.testing.expectEqual(@as(u16, 20), rect.width);
    try std.testing.expectEqual(@as(u16, 3), rect.height);
}

test "Accordion bodyRectFor returns zero height for collapsed sections" {
    const sections = [_]Accordion.Section{
        .{ .title = "A", .expanded = false, .body_height = 3 },
    };

    const rect = Accordion.bodyRectFor(.{
        .col = 1,
        .row = 2,
        .width = 10,
        .height = 5,
    }, &sections, 0);

    try std.testing.expectEqual(@as(u16, 1), rect.col);
    try std.testing.expectEqual(@as(u16, 3), rect.row);
    try std.testing.expectEqual(@as(u16, 10), rect.width);
    try std.testing.expectEqual(@as(u16, 0), rect.height);
}

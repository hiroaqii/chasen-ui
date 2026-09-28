# Layout and Child Surfaces

Applications position components by passing child surfaces. Component options
may describe internal padding, columns, or alignment, but the app controls the
outer screen region.

The layout vocabulary is small:

```text
Rect
  = position + size inside a Surface

ui.layout
  = helpers that calculate Rect values

Surface
  = drawing target

Surface.child(Rect)
  = clipped child Surface for that Rect

chasen-ui component
  = draws inside the Surface it receives
```

In a typical `view`, the app calculates rectangles, creates child surfaces from
those rectangles, and passes the child surfaces to components.

The application calculates layout and creates clipped child surfaces:

```zig
const body_rect = chasen.Rect{
    // Start 2 terminal cells from the left edge of the parent surface.
    .col = 2,
    // Start 4 terminal cells from the top edge of the parent surface.
    .row = 4,
    // Reserve 60 terminal cells horizontally.
    .width = 60,
    // Reserve 12 terminal cells vertically.
    .height = 12,
};

var body = surface.child(body_rect);
```

For simple screens, writing `Rect` values directly is fine. For larger screens,
use `ui.layout` to calculate regions:

```text
Root Surface
┌────────────────────────────────────────────┐
│ header                                     │
├──────────────┬─────────────────────────────┤
│ sidebar      │ content                     │
│              │                             │
│              │                             │
├──────────────┴─────────────────────────────┤
│ footer                                     │
└────────────────────────────────────────────┘

ui.layout computes the Rect values above.

header_rect  -> Surface.child(header_rect)
sidebar_rect -> Surface.child(sidebar_rect)
content_rect -> Surface.child(content_rect)
footer_rect  -> Surface.child(footer_rect)

ui.Panel / ui.Table / ui.Paragraph / ...
  -> draw inside those child surfaces
```

The same idea in code:

```zig
// Start with a Rect that covers the entire current surface.
const root = chasen.Rect{
    .col = 0,
    .row = 0,
    .width = surface.size().width,
    .height = surface.size().height,
};

// takeTop returns the top band in `.taken` and the remaining area in `.rest`.
const header = ui.layout.takeTop(root, 1);
// Continue splitting the remaining area. Nothing has been drawn yet.
const footer = ui.layout.takeBottom(header.rest, 1);
const sidebar = ui.layout.takeLeft(footer.rest, 18);
const content = sidebar.rest;

// Turn each Rect into a clipped drawing target.
var header_surface = surface.child(header.taken);
var sidebar_surface = surface.child(sidebar.taken);
var content_surface = surface.child(content);
var footer_surface = surface.child(footer.taken);

// Drawing at 0,0 is now local to each child surface.
_ = header_surface.borrowTextAt(0, 0, "Header", .{ .bold = true });
_ = sidebar_surface.borrowTextAt(0, 0, "Navigation", .{});
_ = content_surface.borrowTextAt(0, 0, "Main content", .{});
_ = footer_surface.borrowTextAt(0, 0, "Esc: quit", .{ .fg = .gray });
```

Common layout helpers include:

- `inset`: shrink a rectangle by padding values
- `takeTop`: split a top band from a rectangle
- `takeBottom`: split a bottom band from a rectangle
- `takeLeft`: split a left band from a rectangle
- `takeRight`: split a right band from a rectangle
- `center`: create a centered rectangle
- `columns`: split a rectangle into equal-width columns
- `rows`: split a rectangle into equal-height rows
- `fixedGrid`: split a rectangle into fixed rows and columns
- `stack`: place fixed-height rows with gaps

The layout helpers only calculate rectangles. They do not render and they do
not own component state.


See the [README](../README.md#basic-usage) for a complete panel app and
[Components](COMPONENTS.md) for component state and text lifetimes.

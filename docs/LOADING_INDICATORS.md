# Loading Indicators

Run the gallery (64x24 minimum; 80x24 recommended):

```sh
zig build run-loading_indicators
```

The gallery starts with all five animations at their minimum 1x1-cell size.
Space pauses/resumes; `[` slows down and `]` speeds up; `s` cycles
tiny → small → medium → large for all five; `c` cycles colors; `r` resets the
phase; Esc exits. Periods are
400/800/1200/1600 milliseconds per cycle, initially 1200. Speed changes preserve
phase. Pausing stops frame requests, resuming ignores the first idle delta, and
changing settings or resetting while paused keeps the gallery paused.

| Display | API | Tiny | Small | Medium | Large |
| --- | --- | --- | --- | --- | --- |
| Dots / Wave | existing `chasen_ui.Spinner` | 1x1 | 5x1 | 5x1 | 5x1 |
| Blocks | `chasen_ui_graphics.LoadingIndicator` | 1x1 | 8x5 | 14x8 | 20x11 |
| Arc / Ripple | `chasen_ui_graphics.LoadingIndicator` | 1x1 | 8x4 | 12x6 | 16x8 |

Dimensions exclude labels. Dots/Wave accept the static
`chasen_graphics.glyph.spinner.linear_dots` / `wave` frame lists through
`Spinner.init(.{ .frames = &graphics.glyph.spinner.wave, .label = "Loading" })`;
pass a frame index and `frame_style` to `view`.
Use `linear_dots_tiny` / `wave_tiny` for their one-cell variants. At 1x1,
Blocks rotates a quadrant, Arc rotates three dots, and Ripple expands from
center to outer dots before fading. Labels are additional text, outside that cell.

Multiline indicators live in the **optional** `chasen_ui_graphics` module.
The main `chasen_ui` module does not import graphics or anim. The adapter uses
`chasen_graphics`; the gallery also uses `chasen_anim`. In your build,
register the adapter from the same UI dependency:

```zig
exe.root_module.addImport("chasen_ui_graphics", ui_dep.module("chasen_ui_graphics"));
```

Then draw into an app-positioned, dedicated child Surface:

```zig
const Indicator = @import("chasen_ui_graphics").LoadingIndicator;
const indicator = Indicator.init(.{ .kind = .arc, .label = "Loading" });
indicator.view(&region, .{
    .phase = 0.25,
    .size = .tiny, // Minimum; omit this option to use the adapter default, medium.
    .style = .{ .fg = .{ .index = 14 } },
});
```

The app owns elapsed time, period, pause policy, and frame requests. The gallery
uses `chasen_anim.blink.phase(cycle_ns, period_ns)` with both arguments in
nanoseconds. Components contain no timers or animation state.
`LoadingIndicator.view` clears its entire supplied Surface using `style`, draws
at the top left, clips to its bounds, and puts the borrowed label below the
nominal shape. Reserve one extra row for a label; moving or shrinking the Surface
requires the app to clear its old region. Glyphs have static lifetime; labels
must outlive the component and render. Low-intensity cells add the terminal dim
attribute. Unicode Braille/block coverage, dim appearance, and circle proportions
depend on the terminal font (circles assume cells twice as tall as wide).

Focused checks: `zig build test-loading-indicator test-loading_indicators`.
When both optional dependencies resolve, the gallery is included in
`check-examples`, and its tests in `test`. The adapter tests need graphics.
See [Development](DEVELOPMENT.md) for the dependency and check matrix.

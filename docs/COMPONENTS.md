# Components

Public components and helpers are exported from
[`src/root.zig`](../src/root.zig) as `chasen_ui`.

## Component Model

Display-only components draw the values the app gives them.

Interactive components can retain local component state, while the app owns
event routing and decides how component messages affect app state. The catalog
below groups both display and interactive APIs by role.

### Input and Updates

Chasen delivers terminal events to optional `app.handleEvent`. The app selects
an input target, may call its `component.handleEvent`, and maps the returned
component message into the root `App.Msg`. Chasen then calls `app.update` with
that message. The app decides whether to call `component.update`, change other
state, or request runtime effects.

```text
Chasen -> app.handleEvent(event)
  app optionally calls component.handleEvent(event)
  app returns an App.Msg, or null
Chasen -> app.update(msg, ctx), if a message was returned
  app optionally calls component.update(component_msg)
```

The component does not call the app or runtime automatically. App shortcuts can
consume an event before a component sees it, and the app can construct component
messages directly for custom bindings. Timer and task results are already app
messages, so Chasen delivers them directly to `app.update` without `handleEvent`.
See the [TextInput example](../examples/text_input/main.zig) for event delegation
and app-defined submit behavior.

### Drawing and Redraws

Chasen calls `app.view` when a render is needed. The app reads current state,
calculates rectangles, and passes child surfaces to component `view` or `draw`
methods. The runtime presents the resulting cells to the terminal after the
app's view returns. A component does not schedule its own rendering.

An update normally requests a redraw. `ctx.redraw().skip()` suppresses the
redraw for that message, while queued effects still drain. Returning `null`
from `handleEvent` causes no update or redraw for that event, except that resize
always redraws. Initial rendering and resize therefore do not require an app
state change. See [Chasen's runtime guide](https://github.com/hiroaqii/chasen/blob/main/docs/RUNTIME.md)
for the full runtime lifecycle.

### State and Text Lifetimes

The app owns component instances and controls their lifetime. A component may
own editable buffers or local focus/scroll state; it does not become a
framework-managed object. Call a component's `deinit` when required, including
from the app's optional `deinit` hook at shutdown. Keep cleanup correct on error
paths as well as normal quit.

Use `.quit` to request shutdown and `App.deinit` to release app-owned components
and buffers. Chasen also calls this hook when `App.init` or a later app callback
returns an error, so track which resources have been initialized. The
[TextInput example](../examples/text_input/main.zig) uses optional fields for
this purpose; a failed init leaves uninitialized fields null.

Borrowed labels, placeholders, rows, frame lists, and other borrowed values must
remain valid for as long as the component retains them and until Chasen finishes
rendering any cells that borrow them. A component `view` returning does not end
that requirement. Use owned app storage for retained data, and frame-owned copies
for generated text used only in the current render. Never keep frame-allocator
memory in a component across frames.

## Input

Use input components when the app needs editable state:

- `TextInput`
- `TextArea`
- `PasswordInput`
- `NumberInput`
- `Select`
- `Checkbox`
- `Radio`
- `Button`
- `FormField`

## Radio Markers

`Radio.view` uses filled and empty circles (`●` / `○`) by default. Set
`ViewOptions.marker` to choose a different appearance without changing the
option state or group behavior:

```zig
const radio = ui.Radio.init(.{ .selected = true, .label = "All changes" });
radio.view(&surface, .{ .marker = .ring });
```

| `ui.Radio.Marker` | Selected | Unselected |
| --- | --- | --- |
| `.circle` (default) | `●` | `○` |
| `.ring` | `◉` | `○` |
| `.diamond` | `◆` | `◇` |

Marker colors still use `style` and `selected_style`; label colors use
`label_style`. The label follows the marker with a one-cell gap (column 2 for
these presets), and `show_cursor` places the cursor on the marker at column 0.
This replaces the previous `(o)` / `( )` layout, whose label began at column 4;
align app-owned descriptions with the new label position.

Run `zig build run-radio` and press `1`, `2`, or `3` to compare the markers.

## Lists and Navigation

Use these when the app owns collections, focus, filtering, or scroll state:

- `Viewport`: offset clamp and visible range helper for fixed-size collections
- `ListViewport`: visible range and focus visibility for fixed-height rows
- `ListFilter`: small filter state helper for app-owned lists
- `ColumnList`: table-like list rows with per-column styling and alignment, up
  to `ColumnList.max_columns`
- `BlockViewport`: scrollable content made of variable-height blocks
- `FocusList`: fixed-length focus state for app-owned event routing
- `List`
- `SelectableList`
- `MultiSelectList`: local focus and 64-bit selection mask with derived visible range
- `Menu`
- `Tabs`
- `Breadcrumbs`
- `Accordion`

## Structure

Use these to frame, layer, or group content:

- `Panel`
- `Overlay`
- `Modal`
- `Box`
- `Table`
- `Tree`

## Display

Use these for display-only UI:

- `Paragraph`
- `StatusLine`
- `key_hint`
- `MessageBlock`
- `Spinner`
- `ProgressBar`
- `Gauge`
- `Toast`
- `Rating`
- `Badge`
- `Alert`
- `Divider`
- `Label`

## Text Geometry and Presentation

`ui.text_projection` maps borrowed UTF-8 byte offsets to terminal cells, including
TAB expansion and grapheme boundaries. Construction validates the entire line;
keep the source bytes alive and unchanged while using its projection.

`ui.text_presentation` provides projection-backed ranges, clipping, and terminal
materialization. Geometry values borrow the source. `Clip.materialize` transfers
an allocation to its caller; `drawAt` instead keeps the backing text in the
Surface frame arena. See [projection](../src/text/projection.zig) and
[presentation](../src/text/presentation.zig) for API contracts and tests.

## Related Guides

- [Layout and Child Surfaces](LAYOUT.md): app-owned placement and rectangle helpers.
- [Loading Indicators](LOADING_INDICATORS.md): the optional graphics adapter.
- [Development](DEVELOPMENT.md): example and test commands.

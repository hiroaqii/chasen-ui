# chasen-ui

Small component package for [Chasen](https://github.com/hiroaqii/chasen)
terminal applications.

The Zig module name is `chasen_ui`.

## Components

- `TextInput`: owned UTF-8 single-line text input.
- `TextArea`: owned UTF-8 multi-line text input.
- `FormField`: allocation-free display-only form field chrome.
- `PasswordInput`: owned UTF-8 single-line masked text input.
- `NumberInput`: owned UTF-8 single-line integer input.
- `Select`: allocation-free one-line option picker.
- `Checkbox`: allocation-free boolean checkbox.
- `Radio`: allocation-free radio option.
- `Button`: allocation-free action button.
- `List`: allocation-free vertical list with local focus state.
- `SelectableList`: allocation-free vertical list with local focus and selection state.
- `MultiSelectList`: allocation-free vertical list with local focus and multi-selection state.
- `Menu`: allocation-free vertical command menu with local focus state.
- `Tabs`: allocation-free one-line tab strip with local focus and active tab state.
- `Breadcrumbs`: allocation-free display-only navigation trail.
- `Box`: allocation-free display-only borderless container helper.
- `Panel`: allocation-free display-only bordered container chrome.
- `Modal`: allocation-free display-only modal overlay chrome.
- `Table`: allocation-free display-only fixed-width table with optional grid chrome.
- `Tree`: allocation-free display-only visible node outline.
- `Accordion`: allocation-free display-only section header stack.
- `Spinner`: allocation-free frame-based spinner.
- `ProgressBar`: allocation-free horizontal progress bar.
- `Gauge`: allocation-free compact metric gauge.
- `Toast`: allocation-free display-only toast notification chrome.
- `Rating`: allocation-free display-only rating indicator.
- `Badge`: allocation-free compact marker/text badge.
- `Alert`: allocation-free display-only alert.
- `Divider`: allocation-free horizontal or vertical divider.
- `Label`: allocation-free single-line text label.
- `Paragraph`: allocation-free multi-line text paragraph.
- `StatusLine`: allocation-free one-line status component.
- `Help`: allocation-free one-line shortcut help component.

## Helpers

- `FocusList`: fixed-length list focus state for app-owned event routing.
- `layout`: small rectangle helpers for inset, edge bands, centering, equal bands, split, alignment, stack, and row calculations.

## Component Pattern

Interactive components follow the same flow as Chasen apps:

```text
app handleEvent -> component handleEvent -> app Msg -> app update -> component update
```

Display-only components have a smaller shape:

```text
app view -> component view
```

Applications own policy. Interactive components may translate events into
component messages and update their own local state when asked. Display-only
components draw borrowed or app-owned values in `view`.

Applications also own layout. Create a clipped region with
`Surface.child(Rect)` and pass that child surface to the component. Component
`ViewOptions` describe how to draw inside the provided surface; they do not
carry placement fields such as `col`, `row`, `width`, or `height`.

Borrowed labels, placeholders, frame lists, and other borrowed values must
outlive the component.

## Examples

Component-specific usage lives under `examples/<name>/main.zig`.

Run an example from this package:

```sh
zig build run-text_input
```

Use the example directory name after `run-`, for example
`zig build run-table`, `zig build run-tree`, or `zig build run-settings`.

Build all examples, or list all available build steps:

```sh
zig build check-examples
zig build --help
```

## Development

Source files are grouped by component role:

```text
src/input
src/navigation
src/display
src/structure
```

`src/root.zig` re-exports the public API, so callers can continue to use
top-level names such as `ui.TextInput`, `ui.Panel`, and `ui.Table`.

Run tests and build one example:

```sh
zig build test
zig build check-text_input
```

Individual example build steps use the same name as run steps with
`check-<name>`.

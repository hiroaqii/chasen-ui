# chasen-ui

Small component package for [Chasen](https://github.com/hiroaqii/chasen)
terminal applications.

The Zig module name is `chasen_ui`.

## Components

### Input

- `TextInput`
- `TextArea`
- `PasswordInput`
- `NumberInput`
- `Select`
- `Checkbox`
- `Radio`
- `Button`
- `FormField`

### Navigation

- `List`
- `SelectableList`
- `MultiSelectList`
- `Menu`
- `Tabs`
- `Breadcrumbs`

### Structure

- `Box`
- `Panel`
- `Modal`
- `Table`
- `Tree`
- `Accordion`

### Display

- `Spinner`
- `ProgressBar`
- `Gauge`
- `Toast`
- `Rating`
- `Badge`
- `Alert`
- `Divider`
- `Label`
- `Paragraph`
- `StatusLine`
- `Help`

## Helpers

- `FocusList`: fixed-length list focus state for app-owned event routing.
- `layout`: small rectangle helpers for inset, edge bands, centering, equal bands, fixed grids, split, alignment, stack, and row calculations.

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

# chasen-ui

Small component package for [Chasen](https://github.com/hiroaqii/chasen)
terminal applications.

The Zig module name is `chasen_ui`.

## Components

- `TextInput`: owned UTF-8 single-line text input.
- `Select`: allocation-free one-line option picker.
- `Checkbox`: allocation-free boolean checkbox.
- `Radio`: allocation-free radio option.
- `Button`: allocation-free action button.
- `List`: allocation-free vertical list with local focus state.
- `Spinner`: allocation-free frame-based spinner.
- `ProgressBar`: allocation-free horizontal progress bar.
- `Rating`: allocation-free display-only rating indicator.
- `Badge`: allocation-free compact marker/text badge.
- `Divider`: allocation-free horizontal or vertical divider.
- `Label`: allocation-free single-line text label.
- `Paragraph`: allocation-free multi-line text paragraph.
- `StatusLine`: allocation-free one-line status component.

## Helpers

- `FocusList`: fixed-length list focus state for app-owned event routing.

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

Borrowed labels, placeholders, frame lists, and other borrowed values must
outlive the component.

## Examples

Component-specific usage lives in examples:

- `examples/text_input/main.zig`
- `examples/select/main.zig`
- `examples/checkbox/main.zig`
- `examples/radio/main.zig`
- `examples/button/main.zig`
- `examples/list/main.zig`
- `examples/spinner/main.zig`
- `examples/progress_bar/main.zig`
- `examples/animated_feedback/main.zig`
- `examples/rating/main.zig`
- `examples/badge/main.zig`
- `examples/divider/main.zig`
- `examples/label/main.zig`
- `examples/paragraph/main.zig`
- `examples/status_line/main.zig`
- `examples/settings/main.zig`

Run examples from this repository:

```sh
zig build run-text_input
zig build run-select
zig build run-checkbox
zig build run-radio
zig build run-button
zig build run-list
zig build run-spinner
zig build run-progress_bar
zig build run-animated_feedback
zig build run-rating
zig build run-badge
zig build run-divider
zig build run-label
zig build run-paragraph
zig build run-status_line
zig build run-settings
```

Build all examples:

```sh
zig build check-examples
```

## Development

Run tests:

```sh
zig build test
```

Build individual examples:

```sh
zig build check-text_input
zig build check-select
zig build check-checkbox
zig build check-radio
zig build check-button
zig build check-list
zig build check-spinner
zig build check-progress_bar
zig build check-animated_feedback
zig build check-rating
zig build check-badge
zig build check-divider
zig build check-label
zig build check-paragraph
zig build check-status_line
zig build check-settings
```

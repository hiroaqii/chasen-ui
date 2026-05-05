# chasen-ui

Small component package for [Chasen](https://github.com/hiroaqii/chasen)
terminal applications.

The Zig module name is `chasen_ui`.

## Components

- `TextInput`: owned UTF-8 single-line text input.
- `Checkbox`: allocation-free boolean checkbox.
- `Radio`: allocation-free radio option.

## Helpers

- `FocusList`: fixed-length list focus state for app-owned event routing.

## Component Pattern

Components follow the same flow as Chasen apps:

```text
app handleEvent -> component handleEvent -> app Msg -> app update -> component update
```

Applications own policy. Components translate events into component messages,
update their own local state when asked, and draw their current state in `view`.

Borrowed labels and placeholders must outlive the component.

## Examples

Component-specific usage lives in examples:

- `examples/text_input/main.zig`
- `examples/checkbox/main.zig`
- `examples/radio/main.zig`
- `examples/settings/main.zig`

Run examples from this repository:

```sh
zig build run-text_input
zig build run-checkbox
zig build run-radio
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
zig build check-checkbox
zig build check-radio
zig build check-settings
```

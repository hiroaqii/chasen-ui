# Development

## Module and Example Dependencies

The core `chasen_ui` source module imports Chasen only. The optional
`chasen_ui_graphics` adapter adds graphics; the example dependencies below do not
mean the main UI module imports graphics or animation.

| Module or examples | Extra dependencies beyond Chasen/UI |
| --- | --- |
| Standard component examples (including `spinner`) | None |
| `chasen_ui_graphics`, adapter tests | `chasen_graphics` |
| `rating`, `badge`, `alert` examples | `chasen_graphics` for glyph presets |
| `animated_feedback`, `loading_indicators` examples | `chasen_anim` and `chasen_graphics` |

Chasen, chasen-anim, and chasen-graphics are fetched from public Git URLs pinned
by commit and hash in [build.zig.zon](../build.zig.zon). No sibling checkouts or
private repository tokens are required. Update the URL revision and hash together
when changing a dependency.

The current pins correspond to Chasen v0.1.2, chasen-anim v0.1.0, and
chasen-graphics v0.1.1.
The package build requests both lazy dependencies even for core-only builds;
their optional status describes the source modules, not an offline build mode.

## Build and Test

Run from the `chasen-ui` checkout:

```sh
zig build test
zig build check-examples
```

`test` runs core module, terminal-serialization, loading-adapter, and gallery
tests. `check-examples` compiles all 40 component and integration examples. These
steps do not launch interactive galleries. `zig build` without a named step does
not substitute for either check.

Focused checks:

```sh
zig build test-terminal-serialization
zig build test-loading-indicator test-loading_indicators
zig build check-panel
zig build run-panel
zig build --help
```

`test-loading-indicator` tests the optional adapter;
`test-loading_indicators` tests the gallery's timing and controls. `check-<name>`
builds an example; `run-<name>` launches it. Interactive examples need a terminal.
Zig fetches the requested lazy dependencies and reruns build configuration before
executing these steps. A dependency download failure fails the build; it does not
silently skip the adapter or integration examples.

For drawing assertions without an interactive terminal, use
`chasen.testing.TestSurface`; see the component
source tests and [Chasen's component authoring guide](https://github.com/hiroaqii/chasen/blob/v0.1.2/docs/AUTHORING_COMPONENTS.md).

## Continuous Integration

The [CI workflow](https://github.com/hiroaqii/chasen-ui/blob/main/.github/workflows/ci.yml) runs on pushes, pull requests,
and manual dispatch. It uses Ubuntu, macOS, and Zig 0.16.0 to run `zig build test` and
`zig build check-examples`, including the graphics adapter and integration
examples. Zig resolves the dependencies from `build.zig.zon`; the workflow
only checks out chasen-ui. Fork pull requests can run the same checks without
a dependency access secret.

## Source Map

| Path | Purpose |
| --- | --- |
| `src/root.zig` | Main `chasen_ui` public exports |
| `src/graphics.zig` | Optional `chasen_ui_graphics` exports |
| `src/input` | Input components |
| `src/navigation` | Focus, selection, lists, scrolling |
| `src/display` | Display components and loading adapter |
| `src/structure` | Panels, overlays, tables, trees |
| `src/layout.zig` | Rectangle geometry helpers |
| `src/text` | Byte/cell projection and presentation |
| `src/viewport.zig` | Collection range/offset helper |
| `examples` | Runnable component and integration examples |
| `test` | Terminal-serialization checks |

The package's `.paths` includes examples, tests, and these guides. See the
[README](../README.md)
for basic usage and [Components](COMPONENTS.md) for the public catalog.

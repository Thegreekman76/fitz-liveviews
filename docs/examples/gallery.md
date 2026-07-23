# Component gallery

An interactive **gallery of the Companion UI components**, each rendered in
isolation on one live page — **no database, no auth**, just in-memory
per-connection state in the `@ws` loop.

Where the [Admin ABM](admin.md) shows the components working together in a real
app over Postgres, the gallery shows each one **on its own** so you can lift the
pattern straight into your project. It's the runnable companion to the
[UI components catalog](../ui-components.md) and the seed for a future
playground.

Source: [`examples/gallery/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/gallery)

## Run

```powershell
cd examples/gallery
fitz run
```

Open http://127.0.0.1:3000/. Or build a native binary — both serve the same
page bit-for-bit:

```powershell
fitz build
./target/release/gallery-example
```

## What's in it

Three tabs, each a group of cards. Every interactive control is wired over the
WebSocket with `data-flv-*` attributes — no custom JS.

| Tab           | Components                                                        |
|---------------|------------------------------------------------------------------|
| **Controles** | Button + reactive counter, Badge, Chip, Tooltip (CSS), Rating (★), ProgressBar, Spinner, Divider |
| **Feedback**  | Modal / ConfirmDialog, Toast, ExpansionPanel (native `<details>`), Stepper |
| **Formulario**| Text input, Select, Radio group, Checkbox group, Textarea, submit → echo |

Each control demonstrates one of the three wiring patterns:

- **`data-flv-click="event"`** — a button click sends `event` over the socket
  (counter, tabs, modal, toast, stepper).
- **`data-flv-submit="event"`** on a `<form>` — the submit serializes every
  named input (checkbox groups included) into the event payload.
- **CSS-only** — Tooltip, ExpansionPanel and Spinner need no server round-trip;
  they're pure markup + CSS.

## How it fits together

The whole gallery is one file, `src/main.fitz`:

- **helpers** (`badge`, `chip`, `progress_bar`, `rating_input`) return HTML
  fragments as `Str`;
- **panels** (`panel_controls`, `panel_feedback`, `panel_form`) compose the
  helpers into cards;
- **`render_gallery(...)`** builds the full page from the current state;
- **`@ws("/live/gallery")`** keeps state in local variables, applies each event,
  re-renders, and ships the diff with `diff_html`.

No component here uses a database or a LiveComponent (`.fitzv`) — it's the
smallest possible surface to see the visual components and their events.

## The `@ws` loop

The state lives entirely in the socket handler — one set of locals per
connection, mutated per event, re-rendered, diffed:

```fitz
--8<-- "gallery/src/main.fitz:233:305"
```

## Next

This gallery is the seed for a **playground** (edit-and-preview) and the
per-component runnable examples of the Companion UI adoption package. See the
[UI components catalog](../ui-components.md) for every component and the
[Admin ABM](admin.md) for the same components in a production-shaped app.

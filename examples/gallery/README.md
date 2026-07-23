# Component gallery

An interactive **gallery of the Companion UI components**, each rendered in
isolation on a single live page — **no database, no auth**, just in-memory
per-connection state in the `@ws` loop. It's the runnable companion to
[`docs/ui-components.md`](../../docs/ui-components.md) and the seed for the
future playground.

Where the [Admin ABM](../admin) shows the components working together in a
real app over Postgres, the gallery shows each one **on its own** so you can
copy the pattern into your project.

---

## Run it

### `fitz run` (interpreter)

```bash
fitz run
```

Open **http://127.0.0.1:3000/**.

### `fitz build` (native binary)

```bash
fitz build
./target/release/gallery-example        # gallery-example.exe on Windows
```

Both serve **bit-for-bit the same page** — the gallery is a parity smoke for
`fitz run` ↔ `fitz build` with a `.fitzv`-free live page.

---

## What's in it

Three tabs, each a group of cards. Every interactive control is wired over the
WebSocket with the `data-flv-*` attributes — no custom JS.

| Tab           | Components                                                        |
|---------------|------------------------------------------------------------------|
| **Controles** | Button + reactive counter, Badge, Chip, Tooltip (CSS), Rating (★), ProgressBar, Spinner, Divider |
| **Feedback**  | Modal / ConfirmDialog, Toast, ExpansionPanel (native `<details>`), Stepper |
| **Formulario**| Text input, Select, Radio group, Checkbox group, Textarea, submit → echo |

Each control demonstrates one of the three wiring patterns:

- **`data-flv-click="event"`** — a button click sends `event` over the socket
  (counter, tabs, modal open/confirm, toast, stepper next/prev).
- **`data-flv-submit="event"`** on a `<form>` — the submit serializes every
  named input (including checkbox groups) into the event payload.
- **CSS-only** — Tooltip, ExpansionPanel and Spinner need no server round-trip
  at all; they're here to show the components that are pure markup + CSS.

---

## How it fits together

```
examples/gallery/
├── fitz.toml          package + path dependency on ../.. (fitz_liveviews)
└── src/
    └── main.fitz      helpers per component, three tab panels, the @ws loop
```

The whole thing is one file:

- **helpers** (`badge`, `chip`, `progress_bar`, `rating_input`) return HTML
  fragments as `Str`;
- **panels** (`panel_controls`, `panel_feedback`, `panel_form`) compose the
  helpers into cards;
- **`render_gallery(...)`** builds the full page from the current state;
- **`@ws("/live/gallery")`** keeps the state in local variables, applies each
  event, re-renders, and ships the diff with `diff_html`.

No component here uses a database or a LiveComponent (`.fitzv`) — it's the
smallest possible surface to see the visual components and their events.

---

## Next

This gallery is the seed for a **playground** (edit-and-preview) and the
per-component runnable examples of the Companion UI adoption package. See
[`docs/ui-components.md`](../../docs/ui-components.md) for the full catalog and
the [Admin ABM](../admin) for the same components in a production-shaped app.

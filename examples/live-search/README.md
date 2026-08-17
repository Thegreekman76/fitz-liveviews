# Live search — debounced input (Phase 3c)

A LiveView that filters a list **as you type**, showcasing the Phase 3c live-input
wiring:

- **`@input="on_search"`** → lowers to `data-flv-input`, firing on every keystroke
  and carrying the field value under `payload["value"]`.
- **`data-flv-debounce="300"`** → coalesces the keystroke burst with a per-element
  timer, so the socket sees **one** filtered re-render ~300 ms after you stop
  typing (not one per key).

Filtering runs server-side (`{#if it.contains(query)}` in the template); the diff
engine patches only the `<ul>` that changed.

## Run

```
fitz run
```

Open <http://127.0.0.1:3000/> and type a fruit name (lowercase). The list narrows
after you pause — open the Network tab and watch: three fast keystrokes send a
single WebSocket frame.

## The live-input attributes

| Attribute | Fires on | Payload | Notes |
| --- | --- | --- | --- |
| `@input` (`data-flv-input`) | every keystroke | `value` (post-key) | use for as-you-type / live search |
| `@keydown` (`data-flv-keydown`) | keydown | `value` (pre-key) + `key` | use for key actions; pair with `data-flv-keyfilter="Enter"` |
| `data-flv-debounce="N"` | — | — | ms; delays the send. Absent or `0` = immediate |
| `data-flv-keyfilter="Enter,Escape"` | — | — | only fire `keydown` on the listed `event.key`s |

**`@input` vs `@keydown`:** on `keydown` the field value is *pre-key* (the char
isn't in `.value` yet), so use `@input` when you need the typed value and
`@keydown` (+ `data-flv-keyfilter`) for key-driven actions like submit-on-Enter.

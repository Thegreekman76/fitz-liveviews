# C2 — Events, payloads & forms

**Prerequisite:** [C1](c1-first-live-component.md) — you can build and run a live
component and you know the four parts (state, render, `@get`, `@ws`).

**Objective:** make events carry *data*. By the end you'll have a live name
list: add with a form, remove a specific row, and filter as you type — all with
zero JavaScript.

**Why it matters:** the counter's events were bare (`"increment"` with no data).
Real UIs need three things the counter didn't have: a **form** to submit, a way
for a **specific element** to say "this event is about *me*", and **live input**
that reacts as you type. Those are three `data-flv-*` attributes, and they're
all you need for the vast majority of interactions.

---

## The three mechanisms

Everything an event carries ends up in `frame.payload` — a `Map<Str, Str>` your
`@ws` handler reads. There are three ways to fill it:

### 1. `data-flv-value-*` — a click that carries data

Add `data-flv-value-<key>="<val>"` next to a `data-flv-click` and the click's
payload gets `payload[key] = val`. This is how one button in a list says which
row it belongs to:

```fitz
<button data-flv-click="remove" data-flv-value-item="{flv(name)}">x</button>
```

Clicking it sends `{"event": "remove", "payload": {"item": "<name>"}}`. The
handler reads `payload["item"]` to know *which* name to remove. You can add as
many `data-flv-value-*` attributes as you need.

### 2. `data-flv-submit` — a form, serialized

Put `data-flv-submit="<event>"` on a `<form>`. On submit, the client cancels the
normal page reload and serializes **every named field** into the payload, keyed
by each input's `name`:

```fitz
<form data-flv-submit="add">
  <input name="item" data-flv-clear autocomplete="off" />
  <button type="submit">Add</button>
</form>
```

Submitting sends `{"event": "add", "payload": {"item": "<typed value>"}}`. The
handler reads `payload["item"]`. The extra `data-flv-clear` tells the client to
empty that input after a successful submit — so the box is ready for the next
name without you touching it.

(Checkbox groups sharing a `name` arrive comma-joined; radios send the checked
value. You get the whole selection as one string — more on that when we build
richer forms.)

### 3. `data-flv-change` — live input

Put `data-flv-change="<event>"` on an input or select and it fires on every
change (each keystroke for a text input), with the current value in
`payload["value"]`:

```fitz
<input name="q" data-flv-change="filter" value="{flv(filter)}" />
```

Typing sends `{"event": "filter", "payload": {"value": "<current text>"}}` on
each change. The handler updates its filter and re-renders — instant, no submit
button, no `fetch`.

---

## The whole program — string-helper form

Here's the live name list using all three mechanisms, in the string-helper
style from C1. It's a complete, runnable program — the
[`examples/course/c2-name-list`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/course/c2-name-list)
project:

```fitz
--8<-- "course/c2-name-list/src/main.fitz"
```

Run it (`cd examples/course/c2-name-list && fitz run`, or copy it into your own
project) and open http://127.0.0.1:3000/. Add names, filter, remove a row.

## The same program — SFC form

As C1's "when to use each" table noted, anything stateful reads better as a
single-file component. Here's the exact same name list as an SFC — the
[`examples/course/c2-name-list-sfc`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/course/c2-name-list-sfc)
project. The component:

```fitz
--8<-- "course/c2-name-list-sfc/src/NoteList.fitzv"
```

Look at what disappeared: no `html("""...""")`, no `flv(...)`, no `h_join`, no
`.raw`. The three event mechanisms are *identical* — `data-flv-submit="add"`,
`data-flv-value-item="{it}"`, `data-flv-change="set_filter"` all work the same —
but the markup is real `<template>` with `{#for}` and auto-escaped `{it}`, and
each `event` handler reads `payload` directly instead of matching `frame.event`.

The component still needs a small `main.fitz` to mount it:

```fitz
--8<-- "course/c2-name-list-sfc/src/main.fitz"
```

That `@ws` loop is generic — `dispatch_component_events(frame)` routes `add`,
`remove`, and `set_filter` without you writing a single `if`. The one rough
edge is the `from NoteList import ...` line, which lists each event handler by
its generated name.

!!! note "Comparison operators in `.fitzv` (v0.28.2)"
    The `remove` handler uses `it != target` and the filter uses `filter == ""`.
    Comparison operators (`==`, `!=`, `<=`, `>=`) inside `.fitzv` event bodies
    and templates need **Fitz ≥ v0.28.2** — earlier builds only round-tripped
    `==` sometimes and rejected `!=` outright. If you hit a parse error on a
    comparison, update `fitz`.

---

## Reading it (string-helper form)

A few things worth calling out:

**`flv(...)` on everything user-typed.** The names come from user input, so
every time one is rendered — in the `<li>`, in the remove button's
`data-flv-value-item`, in the filter's `value` — it goes through `flv(...)`,
which HTML-escapes it. This is your XSS defense: a name like `<script>` renders
as text, not markup. Interpolating a plain `Int` (like the counts) is safe
without `flv`; anything a user can type is not.

**The handler is a reducer.** Same shape as C1: `items` and `filter` are locals
(one copy per connection), the `loop` waits on `ws.recv()`, and each `if` block
applies one event:

- `"add"` → `items.push(name)` when the field isn't empty.
- `"remove"` → `items.filter(fn(it) => it != target)` — keep everything except
  the clicked name.
- `"filter"` → store the new filter string; `render` does the actual filtering.

**`render` is still pure.** It takes `items` and `filter`, computes `shown`
(the filtered list), builds the rows with `.map`, joins them with `h_join`
(which takes a `List<Html>` and returns one `Str`), and returns the page. No
event logic leaks into it.

**`get_or` — reading the payload safely.** `payload.get(key)` returns a
`Result` (the key might be missing), so the little `get_or` helper `match`es it
to a default. That's the idiomatic way to pull a value out of a `Map`.

**First paint matches the socket.** Both `@get` and `@ws` seed from the same
`seed()` function, so the page renders the three starting names immediately —
before the socket even connects. Keep your initial `@get` render and your `@ws`
starting state in sync, or the list will "pop" when the socket takes over.

---

## Checkpoint

You should be able to:

- [x] Add a name with the form and see it appear (and the input clear itself).
- [x] Remove a specific row — the right one, because the button carried its
      value.
- [x] Type in the filter and watch the list narrow live, with the counts
      updating.
- [x] Explain where each piece of `frame.payload` came from
      (`data-flv-submit` / `data-flv-value-*` / `data-flv-change`).

---

## Troubleshooting

!!! failure "The form reloads the page instead of adding"
    The `<form>` is missing `data-flv-submit`, or its value doesn't match the
    event name in the handler. The attribute is what cancels the browser's
    default submit.

!!! failure "Remove deletes the wrong row (or nothing)"
    The button needs `data-flv-value-item="{flv(name)}"` and the handler must
    read the **same key** (`payload["item"]`). Key names are your contract — a
    typo on either side breaks it silently.

!!! failure "`flv` / `h_join` unknown variable"
    Add them to the import: `from fitz_liveviews import ..., flv, h_join, ...`.
    `h_join` takes exactly one argument, a `List<Html>` — not a `List<Str>` and
    not a separator. Build your rows as `Html` (don't call `.raw` on them) and
    pass the list straight in.

!!! failure "The list is empty until I interact"
    Your `@get` render and `@ws` starting state disagree. Seed both from the
    same function (here, `seed()`).

---

## What's next

You can now wire any interaction: clicks with data, forms, live input. **[C3 —
Composing UI](c3-composing-ui.md)** is about *scale*: pulling repeated markup into render helpers,
reaching for the [component catalog](../ui-components.md) instead of hand-writing
every control, and adding scoped styles. The [component gallery](../examples/gallery.md)
is the reference — every control there is one of these three mechanisms with
nicer CSS.

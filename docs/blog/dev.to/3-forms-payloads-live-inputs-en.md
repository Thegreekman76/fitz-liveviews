---
title: "Forms, payloads, and live inputs in Fitz LiveViews"
published: false
description: How events carry data in Fitz LiveViews — click payloads, form submits, and live @input / @change value binding — with a name list you can add to, remove from, and count, live.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — Events in [Fitz LiveViews](https://github.com/Thegreekman76/fitz-liveviews) carry data three ways: a **click payload** (`data-flv-value-*`) tags a button with the value it should send; a **form submit** (`data-flv-submit`) reads the form's named inputs; and a **live value** (`@input` / `@change`) delivers a control's current value in `payload["value"]`. All three land in the same place — a `payload` map your handler reads. This post builds a live name list (add / remove / count) that runs both server-rendered and as WebAssembly. *(Part 3 of the FitzLiveViews series.)*

Parts [1](https://dev.to/) and [2](https://dev.to/) covered the pitch and the counter. A counter only reads `+1`/`-1` — no data flows *in*. Real UIs take input: text, selections, form fields. Here's how that data reaches your handlers.

## The `payload`

Every event handler has a `payload` in scope — a `Map<Str, Str>`. The three mechanisms below all fill it; your handler reads it with `payload["key"]` (guard with `payload.has("key")`):

### 1. Click payload — a button that carries a value

Tag any element with `data-flv-value-<key>="{expr}"`, and when a `data-flv-click` on it (or an ancestor) fires, that value rides along:

```
<button data-flv-click="remove" data-flv-value-item="{it}">×</button>
```

```
event remove() {
  if (payload.has("item")) {
    let target = payload["item"]
    names = names.filter(fn(it) => it != target)
  }
}
```

The delete button *knows which row it is* because the row's value is stamped on it. No IDs threaded through a callback, no closure capture.

### 2. Form submit — the whole form at once

`data-flv-submit="handler"` on a `<form>` reads each named input into the payload on submit; `data-flv-clear` resets a field afterward:

```
<form data-flv-submit="add">
  <input name="item" placeholder="Add a name" data-flv-clear />
  <button type="submit">Add</button>
</form>
```

```
event add() {
  if (payload.has("item")) {
    let n = payload["item"]
    if (n != "") { names.push(n) }
  }
}
```

`payload["item"]` is the input's value at submit time. No `preventDefault`, no `FormData`, no `fetch`.

### 3. Live value — `@input` / `@change`

For a control that reports as you type or on selection, `@input` (every keystroke) and `@change` (on blur/selection) deliver the current value in `payload["value"]`:

```
<input @input="on_name" value="{name}" />
<select @change="on_color"> … </select>
```

```
event on_name() { name = payload["value"] }
```

The same `payload["value"]` covers `<input>`, `<select>`, and `<textarea>`. On the server-rendered target this is the classic `data-flv-change` attribute; on the client-WASM target it's the `@input` / `@change` decorator — same payload, same handler, so one `.fitzv` serves both.

## Putting it together — a live name list

```
component NameList {
  state {
    names: List<Str> = ["Ada", "Grace", "Margaret"]
  }

  event add() {
    if (payload.has("item")) {
      let n = payload["item"]
      if (n != "") { names.push(n) }
    }
  }

  event remove() {
    if (payload.has("item")) {
      let target = payload["item"]
      names = names.filter(fn(it) => it != target)
    }
  }

  <template>
    <div class="names">
      <form data-flv-submit="add">
        <input name="item" placeholder="Add a name" data-flv-clear />
        <button type="submit">Add</button>
      </form>
      <ul>
        {#for it in names}
          <li>{it} <button data-flv-click="remove" data-flv-value-item="{it}">×</button></li>
        {/for}
      </ul>
      <p>{names.len()} total</p>
    </div>
  </template>
}
```

`{#for it in names}` iterates; `{it}` interpolates each item; the remove button stamps its own value. Add a name, remove a row, watch the count — no client code, no API.

**It's running** in the [live gallery](https://thegreekman76.github.io/fitz-liveviews/live/embed/?c=namelist) as a client-WASM build: the add/remove/count all run in your browser, offline.

## Two honest caveats

- **String methods on WASM.** A case-insensitive filter (`names.filter(fn(x) => x.lower().contains(q))`) works on the server-rendered target but not (yet) on client-WASM — the wasm envelope doesn't have `.lower()` / `.contains()` yet. So the WASM name list above has add/remove/count; a live *filter* stays server-side for now. (The envelope grows release by release; this is on the list.)
- **Live text inputs re-mount.** The current rendering model is dirty-flag + naive re-render: a state change rebuilds the component's DOM. For a `<select> @change` that's invisible; for a live text `<input> @input`, the field re-mounts each keystroke — the value re-binds via `value="{name}"`, but the caret jumps to the end. Fine-grained reactivity (patch in place) is the next rendering-model step. The value always reaches the handler reliably; that's what `@input` guarantees today.

## What's next in this series

- **#4+ — Building the flagship.** A complete admin panel in Fitz + Fitz LiveViews: cookie-based auth (Argon2id + JWT), live DataGrids querying Postgres over WebSockets, the packaged UI library, i18n, and a one-command Docker setup.

If typed events without a client framework sound good, star the [repo](https://github.com/Thegreekman76/fitz-liveviews). Next: a real app.

# Learn Fitz LiveViews

A hands-on course that takes you from zero to a real, deployable app — one
live component at a time. Where the [Guide](../live.md) is the reference and
the [examples](../examples/counter.md) are finished apps to read, the course is
the **guided path**: each chapter builds on the last, every step runs, and you
end with something you understand top to bottom.

It's the companion to the [Fitz language course](https://thegreekman76.github.io/fitz/curso/)
— same shape, same pace, focused on the UI layer.

!!! tip "Before you start"
    You need the `fitz` binary (≥ **v0.28.1**) and a browser. The
    [Fitz install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/)
    covers Windows / macOS / Linux plus the VSCode extension. No Node, no
    bundler, no `npm install` — ever.

---

## The path

| # | Chapter | You build | Status |
|---|---------|-----------|--------|
| **C1** | [Your first live component](c1-first-live-component.md) | A real-time counter, from `fitz new` to a running page — every line explained | ✅ |
| **C2** | [Events, payloads & forms](c2-events-payloads-forms.md) | A live name list: add with a form, remove a specific row, filter as you type — the three `data-flv-*` mechanisms | ✅ |
| **C3** | [Composing UI](c3-composing-ui.md) | A team panel from reusable render helpers: a `type`, a reused `stat_card`, a `badge`, scoped styling | ✅ |
| **C4** | [Persistent & multi-user state](c4-persistent-multiuser.md) | A Postgres-backed notes list, `ws.broadcast(...)`, two tabs in sync — and why this one is string-helper only | ✅ |
| **C5** | [LiveComponents](c5-livecomponents.md) | One `Tile` definition, three independent instances — per-instance state, the dashboard/kanban pattern | ✅ |
| **C6** | Ship it | `fitz build` → one binary, Docker, deploy — the Admin ABM as the blueprint | 🚧 |

Each chapter is self-contained and ends with a **checkpoint** (what should work
now) and a **troubleshooting** box for the mistakes people actually hit.

---

## How the course relates to the rest of the docs

- **Guide** ([HTML](../html.md), [LiveViews](../live.md),
  [LiveComponents](../components.md), [UI catalog](../ui-components.md)) — the
  reference. Look things up here.
- **Course** (you are here) — the path. Read it in order.
- **Examples** ([counter](../examples/counter.md), [chat](../examples/chat.md),
  [gallery](../examples/gallery.md), [Admin ABM](../examples/admin.md)) —
  finished apps. Each chapter points to the example that takes its idea further.

---

## What you'll be able to do at the end

- Write a live component from scratch: state, render, events, the `@ws` loop.
- Wire any interaction with the `data-flv-*` conventions — no JavaScript.
- Assemble a screen from the [component catalog](../ui-components.md) and style
  it with scoped CSS.
- Back it with Postgres, keep multiple users in sync, and split reusable parts
  into LiveComponents.
- Ship the whole thing as a single native binary in a container.

Start with **[C1 — Your first live component](c1-first-live-component.md)**.

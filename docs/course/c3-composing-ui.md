# C3 — Composing UI

**Prerequisite:** [C2](c2-events-payloads-forms.md) — you can wire clicks with
data, forms, and live input.

**Objective:** stop hand-writing every element. Build a small screen by
*composing* reusable render helpers, back it with a structured `type`, and give
it scoped styling.

**Why it matters:** C1 and C2 rendered everything inline in one big template.
That doesn't scale — real screens repeat the same card, the same row, the same
badge dozens of times. In Fitz, a "component" is just **a function that returns
`Html`**. Compose those and a screen becomes readable, and each piece is reused
and tested on its own. This is the same idea the [component
catalog](../ui-components.md) is built on.

---

## An `Html` fragment is just a function

There's no special component syntax for this. A render helper is a normal Fitz
function with an `Html` return type:

```fitz
fn badge(active: Bool) -> Html {
  let cls = match active { true => "on", false => "off" }
  let txt = match active { true => "active", false => "inactive" }
  return html("""<span class="badge {cls}">{txt}</span>""")
}
```

Call it wherever you need a badge. Because it's typed, the compiler checks that
you pass a `Bool` and that whatever consumes it gets an `Html`.

### Composing fragments: `.raw` vs `h_join`

Two rules cover every case of putting fragments together:

- **Embed one fragment inside another template** → interpolate its `.raw`:
  ```fitz
  html("""<li>{flv(m.name)} {badge(m.active).raw}</li>""")
  ```
  `html(...)` returns `Html`; `.raw` is its underlying string, dropped into the
  outer template.

- **Join a list of fragments** → `h_join`, which takes a `List<Html>` and
  returns a single `Str`:
  ```fitz
  let rows = members.map(fn(m) => member_row(m))   // List<Html>
  html("""<ul>{h_join(rows)}</ul>""")              // h_join(...) is a Str
  ```
  Note: `h_join` already returns a `Str`, so you interpolate it directly — **no
  `.raw`**. Calling `.raw` on a `Str` is a runtime error. (Rule of thumb: `.raw`
  turns an `Html` into a `Str`; don't apply it to something that's already a
  `Str`.)

---

## Structured state with a `type`

C2's state was a `List<Str>`. Real data has fields, so use a `type`:

```fitz
type Member {
  name: Str
  active: Bool
}
```

Now the compiler checks every `m.name` and `m.active`, and your helpers take a
`Member` instead of loose strings.

---

## The whole screen

Here's a team panel: two stat cards (the `stat_card` helper **reused** with
different props), a member list built from a `member_row` helper, a `badge`
helper, and a scoped `<style>` — the complete
[`examples/course/c3-team-panel`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/course/c3-team-panel)
project:

```fitz
--8<-- "course/c3-team-panel/src/main.fitz"
```

Run it (`cd examples/course/c3-team-panel && fitz run`) and click **toggle** on
any row — the badge flips and the "Active" stat card updates, because both are
computed from the same `members` list on every render.

---

## Reading it

**Reuse is just calling the function twice.** The two stat cards are one helper:

```fitz
let cards = h_join([
  stat_card("Members", members.len()),
  stat_card("Active", count_active(members)),
])
```

Same function, different props, composed with `h_join`. Add a third card and
it's one more line — no copy-paste.

**Derived values live in helpers, not state.** `count_active(members)` is
computed from the list every render; it isn't stored. The list is the single
source of truth, and everything on screen is a function of it. That's the whole
reactive model — change the list, re-render, diff, done.

**Scoped styling.** The `<style>` block lives inside the `#app` root and its
rules are prefixed (`#app`, `.card`, `.badge.on`). One caveat: because Fitz's
`"""..."""` strings use `{ }` for interpolation, **CSS braces must be escaped**
as `\{` and `\}`:

```fitz
.card \{ border: 1px solid #ddd; border-radius: .5rem; \}
```

Miss that and you'll get an "invalid format spec" error at compile time. (This
is only for CSS/JS braces inside a template; your `{value}` interpolations stay
as-is. True per-component scoped styles — where the framework prefixes selectors
for you — come with LiveComponents in C5.)

**The event carries the row's identity.** The toggle button uses
`data-flv-value-name="{flv(m.name)}"` (the C2 pattern), and `flip_if` rebuilds
the list, flipping only the matching member:

```fitz
members = members.map(fn(m) => flip_if(m, target))
```

`.map` returns a new list; the handler reassigns `members`. No mutation of the
element in place — build the new state and re-render.

---

## Where components come from next

You just built badge / card / row "components" as functions. The [component
catalog](../ui-components.md) is a whole cookbook of these — DataGrid, tabs,
modal, toasts, tree, cascade selects — each a render helper (or a small set)
you can lift into your screen. The [component gallery](../examples/gallery.md)
runs them all in one page. When you need one, copy the pattern; it's the same
`fn ... -> Html` you've been writing.

---

## Checkpoint

You should be able to:

- [x] Write a render helper (`fn ... -> Html`) and call it from another template
      with `.raw`.
- [x] Join a `List<Html>` with `h_join` (and know not to `.raw` the result).
- [x] Reuse one helper with different props (the two stat cards).
- [x] Back a screen with a `type` and derive on-screen values with helpers.
- [x] Add a scoped `<style>` with escaped CSS braces.

---

## Troubleshooting

!!! failure "`invalid format spec` on a `<style>` or `<script>`"
    Raw `{` / `}` in CSS or JS collide with Fitz interpolation. Escape them as
    `\{` and `\}` inside the template string.

!!! failure "`field access .raw on a value of type Str`"
    You called `.raw` on something that's already a `Str` — usually an `h_join`
    result. `h_join` returns `Str`; interpolate it directly. Use `.raw` only to
    turn an `Html` into a string.

!!! failure "The whole page re-renders / flickers on toggle"
    It shouldn't — the diff only moves changed nodes. If it does, your `@get`
    and `@ws` initial renders probably disagree (see C2's checkpoint) so the
    first diff is huge. Seed both from the same function.

---

## What's next

You can compose a screen from typed helpers and style it. So far state has been
in memory and per-connection. **C4 — Persistent & multi-user state** backs the
list with Postgres and uses `ws.broadcast(...)` so two browsers stay in sync —
the step from "a nice demo" to "a real app". The [chat example](../examples/chat.md)
and the [Admin ABM](../examples/admin.md) are where this goes.

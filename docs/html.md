# The `Html` type and templating (Phase 1)

Fitz LiveViews templates are just Fitz functions that return values of a
new opaque type: `Html`. This document walks through the API landed in
Phase 1 and the XSS-safety convention that goes with it.

## Overview

At its core, `Html` is a thin wrapper over `Str` that carries a
type-level signal: **"this string has already been rendered safely and
can go directly into a response"**. The distinction between `Str`
(potentially unsafe) and `Html` (safe) is what makes the escaping
convention work.

The full Phase 1 API is nine names:

| Name                              | Kind         | Purpose                                             |
|-----------------------------------|--------------|-----------------------------------------------------|
| `Html`                            | Type         | Wrapper around a rendered HTML string               |
| `html(raw: Str) -> Html`          | Constructor  | Wrap a raw HTML string                              |
| `raw_html(s: Str) -> Html`        | Constructor  | Explicit "unsafe intent" alias for `html()`         |
| `flv(s: Str) -> Str`              | Escape       | Escape 5 HTML-critical chars in user data           |
| `h_join(items: List<Html>) -> Str`| Composition  | Concatenate a list of fragments                     |
| `h_when(c, h) -> Str`             | Composition  | Render `h` if `c` is true, else empty               |
| `h_either(c, a, b) -> Str`        | Composition  | Ternary render                                      |

## The `Html` type

```fitz
type Html {
  raw: Str
}
```

You rarely touch the `.raw` field directly — the composition helpers
below do it for you. When you do need it (for example, embedding a
pre-built fragment inside another template), it is safe to access.

## Constructing `Html`

Two constructors, both trivial:

```fitz
let greeting = html("<h1>Hello</h1>")     // server-controlled
let unsafe   = raw_html(user_html)        // explicit "trust me"
```

`raw_html()` is an alias for `html()` — it does the exact same thing.
The reason it exists is to make review easier: `raw_html(x)` reads as
**"I know this came from an untrusted source and I am consciously
opting out of escaping"**. Prefer it whenever the trust decision is
worth flagging to future readers.

## The `flv()` escape function

`flv()` is short for **"fitz-liveviews escape"**. It replaces the five
HTML-critical characters with entity references:

```
&  →  &amp;
<  →  &lt;
>  →  &gt;
"  →  &quot;
'  →  &#39;
```

It returns a `Str` (not an `Html`), because you almost always want to
interpolate the result directly into a template:

```fitz
html("<p>Hi {flv(user.name)}</p>")
```

### When to use `flv()`

**Wrap user-controlled data.** That includes anything typed by the
user, pulled from the database, or coming in through a query param /
header:

```fitz
html("<p>Hi {flv(user.name)}</p>")                   // form input
html("<p>Bio: {flv(profile.description)}</p>")       // DB text
html("<p>Query: {flv(request.query)}</p>")           // URL param
```

**Skip it for server-controlled values.** Numbers, booleans, hardcoded
strings, and values you computed yourself have no XSS risk:

```fitz
html("<p>Count: {state.count}</p>")            // Int
html("<p>Version: {VERSION}</p>")              // Str constant
html("<p>Total: ${format_money(sum)}</p>")     // computed by you
```

**When in doubt, wrap it.** `flv()` on server-controlled data is a
no-op (nothing to escape), so overuse costs a tiny bit of CPU and
zero correctness.

### Order of replacement

The implementation replaces `&` first, then the other four characters.
That order is important: if `<` were replaced first, its output `&lt;`
would get double-encoded to `&amp;lt;` when the ampersand pass ran.

## Composition helpers

Every composition helper returns `Str` (not `Html`) so it drops
directly into template interpolation without needing `.raw`.

### `h_join(items: List<Html>) -> Str`

Concatenates a list of fragments in order. This is the workhorse for
rendering lists:

```fitz
type User { name: Str, is_admin: Bool }

fn user_row(u: User) -> Html {
  return html("<li>{flv(u.name)}</li>")
}

fn user_list(users: List<User>) -> Html {
  let rows = users.map(fn(u) => user_row(u))
  return html("<ul>{h_join(rows)}</ul>")
}
```

### `h_when(cond: Bool, h: Html) -> Str`

Renders `h` when `cond` is true, otherwise the empty string. Use it
for conditional bits of a template:

```fitz
html("""
  <li>
    {flv(u.name)}
    {h_when(u.is_admin, html("<span class='badge'>admin</span>"))}
  </li>
""")
```

### `h_either(cond: Bool, if_true: Html, if_false: Html) -> Str`

Ternary render. Useful when the two branches are of similar weight:

```fitz
html("""
  <div>
    {h_either(cart.is_empty(),
              html("<p>Your cart is empty.</p>"),
              html("<a href='/checkout'>Checkout</a>"))}
  </div>
""")
```

## Complete example — a user list with an empty state

Putting it all together:

```fitz
type User { name: Str, is_admin: Bool }

fn user_row(u: User) -> Html {
  return html("""
    <li>
      {flv(u.name)}
      {h_when(u.is_admin, html("<span class='badge'>admin</span>"))}
    </li>
  """)
}

fn user_list(users: List<User>) -> Html {
  let rows = users.map(fn(u) => user_row(u))
  return html("""
    <div>
      <h1>Users ({users.len()})</h1>
      <ul>
        {h_join(rows)}
      </ul>
      {h_when(users.is_empty(), html("<p>No users yet.</p>"))}
    </div>
  """)
}
```

Rendered output (with three users, one admin) is:

```html
<div>
  <h1>Users (3)</h1>
  <ul>
    <li>Alice<span class='badge'>admin</span></li>
    <li>Bob &lt;script&gt;</li>
    <li>Carol</li>
  </ul>
</div>
```

Note that Bob's malicious name `Bob <script>` was neutralized by
`flv()` inside `user_row` — the browser will show it as literal text,
not execute anything.

## What is missing (comes later)

- **Template control flow** (`{#for}...{/for}`, `{#if}...{/if}`) —
  landing in Phase 3, once the WebSocket + diff engine is proven.
  Meanwhile the `h_*` composition helpers cover the same ground with
  slightly more boilerplate.
- **Auto-escaping** — for now `flv()` is manual by convention. Phase 6
  ships a lint rule that warns when it sees `{ident: Str}` inside
  `html()` without `flv()` wrapping it.
- **Nested component composition without `.raw`** — while `.raw`
  works, we may add a smarter interpolation path once the diff engine
  requires a tree representation of `Html` (Phase 2).

## Verifying it works

The primitives ship with `@test` functions covered by `fitz test`:

```
fitz test
```

You should see fifteen tests pass in a fresh clone.

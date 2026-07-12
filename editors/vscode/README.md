# Fitz LiveViews for VSCode

HTML syntax highlighting and snippets for
[Fitz LiveViews](https://github.com/Thegreekman76/fitz-liveviews) templates.
Depends on the base
[Fitz Language extension](https://github.com/Thegreekman76/fitz).

## What it does

**HTML highlighting inside `html("""...""")` templates.**

Every triple-quoted string in a Fitz file is treated as HTML: tag
names, attribute names, entities, and comments all get their proper
scopes. Fitz's native `{expr}` interpolation keeps working.

Fitz LiveViews directives (`data-flv-click`, `data-flv-submit`,
`data-flv-input`, `data-flv-change`, `data-flv-keydown`,
`data-flv-clear`, `data-flv-value-*`, `data-flv-ws`, `data-flv-root`)
get a distinct highlight so they stand out from plain HTML attributes.

**Snippets for common Phase 2 + 3 patterns.**

Type any of these prefixes and hit Tab:

| Prefix       | What it expands to                                       |
|--------------|----------------------------------------------------------|
| `liveview`   | Full Phase 2 scaffold: `type`, `render`, `@get`, `@ws`, `@server` |
| `render`     | A `fn render(state) -> Html` skeleton                     |
| `get`        | `@get(...)` handler returning `Response`                  |
| `ws`         | `@ws(...)` handler with the recv/patch/send cycle         |
| `broadcast`  | `@ws(...)` for shared-state chat-style with `ws.broadcast`|
| `flv`        | `{flv(user_data)}` for XSS-safe interpolation             |
| `hwhen`      | `{h_when(cond, html(...))}`                               |
| `heither`    | `{h_either(cond, if_true, if_false)}`                     |
| `hjoin`      | `{h_join(items.map(fn(x) => render(x)))}`                 |
| `btnclick`   | `<button data-flv-click="event">…</button>`              |
| `flvform`    | `<form data-flv-submit>` with an input and submit button  |

## Requirements

- VSCode 1.85 or later
- The Fitz Language extension
  ([`thegreekman76.fitz-language`](https://marketplace.visualstudio.com/items?itemName=thegreekman76.fitz-language))
  — installed automatically as a dependency

## Not included (yet)

Coming in future phases:

- LSP-level autocomplete inside templates (state field names,
  event handler references)
- Emmet expansion inside `html("""...""")`
- Hover on component functions from inside a template
- Diagnostics for unclosed tags or unknown directives

Track progress in the [Roadmap](https://github.com/Thegreekman76/fitz-liveviews/blob/main/ROADMAP.md).

## License

MIT. See the parent repository.

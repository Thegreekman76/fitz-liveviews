#!/usr/bin/env python3
"""WS smoke for the Admin ABM departamentos ABM.

Usage: python dep_smoke.py <port> <out_file>

Part A (read-only) fires a fixed event sequence and dumps each frame's `html`
for the run<->binario diff (deterministic → identical modulo per-connection cid
+ multi-line literal line-endings). Part B is a self-cleaning CRUD cycle (create
a throwaway department, verify it shows, then delete it) that asserts save/delete
actually persist — it does NOT go into the diffed frames (it mutates the DB, and
cleans up after itself so the DB is left unchanged).
"""
import json, sys, re
import requests
from websocket import create_connection

PORT = sys.argv[1]
OUT = sys.argv[2]
BASE = f"http://127.0.0.1:{PORT}"
WS = f"ws://127.0.0.1:{PORT}/live/departamentos"

# 1) login -> session cookie
r = requests.post(f"{BASE}/login",
                  json={"email": "admin@fitz.dev", "password": "admin1234"},
                  timeout=10)
assert r.status_code == 200, f"login status {r.status_code}: {r.text[:200]}"
cookie = r.headers.get("Set-Cookie", "")
assert "flv_admin_session=" in cookie, f"no session cookie: {cookie!r}"
cookie_val = cookie.split(";")[0]

# 2) SSR first paint — the menu is no longer a placeholder
sess = requests.Session()
sess.headers["Cookie"] = cookie_val
page = sess.get(f"{BASE}/departamentos", timeout=10).text
assert 'id="departamentos-live"' in page, "SSR: departamentos-live root missing"
assert 'construcción' not in page, "SSR: still shows the placeholder"
assert 'data-flv-submit="save_departamento"' in page or 'class="grid"' in page, \
    "SSR: no grid/toolbar rendered"

# 3) WS connect
ws = create_connection(WS, header=[f"Cookie: {cookie_val}"], timeout=15)

def send_recv(event, payload=None):
    ws.send(json.dumps({"event": event, "payload": payload or {},
                        "html": "", "patches": []}))
    return json.loads(ws.recv())["html"]

frames = []
def step(label, event, payload=None):
    html = send_recv(event, payload)
    frames.append((label, html))
    return html

# --- Part A: read-only paridad frames (no DB mutation) ---
step("init", "__flv_init", {})
step("search_ing", "search", {"q": "e"})       # broad term, matches something
step("search_clear", "search", {"q": ""})
step("sort_nombre", "sort", {"col": "nombre"})
step("sort_nombre_desc", "sort", {"col": "nombre"})
step("sort_id", "sort", {"col": "id"})
step("new_departamento", "new_departamento", {})
step("cancel_form", "cancel_form", {})
step("edit_dep_1", "edit_departamento", {"id": "1"})
step("cancel_form2", "cancel_form", {})

# dump Part A frames for the run<->binario diff
with open(OUT, "w", encoding="utf-8") as f:
    for label, html in frames:
        f.write(f"===== {label} =====\n{html}\n")

# --- Part A invariants ---
by = dict(frames)
def has(label, needle):
    assert needle in by[label], f"[{label}] missing: {needle!r}"
def hasnt(label, needle):
    assert needle not in by[label], f"[{label}] should NOT have: {needle!r}"

has("init", 'id="departamentos-live"')
has("init", 'class="grid"')
has("init", 'data-flv-click="new_departamento"')
has("init", 'data-flv-submit="search"')
# search reflected in the input
has("search_ing", 'name="q" value="e"')
has("search_clear", 'name="q" value=""')
# sort arrow on the active column
has("sort_nombre", 'data-flv-value-col="nombre"')
assert '▲' in by["sort_nombre"] or '▼' in by["sort_nombre"], "sort: no arrow"
# new -> form, edit -> form with data, cancel -> back to grid
has("new_departamento", 'data-flv-submit="save_departamento"')
hasnt("new_departamento", 'class="grid-toolbar"')
has("edit_dep_1", 'data-flv-submit="save_departamento"')
has("edit_dep_1", 'name="nombre" value=')
has("cancel_form", 'data-flv-click="new_departamento"')  # back on the grid

# --- Part B: self-cleaning CRUD cycle (asserts real persistence) ---
MARKER = "ZZ_SMOKE_TMP"
# create
h = send_recv("save_departamento", {"id": "0", "nombre": MARKER, "codigo": "ZZS"})
assert MARKER in h, "CRUD: created department not shown in the grid"
assert 'class="grid"' in h, "CRUD: after save should be back on the grid"
# find its id (the edit button on the ZZ row)
seg = h[h.index(MARKER):]
m = re.search(r'data-flv-value-id="(\d+)"', seg)
assert m, "CRUD: could not find the new row's id"
new_id = m.group(1)
# edit it (round-trips through the form) then cancel
he = send_recv("edit_departamento", {"id": new_id})
assert f'value="{MARKER}"' in he, "CRUD: edit form did not prefill the name"
send_recv("cancel_form", {})
# delete it: ask -> dialog opens -> confirm
hd = send_recv("ask_delete_one", {"id": new_id})
# The confirm dialog is now the companion-library component
# (fitz_liveviews.ui.ConfirmDialog). Its `<style scoped>` suffixes the
# class token, so the element renders as
# `class="cd-overlay cd-overlay-confirm-dialog-c-<hash>"` — match the base
# token as a substring. The old vendored copy used a plain `modal-overlay`.
assert 'cd-overlay' in hd, "CRUD: confirm dialog did not open"
hc = send_recv("confirm_delete", {})
assert MARKER not in hc, "CRUD: department still present after delete"

ws.close()
print(f"OK {len(frames)} paridad frames + CRUD cycle (create/edit/delete {MARKER}) -> {OUT}")

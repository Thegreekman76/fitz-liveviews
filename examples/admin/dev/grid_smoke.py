#!/usr/bin/env python3
"""WS smoke for the Admin ABM empleados grid.

Usage: python grid_smoke.py <port> <out_file>

Logs in, opens /live/empleados, fires a fixed event sequence, and writes each
response frame's `html` to <out_file> with per-event markers. Run it against
`fitz run` and against the native binary, then diff the two out_files: identical
=> run<->binario parity. Also asserts a few toolbar/grid invariants inline.
"""
import json, sys, re
import requests
from websocket import create_connection

PORT = sys.argv[1]
OUT = sys.argv[2]
BASE = f"http://127.0.0.1:{PORT}"
WS = f"ws://127.0.0.1:{PORT}/live/empleados"

# 1) login -> session cookie
r = requests.post(f"{BASE}/login",
                  json={"email": "admin@fitz.dev", "password": "admin1234"},
                  timeout=10)
assert r.status_code == 200, f"login status {r.status_code}: {r.text[:200]}"
cookie = r.headers.get("Set-Cookie", "")
assert "flv_admin_session=" in cookie, f"no session cookie: {cookie!r}"
cookie_val = cookie.split(";")[0]

# 2) WS connect with the session cookie
ws = create_connection(WS, header=[f"Cookie: {cookie_val}"], timeout=15)

def send_recv(event, payload=None):
    ws.send(json.dumps({"event": event, "payload": payload or {},
                        "html": "", "patches": []}))
    msg = ws.recv()
    return json.loads(msg)["html"]

# 3) __flv_init -> initial grid frame
frames = []
def step(label, event, payload=None):
    html = send_recv(event, payload)
    frames.append((label, html))
    return html

step("init", "__flv_init", {})
step("search_ada", "search", {"q": "ada"})
step("search_clear", "search", {"q": ""})
step("estado_active", "estado_active", {})
step("estado_inactive", "estado_inactive", {})
step("estado_all", "estado_all", {})
step("filter_depto_1", "filter_depto", {"depto": "1"})
step("filter_depto_all", "filter_depto", {"depto": "0"})
step("group_depto", "group_depto", {})
step("group_estado", "group_estado", {})
step("group_none", "group_none", {})
step("sort_nombre", "sort", {"col": "nombre"})
step("sort_nombre_desc", "sort", {"col": "nombre"})
step("page_next", "page_next", {})
step("goto_page_1", "goto_page", {"page": "1"})
step("show_tree", "show_tree", {})
step("show_grid", "show_grid", {})
step("new_empleado", "new_empleado", {})
step("cancel_form", "cancel_form", {})

ws.close()

# 4) dump frames for the run<->binario diff
with open(OUT, "w", encoding="utf-8") as f:
    for label, html in frames:
        f.write(f"===== {label} =====\n")
        f.write(html)
        f.write("\n")

# 5) inline invariants (fail loud) --------------------------------------------
by = dict(frames)

def has(label, needle):
    assert needle in by[label], f"[{label}] missing: {needle!r}"

# toolbar present in the grid frames
has("init", 'class="grid-toolbar"')
has("init", 'data-flv-submit="search"')
# search value reflected in the input
has("search_ada", 'value="ada"')
has("search_clear", 'name="q" value=""')
# estado pill active state (exactly the clicked one is pill-active)
has("estado_active", 'class="pill pill-active" data-flv-click="estado_active"')
assert 'class="pill pill-active" data-flv-click="estado_all"' not in by["estado_active"], \
    "estado_active: 'all' pill should not be active"
has("estado_all", 'class="pill pill-active" data-flv-click="estado_all"')
# export link carries the active filters
has("estado_active", 'href="/empleados/export.csv?q=&estado=active&depto=0"')
has("filter_depto_1", 'href="/empleados/export.csv?q=&estado=all&depto=1"')
# action buttons fall-through events present
has("init", 'data-flv-click="new_empleado"')
has("init", 'data-flv-click="show_tree"')
# filters bar: depto pills + group bar present
has("init", 'class="grid-filters grid-deptos"')
has("init", 'class="grid-filters grid-group"')
has("init", 'data-flv-click="filter_depto" data-flv-value-depto="0"')
# depto=1 pill active after filtering to depto 1; "Todos" (0) no longer active
has("filter_depto_1", 'class="pill pill-active" data-flv-click="filter_depto" data-flv-value-depto="1"')
assert 'class="pill pill-active" data-flv-click="filter_depto" data-flv-value-depto="0"' not in by["filter_depto_1"], \
    "filter_depto_1: 'Todos' depto pill should not be active"
# group-by pill active state
has("group_depto", 'class="pill pill-active" data-flv-click="group_depto"')
has("group_none", 'class="pill pill-active" data-flv-click="group_none"')
# form screen replaces the grid on new_empleado, toolbar gone
assert 'class="grid-toolbar"' not in by["new_empleado"], "new_empleado: toolbar should be gone"
has("new_empleado", 'data-flv-submit="save_empleado"')
# back to grid on cancel
has("cancel_form", 'class="grid-toolbar"')

print(f"OK {len(frames)} frames, invariants passed -> {OUT}")

#!/usr/bin/env python3
"""WS smoke for the Admin ABM empleados grid + form.

Usage: python grid_smoke.py <port> <out_file>

Logs in, opens /live/empleados, fires a fixed event sequence, and writes each
response frame's `html` to <out_file> with per-event markers. Run it against
`fitz run` and against the native binary, then diff the two out_files. They are
bit-a-bit identical MODULO two expected, cosmetic differences: (1) the
per-connection `instance_id` uuids the Toast/ConfirmDialog carry (a fresh
`Uuid.v4()` per socket), and (2) blank-line / trailing whitespace inside
multi-line string literals (a known run<->binario core artifact — browsers
collapse it). Normalize both away and the grid content matches exactly. The
inline invariants below assert the behavior directly.

Covers the LiveComponents refactor: GridToolbar, GridFilters, EmpleadoRow
(checked/expanded via toggle_sel/toggle_row) and EmpleadoForm (alta stepper,
edición tabs, tab switch, país cascade, invalid-save banner).

NOTE: a *valid* save is deliberately NOT exercised — it INSERTs/UPDATEs the DB,
which would diverge between the two independent runs (different ids / row counts)
and break the bit-a-bit diff. The visual/save happy-path is checked by hand in
the browser (same reason the previous smoke never fired a real delete).
"""
import json, re, sys
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

# --- EmpleadoRow: checked/expanded (initial sort = id asc, page 1 = ids 1-8) ---
step("sel_1_on", "toggle_sel", {"id": "1"})     # fila 1 -> row-selected + checked
step("row_2_open", "toggle_row", {"id": "2"})   # fila 2 -> row-expanded + chevron ▾
step("sel_1_off", "toggle_sel", {"id": "1"})    # clear selection
step("row_2_close", "toggle_row", {"id": "2"})  # clear expansion (back to clean grid)

# --- grid dimensions (GridToolbar + GridFilters) ---
step("search_ada", "search", {"q": "ada"})
step("search_clear", "search", {"q": ""})
step("estado_active", "estado_active", {})
step("estado_inactive", "estado_inactive", {})
step("estado_all", "estado_all", {})
step("filter_depto_1", "filter_depto", {"value": "1"})
step("filter_depto_all", "filter_depto", {"value": "0"})
step("group_depto", "group_depto", {})
step("group_estado", "group_estado", {})
step("group_none", "group_none", {})
step("sort_nombre", "sort", {"col": "nombre"})
step("sort_nombre_desc", "sort", {"col": "nombre"})
step("page_next", "page_next", {})
step("goto_page_1", "goto_page", {"page": "1"})
step("show_tree", "show_tree", {})
step("show_grid", "show_grid", {})

# --- EmpleadoForm: alta (stepper) ---
step("new_empleado", "new_empleado", {})
step("form_tab_org", "form_tab",
     {"tab": "org", "nombre": "Prueba", "email": "p@x.com"})
step("cascade_pais", "cascade_pais",
     {"value": "1", "nombre": "Prueba", "email": "p@x.com"})
step("form_tab_accesos", "form_tab",
     {"tab": "accesos", "nombre": "Prueba", "email": "p@x.com"})
step("save_invalid", "save_empleado", {"id": "0", "nombre": "", "email": ""})
step("cancel_form", "cancel_form", {})

# --- EmpleadoForm: edición (tabs) ---
step("edit_empleado", "edit_empleado", {"id": "1"})
step("edit_tab_accesos", "form_tab", {"tab": "accesos"})
step("cancel_form2", "cancel_form", {})

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

def hasnt(label, needle):
    assert needle not in by[label], f"[{label}] should NOT have: {needle!r}"

# A packaged GridFilters pill is `<button class="flv-pill[ flv-pill-active] …scoped"
# data-flv-click="EVENT" data-flv-value-value="VAL">`. The scope suffixes make an
# exact class match brittle, so key on the pill's (event, value) and inspect its
# class list for `flv-pill-active`.
def pill_active(label, event, val=""):
    html = by[label]
    m = re.search(
        r'<button class="([^"]*)"[^>]*data-flv-click="' + re.escape(event) +
        r'" data-flv-value-value="' + re.escape(val) + r'"', html)
    assert m, f"[{label}] no pill event={event!r} value={val!r}"
    assert "flv-pill-active" in m.group(1), f"[{label}] pill {event}/{val} not active"

def pill_inactive(label, event, val=""):
    html = by[label]
    m = re.search(
        r'<button class="([^"]*)"[^>]*data-flv-click="' + re.escape(event) +
        r'" data-flv-value-value="' + re.escape(val) + r'"', html)
    assert m, f"[{label}] no pill event={event!r} value={val!r}"
    assert "flv-pill-active" not in m.group(1), f"[{label}] pill {event}/{val} should be inactive"

# packaged GridToolbar present in the grid frames (search form + fall-through)
has("init", 'flv-grid-toolbar')
has("init", 'data-flv-submit="search"')
# search value reflected in the input
has("search_ada", 'value="ada"')
has("search_clear", 'name="q" value=""')
# estado pill active state (exactly the clicked one is flv-pill-active)
pill_active("estado_active", "estado_active")
pill_inactive("estado_active", "estado_all")
pill_active("estado_all", "estado_all")
# export link carries the active filters
has("estado_active", 'href="/empleados/export.csv?q=&estado=active&depto=0"')
has("filter_depto_1", 'href="/empleados/export.csv?q=&estado=all&depto=1"')
# action buttons fall-through events present (in the GridToolbar `actions` slot)
has("init", 'data-flv-click="new_empleado"')
has("init", 'data-flv-click="show_tree"')
# packaged GridFilters bars: depto pills + group bar present. The depto pill
# carries the id in `data-flv-value-value` (the loop reads payload["value"]).
has("init", 'flv-grid-filters')
has("init", 'data-flv-click="filter_depto" data-flv-value-value="0"')
has("init", 'data-flv-click="group_none"')
# depto=1 pill active after filtering to depto 1; "Todos" (0) no longer active
pill_active("filter_depto_1", "filter_depto", "1")
pill_inactive("filter_depto_1", "filter_depto", "0")
# group-by pill active state
pill_active("group_depto", "group_depto")
pill_active("group_none", "group_none")

# --- EmpleadoRow (checked / expanded) ---
# id 1 selected -> row-selected class + a checked row checkbox for id 1
has("sel_1_on", 'class="row-selected"')
has("sel_1_on", 'data-flv-click="toggle_sel" data-flv-value-id="1" checked')
# id 2 expanded -> row-expanded class + the ▾ chevron on that row's toggle
has("row_2_open", 'class="row-expanded"')
has("row_2_open", "▾")
# after clearing, no row is selected/expanded anymore
hasnt("row_2_close", 'class="row-selected"')
hasnt("row_2_close", 'class="row-expanded"')

# --- EmpleadoForm ---
# alta uses the guided packaged Stepper; grid toolbar gone; save form present
has("new_empleado", 'flv-stepper')
has("new_empleado", 'data-flv-submit="save_empleado"')
hasnt("new_empleado", 'flv-grid-toolbar')
# all 3 panels stay in the DOM. The cascade país/prov/ciudad are the packaged
# Select in on_change mode; the "reporta a" is the packaged GroupSelect.
has("new_empleado", 'data-flv-change="cascade_pais"')
has("new_empleado", 'data-flv-change="cascade_provincia"')
has("new_empleado", 'data-flv-change="cascade_ciudad"')
has("new_empleado", '<optgroup')                 # GroupSelect (reporta a)
# permisos (packaged MultiSelect) + skills (packaged CheckboxGroup) present
has("new_empleado", 'name="permisos"')
has("new_empleado", '<fieldset')                 # MultiSelect group
has("new_empleado", 'name="skills"')
# rating stars present (packaged Rating)
has("new_empleado", 'name="nivel"')
# invalid save -> validation banner (packaged Alert, danger variant), still on the form
has("save_invalid", 'data-variant="danger"')
has("save_invalid", 'role="alert"')
has("save_invalid", 'data-flv-submit="save_empleado"')
# edición uses the packaged Tabs, NOT the stepper
has("edit_empleado", 'flv-tabs')
hasnt("edit_empleado", 'flv-stepper')
has("edit_empleado", 'data-flv-submit="save_empleado"')
# --- TreeView (locations screen) ---
# the packaged TreeView; branch toggles carry the id in data-flv-value-value
has("show_tree", 'flv-tree')
has("show_tree", 'data-flv-click="toggle_pais" data-flv-value-value=')
# back to grid on cancel (both times)
has("cancel_form", 'flv-grid-toolbar')
has("cancel_form2", 'flv-grid-toolbar')

print(f"OK {len(frames)} frames, invariants passed -> {OUT}")

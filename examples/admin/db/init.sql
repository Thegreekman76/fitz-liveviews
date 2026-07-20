-- Admin ABM showcase — schema + demo seed.
--
-- This is the single source of truth for the database. The Fitz ORM does
-- not auto-create tables from `@table` types yet (that's a core roadmap
-- item), so the schema lives here as plain SQL.
--
-- Docker: docker-compose mounts this file into the postgres container's
-- /docker-entrypoint-initdb.d/, so it runs automatically the first time
-- the database volume is created.
--
-- Local (without Docker): run it once against your Postgres, e.g.
--   psql "postgres://fitz:fitz@localhost:5432/fitz_admin" -f db/init.sql
--
-- The app itself never runs DDL or seeds at boot — it only reads/writes
-- during requests. (Connecting at boot in `fitz run` would bind the
-- connection pool to the interpreter's short-lived boot runtime, which is
-- gone by the time requests arrive.)

-- --- Schema ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS admin_users (
    id              bigserial PRIMARY KEY,
    email           text NOT NULL UNIQUE,
    name            text NOT NULL,
    password_hash   text NOT NULL,
    role            text NOT NULL DEFAULT 'admin',
    created_at      timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS departamentos (
    id      bigserial PRIMARY KEY,
    nombre  text NOT NULL,
    codigo  text NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS empleados (
    id               bigserial PRIMARY KEY,
    nombre           text NOT NULL,
    email            text NOT NULL DEFAULT '',
    cargo            text NOT NULL DEFAULT '',
    departamento_id  bigint NOT NULL DEFAULT 0,
    activo           boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_empleados_depto ON empleados(departamento_id);

-- --- Seed ------------------------------------------------------------------

-- Demo admin. Password: admin1234 (Argon2id hash generated with the Fitz
-- built-in `hash.password("admin1234")`). CHANGE before any real use.
INSERT INTO admin_users (email, name, password_hash, role)
VALUES (
    'admin@fitz.dev',
    'Admin Fitz',
    '$argon2id$v=19$m=19456,t=2,p=1$y4j9UABUgmYG++pHW4/OdQ$Tz42qisfM/bSAqqbRFErTqscU3vy7UM83z0mCzA3Ve8',
    'admin'
)
ON CONFLICT (email) DO NOTHING;

-- Demo departments — inserted only when the table is still empty.
INSERT INTO departamentos (nombre, codigo)
SELECT nombre, codigo FROM (VALUES
    ('Ingeniería',        'ENG'),
    ('Ventas',            'VEN'),
    ('Recursos Humanos',  'RRHH'),
    ('Operaciones',       'OPS')
) AS v(nombre, codigo)
WHERE NOT EXISTS (SELECT 1 FROM departamentos);

-- Demo employees — inserted only when the table is still empty. The
-- departamento_id values reference the department ids assigned above
-- (1..4 on a fresh database).
INSERT INTO empleados (nombre, email, cargo, departamento_id, activo)
SELECT nombre, email, cargo, departamento_id, activo FROM (VALUES
    ('Ada Lovelace',      'ada@fitz.dev',      'Tech Lead',     1, true),
    ('Alan Turing',       'alan@fitz.dev',     'Ingeniero Sr',  1, true),
    ('Grace Hopper',      'grace@fitz.dev',    'Ingeniera',     1, true),
    ('Margaret Hamilton', 'margaret@fitz.dev', 'Ingeniera',     1, true),
    ('Linus Torvalds',    'linus@fitz.dev',    'Ingeniero',     1, true),
    ('Dennis Ritchie',    'dennis@fitz.dev',   'Vendedor Sr',   2, true),
    ('Edsger Dijkstra',   'edsger@fitz.dev',   'Vendedor',      2, false),
    ('Barbara Liskov',    'barbara@fitz.dev',  'Gerente RRHH',  3, true),
    ('Katherine Johnson', 'kat@fitz.dev',      'Analista',      4, true),
    ('Ken Thompson',      'ken@fitz.dev',      'Operador',      4, false)
) AS v(nombre, email, cargo, departamento_id, activo)
WHERE NOT EXISTS (SELECT 1 FROM empleados);

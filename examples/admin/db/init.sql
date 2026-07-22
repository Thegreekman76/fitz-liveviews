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
    ciudad_id        bigint NOT NULL DEFAULT 0,
    reporta_a        bigint NOT NULL DEFAULT 0,
    fecha_ingreso    text NOT NULL DEFAULT '',
    notas            text NOT NULL DEFAULT '',
    nivel            bigint NOT NULL DEFAULT 0,
    activo           boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT NOW()
);

-- Existing databases (created before Slice 4b) get the new column too.
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS ciudad_id bigint NOT NULL DEFAULT 0;
-- Slice 8 columns (fecha_ingreso / notas as ISO-8601 text — Fitz dates are Str;
-- reporta_a is a self-FK for the "reporta a" group-select).
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS reporta_a bigint NOT NULL DEFAULT 0;
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS fecha_ingreso text NOT NULL DEFAULT '';
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS notas text NOT NULL DEFAULT '';
-- Slice 8c: performance rating 0-5 (0 = sin calificar), for the star widget.
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS nivel bigint NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_empleados_depto ON empleados(departamento_id);

-- Ubicaciones — a país → provincia → ciudad hierarchy that feeds the
-- cascade select in the employee form (Slice 4b).
CREATE TABLE IF NOT EXISTS paises (
    id      bigserial PRIMARY KEY,
    nombre  text NOT NULL
);

CREATE TABLE IF NOT EXISTS provincias (
    id      bigserial PRIMARY KEY,
    pais_id bigint NOT NULL DEFAULT 0,
    nombre  text NOT NULL
);

CREATE TABLE IF NOT EXISTS ciudades (
    id           bigserial PRIMARY KEY,
    provincia_id bigint NOT NULL DEFAULT 0,
    nombre       text NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_provincias_pais ON provincias(pais_id);
CREATE INDEX IF NOT EXISTS idx_ciudades_provincia ON ciudades(provincia_id);

-- Permisos — grouped by module. Feed the group-checkbox in the employee form
-- (Slice 4c): a fieldset per module, one checkbox per permiso. The employee's
-- selection lives in the `empleado_permisos` join table.
CREATE TABLE IF NOT EXISTS permisos (
    id      bigserial PRIMARY KEY,
    modulo  text NOT NULL,
    accion  text NOT NULL,
    nombre  text NOT NULL
);

CREATE TABLE IF NOT EXISTS empleado_permisos (
    id          bigserial PRIMARY KEY,
    empleado_id bigint NOT NULL DEFAULT 0,
    permiso_id  bigint NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_emp_perm_empleado ON empleado_permisos(empleado_id);

-- Skills — a flat catalog; the employee form picks a subset via a multiselect
-- (checkbox list, Slice 4d). Selection lives in `empleado_skills`.
CREATE TABLE IF NOT EXISTS skills (
    id      bigserial PRIMARY KEY,
    nombre  text NOT NULL
);

CREATE TABLE IF NOT EXISTS empleado_skills (
    id          bigserial PRIMARY KEY,
    empleado_id bigint NOT NULL DEFAULT 0,
    skill_id    bigint NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_emp_skill_empleado ON empleado_skills(empleado_id);

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

-- Demo ubicaciones — país → provincia → ciudad. Seeded only when empty;
-- FKs resolved by name so the ids don't have to be hard-coded.
INSERT INTO paises (nombre)
SELECT nombre FROM (VALUES ('Argentina'), ('Uruguay')) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM paises);

INSERT INTO provincias (pais_id, nombre)
SELECT (SELECT id FROM paises WHERE nombre = v.pais), v.nombre FROM (VALUES
    ('Argentina', 'Buenos Aires'),
    ('Argentina', 'Córdoba'),
    ('Argentina', 'Santa Fe'),
    ('Uruguay',   'Montevideo'),
    ('Uruguay',   'Canelones')
) AS v(pais, nombre)
WHERE NOT EXISTS (SELECT 1 FROM provincias);

INSERT INTO ciudades (provincia_id, nombre)
SELECT (SELECT id FROM provincias WHERE nombre = v.provincia), v.nombre FROM (VALUES
    ('Buenos Aires', 'La Plata'),
    ('Buenos Aires', 'Mar del Plata'),
    ('Córdoba',      'Córdoba Capital'),
    ('Córdoba',      'Villa Carlos Paz'),
    ('Santa Fe',     'Rosario'),
    ('Santa Fe',     'Santa Fe Capital'),
    ('Montevideo',   'Montevideo'),
    ('Canelones',    'Las Piedras')
) AS v(provincia, nombre)
WHERE NOT EXISTS (SELECT 1 FROM ciudades);

-- Demo permisos — grouped by module. Seeded only when empty.
INSERT INTO permisos (modulo, accion, nombre)
SELECT modulo, accion, nombre FROM (VALUES
    ('Empleados',     'ver',      'Ver empleados'),
    ('Empleados',     'crear',    'Crear empleados'),
    ('Empleados',     'editar',   'Editar empleados'),
    ('Empleados',     'eliminar', 'Eliminar empleados'),
    ('Departamentos', 'ver',      'Ver departamentos'),
    ('Departamentos', 'gestionar','Gestionar departamentos'),
    ('Reportes',      'ver',      'Ver reportes'),
    ('Reportes',      'exportar', 'Exportar reportes')
) AS v(modulo, accion, nombre)
WHERE NOT EXISTS (SELECT 1 FROM permisos);

-- Demo skills — flat catalog. Seeded only when empty.
INSERT INTO skills (nombre)
SELECT nombre FROM (VALUES
    ('Rust'), ('Python'), ('SQL'), ('Docker'),
    ('Kubernetes'), ('React'), ('Liderazgo'), ('Inglés')
) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM skills);

-- --- Grants ----------------------------------------------------------------
-- In Docker init.sql runs as the app role (POSTGRES_USER=fitz), which owns
-- every table, so these are a no-op. When bootstrapping a LOCAL Postgres as a
-- superuser (e.g. `postgres`), they make sure the app's `fitz` role can
-- read/write the tables it doesn't own.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO fitz;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO fitz;

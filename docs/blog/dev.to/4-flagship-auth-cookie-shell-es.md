---
title: "Construyendo el flagship (1): auth por cookie browser-correcta en Fitz"
published: false
description: La auth del panel Admin, completa — por qué es por cookie y no Bearer, un login Argon2id + JWT que Setea una cookie HttpOnly, y páginas protegidas que resuelven el usuario vía el ORM y redirigen a /login. Más el shell responsive.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — Fitz tiene `@auth_provider` / `@authenticated` para APIs con Bearer token, pero un panel de administración de **browser** necesita otra cosa: el browser no puede mandar un header `Authorization` en una navegación de página ni en un handshake de WebSocket, y una request no autenticada debería **redirigir a `/login`**, no devolver un JSON 401. Así que el [Admin flagship](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin) usa una **cookie** de sesión: el login verifica la contraseña con **Argon2id**, firma un **JWT**, y lo pone en una cookie `HttpOnly`; cada página protegida lee la cookie, resuelve el usuario por el **ORM**, y redirige si falla — como Django o Rails gatean una sesión de browser. Todo en Fitz, sin librería de auth externa. *(Parte 4 de la serie FitzLiveViews — la primera de varias sobre el flagship.)*

Las partes 1–3 construyeron componentes aislados. Ahora lo real: un panel de administración de back-office completo — auth, un shell responsive, DataGrids en vivo sobre Postgres, i18n, Docker. Este post es la auth y el shell; los próximos son las grillas.

> **El código de abajo son extractos de la app real** ([`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)) para mostrar la forma — es un proyecto de 14 archivos, con Postgres, dockerizado, así que el camino garantizado-que-funciona es clonarlo y correr `docker compose up` (ver "Probalo" al final). Los snippets son fieles a la fuente; el repo es el artefacto runnable.

## Por qué cookies, no `@auth_provider`

Fitz core trae `@auth_provider` + `@authenticated` — y son geniales para una API JSON donde el cliente manda `Authorization: Bearer <token>` y recibe un `401` si falla. Un panel de administración de browser quiere dos cosas distintas:

1. **El browser no puede mandar un header `Authorization`** en una navegación de página, ni en un handshake de WebSocket. Sí manda cookies, automático. Así que el token de sesión viaja en una cookie `HttpOnly`.
2. **Una página no autenticada debería redirigir a `/login`**, no tirarle un error JSON al usuario.

Así que la app se arma una sesión por cookie a mano — que en Fitz son unas 40 líneas, porque JWT y el hashing de contraseñas están integrados en el lenguaje.

## Login — Argon2id + JWT → Set-Cookie

El login es un `@post` que toma credenciales JSON, verifica la contraseña contra el hash Argon2id guardado, firma un JWT, y lo devuelve como header `Set-Cookie` usando el built-in `Response { ... }`:

```
@post("/login")
async fn login_submit(creds: Credentials, cookie: Str?) -> Response {
  let user = match find_by_email(creds.email).await { ... }

  // hash.verify es Argon2id — built-in de Fitz, sin dep passlib/bcrypt.
  if (not hash.verify(creds.password, user.password_hash)) {
    return login_failed(...)
  }

  let claims = { "email": user.email, "role": user.role }
  let token = jwt.encode(claims, jwt_secret())     // HS256, built-in

  let set_cookie = session_cookie_name() + "=" + token
    + "; HttpOnly; Path=/; SameSite=Lax; Max-Age=86400"

  return Response {
    status: 200,
    headers: { "Set-Cookie": set_cookie },
  }
}
```

`hash.verify` (Argon2id) y `jwt.encode` (HS256) son built-ins de Fitz — sin `pip install passlib python-jose`, sin `npm install bcrypt jsonwebtoken`. El built-in `Response { ... }` es lo que deja a un handler setear un header custom en vez de devolver JSON plano.

*(Un detalle: el login postea JSON con un `fetch` chiquito, no un `<form>` nativo, porque los handlers `@post` de Fitz toman un body JSON, no form-urlencoded. Una mejora futura del core puede aceptar form posts.)*

## El chequeo de sesión — cookie → JWT → usuario (vía el ORM)

Resolver el usuario logueado es: sacar el token del header `Cookie` crudo, decodificar el JWT, leer el claim `email`, y buscar el usuario en Postgres — por el ORM de Fitz:

```
async fn user_from_cookie(cookie: Str?) -> Result<User> {
  let token  = token_from_cookie(cookie)?          // parsea el header Cookie
  let claims = jwt.decode(token, jwt_secret())?    // verifica firma + expiración
  let email  = match claims.get("email") { ... }

  let conn = db.connect(db_url()).await?
  return User.where(fn(u) => u.email == email).first(conn).await
}
```

Cualquier falla — cookie ausente, firma mala, token expirado, usuario desconocido — sale como `Err`, que una página protegida convierte en redirect. Fijate en `User.where(fn(u) => u.email == email).first(conn)`: ese es el ORM nativo de Fitz, una query tipada contra Postgres, en el mismo archivo que la auth.

## Proteger una página

Un handler protegido lee la cookie con `@header(name="cookie")` y redirige a `/login` ante cualquier falla de auth — un `303` real, browser-correcto:

```
@header(name="cookie")
@get("/")
async fn dashboard(cookie: Str?) -> Response {
  let user = match user_from_cookie(cookie).await {
    Ok(u) => u,
    Err(_) => return redirect_to("/login"),   // 303 → /login
  }
  // ... renderiza el dashboard para `user` ...
}
```

Ese es todo el gate. Una request no autenticada a `/` recibe `303 → /login` — exactamente lo que un browser espera, y lo que no podés expresar con un auth provider de JSON-401. `/logout` limpia la cookie (`Max-Age=0`) y redirige. Verifiqué el flujo entero end-to-end: `GET /` sin cookie → `303 /login`; `POST /login` → `Set-Cookie` con el JWT `HttpOnly`; `GET /` con la cookie → el dashboard.

## El shell responsive

Alrededor de cada página protegida hay un shell armado enteramente con la librería de UI empaquetada (`AppShell` / `Sidebar` / `Topbar` / `Breadcrumbs` / `ThemeToggle`):

- **Sidebar colapsable** en desktop, **drawer off-canvas** en mobile — funciona hasta 320px.
- Un switch de tema **light / dark / auto**, persistido por browser y **aplicado antes del primer paint** (un script inline chiquito lee la preferencia y setea el atributo de tema antes de que renderice el body — sin flash del tema equivocado).
- Un switch de idioma **🌐 ES / EN** (`GET /lang/{code}` setea una cookie de idioma y redirige de vuelta).

Todo está tematizado con design tokens `--flv-*` aliaseados a la paleta del admin, así que todo el panel — cada componente empaquetado — hereda el switch de tema gratis.

## Probalo

```bash
git clone https://github.com/Thegreekman76/fitz-liveviews
cd fitz-liveviews/examples/admin
docker compose up --build          # Postgres + la app, un comando
# → http://localhost:3000/   login: admin@fitz.dev / admin1234
```

## Qué viene en la serie

- **#5 — El DataGrid en vivo.** La pieza central del flagship: una grilla de empleados con búsqueda, filtros, ordenamiento y paginación, re-consultando Postgres y diff-parcheando por WebSocket en cada tecla.

Dale una estrella al [repo](https://github.com/Thegreekman76/fitz-liveviews) si una app real en un solo lenguaje es lo tuyo. Lo próximo: la grilla en vivo.

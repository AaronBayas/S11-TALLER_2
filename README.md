# Taller API REST — Libros (Node.js + Express + PostgreSQL + JWT)

API que permite crear, consultar, actualizar y eliminar **libros** en PostgreSQL.
Todas las rutas del CRUD están protegidas con JWT; la única ruta pública es `POST /auth/login`.

**Entidad:** `libros` → `id` (identificador), `titulo`*, `autor`*, `anio_publicacion`, `disponible` (* obligatorios).

## Requisitos

- Node.js 18 o superior y npm
- PostgreSQL 13 o superior (con `psql` o pgAdmin para revisar la tabla)
- Postman

## Instalación y ejecución

```bash
# 1. Instalar dependencias (usa package-lock.json)
npm install

# 2. Crear la base de datos y un usuario de PostgreSQL (una sola vez)
psql -U postgres -c "CREATE USER taller WITH PASSWORD 'elija_una_clave';"
psql -U postgres -c "CREATE DATABASE taller_api OWNER taller;"

# 3. Configurar variables de entorno
cp .env.example .env        # en Windows: copy .env.example .env
#    completar DB_USER, DB_PASSWORD, JWT_SECRET y TEST_PASSWORD
#    JWT_SECRET se puede generar con:
#    node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"

# 4. Inicializar tablas y cuenta de prueba
npm run db:init

# 5. Iniciar la API (http://localhost:3000)
npm start
```

## Inicialización de la cuenta de prueba

`npm run db:init` ejecuta `db/schema.sql` (tablas `usuarios` y `libros`) y crea el usuario
`TEST_USER` con la contraseña `TEST_PASSWORD` definidas en `.env`. La contraseña se guarda
**solo como hash bcrypt** (10 rondas) en `usuarios.password_hash`. Si se ejecuta de nuevo,
actualiza el hash de ese usuario. No existe registro de usuarios ni roles (fuera del alcance).

Comprobar: `SELECT id, username, password_hash FROM usuarios;` → el valor empieza con `$2b$10$`.

## Obtener y usar el JWT

1. Iniciar sesión:

   ```http
   POST http://localhost:3000/auth/login
   Content-Type: application/json

   { "username": "admin", "password": "<TEST_PASSWORD>" }
   ```

   Respuesta `200`: `{ "token": "eyJ...", "tipo": "Bearer", "expira_en": "..." }`.
   Credenciales incorrectas → `401`. El token vence según `JWT_EXPIRES_IN` (por defecto 1 h).

2. Enviar el token en cada petición del CRUD:

   ```
   Authorization: Bearer <token>
   ```

   Sin token, con token alterado o vencido → `401` (el middleware corta la petición antes del controlador y no se toca la base de datos).

## Rutas

| Método | Ruta | Resultado | Códigos |
|---|---|---|---|
| POST | `/auth/login` | Valida credenciales y devuelve JWT | 200, 400, 401 |
| POST | `/libros` | Crea un libro y devuelve su `id` | 201, 400, 401 |
| GET | `/libros` | Lista los libros | 200, 401 |
| GET | `/libros/:id` | Consulta un libro | 200, 400, 401, 404 |
| PUT | `/libros/:id` | Actualiza un libro (requiere `titulo` y `autor`) | 200, 400, 401, 404 |
| DELETE | `/libros/:id` | Elimina un libro | 200, 400, 401, 404 |

Ejemplo de cuerpo para crear/actualizar:

```json
{ "titulo": "Cien años de soledad", "autor": "Gabriel García Márquez", "anio_publicacion": 1967, "disponible": true }
```

Solo se aceptan esos cuatro campos; un campo desconocido o faltante devuelve `400` con el detalle.

## Pruebas con Postman

1. Importar `postman/Taller_API_Libros.postman_collection.json` y `postman/local.postman_environment.json`.
2. Seleccionar el entorno **Taller API - Local** y escribir la contraseña de prueba en la variable `password`.
3. Para la prueba de token vencido: `npm run token:vencido` y pegar el resultado en la variable `tokenVencido`.
4. Ejecutar las carpetas en orden. El login guarda el token en `{{token}}` y la creación guarda `{{libroId}}`;
   las demás peticiones los reutilizan. **Antes de la carpeta 5, detener (Ctrl+C) y volver a iniciar `npm start`**.

Desde consola (opcional): `npx newman run postman/Taller_API_Libros.postman_collection.json -e postman/local.postman_environment.json --env-var "password=<TEST_PASSWORD>" --env-var "tokenVencido=$(npm run -s token:vencido)" --folder "1. Autenticación"`

Consultas para la evidencia en la base de datos:

```sql
SELECT * FROM libros ORDER BY id;            -- tras crear / actualizar
SELECT * FROM libros WHERE id = 1;           -- tras eliminar: 0 filas
SELECT COUNT(*) FROM libros;                 -- antes y después de las pruebas 401
```

## Estructura

```
src/
  server.js                    arranque: prueba la conexión a BD y escucha el puerto
  app.js                       Express, express.json(), rutas, 404 y manejo de errores
  config/env.js                lee y valida variables de entorno
  config/db.js                 pool de conexiones PostgreSQL (pg)
  middleware/auth.js           verifica firma y vencimiento del JWT → 401
  routes/auth.routes.js        POST /auth/login (pública)
  routes/libro.routes.js       CRUD; router.use(verificarToken) antes de los controladores
  controllers/auth.controller.js   bcrypt.compare + jwt.sign
  controllers/libro.controller.js  validación y códigos HTTP
  models/usuario.model.js      consultas a "usuarios"
  models/libro.model.js        consultas parametrizadas a "libros"
db/schema.sql                  script SQL de las tablas
scripts/init-db.js             crea tablas y cuenta de prueba con hash
scripts/token-vencido.js       genera un JWT expirado para la prueba 401
postman/                       colección y entorno exportados
```

## Flujo de una petición protegida

`PUT /libros/1` → `express.json()` → `libro.routes.js` → `verificarToken` (lee `Authorization`, `jwt.verify` con `JWT_SECRET` y `exp`) → `libro.controller.actualizar` (valida id y campos) → `libro.model.actualizar` (`UPDATE ... WHERE id = $5 RETURNING ...`) → `200` con el registro o `404` si `RETURNING` no devolvió filas.

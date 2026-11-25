# FarmMind MVP

FarmMind is a Flutter client, Spring Boot/PostgreSQL API, and separate FastAPI plant-analysis service.

## Project layout

- `frontend/farm_mind` — Flutter app
- `backend/demo (4)/demo` — Spring Boot REST API
- `database` — PostgreSQL schema and Docker Compose setup
- `ai-service` — FastAPI classifier adapter

## Local setup (Windows)

### PostgreSQL

Use an existing local PostgreSQL server, or copy `.env.example` to `.env`, replace the sample password, then start the bundled database:

```cmd
copy .env.example .env
docker compose -f database\docker-compose.yml up -d
```

The `.env` file configures Docker Compose only. Keep it local; Git ignores it. For an existing PostgreSQL instance, create a `farmmind` database and login role, or set `DATABASE_URL`, `DATABASE_USERNAME`, and `DATABASE_PASSWORD` to credentials for your existing role.

### Backend

In a new CMD window, set the database values for that terminal. Use the same password configured for the `farmmind` role in PostgreSQL:

```cmd
cd /d "backend\demo (4)\demo"
set "DATABASE_URL=jdbc:postgresql://localhost:5432/farmmind"
set "DATABASE_USERNAME=farmmind"
set "DATABASE_PASSWORD=your-local-database-password"
mvnw.cmd spring-boot:run
```

Do not commit real passwords. The Spring configuration requires `DATABASE_PASSWORD` to be provided through the environment.

### AI service

Python 3.11 is recommended for the pinned TensorFlow dependency:

```cmd
cd /d ai-service
py -3.11 -m venv .venv
.venv\Scripts\activate.bat
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload --port 8000
```

The service starts without model weights, but `/predict` returns HTTP 503 until a real Keras classifier and matching ordered labels are installed. See `ai-service/README.md`.

### Flutter app

For an Android emulator:

```cmd
cd /d frontend\farm_mind
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

For Flutter desktop, the default API URL is `http://localhost:8080`.

## API overview

- `POST /api/auth/register`, `POST /api/auth/login`
- `GET/POST/GET by id/PUT/DELETE /api/farms`
- `GET/POST/GET by id/PUT/DELETE /api/crops`
- `POST /api/scans` (multipart image, optional `cropId`), `GET /api/scans/{cropId}`
- `POST /api/irrigation`, `GET /api/irrigation/{cropId}`
- `POST /api/soil-measurements`, `GET /api/soil-measurements/{cropId}`
- `GET /api/dashboard/{farmId}`
- `GET /api/irrigation/recommendation/{cropId}?soilMoisture=...`
- `GET /api/weather`

Authenticated routes use `Authorization: Bearer <token>`. Passwords are BCrypt-hashed. MVP session tokens are in memory and reset when the backend restarts. Uploaded scan images are stored under the configured upload directory, which is ignored by Git.

# FrigoCheck MVP runbook

## Backup

Antes de esta fase se creo la rama:

```text
backup/pre-codex-mvp-2026-06-09
```

Apunta al commit original:

```text
54b8b5d38f4e626a5742764cad933bbcbec4cb81
```

La rama de trabajo de esta version es:

```text
codex/mvp-real-data-auth-stats
```

## Backend local

```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Variables necesarias:

```env
OPENAI_API_KEY=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
ENVIRONMENT=development
APP_NAME=FrigoCheck API
```

## Android APK

Compila indicando la URL real del backend y, si ya tienes Supabase Auth, las claves publicas de la app:

```bash
cd app
flutter clean
flutter pub get
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://TU_IP:8000 \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Si omites `SUPABASE_URL` y `SUPABASE_ANON_KEY`, la app entra en modo demo y usa el usuario temporal actual.

## Flujo que debe probarse

1. Entrar con email/contrasena, Google o modo demo.
2. Escanear o importar una imagen de ticket.
3. Revisar productos detectados y guardar.
4. Ver productos activos en Inicio.
5. Entrar en Mi nevera y marcar consumido o tirado.
6. Revisar Estadisticas y confirmar ahorro/perdida.

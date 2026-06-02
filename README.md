# FrigoCheck

FrigoCheck es una app móvil para escanear tickets de compra, detectar productos con IA y crear una nevera digital con recordatorios para evitar desperdiciar alimentos.

## Stack propuesto

- App móvil: Flutter
- Backend: FastAPI
- Base de datos: Supabase / PostgreSQL
- IA: OpenAI API
- Notificaciones: Firebase Cloud Messaging

## Estructura

```text
FrigoCheck-/
├── app/                 # App Flutter
├── backend/             # API FastAPI
├── supabase/            # SQL inicial y migraciones
├── docs/                # Documentación técnica breve
├── .gitignore
└── README.md
```

## Primer arranque backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Prueba:

```bash
curl http://127.0.0.1:8000/health
```

## Primer arranque Flutter

```bash
cd app
flutter pub get
flutter run
```

## Variables importantes

No subas nunca `.env` a GitHub.

```env
OPENAI_API_KEY=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
ENVIRONMENT=development
APP_NAME=FrigoCheck API
```

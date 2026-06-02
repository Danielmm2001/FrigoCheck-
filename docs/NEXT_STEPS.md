# FrigoCheck - Próximos pasos

## Estado actual

El repositorio ya contiene una primera base funcional:

- README principal.
- Backend FastAPI inicial.
- Endpoint `/health`.
- Endpoint `/receipts/analyze` preparado para OpenAI.
- Rutas mock de productos y estadísticas.
- Prompt extractor de tickets.
- App Flutter inicial con branding FrigoCheck.
- Pantallas mock navegables.
- Migración SQL inicial para Supabase.

## Siguiente paso recomendado

### 1. Probar backend local

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Probar:

```bash
curl http://127.0.0.1:8000/health
```

Respuesta esperada:

```json
{
  "status": "ok",
  "service": "FrigoCheck API"
}
```

### 2. Configurar OpenAI

Editar `backend/.env` y añadir:

```env
OPENAI_API_KEY=tu_api_key
```

Nunca subir `.env` al repositorio.

### 3. Probar análisis de ticket

Cuando el backend esté funcionando, probar con Postman, Insomnia o curl enviando una imagen al endpoint:

```text
POST /receipts/analyze
```

### 4. Crear Supabase

- Crear proyecto en Supabase.
- Ejecutar `supabase/migrations/001_initial_schema.sql`.
- Copiar `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` al `.env` local.

### 5. Probar Flutter

```bash
cd app
flutter pub get
flutter run
```

## Prioridades de desarrollo

1. Corregir posibles errores de compilación Flutter.
2. Conectar Flutter con el backend.
3. Conectar backend con Supabase.
4. Guardar productos reales.
5. Implementar login real.
6. Implementar notificaciones.

## Nota importante

La app actualmente tiene datos mock para validar la estética, navegación y estructura. La siguiente fase consiste en sustituir esos mocks por datos reales desde backend/Supabase.

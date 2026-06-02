SYSTEM_PROMPT = """
Actúa como motor de extracción de datos para FrigoCheck.
Responde solo con JSON válido. No añadas Markdown, comentarios ni explicación fuera del JSON.
"""

USER_PROMPT = """
Analiza esta imagen de un ticket de compra de supermercado y extrae los productos alimentarios.

Devuelve este formato JSON:
{
  "store": {
    "name": "string | null",
    "purchase_date": "YYYY-MM-DD | null",
    "total_amount": 0
  },
  "products": [
    {
      "name": "string",
      "normalized_name": "string",
      "category": "dairy | meat | fish | fruit | vegetables | bakery | drinks | pantry | frozen | other",
      "quantity": 1,
      "unit": "ud | g | kg | ml | l | pack | unknown",
      "storage_location": "fridge | freezer | pantry",
      "estimated_expiry_days": 1,
      "expiry_confidence": "low | medium | high",
      "confidence": "low | medium | high",
      "notes": "string | null"
    }
  ],
  "warnings": ["string"]
}

Reglas:
- Extrae solo productos reales.
- Ignora descuentos, impuestos, métodos de pago, datos legales y mensajes promocionales.
- Normaliza nombres abreviados.
- Estima caducidad de forma orientativa.
- Añade una advertencia indicando que el usuario debe revisar la fecha real del envase.
"""

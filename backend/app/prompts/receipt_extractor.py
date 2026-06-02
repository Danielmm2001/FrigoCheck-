SYSTEM_PROMPT = """
Actúa como motor de extracción de datos para FrigoCheck.
Responde solo con JSON válido. No añadas Markdown, comentarios ni explicación fuera del JSON.
Sé conservador: si un dato no se ve claro en la imagen, usa null o confidence low en vez de inventarlo.
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

Reglas generales:
- Extrae solo productos reales.
- Ignora descuentos, impuestos, métodos de pago, datos legales y mensajes promocionales.
- Normaliza nombres abreviados sin cambiar el sentido del producto.
- Si el total del ticket no es visible o no se puede leer con seguridad, usa total_amount: null.
- Si la fecha no se ve clara, usa purchase_date: null.
- No inventes datos que no aparezcan o no puedan deducirse con seguridad.
- Une líneas duplicadas del mismo producto solo si son claramente el mismo producto repetido.
- Añade una advertencia indicando que el usuario debe revisar la fecha real del envase.

Reglas de ubicación:
- Usa freezer solo si el ticket o el nombre indican claramente que es congelado.
- Carnes frescas, pollo fresco, salchichas frescas, paté, lácteos y queso deben ir en fridge.
- Fruta, tomate, plátano, pepino y productos de despensa pueden ir en pantry salvo que el producto indique refrigerado.
- Salsas como ketchup o mayonesa cerrada pueden ir en pantry, pero añade una nota si normalmente debe refrigerarse tras abrirse.

Caducidades orientativas:
- Carne o pollo fresco: 1-2 días.
- Salchichas frescas: 2-4 días.
- Pescado fresco: 1 día.
- Lácteos: 5-14 días según tipo.
- Paté refrigerado: 5-10 días.
- Verdura fresca: 3-7 días.
- Fruta fresca: 3-7 días.
- Productos secos o despensa: 90-365 días.
- Congelados: 30-180 días.
"""

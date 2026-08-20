\
# Workflow recomendado: generar-reporte

## Entrada esperada

```json
{
  "fecha_desde": "2026-08-01",
  "fecha_hasta": "2026-08-15",
  "cliente": "ACME S.A.",
  "tipo_reporte": "ejecutivo",
  "email": "usuario@ejemplo.com"
}
```

## Nodos

### 1. Webhook

- POST
- Path: `generar-reporte`

### 2. Validación

Validar al menos:

- fechas presentes y válidas;
- `fecha_desde <= fecha_hasta`;
- cliente no vacío;
- tipo de reporte dentro de una lista permitida;
- email válido.

### 3. PostgreSQL

Usar una consulta parametrizada.
No concatenar valores recibidos para construir SQL.

### 4. AI Agent

Instrucción sugerida:

```text
Actúa como analista de negocios.

Genera un reporte de tipo {{ tipo_reporte }} usando exclusivamente
los datos suministrados.

Incluye:
- resumen ejecutivo;
- total facturado;
- productos principales;
- tendencias;
- anomalías observables;
- conclusiones;
- recomendaciones.

No inventes cifras ausentes.
```

### 5. Ollama Chat Model

- Credential URL: `http://ollama:11434`
- Model: `qwen3:4b`

### 6. HTML

Convertir la salida en un reporte HTML.

### 7. Email

Configurar SMTP en las Credentials de n8n.

### 8. Respond to Webhook

Por ejemplo:

```json
{
  "ok": true,
  "mensaje": "El reporte fue procesado."
}
```

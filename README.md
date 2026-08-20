\
# n8n local + React/Webhooks públicos + Ollama/Qwen3 + Cloudflare

## Objetivo

Este stack implementa exactamente este escenario:

```text
                         INTERNET
                            │
                        Cloudflare
                            │
                            ▼
                  ia.mysite.com.ar
                            │
                       cloudflared
                            │
                            ▼
                     ia_service:80
                     ┌──────┴──────┐
                     │             │
                     ▼             ▼
                   React       /webhook/*
                                     │
                                     ▼
                                    n8n
                              ┌──────┴──────┐
                              ▼             ▼
                         PostgreSQL       Ollama
                                            │
                                            ▼
                                         Qwen3

PC LOCAL
   │
   └── http://127.0.0.1:5678 → panel/editor n8n
```

No existe `n8n.mysite.com.ar`.
Cloudflare nunca apunta directamente al editor.

---

## 1. Crear .env

```bash
cp .env.example .env
```

Generar contraseña PostgreSQL:

```bash
openssl rand -hex 24
```

Generar `N8N_ENCRYPTION_KEY`:

```bash
openssl rand -hex 32
```

Editar:

```bash
nano .env
```

Completar también `CLOUDFLARE_TUNNEL_TOKEN`.

---

## 2. Configurar Cloudflare Tunnel

Usar un Tunnel remotamente administrado.

Crear UNA sola Published Application:

- Hostname: `ia.mysite.com.ar`
- Service URL: `http://ia_service:80`

No crear ninguna ruta para n8n.

El contenedor `cloudflared` comparte la red Docker `edge` con `ia_service`,
por eso puede resolver ese nombre DNS interno.

---

## 3. Construir y levantar

```bash
docker compose config
docker compose pull
docker compose up -d --build
```

Verificar:

```bash
docker compose ps
```

Logs útiles:

```bash
docker compose logs -f cloudflared
docker compose logs -f n8n
docker compose logs -f ollama_init
```

---

## 4. Verificar Qwen3

```bash
docker compose exec ollama ollama list
```

Debe aparecer:

```text
qwen3:4b
```

---

## 5. Acceder al panel n8n

Sólo desde la misma PC Ubuntu:

```text
http://127.0.0.1:5678
```

También sirve:

```text
http://localhost:5678
```

IMPORTANTE:

Docker publica:

```yaml
127.0.0.1:5678:5678
```

y NO:

```yaml
5678:5678
```

Esto impide que n8n quede escuchando en todas las interfaces de red del host.

Comprobar:

```bash
ss -lntp | grep 5678
```

Esperado:

```text
127.0.0.1:5678
```

---

## 6. Probar React localmente

El gateway público también se publica localmente sólo para diagnóstico:

```text
http://127.0.0.1:8081
```

Prueba:

```bash
curl -I http://127.0.0.1:8081
```

---

## 7. Probar desde Internet

Una vez que el Tunnel esté Healthy:

```text
https://ia.mysite.com.ar
```

debe mostrar React.

No debe existir una URL pública para el panel de n8n.

---

## 8. Conectar n8n con Ollama

Desde el editor local:

1. Credentials.
2. New credential.
3. Ollama.
4. Base URL:

```text
http://ollama:11434
```

5. Guardar como `Ollama local`.

En el workflow usar:

- AI Agent
- Ollama Chat Model
- Model: `qwen3:4b`

---

## 9. Base PostgreSQL de demostración

El stack crea automáticamente:

```text
Database: reportes
Table: ventas
```

Credencial n8n:

```text
Host: postgres
Port: 5432
Database: reportes
User: valor de POSTGRES_USER
Password: valor de POSTGRES_PASSWORD
SSL: off
```

Ejemplo de consulta:

```sql
SELECT
    fecha,
    cliente,
    producto,
    cantidad,
    importe_total
FROM ventas
WHERE cliente = $1
  AND fecha BETWEEN $2 AND $3
ORDER BY fecha;
```

Usar parámetros; nunca recibir SQL arbitrario desde React.

---

## 10. Crear Webhook

Nodo Webhook:

```text
Method: POST
Path: generar-reporte
```

La URL productiva será:

```text
https://ia.mysite.com.ar/webhook/generar-reporte
```

La de prueba:

```text
https://ia.mysite.com.ar/webhook-test/generar-reporte
```

El gateway Nginx sólo deriva estas rutas a n8n.
El resto del hostname público va a React.

---

## 11. Prueba curl

Después de activar el workflow:

```bash
curl -X POST \
  'https://ia.mysite.com.ar/webhook/generar-reporte' \
  -H 'Content-Type: application/json' \
  -d '{
    "fecha_desde":"2026-08-01",
    "fecha_hasta":"2026-08-15",
    "cliente":"ACME S.A.",
    "tipo_reporte":"ejecutivo",
    "email":"usuario@ejemplo.com"
  }'
```

---

## 12. Flujo recomendado

```text
Webhook
  ↓
Validar datos
  ↓
PostgreSQL
  ↓
Preparar datos
  ↓
AI Agent
  ↓
Ollama Chat Model / Qwen3
  ↓
Generar HTML
  ↓
Enviar email
  ↓
Respond to Webhook
```

Para SMTP deberás configurar en n8n las credenciales reales del proveedor de correo.
No deben estar en React.

---

## 13. Seguridad conseguida

### Público

```text
https://ia.mysite.com.ar/
https://ia.mysite.com.ar/webhook/*
```

### Sólo PC local

```text
http://127.0.0.1:5678
```

### Sólo red Docker privada

```text
postgres:5432
ollama:11434
n8n:5678
```

Ollama y PostgreSQL no tienen `ports:`.

---

## 14. Comprobaciones importantes

Panel:

```bash
curl -I http://127.0.0.1:5678
```

React:

```bash
curl -I http://127.0.0.1:8081
```

Ollama desde n8n no se prueba con localhost.
Desde el contenedor se resuelve por DNS Docker:

```text
http://ollama:11434
```

Estado:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs --tail=100 n8n
docker compose logs --tail=100 ia_service
docker compose logs --tail=100 cloudflared
docker compose logs --tail=100 ollama
```

---

## 15. Regla conceptual

`127.0.0.1` significa "esta misma máquina".

Por eso:

```yaml
ports:
  - "127.0.0.1:5678:5678"
```

es la barrera que evita publicar accidentalmente el editor n8n en la LAN.

Cloudflare no necesita ese puerto. Cloudflare llega a `ia_service`
por una red Docker compartida con `cloudflared`.

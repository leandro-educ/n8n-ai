import { useState } from 'react'

const inicial = {
  fecha_desde: '2026-08-01',
  fecha_hasta: '2026-08-15',
  cliente: 'ACME S.A.',
  tipo_reporte: 'ejecutivo',
  email: 'usuario@ejemplo.com',
}

export default function App() {
  const [form, setForm] = useState(inicial)
  const [estado, setEstado] = useState('')
  const [resultado, setResultado] = useState(null)

  const cambiar = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value })
  }

  const enviar = async (e) => {
    e.preventDefault()
    setEstado('Procesando solicitud...')
    setResultado(null)

    try {
      const response = await fetch('/webhook/generar-reporte', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(form),
      })

      const raw = await response.text()
      let data

      try {
        data = JSON.parse(raw)
      } catch {
        data = { respuesta: raw }
      }

      if (!response.ok) {
        throw new Error(data?.message || data?.respuesta || `HTTP ${response.status}`)
      }

      setResultado(data)
      setEstado('Solicitud enviada correctamente.')
    } catch (error) {
      setEstado(`Error: ${error.message}`)
    }
  }

  return (
    <main className="page">
      <section className="card">
        <span className="badge">n8n · Ollama · Qwen3</span>

        <h1>Generador de reportes con IA</h1>

        <p className="intro">
          React envía los parámetros al webhook público. El panel de n8n
          permanece disponible únicamente en la PC local.
        </p>

        <form onSubmit={enviar}>
          <label>
            Cliente
            <input
              name="cliente"
              value={form.cliente}
              onChange={cambiar}
              required
            />
          </label>

          <div className="grid">
            <label>
              Fecha desde
              <input
                type="date"
                name="fecha_desde"
                value={form.fecha_desde}
                onChange={cambiar}
                required
              />
            </label>

            <label>
              Fecha hasta
              <input
                type="date"
                name="fecha_hasta"
                value={form.fecha_hasta}
                onChange={cambiar}
                required
              />
            </label>
          </div>

          <label>
            Tipo de reporte
            <select
              name="tipo_reporte"
              value={form.tipo_reporte}
              onChange={cambiar}
            >
              <option value="ejecutivo">Ejecutivo</option>
              <option value="detallado">Detallado</option>
              <option value="resumen">Resumen</option>
            </select>
          </label>

          <label>
            Email destino
            <input
              type="email"
              name="email"
              value={form.email}
              onChange={cambiar}
              required
            />
          </label>

          <button type="submit">Generar reporte</button>
        </form>

        {estado && <p className="status">{estado}</p>}

        {resultado && (
          <pre>{JSON.stringify(resultado, null, 2)}</pre>
        )}
      </section>
    </main>
  )
}

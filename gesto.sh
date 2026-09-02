#!/usr/bin/env bash

CONTAINER="${OLLAMA_CONTAINER:-n8n_ollama}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"

pausa() {
  echo
  read -rp "Presioná Enter para continuar..." _
}

titulo() {
  clear
  echo "============================================================"
  echo "              GESTOR DE MODELOS OLLAMA"
  echo "============================================================"
  echo "Contenedor : $CONTAINER"
  echo "API        : $OLLAMA_URL"
  echo
}

comprobar_entorno() {
  command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker no está disponible."; exit 1; }
  docker inspect "$CONTAINER" >/dev/null 2>&1 || { echo "ERROR: No existe el contenedor '$CONTAINER'."; exit 1; }

  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "ERROR: El contenedor '$CONTAINER' no está ejecutándose."
    exit 1
  fi

  command -v curl >/dev/null 2>&1 || {
    echo "ERROR: Falta curl. Instalalo con: sudo apt install curl"
    exit 1
  }
}

obtener_modelos() {
  docker exec "$CONTAINER" ollama list 2>/dev/null | awk 'NR>1 && NF {print $1}'
}

obtener_activos() {
  docker exec "$CONTAINER" ollama ps 2>/dev/null | awk 'NR>1 && NF {print $1}'
}

listar_instalados() {
  echo "MODELOS INSTALADOS"
  echo "------------------------------------------------------------"
  docker exec "$CONTAINER" ollama list
}

listar_activos() {
  echo "MODELOS CARGADOS / ACTIVOS"
  echo "------------------------------------------------------------"
  local salida
  salida="$(docker exec "$CONTAINER" ollama ps 2>/dev/null)"
  if [ "$(printf '%s\n' "$salida" | wc -l)" -le 1 ]; then
    echo "No hay modelos cargados actualmente."
  else
    printf '%s\n' "$salida"
  fi
}

seleccionar_modelo_instalado() {
  mapfile -t MODELOS < <(obtener_modelos)
  [ "${#MODELOS[@]}" -gt 0 ] || { echo "No hay modelos instalados."; return 1; }

  echo "Seleccioná un modelo:"
  echo
  local i
  for i in "${!MODELOS[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${MODELOS[$i]}"
  done

  echo
  read -rp "Opción: " seleccion
  [[ "$seleccion" =~ ^[0-9]+$ ]] || { echo "Opción inválida."; return 1; }
  (( seleccion >= 1 && seleccion <= ${#MODELOS[@]} )) || { echo "Opción fuera de rango."; return 1; }

  MODELO_SELECCIONADO="${MODELOS[$((seleccion - 1))]}"
}

seleccionar_modelo_activo() {
  mapfile -t ACTIVOS < <(obtener_activos)
  [ "${#ACTIVOS[@]}" -gt 0 ] || { echo "No hay modelos activos."; return 1; }

  echo "Seleccioná un modelo activo:"
  echo
  local i
  for i in "${!ACTIVOS[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${ACTIVOS[$i]}"
  done

  echo
  read -rp "Opción: " seleccion
  [[ "$seleccion" =~ ^[0-9]+$ ]] || { echo "Opción inválida."; return 1; }
  (( seleccion >= 1 && seleccion <= ${#ACTIVOS[@]} )) || { echo "Opción fuera de rango."; return 1; }

  MODELO_SELECCIONADO="${ACTIVOS[$((seleccion - 1))]}"
}

detener_todos_excepto() {
  local conservar="$1"
  mapfile -t ACTIVOS < <(obtener_activos)
  local modelo
  for modelo in "${ACTIVOS[@]}"; do
    if [ "$modelo" != "$conservar" ]; then
      echo "Deteniendo $modelo..."
      docker exec "$CONTAINER" ollama stop "$modelo" >/dev/null 2>&1 || true
    fi
  done
}

activar_modelo() {
  titulo
  seleccionar_modelo_instalado || { pausa; return; }
  local modelo="$MODELO_SELECCIONADO"

  echo
  echo "Se dejará activo solamente: $modelo"
  read -rp "¿Continuar? [S/n]: " confirmar
  confirmar="${confirmar:-S}"
  [[ "$confirmar" =~ ^[sS]$ ]] || { echo "Operación cancelada."; pausa; return; }

  echo
  detener_todos_excepto "$modelo"
  echo "Cargando $modelo y manteniéndolo activo..."

  if ! curl -fsS       -H "Content-Type: application/json"       -d "{\"model\":\"$modelo\",\"prompt\":\"\",\"stream\":false,\"keep_alive\":-1}"       "$OLLAMA_URL/api/generate" >/dev/null; then
    echo "ERROR: No se pudo cargar el modelo mediante la API de Ollama."
    pausa
    return
  fi

  sleep 1
  echo
  docker exec "$CONTAINER" ollama ps
  pausa
}

detener_modelo() {
  titulo
  seleccionar_modelo_activo || { pausa; return; }
  echo
  echo "Deteniendo $MODELO_SELECCIONADO..."
  docker exec "$CONTAINER" ollama stop "$MODELO_SELECCIONADO"
  echo
  listar_activos
  pausa
}

detener_todos() {
  titulo
  mapfile -t ACTIVOS < <(obtener_activos)

  if [ "${#ACTIVOS[@]}" -eq 0 ]; then
    echo "No hay modelos cargados."
    pausa
    return
  fi

  echo "Se detendrán:"
  printf '  - %s\n' "${ACTIVOS[@]}"
  echo
  read -rp "¿Continuar? [S/n]: " confirmar
  confirmar="${confirmar:-S}"
  [[ "$confirmar" =~ ^[sS]$ ]] || { echo "Operación cancelada."; pausa; return; }

  local modelo
  for modelo in "${ACTIVOS[@]}"; do
    echo "Deteniendo $modelo..."
    docker exec "$CONTAINER" ollama stop "$modelo" >/dev/null
  done

  echo
  echo "Todos los modelos fueron descargados de memoria."
  pausa
}

chat_interactivo() {
  titulo
  seleccionar_modelo_instalado || { pausa; return; }
  local modelo="$MODELO_SELECCIONADO"

  echo
  detener_todos_excepto "$modelo"
  echo
  echo "Iniciando chat con: $modelo"
  echo "Para salir escribí: /bye"
  echo "------------------------------------------------------------"
  docker exec -it "$CONTAINER" ollama run "$modelo"
  pausa
}

mostrar_gpu() {
  titulo
  echo "ESTADO DE LA GPU"
  echo "------------------------------------------------------------"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
  else
    echo "nvidia-smi no está disponible."
  fi
  echo
  listar_activos
  pausa
}

estado_general() {
  titulo
  listar_instalados
  echo
  listar_activos
  echo
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "GPU NVIDIA"
    echo "------------------------------------------------------------"
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total       --format=csv,noheader 2>/dev/null || true
  fi
  pausa
}

comprobar_entorno

while true; do
  titulo
  echo "1) Ver modelos instalados"
  echo "2) Ver modelos cargados / activos"
  echo "3) Elegir modelo y dejarlo activo"
  echo "4) Detener un modelo activo"
  echo "5) Detener todos los modelos"
  echo "6) Abrir chat interactivo con un modelo"
  echo "7) Ver estado de GPU y Ollama"
  echo "8) Estado general"
  echo "0) Salir"
  echo
  read -rp "Elegí una opción: " opcion

  case "$opcion" in
    1) titulo; listar_instalados; pausa ;;
    2) titulo; listar_activos; pausa ;;
    3) activar_modelo ;;
    4) detener_modelo ;;
    5) detener_todos ;;
    6) chat_interactivo ;;
    7) mostrar_gpu ;;
    8) estado_general ;;
    0) clear; echo "Gestor Ollama finalizado."; exit 0 ;;
    *) echo; echo "Opción inválida."; sleep 1 ;;
  esac
done


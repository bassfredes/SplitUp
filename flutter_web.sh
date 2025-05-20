#!/bin/bash

LOG_FILE="/tmp/flutter_web_output.log"
CHROME_PATH="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"

echo "🚀 Iniciando Flutter Web con hot reload..."
echo "⌨️  Presiona 'r' para recargar, 'q' para salir."

# Limpiar ejecuciones previas
rm -f "$LOG_FILE"
touch "$LOG_FILE"

# Función de limpieza
cleanup() {
  echo ""
  echo "🛑 Terminando sesión de desarrollo..."

  if ps -p $FLUTTER_PID > /dev/null; then
    kill $FLUTTER_PID
    wait $FLUTTER_PID 2>/dev/null
  fi

  rm -f "$LOG_FILE"
  echo "✅ Limpieza completa (Chrome queda abierto)."
  exit 0
}

# Capturar Ctrl+C
trap cleanup SIGINT

# Ejecutar flutter run
flutter run -d web-server | tee "$LOG_FILE" &
FLUTTER_PID=$!

# Esperar URL
echo "⏳ Esperando que Flutter exponga la URL..."
until grep -q 'http://localhost:' "$LOG_FILE"; do
  sleep 1
done

# Extraer URL
URL=$(grep -o 'http://localhost:[0-9]*' "$LOG_FILE" | head -n 1)

# Abrir Chrome en background sin trackear el PID
echo "🌐 Abriendo en Chrome de Windows: $URL"
"$CHROME_PATH" "$URL" &

# Mantener sesión activa para hot reload
wait $FLUTTER_PID

# Ejecutar limpieza al terminar normalmente
cleanup

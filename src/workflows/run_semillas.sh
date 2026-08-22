#!/usr/bin/env bash
#
# run_semillas.sh
#   Corre el workflow z950 (Analista Senior) en forma secuencial,
#   una corrida completa por cada semilla, tomando las primeras
#   N semillas del archivo  ./semillas
#
# Usa papermill para ejecutar los notebooks, que ademas de loguear
# la salida de cada celda EN VIVO, deja una copia del notebook ya
# ejecutado (con todos sus outputs) en la carpeta de la corrida
# (exp/WF9500_s<semilla>/salida_corrida.ipynb)
#
# Si no hay internet para instalar, hace fallback a jupyter nbconvert
#
# Uso:
#   bash run_semillas.sh [N_SEMILLAS]     # default: 5
#
# Requiere:
#   pip install papermill
#
# En GCE, correr dentro de tmux para que sobreviva a desconecciones:
#   tmux new -s semillas
#   bash run_semillas.sh 5 2>&1 | tee corrida.log
#   # Ctrl+B luego D para despegarse; la corrida sigue
#   # para ver progreso desde otra terminal:
#   tail -f corrida.log
#   grep "=== " corrida.log
#

set -uo pipefail

N_SEMILLAS="${1:-5}"
NB="z950_WorkFlow_01_senior.ipynb"
NB_CORRIDA="corrida_activo.ipynb"

if [[ ! -f "$NB" ]]; then
  echo "ERROR: no se encontro $NB" >&2
  exit 1
fi

if [[ ! -f semillas ]]; then
  echo "ERROR: no se encontro el archivo semillas" >&2
  exit 1
fi

if ! command -v papermill > /dev/null 2>&1; then
  echo "AVISO: papermill no esta instalado, se usara jupyter nbconvert" >&2
  echo "       (sin salida en vivo por celda; instale con: pip install papermill)" >&2
fi

echo "=== SWEEP INICIO $(date)  N_SEMILLAS=$N_SEMILLAS ==="

head -n "$N_SEMILLAS" semillas | while read -r s; do
  echo ""
  echo "=== INICIO corrida SEMILLA=$s  $(date) ==="

  cp "$NB" "$NB_CORRIDA"

  if command -v papermill > /dev/null 2>&1; then
    # papermill: salida de cada celda en vivo en el log,
    #  y guarda el notebook ejecutado dentro de la carpeta del experimento
    SALIDA="exp/WF9500_s${s}/salida_corrida.ipynb"
    mkdir -p "$(dirname "$SALIDA")"

    if SEMILLA="$s" papermill \
        "$NB_CORRIDA" "$SALIDA" \
        --log-output \
        --cwd .; then
      echo "=== FIN OK SEMILLA=$s  $(date) ==="
    else
      # log-and-continue: una corrida fallida no corta el sweep
      echo "=== FIN ERROR SEMILLA=$s  $(date) ==="
    fi
  else
    # fallback sin papermill
    if SEMILLA="$s" jupyter nbconvert \
        --to notebook --execute --inplace \
        --ExecutePreprocessor.timeout=-1 \
        "$NB_CORRIDA"; then
      echo "=== FIN OK SEMILLA=$s  $(date) ==="
    else
      echo "=== FIN ERROR SEMILLA=$s  $(date) ==="
    fi
  fi
done

echo ""
echo "=== SWEEP COMPLETO $(date) ==="

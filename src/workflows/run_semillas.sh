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
# (exp/WF<exp>_s<semilla>/salida_corrida_exp<exp>.ipynb)
#
# Si no hay internet para instalar, hace fallback a jupyter nbconvert
#
# Uso:
#   bash run_semillas.sh [N_SEMILLAS] N_EXP [SELECTOR] [SKIP]
#
#   N_SEMILLAS   cantidad de semillas a correr        (default: 5)
#   N_EXP        numero de experimento (entero), OBLIGATORIO, ej: 1
#                se pasa al notebook via la variable de ambiente
#                EXP_NUM (igual que SEMILLA) y se usa como sufijo
#                en el log y los notebooks, para poder correr varias
#                experiencias en paralelo en distintas VMs que
#                comparten el mismo bucket
#   SELECTOR     seleccion de variables: "canarito" (default) o
#                "boruta"; se pasa al notebook via la variable de
#                ambiente SELECTOR. Usar un N_EXP distinto por cada
#                selector (la proteccion anti-pisado es por EXP_NUM)
#   SKIP         cantidad de semillas iniciales a saltear (default: 0)
#                util para resumir tras preemption: ej SKIP=1 saltea
#                la primera semilla (644857) y corre desde la 2da
#
# Requiere:
#   pip install papermill
#
# En GCE, correr dentro de tmux para que sobreviva a desconecciones:
#   tmux new -s semillas_exp1
#   bash run_semillas.sh 5 1 2>&1 | tee corrida_exp1.log
#   # Ctrl+B luego D para despegarse; la corrida sigue
#   # para ver progreso desde otra terminal:
#   tail -f corrida.log
#   grep "=== " corrida.log
#

set -uo pipefail

N_SEMILLAS="${1:-5}"
N_EXP="${2:-}"
SELECTOR="${3:-canarito}"
SKIP="${4:-0}"

if [[ -z "$N_EXP" ]]; then
  echo "ERROR: falta el numero de experimento (segundo parametro, obligatorio)" >&2
  echo "       uso: bash run_semillas.sh [N_SEMILLAS] N_EXP [SELECTOR]    ej: bash run_semillas.sh 5 1 boruta" >&2
  exit 1
fi

if [[ "$SELECTOR" != "canarito" && "$SELECTOR" != "boruta" ]]; then
  echo "ERROR: SELECTOR invalida: '$SELECTOR'  (valores: canarito | boruta)" >&2
  exit 1
fi

SUFIJO="_exp${N_EXP}"

NB="z950_WorkFlow_01_senior.ipynb"
NB_CORRIDA="corrida_activo${SUFIJO}.ipynb"

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

echo "=== SWEEP INICIO $(date)  N_SEMILLAS=$N_SEMILLAS  EXP=${N_EXP}  SELECTOR=${SELECTOR}  SKIP=${SKIP} ==="

tail -n +"$((SKIP+1))" semillas | head -n "$N_SEMILLAS" | while read -r s; do
  echo ""
  echo "=== INICIO corrida SEMILLA=$s EXP=${N_EXP} SELECTOR=${SELECTOR} $(date) ==="

  cp "$NB" "$NB_CORRIDA"

  if command -v papermill > /dev/null 2>&1; then
    # papermill: salida de cada celda en vivo en el log,
    #  y guarda el notebook ejecutado dentro de la carpeta del experimento
    SALIDA="exp/WF${N_EXP}_s${s}/salida_corrida${SUFIJO}.ipynb"
    mkdir -p "$(dirname "$SALIDA")"

    if env EXP_NUM="$N_EXP" SEMILLA="$s" SELECTOR="$SELECTOR" papermill \
        "$NB_CORRIDA" "$SALIDA" \
        --log-output \
        --cwd .; then
      echo "=== FIN OK SEMILLA=$s EXP=${N_EXP} SELECTOR=${SELECTOR} $(date) ==="
    else
      # log-and-continue: una corrida fallida no corta el sweep
      echo "=== FIN ERROR SEMILLA=$s EXP=${N_EXP} SELECTOR=${SELECTOR} $(date) ==="
    fi
  else
    # fallback sin papermill
    if env EXP_NUM="$N_EXP" SEMILLA="$s" SELECTOR="$SELECTOR" jupyter nbconvert \
        --to notebook --execute --inplace \
        --ExecutePreprocessor.timeout=-1 \
        "$NB_CORRIDA"; then
      echo "=== FIN OK SEMILLA=$s EXP=${N_EXP} SELECTOR=${SELECTOR} $(date) ==="
    else
      echo "=== FIN ERROR SEMILLA=$s EXP=${N_EXP} SELECTOR=${SELECTOR} $(date) ==="
    fi
  fi
done

echo ""
echo "=== SWEEP COMPLETO $(date) ==="

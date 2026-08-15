"""Descarga el historial de submissions propias de una competencia Kaggle.

Requisitos: CLI de Kaggle instalada y autenticada (kaggle.json o access_token en ~/.kaggle).

Salida en datasets/kaggle/submissions.csv y submissions.json
"""

import io
import json
import subprocess
import sys
from pathlib import Path

import pandas as pd

COMPETITION = "data-mining-inicial-2026-b"
OUT_DIR = Path(__file__).parent / "datasets" / "kaggle"


def main() -> int:
    result = subprocess.run(
        ["kaggle", "competitions", "submissions", "-c", COMPETITION, "--page-size", "200"],
        capture_output=True,
        text=True,
        check=True,
    )
    df = pd.read_fwf(io.StringIO(result.stdout))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = OUT_DIR / "submissions.csv"
    json_path = OUT_DIR / "submissions.json"
    df.to_csv(csv_path, index=False)
    json_path.write_text(json.dumps(df.astype(str).to_dict("records"), indent=2, ensure_ascii=False))

    print(f"{len(df)} submissions -> {csv_path}")
    print(df[["date", "fileName", "publicScore", "description"]].to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
#!/usr/bin/env bash
# Uma fatia do balanceamento (usado pelo workflow "Balanceamento" e à mão).
# Uso: tools/balance_run.sh PARTE TOTAL SEMENTES SEMENTES_EXTRAS NIVEIS RODA EXTRAS SAIDA
#   PARTE/TOTAL      fatia das 64 combinações de cada semente (--part=PARTE/TOTAL)
#   SEMENTES         sementes do balanceamento principal (32 ≈ 1.000 partidas por herói)
#   SEMENTES_EXTRAS  sementes de cada teste extra (peso de cada elo e Difícil × Normal)
#   NIVEIS           níveis dos bots no principal, ex.: hard,hard
#   RODA             on ou off
#   EXTRAS           true ou false
#   SAIDA            pasta dos logs
# Roda até $JOBS processos ao mesmo tempo (padrão: número de CPUs).
set -u
PART=$1; TOTAL=$2; SEEDS=$3; XSEEDS=$4; DIFFS=$5; WHEEL=$6; EXTRAS=$7; OUT=$8
GODOT=${GODOT:-godot}
JOBS=${JOBS:-$(nproc)}
mkdir -p "$OUT"
WARG=""
[ "$WHEEL" = "off" ] && WARG="--wheel=off"

tasks=()
for s in $(seq 0 $((SEEDS - 1))); do
  tasks+=("main $s --diffs=$DIFFS $WARG")
done
if [ "$EXTRAS" = "true" ]; then
  for s in $(seq 0 $((XSEEDS - 1))); do
    if [ "$WHEEL" != "off" ]; then
      for g in 0 1 2 3; do
        tasks+=("nobonus$g $s --diffs=hard,hard --nobonus=$g")
      done
    fi
    tasks+=("hardnormal $s --diffs=hard,normal $WARG")
  done
fi

run_task() {
  local kind=$1 s=$2; shift 2
  # Sementes distantes (cada uma usa 64 valores a partir de 1000 + deslocamento).
  "$GODOT" --headless --path . --script res://tests/simulate.gd -- --balance \
    --part="$PART/$TOTAL" --seed=$((s * 1000)) "$@" > "$OUT/${kind}_s${s}_p${PART}.log" 2>&1 || true
}

for t in "${tasks[@]}"; do
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 1; done
  # shellcheck disable=SC2086
  run_task $t &
done
wait
echo "fatia $PART/$TOTAL: ${#tasks[@]} execuções"

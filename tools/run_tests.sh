#!/usr/bin/env bash
# Roda o sistema de testes completo do Clockwork Gods.
#   tools/run_tests.sh               testes + simulação (12 partidas)
#   tools/run_tests.sh --matches=30  simulação mais longa
#   tools/run_tests.sh --shots DIR   também salva capturas de tela (precisa de xvfb-run)
# Variável GODOT: caminho do executável do Godot (padrão: godot).
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
MATCHES="--matches=12"
SHOTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --matches=*) MATCHES="$1" ;;
    --shots) SHOTS="$2"; shift ;;
  esac
  shift
done

fail=0
echo "== Importando projeto =="
timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== Compilação (erros de script) =="
out=$(timeout 120 "$GODOT" --headless --path . --quit 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error"; then
  echo "$out" | grep -A2 "SCRIPT ERROR\|Parse Error"; fail=1
else
  echo "ok"
fi

echo "== Testes de regras e regressão =="
timeout 900 "$GODOT" --headless --path . --script res://tests/tests.gd 2>&1 | tee /tmp/ichor_tests.log | grep -E "FALHOU|^\s{8}|testes,|SCRIPT ERROR"
if grep -q "FALHOU\|SCRIPT ERROR" /tmp/ichor_tests.log || ! grep -q "testes, 0 falharam" /tmp/ichor_tests.log; then fail=1; fi

echo "== Simulação de partidas =="
timeout 1800 "$GODOT" --headless --path . --script res://tests/simulate.gd -- "$MATCHES" 2>&1 | tee /tmp/ichor_sim.log | grep -vE "^\s*$|Godot Engine"
if ! grep -q "RESULTADO_SIMULACAO OK" /tmp/ichor_sim.log || grep -q "SCRIPT ERROR" /tmp/ichor_sim.log; then fail=1; fi

if [ -n "$SHOTS" ]; then
  echo "== Capturas de tela para revisão visual =="
  mkdir -p "$SHOTS"
  timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --shot="$SHOTS/menu.png" --shot-menu >/dev/null 2>&1
  for t in 5 30 70 120 180; do
    timeout 180 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --shot="$SHOTS/partida_${t}s.png" --shot-at=$t >/dev/null 2>&1
  done
  ls "$SHOTS"
fi

echo
if [ $fail -eq 0 ]; then echo "TUDO OK"; else echo "FALHAS ENCONTRADAS"; fi
exit $fail

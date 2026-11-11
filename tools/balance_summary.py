#!/usr/bin/env python3
"""Junta os logs de tools/balance_run.sh e escreve o resumo em Markdown.

Uso: python3 tools/balance_summary.py PASTA_DOS_LOGS [NIVEIS] [RODA] > balance.md

Linhas lidas de tests/simulate.gd:
  BAL heroi partidas vitórias      por herói, sem espelhos (empate = meia vitória)
  SIDE partidas vitórias0 vitórias1
  WHEEL nível n cartas elos cadências voltas   (por time e partida)
"""
import glob
import math
import os
import re
import sys

LOW, HIGH = 43.0, 57.0
HEROES = ["talos", "hercules", "artemis", "zeus", "asclepio", "atena"]
NAMES = {"talos": "Talos", "hercules": "Hércules", "artemis": "Ártemis",
         "zeus": "Zeus", "asclepio": "Asclépio", "atena": "Atena"}
GEARS = ["Defesa → Movimento (escudo)", "Movimento → Controle (+controle)",
         "Controle → Ataque (+dano)", "Ataque → Defesa (+defesa)"]
LEVELS = {"hard": "Difícil", "normal": "Normal", "easy": "Fácil"}


def pct(w, n):
    return 100.0 * w / n if n else 0.0


def margin(w, n):
    """Margem de erro de 95% em pontos percentuais."""
    if not n:
        return 0.0
    p = w / n
    return 196.0 * math.sqrt(p * (1 - p) / n)


def fmt(w, n, bold_out=True):
    p = pct(w, n)
    s = "%.1f%% ± %.1f" % (p, margin(w, n))
    if bold_out and n and (p < LOW or p > HIGH):
        s = "**%s**" % s
    return s


def read(folder):
    data = {}
    errors = 0
    for path in glob.glob(os.path.join(folder, "**", "*.log"), recursive=True):
        kind = re.sub(r"_s\d+_p\d+\.log$", "", os.path.basename(path))
        d = data.setdefault(kind, {"bal": {}, "side": [0, 0.0, 0.0], "wheel": {}, "runs": 0})
        d["runs"] += 1
        text = open(path, encoding="utf-8", errors="replace").read()
        if "SCRIPT ERROR" in text:
            errors += 1
        for line in text.splitlines():
            f = line.split()
            if not f:
                continue
            if f[0] == "BAL" and len(f) == 4:
                g, w = d["bal"].get(f[1], (0, 0.0))
                d["bal"][f[1]] = (g + int(f[2]), w + float(f[3]))
            elif f[0] == "SIDE" and len(f) == 4:
                d["side"][0] += int(f[1])
                d["side"][1] += float(f[2])
                d["side"][2] += float(f[3])
            elif f[0] == "WHEEL" and len(f) == 7:
                acc = d["wheel"].setdefault(f[1], [0, 0, 0, 0, 0])
                for i in range(5):
                    acc[i] += int(f[2 + i])
    return data, errors


def main():
    folder = sys.argv[1]
    diffs = sys.argv[2] if len(sys.argv) > 2 else "hard,hard"
    wheel = sys.argv[3] if len(sys.argv) > 3 else "on"
    data, errors = read(folder)
    out = []
    main_d = data.get("main")
    out.append("# Balanceamento")
    out.append("")
    if not main_d:
        out.append("Nenhum resultado encontrado.")
        print("\n".join(out))
        return
    n_main = main_d["side"][0]
    lv = " × ".join(LEVELS.get(x, x) for x in diffs.split(","))
    out.append("Bots %s, comportamento Equilibrado, Roda do Destino %s. %d partidas (64 combinações de times por semente). "
               "Margem de erro de 95%%. Em **negrito**: fora de %d%% a %d%%." %
               (lv, "ligada" if wheel != "off" else "desligada", n_main, LOW, HIGH))
    out.append("")
    out.append("## Taxa de vitória por herói")
    out.append("")
    out.append("| Herói | Vitória | Partidas |")
    out.append("| --- | --- | --- |")
    for h in HEROES:
        g, w = main_d["bal"].get(h, (0, 0.0))
        out.append("| %s | %s | %d |" % (NAMES[h], fmt(w, g), g))
    s = main_d["side"]
    out.append("")
    out.append("Lado azul (time 0): %s em %d partidas." % (fmt(s[1], s[0], False), s[0]))

    base = main_d["side"]
    links = [(g, data.get("nobonus%d" % g)) for g in range(4)]
    if any(d for _, d in links):
        out.append("")
        out.append("## Peso de cada elo da Roda do Destino")
        out.append("")
        out.append("O time azul joga sem o bônus de um elo; o vermelho tem a roda inteira (bots Difícil × Difícil). "
                   "Diferença = vitória do azul sem o bônus menos a do azul com a roda inteira. "
                   "Em **negrito**: diferença maior que %d pontos (o elo levaria um time de 50%% para fora de %d%% a %d%%)." % (HIGH - 50, LOW, HIGH))
        out.append("")
        out.append("| Sem o bônus de | Vitória do azul | Diferença | Partidas |")
        out.append("| --- | --- | --- | --- |")
        b_ok = diffs == "hard,hard" and wheel != "off"
        for g, d in sorted(links, key=lambda x: [1, 2, 3, 0].index(x[0])):
            if not d:
                continue
            n, w = d["side"][0], d["side"][1]
            diff = "—"
            if b_ok and base[0] and n:
                dv = pct(w, n) - pct(base[1], base[0])
                dm = math.hypot(margin(w, n), margin(base[1], base[0]))
                diff = "%+.1f ± %.1f" % (dv, dm)
                if abs(dv) > HIGH - 50:
                    diff = "**%s**" % diff
            out.append("| %s | %s | %s | %d |" % (GEARS[g], fmt(w, n, False), diff, n))

    if not any(d for _, d in links) and not data.get("hardnormal"):
        out.append("")
        out.append("Testes da Roda e da IA desligados nesta rodada (só o equilíbrio dos heróis).")

    hn = data.get("hardnormal")
    if hn:
        n, w = hn["side"][0], hn["side"][1]
        out.append("")
        out.append("## Difícil × Normal")
        out.append("")
        out.append("Difícil (azul) venceu %s em %d partidas." % (fmt(w, n, False), n))
        rows = []
        for lvl in ["hard", "normal"]:
            acc = hn["wheel"].get(lvl)
            if acc and acc[0]:
                k = acc[0]
                rows.append("| %s | %.1f | %.1f | %.2f | %.2f |" %
                            (LEVELS[lvl], acc[1] / k, acc[2] / k, acc[3] / k, acc[4] / k))
        if rows:
            out.append("")
            out.append("| Bot | Cartas | Elos | Cadências | Voltas completas |")
            out.append("| --- | --- | --- | --- | --- |")
            out.extend(rows)
            out.append("")
            out.append("(por time e partida)")

    if main_d["wheel"]:
        out.append("")
        out.append("## Roda do Destino no balanceamento principal (por time e partida)")
        out.append("")
        out.append("| Bot | Cartas | Elos | Cadências | Voltas completas |")
        out.append("| --- | --- | --- | --- | --- |")
        for lvl, acc in sorted(main_d["wheel"].items()):
            k = max(1, acc[0])
            out.append("| %s | %.1f | %.1f | %.2f | %.2f |" %
                       (LEVELS.get(lvl, lvl), acc[1] / k, acc[2] / k, acc[3] / k, acc[4] / k))
    if errors:
        out.append("")
        out.append("**Atenção: %d execuções tiveram SCRIPT ERROR** (ver os logs no artefato balance-logs)." % errors)
    print("\n".join(out))


if __name__ == "__main__":
    main()

"""Compara las operaciones reales de la demo con las del Strategy Tester en el mismo periodo.

Uso: python tools/compare_demo.py demo.csv informe.htm [--symbol EURUSD]
demo.csv sale de tools/export_history.py. Se emparejan por día y dirección
(el EA abre como mucho una operación al día por símbolo).
"""
import argparse
import csv
from datetime import datetime

from compare_trades import leer_tabla

FMT = "%Y.%m.%d %H:%M:%S"


def num(x):
    return float(str(x).replace(" ", "")) if str(x).strip() else None


def tester_operaciones(ruta):
    """Una fila por entrada del tester, con SL/TP de la orden y motivo de salida."""
    ordenes = leer_tabla(ruta, ("S / L", "T / P"))
    deals = leer_tabla(ruta, ("Deal", "Direction"))
    ops, abierta = [], None
    sltp = {o["Order"]: (num(o["S / L"]), num(o["T / P"])) for o in ordenes}
    for d in deals:
        if d["Direction"] == "in":
            sl, tp = sltp.get(d["Order"], (None, None))
            abierta = {"open_time": d["Time"], "direction": d["Type"], "open_price": num(d["Price"]),
                       "sl": sl, "tp": tp}
            ops.append(abierta)
        elif d["Direction"] == "out" and abierta:
            abierta["close_time"] = d["Time"]
            abierta["close_reason"] = d["Comment"]
            abierta = None
    return ops


def motivo(c):
    c = (c or "").lower()
    return "tp" if "tp" in c else "sl" if "sl" in c else c or "?"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("demo")
    ap.add_argument("informe")
    ap.add_argument("--symbol", default="EURUSD")
    a = ap.parse_args()

    with open(a.demo, encoding="utf-8") as f:
        demo = [r for r in csv.DictReader(f) if r["symbol"] == a.symbol]
    test = tester_operaciones(a.informe)
    inicio = min(r["open_time"] for r in demo)[:10] if demo else ""
    test = [t for t in test if t["open_time"][:10] >= inicio]

    clave = lambda fecha, dirc: (fecha[:10], dirc)
    td = {clave(t["open_time"], t["direction"]): t for t in test}
    dd = {clave(r["open_time"], r["direction"]): r for r in demo}

    print(f"Demo: {len(demo)} operaciones {a.symbol} desde {inicio}; tester: {len(test)} en el mismo periodo\n")
    print(f"{'dia':10} {'dir':4} | {'entrada demo':8} {'tester':8} {'dif s':>5} | {'SL demo':>8} {'tester':>8} | "
          f"{'TP demo':>8} {'tester':>8} | salida demo/tester")
    for k in sorted(set(td) | set(dd)):
        r, t = dd.get(k), td.get(k)
        if not r or not t:
            print(f"{k[0]} {k[1]:4} | SOLO EN {'TESTER' if t else 'DEMO'}: {(t or r)['open_time']}")
            continue
        dt = (datetime.strptime(r["open_time"], FMT) - datetime.strptime(t["open_time"], FMT)).total_seconds()
        print(f"{k[0]} {k[1]:4} | {r['open_time'][11:]} {t['open_time'][11:]} {dt:>5.0f} | "
              f"{num(r['sl']):>8.5f} {t['sl'] or 0:>8.5f} | {num(r['tp']):>8.5f} {t['tp'] or 0:>8.5f} | "
              f"{motivo(r['close_reason'])}/{motivo(t.get('close_reason'))}")


if __name__ == "__main__":
    main()

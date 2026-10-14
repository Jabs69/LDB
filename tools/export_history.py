"""Exporta las operaciones de un EA desde el terminal MT5 abierto a un CSV.

Uso: python tools/export_history.py salida.csv [--magic 123456] [--desde 2026-01-01]
Una fila por posición: entrada, SL/TP iniciales, salida, motivo de cierre y PnL neto.
"""
import argparse
import csv
from datetime import datetime, timedelta

import MetaTrader5 as mt5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("salida")
    ap.add_argument("--magic", type=int, default=123456)
    ap.add_argument("--desde", default="2020-01-01")
    args = ap.parse_args()

    if not mt5.initialize():
        raise SystemExit(f"No se pudo conectar al terminal: {mt5.last_error()}")
    cuenta = mt5.account_info()
    print(f"Cuenta {cuenta.login} ({cuenta.server}), balance {cuenta.balance:.2f} {cuenta.currency}")

    desde = datetime.fromisoformat(args.desde)
    hasta = datetime.now() + timedelta(days=2)
    deals = mt5.history_deals_get(desde, hasta) or ()
    ordenes = {o.ticket: o for o in (mt5.history_orders_get(desde, hasta) or ())}

    posiciones = {}
    for d in deals:
        if d.magic != args.magic and d.entry == mt5.DEAL_ENTRY_IN:
            continue
        p = posiciones.setdefault(d.position_id, {"in": None, "out": []})
        if d.entry == mt5.DEAL_ENTRY_IN:
            p["in"] = d
        elif d.entry in (mt5.DEAL_ENTRY_OUT, mt5.DEAL_ENTRY_OUT_BY):
            p["out"].append(d)

    filas = []
    for pid, p in sorted(posiciones.items(), key=lambda kv: kv[1]["in"].time if kv[1]["in"] else 0):
        e = p["in"]
        if e is None:
            continue
        orden = ordenes.get(e.order)
        cerrada = bool(p["out"])
        s = p["out"][-1] if cerrada else None
        neto = e.commission + e.swap + e.fee + sum(x.profit + x.commission + x.swap + x.fee for x in p["out"])
        filas.append({
            "position": pid,
            "symbol": e.symbol,
            "direction": "buy" if e.type == mt5.DEAL_TYPE_BUY else "sell",
            "volume": e.volume,
            "open_time": datetime.utcfromtimestamp(e.time).strftime("%Y.%m.%d %H:%M:%S"),
            "open_price": e.price,
            "sl": orden.sl if orden else "",
            "tp": orden.tp if orden else "",
            "close_time": datetime.utcfromtimestamp(s.time).strftime("%Y.%m.%d %H:%M:%S") if cerrada else "",
            "close_price": s.price if cerrada else "",
            "close_reason": s.comment if cerrada else "abierta",
            "net_pnl": round(neto, 2) if cerrada else "",
        })

    with open(args.salida, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(filas[0]) if filas else ["position"])
        w.writeheader()
        w.writerows(filas)
    print(f"{len(filas)} posiciones del magic {args.magic} -> {args.salida}")
    mt5.shutdown()


if __name__ == "__main__":
    main()

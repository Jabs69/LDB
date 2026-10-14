"""Compara las operaciones de dos informes del Strategy Tester de MT5 (.htm).

Uso: python tools/compare_trades.py informe_A.htm informe_B.htm
"""
import sys
from html.parser import HTMLParser


class _Tablas(HTMLParser):
    """Extrae todas las filas de tabla como listas de textos de celda."""

    def __init__(self):
        super().__init__()
        self.filas, self._fila, self._celda = [], None, None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self._fila = []
        elif tag in ("td", "th") and self._fila is not None:
            self._celda = []

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self._celda is not None:
            self._fila.append("".join(self._celda).strip())
            self._celda = None
        elif tag == "tr" and self._fila is not None:
            self.filas.append(self._fila)
            self._fila = None

    def handle_data(self, data):
        if self._celda is not None:
            self._celda.append(data)


def leer_tabla(ruta, marcadores):
    """Devuelve como diccionarios las filas de la tabla cuya cabecera contiene todos los marcadores."""
    with open(ruta, "rb") as f:
        crudo = f.read()
    texto = crudo.decode("utf-16") if crudo[:2] in (b"\xff\xfe", b"\xfe\xff") else crudo.decode("utf-8", "replace")
    p = _Tablas()
    p.feed(texto)

    cab, filas = None, []
    for fila in p.filas:
        if cab is None:
            if all(m in fila for m in marcadores):
                cab = fila
            continue
        if len(fila) != len(cab):
            if filas:
                break
            continue
        filas.append(dict(zip(cab, fila)))
    if cab is None:
        raise ValueError(f"No encontré la tabla {marcadores} en {ruta}")
    return filas


def leer_deals(ruta):
    return leer_tabla(ruta, ("Deal", "Direction"))


def operaciones(deals):
    """Entradas y salidas del EA, sin el depósito inicial."""
    ent = [d for d in deals if d.get("Direction") == "in"]
    sal = [d for d in deals if d.get("Direction") == "out"]
    return ent, sal


def clave(d):
    return (d["Time"], d["Type"], d["Price"])


def resumen(nombre, ent, sal):
    beneficio = sum(float(d["Profit"].replace(" ", "")) for d in sal)
    ganadoras = sum(1 for d in sal if float(d["Profit"].replace(" ", "")) > 0)
    print(f"{nombre}: {len(ent)} entradas, {len(sal)} salidas, "
          f"{ganadoras} salidas con beneficio, beneficio total {beneficio:,.2f}")


def main(a, b):
    ent_a, sal_a = operaciones(leer_deals(a))
    ent_b, sal_b = operaciones(leer_deals(b))
    resumen("A", ent_a, sal_a)
    resumen("B", ent_b, sal_b)

    for etiqueta, la, lb in (("ENTRADAS", ent_a, ent_b), ("SALIDAS", sal_a, sal_b)):
        ka, kb = {clave(d) for d in la}, {clave(d) for d in lb}
        solo_a, solo_b = sorted(ka - kb), sorted(kb - ka)
        print(f"\n{etiqueta}: {len(ka & kb)} iguales, {len(solo_a)} solo en A, {len(solo_b)} solo en B")
        for k in solo_a:
            print("  solo A:", *k)
        for k in solo_b:
            print("  solo B:", *k)

    dias = {}
    for d in ent_a:
        dias.setdefault(d["Time"][:10], []).append(d["Type"])
    dobles = {k: v for k, v in dias.items() if len(v) > 1}
    print(f"\nDías con más de una entrada en A: {len(dobles)}")
    for k, v in sorted(dobles.items()):
        print("  ", k, v)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

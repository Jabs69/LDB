# Análisis de la estrategia LondonBreakout (v1.81)

Revisión de la lógica del EA, comparación con modelos conocidos y cuatro pruebas para saber si la ventaja es real o ajuste al pasado. Datos: Strategy Tester de MT5 con la cuenta IC Markets demo, 10.000 USD, riesgo 0,5 % por operación, comisiones incluidas.

## Resumen

- La idea es coherente y tiene antecedentes conocidos (Turtle Soup y barridas de liquidez del rango de Asia).
- La señal **sí aporta algo frente al azar**. El EA supera al 95,7 % de 300 carteras de entradas al azar con las mismas horas, distancias y costes. Operar en la dirección contraria pierde −29R.
- Pero **la ventaja neta es pequeña y frágil**:
  - +515 USD en 5 años, con un estadístico t de 0,49.
  - Las comisiones se comen el 63 % del beneficio bruto.
  - El resultado cambia mucho según cómo simule los ticks el tester.
  - Con la misma lógica, en otros pares pierde en 3 de 4.
- Los parámetros están en una zona estable (meseta), sobre todo la hora de fin de Asia en 9. Aun así, optimizar a ciegas en un periodo y aplicarlo en el siguiente falla.

## Qué hace la estrategia

| Paso | Regla |
| --- | --- |
| Rango de Asia | Máximo y mínimo de las velas H1 de 00:00 a 08:00 (hora del servidor, GMT+2/+3) |
| Señal | La vela H1 de 09:00 o de 10:00 rompe el rango con la mecha, cierra dentro y la mecha mide más de 1,5 veces el cuerpo |
| Entrada | En contra de la ruptura, durante la hora siguiente, en cuanto el precio dé un ratio de al menos 2,4 |
| Salidas | SL 1 pip más allá de la mecha. TP en el extremo opuesto del rango de Asia. Break-even a 2R |
| Filtros | Spread de 30 puntos como máximo, no opera los viernes, una operación al día |

En hora de Londres, la vela de 09:00 del servidor es la de 07:00 y la de 10:00 es la de 08:00. Es decir, opera justo en la apertura de Londres.

## Comparación con modelos conocidos

| Modelo | Relación | Evidencia |
| --- | --- | --- |
| Turtle Soup (Connors y Raschke, 1995) | Mismo principio: ir en contra de una ruptura fallida. El original usa máximos de 20 días. | Fue conocido, pero se considera muy erosionado. |
| "Judas swing" o barrida del rango de Asia (ICT) | Prácticamente esta estrategia. | Casi todo anecdótico, sin estudios rigurosos conocidos. |
| Ruptura del rango de apertura (Crabel, London Breakout clásico) | Lo contrario: sigue la ruptura. | Mixta, más fuerte en los años 90 y 2000. |
| Momentum de tendencia y carry en divisas (Moskowitz, Ooi y Pedersen 2012; Lustig y Verdelhan) | Los efectos más robustos documentados en FX, a horizontes de semanas o meses. | Sólida. |

El efecto intradía bien documentado es que la volatilidad sube en la apertura de Londres. Eso no indica dirección. La estrategia se apoya en un patrón razonable, no en un efecto con respaldo estadístico conocido.

## Resultados base: EURUSD de 2021 a enero de 2026

Modo "cada tick" con ticks generados. El broker solo tiene ticks reales desde abril de 2026. R = riesgo de una operación, unos 50 USD.

| | |
| --- | --- |
| Operaciones | 183: 50 TP, 113 SL, unas 20 en break-even |
| Ganancia media / pérdida media | +2,71R / −1,10R |
| Expectativa | +0,06R por operación, t = 0,49 (hace falta más de 2 para descartar el azar) |
| Beneficio bruto / comisiones / neto | +1.396 / −875 / **+515 USD** |
| Drawdown máximo | −17,5R |
| Por año | 2021 +4,0R · 2022 −8,3R · 2023 +9,8R · 2024 −3,9R · 2025 +12,0R |
| Compras / ventas | +17,4R / −6,0R |
| Entradas a las 10 / a las 11 | +12,9R / −1,5R |
| Abril a octubre de 2026, ticks reales | −2,4R en 23 operaciones. La demo también está en negativo. |

## Pruebas

### 1. ¿La señal es mejor que el azar?

Se hizo con una variante del EA solo para pruebas, `tools/pruebas/LB_pruebas.mq5`. En modo 0 reproduce exactamente la v1.81: las mismas 183 operaciones y el mismo resultado.

| Prueba | Resultado (5 años) |
| --- | --- |
| EA v1.81 | +515 USD (+11,4R) |
| Misma señal, dirección contraria (modo 1) | −29,1R, t = −1,41 |
| 300 carteras al azar (modo 2) | Media −1.228 USD · p5 −2.593 · mediana −1.280 · p95 +386 |
| **EA frente al azar** | **Supera al 95,7 % de las carteras** |

Cómo se construyen las carteras al azar: se opera un día de lunes a jueves con la misma probabilidad que el EA (unas 175 operaciones). El minuto es al azar entre las 10:00 y las 11:59 y la dirección también. El SL y el ratio del TP se toman de las 183 operaciones reales. Spread, comisiones y break-even son los mismos.

**Lectura:** operar a esas horas con esos stops pierde de media unos −24R en 5 años, solo por costes (spread más comisión, con stops de unos 8 pips). La señal de la mecha mejora eso en unos 35R. Eso es información real con p ≈ 0,04. Pero apenas alcanza para cubrir los costes.

**Advertencia:** esta prueba usa el mismo periodo en el que se eligieron los parámetros, así que el 95,7 % está algo inflado.

### 2. Misma lógica en otros pares, sin reoptimizar

| Par | Operaciones | Total | Expectativa | t |
| --- | --- | --- | --- | --- |
| EURUSD | 183 | +11,4R | +0,06R | 0,49 |
| GBPUSD | 206 | −9,1R | −0,04R | −0,39 |
| EURGBP | 215 | −52,0R | −0,24R | −2,35 |
| AUDUSD | 162 | −32,3R | −0,20R | −1,33 |
| USDJPY | 143 | +9,1R | +0,06R | 0,42 |

El patrón no se generaliza. EURGBP pierde de forma significativa. Puede ser que los parámetros solo encajen en EURUSD o que el efecto sea específico del par. En cualquier caso, la idea de "barrida del rango de Asia" no funciona por sí sola en cualquier par.

### 3. Robustez de parámetros: dentro y fuera de muestra

Se probaron todas las combinaciones de una malla de 756: fin de Asia 7–10, ventana 2–4 h, ratio 1,6–3,2 y mecha 1,0–2,5. El periodo de 2021–2023 se usa como dentro de muestra y el de 2024 a enero de 2026 como fuera de muestra. Modo OHLC de 1 minuto. Beneficio neto en USD.

| | 2021–2023 | 2024–2026 |
| --- | --- | --- |
| Combinaciones positivas | 449 de 756 | 179 de 756 |
| Mediana | +227 | −426 |
| Tus parámetros (9 / 3 / 2,4 / 1,5) | +883 (puesto 138) | +615 (puesto 47) |
| Las 20 mejores de 2021–2023, en 2024–2026 | — | media −311, solo 2 positivas |

Correlación de rangos entre periodos: 0,44.

Fin de Asia × ventana, con ratio 2,4 y mecha 1,5 (2021–2023 / 2024–2026):

| Fin de Asia | 2 h | 3 h | 4 h |
| --- | --- | --- | --- |
| 7 | −1.411 / −1.296 | −145 / −1.505 | 332 / −1.612 |
| 8 | 517 / −536 | 1.014 / 75 | 738 / 318 |
| **9** | 925 / 798 | **883 / 615** | −106 / 1.234 |
| 10 | −592 / −515 | −1.308 / −424 | 151 / −796 |

Ratio × mecha, con fin de Asia 9 y ventana 3 (2021–2023 / 2024–2026):

| Ratio \ Mecha | 1,0 | 1,25 | 1,5 | 1,75 | 2,0 | 2,25 | 2,5 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1,6 | 822 / −290 | 686 / −51 | 567 / 280 | 822 / 15 | 635 / −177 | 307 / −142 | 515 / −395 |
| 2,0 | 991 / −219 | 833 / 266 | 639 / 671 | 804 / 370 | 681 / 96 | 326 / 201 | 517 / −62 |
| 2,4 | 808 / −209 | 559 / 282 | **883 / 615** | 1.003 / 266 | 846 / 204 | 803 / 197 | 962 / 22 |
| 2,8 | 1.148 / −340 | 904 / −41 | 895 / 353 | 1.009 / 134 | 702 / 72 | 779 / 123 | 947 / −49 |
| 3,2 | 1.124 / −178 | 916 / 193 | 1.065 / 589 | 1.249 / 331 | 1.078 / 269 | 1.105 / 392 | 1.115 / 214 |

**Lectura:**

- **Lo estable:** fin de Asia en 9 es positivo en los dos periodos. Con 7 o con 10 es negativo en los dos. La hora de la apertura de Londres es lo que más pesa.
- **Tus parámetros caen en una meseta.** Con mecha de 1,5 a 2,25, casi todo sigue positivo fuera de muestra.
- **Optimizar el máximo falla.** El mejor de 2021–2023 (fin 8, ratio 3,2, mecha 1,0) pierde después. Si la optimización genética original incluyó 2024–2025, los +615 de ese periodo tampoco están fuera de muestra.

### 4. Sensibilidad al modelo de ticks

Mismas 183 operaciones en 2021–2026, misma v1.81:

| Modelo del tester | Total |
| --- | --- |
| OHLC de 1 minuto | +30,3R (t = 1,20) |
| Cada tick, generado | +11,4R (t = 0,49) |

Abril a octubre de 2026, con ticks reales disponibles:

| Modelo | Neto |
| --- | --- |
| Ticks reales | −128,62 USD (23 operaciones) |
| Cada tick, generado | −192,42 USD (21 operaciones) |
| OHLC de 1 minuto | −173,54 USD (21 operaciones) |

El resultado depende de cómo se simula el precio dentro de la hora. El motivo es que la entrada espera a que el precio dé un ratio de 2,4, y eso pasa con picos de décimas de pip. El barrido de parámetros con OHLC de 1 minuto da cifras optimistas en valor absoluto. Sirve para comparar combinaciones entre sí, no para estimar beneficios.

## Problemas de lógica detectados

1. **Sobreajuste posible.** Hay unos 8 parámetros elegidos sobre el mismo histórico con una optimización genética de alcance limitado.
2. **El filtro de ratio selecciona entradas al revés.** El EA espera a que el precio vuelva hacia la mecha. La mediana del ratio de entrada es 2,455: casi todas las entradas ocurren justo cuando el precio toca el 2,4. Las entradas tardías (a las 11) suman en negativo.
3. **SL muy ajustado.** La distancia mediana es de 7,9 pips. Con 1 pip de margen más allá de la mecha, en las ventas el SL salta con el ask, así que el margen real es 1 pip menos el spread. Además, el coste fijo (spread más comisión) pesa unos 0,12–0,14R por operación.
4. **El break-even a 2R casi no influye.** El TP siempre está en 2,4R o más.
5. **Compras y ventas asimétricas** (+17,4R / −6,0R). Encaja más con la tendencia del EURUSD en el periodo que con el patrón.

## Conclusión y siguientes pasos

La señal tiene algo de información: es mejor que el azar y mucho mejor que la dirección contraria. Pero el margen sobre los costes es tan estrecho que el resultado neto no se distingue de cero, y no se generaliza a otros pares. Para el meta labeling esto es relevante. La red puede ayudar si aprende a descartar operaciones malas, sobre todo porque el problema principal son los costes frente a stops pequeños. Pero la muestra es pequeña y la base, débil.

Ideas con más fundamento que reoptimizar:

1. **Reducir el peso de los costes.**
   - Estudiar un SL con más margen (por ejemplo, más el spread o una fracción del ATR).
   - Entrar al cierre de la vela de señal en lugar de esperar el ratio de 2,4, para medir si ese filtro aporta o resta.
2. **Quedarse con la parte estable:** solo la vela de 09:00 (entradas a las 10), que concentra el resultado (+12,9R frente a −1,5R).
3. **Validar con ticks reales** a partir de abril de 2026, en demo, sin tocar parámetros.

## Criterios para decidir: seguir o descartar

### Qué dice la literatura

| Criterio | Fuente | Regla |
| --- | --- | --- |
| Significancia ajustada por búsqueda | Harvey, Liu y Zhu, *Review of Financial Studies* 2016 | Tras probar muchas variantes, el estadístico t de la expectativa debe superar 3,0, no el 2,0 clásico. |
| Sobreajuste por número de pruebas (MinBTL) | Bailey, Borwein, López de Prado y Zhu, *Notices of the AMS* 2014 | Con solo 7 configuraciones cabe esperar por azar un backtest de 2 años con Sharpe anual mayor que 1. Cuantas más pruebas, más largo debe ser el backtest. Con sobreajuste, el resultado fuera de muestra suele ser negativo. |
| Probabilidad de sobreajuste (PBO, con CSCV) | Bailey, Borwein, López de Prado y Zhu, *Journal of Computational Finance* 2017 | Se divide el histórico en bloques y se mide cuántas veces la mejor configuración de un tramo queda por debajo de la mediana en el resto. Con un PBO ≥ 0,5 se descarta. |
| Sharpe deflactado (DSR) | Bailey y López de Prado, *Journal of Portfolio Management* 2014 | Corrige el Sharpe por el número de pruebas y por colas no normales. |

### Dónde está la v1.81

- **Estadístico t:** de 0,49 (cada tick) a 1,20 (OHLC de 1 minuto). El umbral es 3,0, y eso sin descontar la optimización genética ni las 756 combinaciones del barrido.
- **Sharpe anual:** unos 0,2 (cada tick) o 0,5 (OHLC). Está dentro de lo que se obtiene por azar con ese número de pruebas.
- **Fuera de muestra:** las mejores combinaciones de 2021–2023 pierden en 2024–2026. Es el síntoma de sobreajuste que describe la literatura.
- **A favor:** supera al 95,7 % de las carteras al azar y la dirección contraria pierde.

### Tamaño de muestra necesario

| Escenario | Operaciones para t = 3 | Años con ~36 operaciones al año |
| --- | --- | --- |
| Cada tick (+0,062R, sd 1,73R) | ~7.000 | ~190 |
| OHLC de 1 minuto (+0,166R, sd 1,87R) | ~1.150 | ~32 |

Con esta frecuencia, ni más histórico ni la demo pueden demostrar la ventaja en un solo par. Más pares darían más muestra, pero 3 de 4 salieron negativos.

### Ronda final propuesta (pendiente de decidir)

No seguir optimizando parámetros: cada ronda suma pruebas y aumenta el sobreajuste. Una única ronda, con criterios fijados antes de ver resultados:

1. **Histórico sin tocar:** v1.81 con los parámetros actuales en 2019–2020, si el broker tiene esa historia. Se descarta si sale negativa.
2. **PBO con CSCV:** barrido de 756 combinaciones en unos 8 bloques de tiempo. Se descarta si el PBO es ≥ 0,5.
3. **Como mucho 2 o 3 cambios de estructura**, declarados de antemano y sin optimizar:
   - Solo la vela de 09:00.
   - SL con margen de spread o ATR.
   - Entrar al cierre de la vela en lugar de esperar el ratio de 2,4.

   Se aceptan solo si mejoran en 2021–2023, en 2024–2026 y en 2019–2020.

Si pasa los puntos 1 y 2, se sigue en demo con ticks reales, sin cambios, solo como seguimiento. Si no los pasa, se descarta.

### Fuentes

- [Pseudo-Mathematics and Financial Charlatanism](https://carmamaths.org/jon/backtest.pdf) (Bailey, Borwein, López de Prado y Zhu, 2014)
- [. . . and the Cross-Section of Expected Returns](https://www.nber.org/papers/w20592) (Harvey, Liu y Zhu). Crítica del umbral: [Chen, arXiv 2206.15365](https://arxiv.org/pdf/2206.15365)
- [The Probability of Backtest Overfitting](https://papers.ssrn.com/abstract=2326253) (Bailey, Borwein, López de Prado y Zhu)

## Cómo reproducirlo

```powershell
# Base y otros pares (cada tick)
.\tools\run_backtest.ps1 -Source LondonBreakout.mq5 -Name LB_v181_GBPUSD -Symbol GBPUSD
# Dirección contraria y carteras al azar
.\tools\run_backtest.ps1 -Source tools\pruebas\LB_pruebas.mq5 -Name LB_p_inv -Inputs "InpModo=1"
.\tools\run_backtest.ps1 -Source tools\pruebas\LB_pruebas.mq5 -Name LB_p_azar -Optimization 1 -Inputs "InpModo=2||2||0||2||N","InpSemilla=1||1||1||300||Y"
# Barrido de parámetros (repetir con -From 2024.01.01 -To 2026.02.01 -Name LB_opt_OOS)
.\tools\run_backtest.ps1 -Source LondonBreakout.mq5 -Name LB_opt_IS -From 2021.01.01 -To 2024.01.01 -Model 1 -Optimization 1 -Inputs "InpHoraFinAsia=9||7||1||10||Y","InpHorasVentana=3||2||1||4||Y","InpRatioMinimo=2.4||1.6||0.2||3.2||Y","InpFactorMecha=1.5||1.0||0.25||2.5||Y"
```

MT5 debe estar cerrado: el script abre el terminal, corre la prueba y lo cierra.

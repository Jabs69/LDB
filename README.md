# Bot de fluidez
## derechos reservadoss
# hola

## Estructura del repositorio

- `LDB/`: Expert Advisors y pruebas de London Breakout.
- `Fluidez/`: Expert Advisors y módulos del bot Fluidez.
- `docs/`: análisis y notas del proyecto.
- `tools/`: scripts para backtests y análisis.

Dentro de `Fluidez/`, los módulos se dividen así:

- `Fluidez.mq5`: inicialización, eventos del EA y coordinación del ciclo.
- `Fluidez_Config.mqh`: parámetros, enumeraciones y estado compartido.
- `Fluidez_Estrategia.mqh`: reconstrucción de rango, detección de entrada y niveles.
- `Fluidez_Gestion.mqh`: cálculo de lotes, operaciones e historial.
- `Fluidez_Graficos.mqh`: dibujo del rango y del retroceso de Fibonacci.

Mantén los módulos `.mqh` junto a `Fluidez.mq5` para que las inclusiones locales se resuelvan al compilar.

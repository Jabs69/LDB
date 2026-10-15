# Bot de fluidez
## derechos reservadoss
# hola

## Estructura de Fluidez.mq5

- `Fluidez.mq5`: inicialización, eventos del EA y coordinación del ciclo.
- `Fluidez_Config.mqh`: parámetros, enumeraciones y estado compartido.
- `Fluidez_Estrategia.mqh`: reconstrucción de rango, detección de entrada y niveles.
- `Fluidez_Gestion.mqh`: cálculo de lotes, operaciones e historial.
- `Fluidez_Graficos.mqh`: dibujo del rango y del retroceso de Fibonacci.

Los módulos `.mqh` deben mantenerse junto a `Fluidez.mq5` para que sus inclusiones locales se resuelvan al compilar.

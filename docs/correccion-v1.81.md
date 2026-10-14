# Corrección del EA London Breakout v1.81: qué se arregló y por qué

Fecha: 2026-10-14

## Resumen

La versión 1.81 del EA corrige tres fallos de programación. Ninguno cambia la estrategia: el rango de Asia, la regla de la mecha, el stop, el objetivo, el ratio mínimo de 2,4, el break-even y el riesgo por operación siguen igual. Los parámetros (inputs) tampoco cambian, así que los archivos de configuración actuales siguen sirviendo.

Los tres fallos tienen algo en común: casi nunca aparecen en el Strategy Tester, porque allí el robot corre de forma continua, sin interrupciones. Aparecen en la cuenta real o demo, cuando el robot se reinicia o cuando se da una vela muy poco habitual.

| Fallo | Cuándo aparece | Qué podía pasar |
| --- | --- | --- |
| 1. Rango de Asia mal medido | Si el robot se enciende o reinicia después de las 09:00 | Rango más grande que el real: señales perdidas o con otro objetivo |
| 2. El robot olvida que ya operó | Si se reinicia después de abrir la operación del día | Una segunda operación el mismo día, con el doble de riesgo |
| 3. Compra y venta a la vez | Una vela que barre el rango de Asia por arriba y por abajo | Dos operaciones opuestas abiertas al mismo tiempo |

Hay además una observación sobre la estrategia, la hora 9, que no se ha tocado porque es una decisión tuya (ver más abajo).

## Fallo 1: el rango de Asia podía incluir velas de después de las 09:00

**Qué debería pasar.** El rango de Asia es el máximo y el mínimo de las velas H1 de 00:00 a 08:00, es decir, de 00:00 a 08:59. La vela de las 09:00 ya es Londres y no debería contar.

**Qué hacía el código.** Pedía las velas "desde las 00:00 hasta la vela de las 09:00, incluida". En el funcionamiento normal esto casi no se nota: el robot mide el rango en el primer tick de las 09:00, cuando esa vela acaba de abrir y apenas tiene precio propio.

**Cuándo sí se nota.** El robot no guarda el rango en ningún sitio. Si se reinicia (corte del VPS, actualización de MetaTrader, cambio de parámetros, cerrar y abrir el gráfico), vuelve a medirlo en ese momento. Ejemplo con un reinicio a las 10:30:

- El robot mide desde las 00:00 hasta la vela de las 09:00, ahora completa.
- Si la vela de 09:00 fue justo el falso rompimiento (la mecha que sale del rango), esa mecha pasa a formar parte del "rango de Asia".
- Como la mecha ya no sale del rango, la señal desaparece. Si había otra señal, el objetivo (el extremo contrario del rango) queda en otro sitio.

**La corrección.** Ahora el robot pide solo las velas que abren entre las 00:00 y las 08:59:59. Mida el rango a la hora que lo mida, el resultado es siempre el mismo y coincide con tu definición. Además, si el servidor aún no tiene esas velas, el robot no dibuja un rectángulo vacío: vuelve a intentarlo en el siguiente tick.

## Fallo 2: tras un reinicio, el robot olvidaba que ya había operado

**Qué debería pasar.** Tu regla es una sola operación al día.

**Qué hacía el código.** El robot apuntaba "ya operé hoy" en su memoria temporal. Esa memoria se borra cada vez que el robot se reinicia. Al volver a arrancar, el robot cree que es un día nuevo sin operaciones.

**Ejemplo.** El robot vende a las 10:15. A las 10:40 el VPS se reinicia. Al arrancar, el robot ha olvidado la venta. Si en lo que queda de ventana (hasta las 12:00) se cumple una señal, abre una segunda operación. Ese día se arriesga el doble de lo previsto (dos veces el 0,5 %), y aparece un resultado que el Strategy Tester nunca habría producido.

**La corrección.** Al empezar cada día, y siempre que el robot arranca, ahora consulta el historial de la cuenta. Si encuentra una operación abierta hoy con su número mágico y en el mismo símbolo, da el día por operado. El historial lo guarda el bróker, así que no se pierde con ningún reinicio.

## Fallo 3: una misma vela podía abrir una compra y una venta a la vez

**Qué hacía el código.** El robot revisa primero la venta (falso rompimiento por arriba) y después la compra (falso rompimiento por abajo). Tras abrir la venta, no comprobaba si ya había operado antes de revisar la compra.

**Cuándo pasa.** Solo con una vela H1 muy rara: una mecha por encima del máximo de Asia y otra por debajo del mínimo, con el cierre dentro del rango y el cuerpo pequeño, de modo que las dos mechas superan 1,5 veces el cuerpo. Es una vela de mucha indecisión, típica de una noticia fuerte. Si además se cumplían los dos ratios de 2,4, el robot abría las dos operaciones. Quedan opuestas, con el doble de riesgo y con un resultado que depende sobre todo de los costes.

**La corrección.** Si ya vendió con esa vela, no compra. Así se respeta la regla de una operación al día.

**Decisión para ti.** Con la corrección, en ese caso gana la venta, porque es la que el robot revisa primero. Otra opción razonable es no operar ese día, ya que la vela no da una dirección clara. Dime cuál prefieres y lo ajusto.

## Observación sin corregir: la ventana de 3 horas en la práctica es de 2

No es un fallo de programación. Es una consecuencia de cómo encajan las reglas, y la decides tú.

El robot solo mira velas **ya cerradas**: a cada hora revisa la vela anterior. Con Asia de 00:00 a 09:00 y una ventana de 3 horas, pasa esto:

| Hora en que el robot revisa | Vela que revisa | ¿Puede dar señal? |
| --- | --- | --- |
| 09:00 a 09:59 | Vela de 08:00 | No: es parte del propio rango de Asia, nunca puede salirse de él |
| 10:00 a 10:59 | Vela de 09:00 | Sí |
| 11:00 a 11:59 | Vela de 10:00 | Sí |
| 12:00 en adelante | Vela de 11:00 | No: la ventana ya cerró |

Así que solo cuentan las velas de 09:00 y 10:00. La vela de 11:00 nunca se evalúa, aunque sea un falso rompimiento perfecto.

**Por qué no lo he cambiado.** Los parámetros óptimos (incluida la ventana de 3 horas) se encontraron con este comportamiento, y la demo coincide con el tester. Si lo cambio, el robot opera distinto a lo que validaste. Si tu idea era evaluar tres velas (09:00, 10:00 y 11:00), la solución es subir la ventana a 4 horas y volver a pasar el backtest. Es un cambio de estrategia, no una corrección.

## Cómo comprobar que nada cambió y próximos pasos

En el Strategy Tester el robot no se reinicia, así que los fallos 1 y 2 no deberían aparecer. Lo esperado es que la versión 1.81 dé **exactamente las mismas operaciones** que la 1.80 entre enero de 2021 y enero de 2026. La única excepción posible es un día con la vela rara del fallo 3. La versión nueva compila sin errores ni avisos.

1. Pasar la versión 1.81 por el Strategy Tester con los mismos ajustes de siempre: ticks reales, delay aleatorio y spread del bróker.
2. Comparar la lista de operaciones con la de la 1.80. Si alguna difiere, revísala: debería ser un día con compra y venta a la vez en la 1.80.
3. Revisar si la demo tuvo algún día con dos operaciones o algún reinicio del VPS. Podría explicar la única operación que no coincidía con el tester.
4. Si todo coincide, instalar la 1.81 en la demo, con el robot sin posiciones abiertas.

**Pendientes por decidir:**

- [ ] Fallo 3: con la vela rara, ¿se queda la venta o no se opera ese día?
- [ ] Ventana: ¿se mantiene en 3 horas (dos velas evaluadas) o se prueba con 4?

La versión `bot LB2.mq5` (2.02) no está en la demo, pero tiene los fallos 2 y 3. El fallo 1 ya estaba corregido en esa versión.

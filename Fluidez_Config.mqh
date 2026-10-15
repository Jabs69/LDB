#ifndef FLUIDEZ_CONFIG_MQH
#define FLUIDEZ_CONFIG_MQH

#include <Trade\Trade.mqh>

enum ENUM_PATRON
  {
   PATRON_NINGUNO,
   PATRON_MARTILLO,        // Alcista: mecha inferior larga, cuerpo pequeño
   PATRON_LIBELULA,        // Alcista: como el martillo pero con cuerpo casi nulo (doji)
   PATRON_ESTRELLA_FUGAZ,  // Bajista: mecha superior larga, cuerpo pequeño
   PATRON_LAPIDA           // Bajista: como la estrella fugaz pero con cuerpo casi nulo (doji)
  };

enum ENUM_SL_MODO
  {
   SL_NIVEL,               // Stop en el nivel de invalidación del Fibo
   SL_MECHA                // Stop en el extremo de la vela de rechazo
  };

input group "Sesión (hora servidor)"
input long MN                 = 2022;  // Magic number
input int  HoraRango          = 7;     // Fin del rango de Asia
input int  HoraFinRuptura     = 11;    // Se evalúan rupturas en velas H1 cerradas antes de esta hora
input int  HoraInicioEntrada  = 11;    // Desde esta hora se busca entrada
input int  HoraFin            = 20;    // Fin de la sesión
input bool CerrarAlFin        = true;  // Cerrar posiciones abiertas al llegar a HoraFin
input bool UnaOperacionPorDia = true;  // No reentrar tras cerrar una operación

input group "Zona de entrada (niveles Fibo: 0 = extremo roto, 1 = lado contrario del rango)"
input double       NivelZona         = 0.75;     // La mecha debe llegar al menos a este nivel
input double       NivelInvalidacion = 1.10;     // Si el precio lo supera desde HoraInicioEntrada, se anula el día
input double       NivelTP           = 0.0;      // Take profit
input ENUM_SL_MODO ModoSL            = SL_NIVEL;
input int          MargenSLPuntos    = 20;       // Margen extra del stop, en puntos
input int          DesvioMaxPuntos   = 10;       // Deslizamiento máximo permitido al enviar la orden

input group "Patrón de vela de rechazo (M5, % del rango de la vela)"
input double MechaMinPct        = 60;   // Mecha de rechazo, mínimo
input double CuerpoMaxPct       = 35;   // Cuerpo, máximo
input double MechaOpuestaMaxPct = 15;   // Mecha contraria, máximo
input double DojiMaxPct         = 10;   // Cuerpo hasta este % = libélula / lápida
input double TamanoMinATR       = 0.5;  // Rango mínimo de la vela, en múltiplos de ATR(14) M5

input group "Gestión"
input double RiesgoPct = 1.0;           // % del balance arriesgado por operación

CTrade trade;
int    hATR = INVALID_HANDLE;

bool Fcompra     = false,
     Fventa      = false,
     FiboIsSet   = false,
     RangoValido = false;
double LowLevel  = 0,
       HighLevel = 0,
       Levels[6] = {0.0,0.750,0.788,0.888,1,1.10},
       Prices[6];
datetime UltimaH1 = 0,
         UltimaM5 = 0,
         DiaActual = 0;

const string OBJ_PREFIJO = "Fluidez_";

#endif

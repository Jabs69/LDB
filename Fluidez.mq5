//+------------------------------------------------------------------+
//|                                                      Fluidez.mq5 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.20"

#include "Fluidez_Config.mqh"
#include "Fluidez_Gestion.mqh"
#include "Fluidez_Estrategia.mqh"
#include "Fluidez_Graficos.mqh"

int OnInit()
  {
   trade.SetExpertMagicNumber(MN);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(DesvioMaxPuntos);

   hATR = iATR(_Symbol, PERIOD_M5, 14);
   if(hATR == INVALID_HANDLE) return(INIT_FAILED);

   // Forzar recálculo en el primer tick: el estado del día se reconstruye
   // desde el historial, así que un reinicio a media sesión no lo pierde.
   UltimaH1 = 0;
   UltimaM5 = 0;
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIJO);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
  }

void OnTick()
  {
   datetime barH1 = iTime(_Symbol, PERIOD_H1, 0);
   if(barH1 == 0) return;                       // historial H1 aún no disponible

   if(barH1 != UltimaH1)
     {
      if(!RecalcularDia(barH1)) return;         // reintentar en el siguiente tick
      UltimaH1 = barH1;
      Dibujar(barH1);
     }

   int hora = Hora(barH1);
   if(hora >= HoraFin)
     {
      if(CerrarAlFin) CerrarPosiciones();
      return;
     }
   if(hora < HoraInicioEntrada) return;

   datetime barM5 = iTime(_Symbol, PERIOD_M5, 0);
   if(barM5 == 0 || barM5 == UltimaM5) return;
   UltimaM5 = barM5;

   if(!RangoValido || Fcompra == Fventa) return; // sin ruptura o ruptura por ambos lados
   if(OperacionesAbiertas() > 0) return;
   if(UnaOperacionPorDia && OperoHoy(DiaActual)) return;

   BuscarEntrada();
  }

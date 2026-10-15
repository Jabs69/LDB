#property copyright "Copyright 2026, Trading Bot"
#property link      "https://mql5.com"
#property version   "2.02"

#include <Trade\Trade.mqh>

//--- INPUTS DE SESIÓN
input int      InpHoraInicioAsia = 0;       
input int      InpHoraFinAsia    = 9;       
input int      InpHorasVentana   = 3;       // Buscar trade X horas tras Asia
input color    InpColorAsia      = clrSlateBlue;

//--- INPUTS DE RIESGO
input double   InpPorcentajeRiesgo = 0.5;   // % de la equidad a arriesgar por trade
input double   InpRatioMinimo      = 2.4;   
input int      InpMagicNumber      = 123456;
input double   InpFactorMecha      = 1.5;   
input int      InpBufferPuntos     = 100;   // Buffer en puntos para SL y BE (10 pips en 5 dígitos)

//--- FILTRO DE SPREAD Y TIEMPO
input int      InpMaxSpread        = 30;    
input bool     InpOperarViernes    = false; 

//--- INPUTS DE GESTIÓN (BREAK EVEN)
input bool     InpUsarBE           = true;  
input double   InpRatioBE          = 2.0;   

//--- VARIABLES GLOBALES
CTrade   trade;
double   maxAsia = 0, minAsia = 0;
bool     operadoHoy = false;
int      diaActual = -1;
datetime ultimaVelaH1Procesada = 0; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() { 
   trade.SetExpertMagicNumber(InpMagicNumber); 
   trade.SetMarginMode(); 
   return(INIT_SUCCEEDED); 
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "AsiaBox_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   MqlDateTime dt;
   TimeCurrent(dt);

   // 1. Gestión de posiciones abiertas en cada tick (Break Even)
   if(InpUsarBE) GestionarPosiciones();
   
   // 2. Reinicio diario de variables al cambiar la fecha del servidor
   if(dt.day != diaActual) {
      diaActual = dt.day; 
      operadoHoy = false; 
      maxAsia = 0; 
      minAsia = 0;
   }

   // 3. Filtro de Viernes
   if(!InpOperarViernes && dt.day_of_week == FRIDAY) return;

   // 4. Calcular rango y DIBUJAR cuando termina la sesión de Asia
   if(dt.hour >= InpHoraFinAsia && maxAsia == 0) {
      CalcularRangoAsia();
      if(maxAsia > 0) DibujarRangoAsia();
   }

   // 5. Filtro de ventana de tiempo operativa (Londres)
   int horaLimiteLondres = InpHoraFinAsia + InpHorasVentana;

   if(maxAsia > 0 && !operadoHoy) {
      bool enVentana = false;
      if(horaLimiteLondres <= 24) {
         enVentana = (dt.hour >= InpHoraFinAsia && dt.hour < horaLimiteLondres);
      } else {
         enVentana = (dt.hour >= InpHoraFinAsia || dt.hour < (horaLimiteLondres - 24));
      }

      if(enVentana) {
         // Optimización: solo evalúa al abrir una nueva vela H1
         datetime tiempoVelaH1Actual = iTime(_Symbol, PERIOD_H1, 0);
         if(tiempoVelaH1Actual != ultimaVelaH1Procesada) {
            VerificarFakeoutH1();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Lógica de Fakeout H1                                             |
//+------------------------------------------------------------------+
void VerificarFakeoutH1() {
   int spreadActual = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadActual > InpMaxSpread) return; 

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Copiamos la última vela H1 cerrada (índice 1)
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, rates) < 1) return; 

   datetime tiempoVelaActual = iTime(_Symbol, PERIOD_H1, 0);

   double hH1 = rates[0].high;
   double lH1 = rates[0].low;
   double cH1 = rates[0].close;
   double oH1 = rates[0].open;
   
   double cuerpo = MathMax(MathAbs(cH1 - oH1), _Point); 
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double buffer = _Point * InpBufferPuntos;

   // --- Fakeout alcista -> Venta ---
   if(hH1 > maxAsia && cH1 < maxAsia) {
      double mechaSup = hH1 - MathMax(oH1, cH1);
      if(mechaSup > (cuerpo * InpFactorMecha)) {
         double sl = NormalizeDouble(hH1 + buffer, _Digits);      
         double tp = NormalizeDouble(minAsia, _Digits);
         
         if((bid - tp) >= ((sl - bid) * InpRatioMinimo)) {
            double lote = CalcularLotaje(bid, sl);
            if(lote > 0) {
               if(trade.Sell(lote, _Symbol, bid, sl, tp)) {
                  operadoHoy = true;
                  ultimaVelaH1Procesada = tiempoVelaActual;
                  Print("Venta ejecutada exitosamente. Ticket: ", trade.ResultOrder());
               } else {
                  PrintFormat("Error al ejecutar Venta. Código: %d (%s)", trade.ResultRetcode(), trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }

   // --- Fakeout bajista -> Compra ---
   if(lH1 < minAsia && cH1 > minAsia) {
      double mechaInf = MathMin(oH1, cH1) - lH1;
      if(mechaInf > (cuerpo * InpFactorMecha)) {
         double sl = NormalizeDouble(lH1 - buffer, _Digits);      
         double tp = NormalizeDouble(maxAsia, _Digits);
         
         if((tp - ask) >= ((ask - sl) * InpRatioMinimo)) {
            double lote = CalcularLotaje(ask, sl);
            if(lote > 0) {
               if(trade.Buy(lote, _Symbol, ask, sl, tp)) {
                  operadoHoy = true;
                  ultimaVelaH1Procesada = tiempoVelaActual;
                  Print("Compra ejecutada exitosamente. Ticket: ", trade.ResultOrder());
               } else {
                  PrintFormat("Error al ejecutar Compra. Código: %d (%s)", trade.ResultRetcode(), trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Funciones de Dibujo                                              |
//+------------------------------------------------------------------+
void DibujarRangoAsia() {
   MqlDateTime dt; TimeCurrent(dt);
   dt.hour = InpHoraInicioAsia; dt.min = 0; dt.sec = 0; datetime t1 = StructToTime(dt);
   dt.hour = InpHoraFinAsia; dt.min = 0; dt.sec = 0; datetime t2 = StructToTime(dt);

   string name = "AsiaBox_" + IntegerToString(diaActual);
   ObjectDelete(0, name);
   
   if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, maxAsia, t2, minAsia)) {
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorAsia);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true); 
   }
}

//+------------------------------------------------------------------+
//| Cálculo de Rango de Asia                                         |
//+------------------------------------------------------------------+
void CalcularRangoAsia() {
   MqlDateTime dt; TimeCurrent(dt);
   dt.hour = InpHoraInicioAsia; dt.min = 0; dt.sec = 0; datetime hIni = StructToTime(dt);
   dt.hour = InpHoraFinAsia; dt.min = 0; dt.sec = 0; 
   datetime hFin = StructToTime(dt) - 1; // Se resta 1 segundo para no incluir la vela de apertura del Fin de Asia
   
   MqlRates rates[];
   int copiados = CopyRates(_Symbol, PERIOD_H1, hIni, hFin, rates);
   if(copiados <= 0) return;
   
   maxAsia = rates[0].high;
   minAsia = rates[0].low;
   
   for(int i = 1; i < copiados; i++) {
      if(rates[i].high > maxAsia) maxAsia = rates[i].high;
      if(rates[i].low < minAsia)  minAsia = rates[i].low;
   }
}

//+------------------------------------------------------------------+
//| Gestión de Posiciones Abiertas (Break Even)                      |
//+------------------------------------------------------------------+
void GestionarPosiciones() {
   double buffer = _Point * InpBufferPuntos;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol) {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            double pOpen = PositionGetDouble(POSITION_PRICE_OPEN);
            double slAct = PositionGetDouble(POSITION_SL);
            double tpAct = PositionGetDouble(POSITION_TP);
            
            // Si la posición no tiene SL configurado, se omite el cálculo
            if(slAct == 0) continue;

            double rIni = MathAbs(pOpen - slAct);
            
            if(rIni > 0) {
               long posType = PositionGetInteger(POSITION_TYPE);
               double pCurr = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               
               if(MathAbs(pCurr - pOpen) / rIni >= InpRatioBE) {
                  if(posType == POSITION_TYPE_BUY && slAct < pOpen) {
                     double nuevoSL = NormalizeDouble(pOpen + buffer, _Digits);
                     if(!trade.PositionModify(ticket, nuevoSL, tpAct)) {
                        PrintFormat("Error al aplicar BE en Compra #%d: %s", ticket, trade.ResultRetcodeDescription());
                     }
                  }
                  if(posType == POSITION_TYPE_SELL && (slAct > pOpen || slAct == 0)) {
                     double nuevoSL = NormalizeDouble(pOpen - buffer, _Digits);
                     if(!trade.PositionModify(ticket, nuevoSL, tpAct)) {
                        PrintFormat("Error al aplicar BE en Venta #%d: %s", ticket, trade.ResultRetcodeDescription());
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calcular Lotaje basado en Riesgo Fijo Dinámico                   |
//+------------------------------------------------------------------+
double CalcularLotaje(double precioEntrada, double precioSL) {
   double distanciaPuntos = MathAbs(precioEntrada - precioSL);
   if(distanciaPuntos <= 0) return 0.0;
   
   double valorTick  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tamañoTick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tamañoTick == 0 || valorTick == 0) return 0.0;
   
   double riesgoMoneda = AccountInfoDouble(ACCOUNT_EQUITY) * (InpPorcentajeRiesgo / 100.0);
   double pérdidaPorLote = (distanciaPuntos / tamañoTick) * valorTick;
   if(pérdidaPorLote == 0) return 0.0;
   
   double loteCalculado = riesgoMoneda / pérdidaPorLote;
   
   double maxLote  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double minLote  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double pasoLote = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(pasoLote <= 0) return 0.0;

   // Corrección de precisión flotante antes del truncamiento
   loteCalculado = MathFloor((loteCalculado / pasoLote) + 0.000001) * pasoLote;
   
   // Normalización decimal según el paso permitido por el bróker
   int decimalesLote = 0;
   if(pasoLote == 0.01) decimalesLote = 2;
   else if(pasoLote == 0.1) decimalesLote = 1;
   
   loteCalculado = NormalizeDouble(loteCalculado, decimalesLote);

   if(loteCalculado < minLote) loteCalculado = 0.0;
   if(loteCalculado > maxLote) loteCalculado = maxLote;
   
   return loteCalculado;
}
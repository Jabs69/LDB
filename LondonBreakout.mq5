#property copyright "Copyright 2023, Trading Bot"
#property link      "https://mql5.com"
#property version   "1.80"
#property strict
#include <Trade\Trade.mqh>

//--- INPUTS DE SESIÓN
input int      InpHoraInicioAsia = 0;       
input int      InpHoraFinAsia    = 9;       
input int      InpHorasVentana   = 3;       // Buscar trade X horas tras Asia
input int      InpHoraAperturaNY = 15;      
input color    InpColorAsia      = clrSlateBlue;

//--- INPUTS DE RIESGO
input double   InpPorcentajeRiesgo = 0.5;   
input double   InpRatioMinimo      = 2.4;   
input int      InpMagicNumber      = 123456;
input double   InpFactorMecha      = 1.5;   

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() { 
   trade.SetExpertMagicNumber(InpMagicNumber); 
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

   GestionarPosiciones();
   
   if(dt.day != diaActual) {
      diaActual = dt.day; 
      operadoHoy = false; 
      maxAsia = 0; 
      minAsia = 0;
      ObjectsDeleteAll(0, "AsiaBox_"); // Limpiar cuadros del día anterior
   }

   if(!InpOperarViernes && dt.day_of_week == FRIDAY) return;

   // 1. Calcular rango y DIBUJAR cuando termina Asia
   if(dt.hour >= InpHoraFinAsia && maxAsia == 0) {
      CalcularRangoAsia();
      DibujarRangoAsia();
   }

   // 2. Filtro de ventana de tiempo (Londres)
   int horaLimiteLondres = InpHoraFinAsia + InpHorasVentana;

   if(maxAsia > 0 && !operadoHoy) {
      if(dt.hour >= InpHoraFinAsia && dt.hour < horaLimiteLondres) {
         VerificarFakeoutH1();
      }
   }
}

//+------------------------------------------------------------------+
//| Lógica de Fakeout H1                                             |
//+------------------------------------------------------------------+
void VerificarFakeoutH1() {
   int spreadActual = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadActual > InpMaxSpread) return; 

   double hH1 = iHigh(_Symbol, PERIOD_H1, 1);
   double lH1 = iLow(_Symbol, PERIOD_H1, 1);
   double cH1 = iClose(_Symbol, PERIOD_H1, 1);
   double oH1 = iOpen(_Symbol, PERIOD_H1, 1);
   
   double cuerpo = MathMax(MathAbs(cH1 - oH1), _Point); 
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(hH1 > maxAsia && cH1 < maxAsia) {
      double mechaSup = hH1 - MathMax(oH1, cH1);
      if(mechaSup > (cuerpo * InpFactorMecha)) {
         double sl = NormalizeDouble(hH1 + (_Point * 10), _Digits);      
         double tp = NormalizeDouble(minAsia, _Digits);
         if((bid - tp) >= ((sl - bid) * InpRatioMinimo)) {
            double lote = CalcularLotaje(bid, sl);
            if(lote > 0 && trade.Sell(lote, _Symbol, bid, sl, tp)) operadoHoy = true;
         }
      }
   }

   if(lH1 < minAsia && cH1 > minAsia) {
      double mechaInf = MathMin(oH1, cH1) - lH1;
      if(mechaInf > (cuerpo * InpFactorMecha)) {
         double sl = NormalizeDouble(lH1 - (_Point * 10), _Digits);      
         double tp = NormalizeDouble(maxAsia, _Digits);
         if((tp - ask) >= ((ask - sl) * InpRatioMinimo)) {
            double lote = CalcularLotaje(ask, sl);
            if(lote > 0 && trade.Buy(lote, _Symbol, ask, sl, tp)) operadoHoy = true;
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
   dt.hour = InpHoraFinAsia; datetime t2 = StructToTime(dt);

   string name = "AsiaBox_" + IntegerToString(diaActual);
   
   // Crear el rectángulo
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, maxAsia, t2, minAsia);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorAsia);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true); // Detrás de las velas
}

//+------------------------------------------------------------------+
//| Soporte Técnico                                                  |
//+------------------------------------------------------------------+
void CalcularRangoAsia() {
   MqlDateTime dt; TimeCurrent(dt);
   dt.hour = InpHoraInicioAsia; dt.min = 0; dt.sec = 0; datetime hIni = StructToTime(dt);
   dt.hour = InpHoraFinAsia; datetime hFin = StructToTime(dt);
   int start = iBarShift(_Symbol, PERIOD_H1, hIni);
   int end   = iBarShift(_Symbol, PERIOD_H1, hFin);
   maxAsia = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, start-end+1, end));
   minAsia = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, start-end+1, end));
}

void GestionarPosiciones() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double pOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double slAct = PositionGetDouble(POSITION_SL);
         double tpAct = PositionGetDouble(POSITION_TP);
         double rIni  = MathAbs(pOpen - slAct);
         if(rIni > 0) {
            double pCurr = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(MathAbs(pCurr - pOpen) / rIni >= InpRatioBE) {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && slAct < pOpen) trade.PositionModify(ticket, pOpen + (_Point * 10), tpAct);
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && (slAct > pOpen || slAct == 0)) trade.PositionModify(ticket, pOpen - (_Point * 10), tpAct);
            }
         }
      }
   }
}

double CalcularLotaje(double precio, double sl) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riesgoDinero = balance * (InpPorcentajeRiesgo / 100.0);
   double pips = MathMax(MathAbs(precio - sl) / _Point, 1);
   return NormalizeDouble(riesgoDinero / (pips * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)), 2);
}

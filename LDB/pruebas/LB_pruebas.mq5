#property copyright "Copyright 2023, Trading Bot"
#property link      "https://mql5.com"
#property version   "1.81"
// Variante SOLO PARA PRUEBAS de LondonBreakout v1.81 (docs/analisis-estrategia.md). No usar en cuenta.
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

//--- MODO DE PRUEBA
input int      InpModo             = 0;     // 0 = EA normal, 1 = dirección invertida, 2 = entradas al azar
input int      InpSemilla          = 1;     // semilla del azar (modo 2)
input double   InpProbAzar         = 0.172; // probabilidad de operar un día lun-jue (modo 2): 183 ops / ~1060 días

// Distancias de SL (puntos) y ratios de TP de las 183 operaciones de la v1.81 en EURUSD 2021-2026 (modo 2)
int    distSL[] = {90,66,98,59,81,106,31,47,62,116,59,61,75,92,65,91,49,58,55,72,48,68,45,71,33,66,46,68,66,64,62,74,40,58,72,56,42,129,72,60,100,55,85,72,117,135,125,222,196,96,75,85,83,123,115,106,107,169,107,76,254,224,162,84,132,121,91,97,142,167,89,113,96,97,91,70,94,120,86,85,136,100,127,87,99,51,104,105,79,161,75,79,60,67,74,82,48,71,50,83,73,55,85,72,67,58,98,72,66,60,93,61,83,82,67,109,110,78,52,53,79,51,45,31,111,99,67,42,42,25,51,56,60,78,61,66,78,113,60,41,77,116,82,93,125,134,89,79,46,77,114,76,49,119,94,502,160,64,58,213,148,150,130,112,84,48,173,70,100,144,126,96,57,56,58,70,47,123,75,111,59,39,162};
double ratioTP[] = {2.533,2.545,3.52,2.458,2.42,3.047,7.484,2.681,2.452,3.155,2.475,3.049,2.84,2.424,2.677,2.418,2.408,2.448,2.491,2.431,2.521,2.471,2.467,2.408,2.576,2.409,2.565,2.412,2.455,2.422,3.613,5.784,2.45,2.431,2.75,3.571,6.286,2.442,2.444,2.5,2.44,5.491,2.424,3.917,2.419,2.4,3.36,2.892,2.531,4.927,2.44,2.424,2.434,2.407,2.426,2.462,2.43,2.438,2.495,2.921,2.433,3.607,2.407,2.405,2.424,2.702,2.473,2.443,2.993,2.419,2.461,2.407,2.438,2.423,2.429,2.429,3.83,2.425,2.419,2.471,2.507,2.68,4.85,2.402,2.404,3.804,2.413,2.495,2.633,2.41,2.493,2.43,2.583,2.552,2.554,2.427,4.0,2.465,2.58,2.434,3.068,2.418,2.447,2.444,2.433,2.448,2.418,2.431,3.394,2.433,2.409,2.525,2.446,2.463,2.418,2.963,2.918,2.423,2.5,2.491,2.848,2.451,2.444,2.484,2.423,2.414,2.433,2.476,2.643,3.16,2.471,2.482,2.417,2.449,2.508,2.439,2.615,2.425,2.4,2.415,2.429,2.655,2.427,2.43,2.464,2.44,3.876,2.405,6.065,2.429,2.43,2.474,4.878,2.412,2.404,2.406,4.719,2.406,6.828,2.493,2.419,2.44,2.415,3.107,2.464,6.833,2.405,2.743,2.47,2.417,2.437,4.76,5.456,2.446,2.414,3.1,2.447,2.667,2.413,3.532,2.424,3.641,3.025};
bool     azarHoy = false;
int      minutoAzar = 0;

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
   MathSrand(InpSemilla);
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
      operadoHoy = YaOperoHoy(); // Sobrevive a reinicios del EA o del terminal
      maxAsia = 0; 
      minAsia = 0;
      ObjectsDeleteAll(0, "AsiaBox_"); // Limpiar cuadros del día anterior
      azarHoy = (MathRand() / 32768.0) < InpProbAzar;
      minutoAzar = 10 * 60 + MathRand() % 120;
   }

   if(!InpOperarViernes && dt.day_of_week == FRIDAY) return;

   if(InpModo == 2) {
      if(azarHoy && !operadoHoy && dt.hour * 60 + dt.min >= minutoAzar && dt.hour < 12) EntradaAzar();
      return;
   }

   // 1. Calcular rango y DIBUJAR cuando termina Asia
   if(dt.hour >= InpHoraFinAsia && maxAsia == 0) {
      CalcularRangoAsia();
      if(maxAsia > 0) DibujarRangoAsia();
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
            if(lote > 0 && Abrir(false, sl - bid, bid - tp, lote)) operadoHoy = true;
         }
      }
   }

   // Si ya se vendió con esta misma vela, no abrir también la compra
   if(!operadoHoy && lH1 < minAsia && cH1 > minAsia) {
      double mechaInf = MathMin(oH1, cH1) - lH1;
      if(mechaInf > (cuerpo * InpFactorMecha)) {
         double sl = NormalizeDouble(lH1 - (_Point * 10), _Digits);      
         double tp = NormalizeDouble(maxAsia, _Digits);
         if((tp - ask) >= ((ask - sl) * InpRatioMinimo)) {
            double lote = CalcularLotaje(ask, sl);
            if(lote > 0 && Abrir(true, ask - sl, tp - ask, lote)) operadoHoy = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Pruebas: abrir con distancias dadas, en la dirección de la señal o la contraria
//+------------------------------------------------------------------+
bool Abrir(bool compra, double dSL, double dTP, double lote) {
   if(InpModo == 1) compra = !compra;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(compra) return trade.Buy(lote, _Symbol, ask, NormalizeDouble(ask - dSL, _Digits), NormalizeDouble(ask + dTP, _Digits));
   return trade.Sell(lote, _Symbol, bid, NormalizeDouble(bid + dSL, _Digits), NormalizeDouble(bid - dTP, _Digits));
}

void EntradaAzar() {
   int spreadActual = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadActual > InpMaxSpread) return;
   int k = MathRand() % ArraySize(distSL);
   bool compra = (MathRand() % 2) == 0;
   double dSL = distSL[k] * _Point;
   double precio = compra ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lote = CalcularLotaje(precio, compra ? precio - dSL : precio + dSL);
   if(lote > 0 && Abrir(compra, dSL, dSL * ratioTP[k], lote)) operadoHoy = true;
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
   dt.hour = InpHoraFinAsia; datetime hFin = StructToTime(dt) - 1; // Excluir la vela que abre al terminar Asia

   // Solo velas H1 que abren dentro de [inicio, fin) de Asia, todas ya cerradas
   MqlRates rates[];
   int copiados = CopyRates(_Symbol, PERIOD_H1, hIni, hFin, rates);
   if(copiados <= 0) return; // Se reintenta en el siguiente tick

   double maxR = rates[0].high, minR = rates[0].low;
   for(int i = 1; i < copiados; i++) {
      if(rates[i].high > maxR) maxR = rates[i].high;
      if(rates[i].low  < minR) minR = rates[i].low;
   }
   maxAsia = maxR;
   minAsia = minR;
}

//+------------------------------------------------------------------+
//| ¿Ya abrió este EA una operación hoy? (consulta el historial)     |
//+------------------------------------------------------------------+
bool YaOperoHoy() {
   MqlDateTime dt; TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   if(!HistorySelect(StructToTime(dt), TimeCurrent() + 60)) return false;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
      ulong deal = HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN) return true;
   }
   return false;
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

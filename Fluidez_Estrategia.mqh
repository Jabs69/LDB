#ifndef FLUIDEZ_ESTRATEGIA_MQH
#define FLUIDEZ_ESTRATEGIA_MQH

// Reconstruye rango y rupturas del día a partir de velas H1 cerradas.
// No depende de haber visto el primer tick de cada vela.
bool RecalcularDia(datetime barH1)
  {
   DiaActual   = barH1 - (barH1 % 86400);
   RangoValido = false;
   Fcompra     = false;
   Fventa      = false;

   datetime finRango = DiaActual + HoraRango * 3600;
   if(barH1 < finRango) return(true);           // el rango aún no está formado

   // Rango: velas H1 cerradas con apertura en [00:00, HoraRango)
   MqlRates r[];
   int n = CopyRates(_Symbol, PERIOD_H1, DiaActual, finRango - 1, r);
   if(n < 0) return(false);
   if(n == 0) return(true);                     // día sin datos (festivo)

   HighLevel = r[0].high;
   LowLevel  = r[0].low;
   for(int i = 1; i < n; i++)
     {
      HighLevel = MathMax(HighLevel, r[i].high);
      LowLevel  = MathMin(LowLevel,  r[i].low);
     }
   RangoValido = true;

   // Rupturas: velas H1 cerradas con apertura en [HoraRango, HoraFinRuptura)
   datetime finRuptura = MathMin(DiaActual + HoraFinRuptura * 3600, barH1);
   if(finRuptura <= finRango) return(true);

   n = CopyRates(_Symbol, PERIOD_H1, finRango, finRuptura - 1, r);
   if(n < 0) return(false);

   for(int i = 0; i < n; i++)                   // CopyRates devuelve en orden cronológico
     {
      if(r[i].high > HighLevel) { HighLevel = r[i].high; Fcompra = true; }
      if(r[i].low  < LowLevel)  { LowLevel  = r[i].low;  Fventa  = true; }
     }
   return(true);
  }

// Entrada: vela M5 recién cerrada que entra en la zona Fibo con su mecha,
// cierra fuera de ella y forma un patrón de rechazo.
void BuscarEntrada()
  {
   bool compra = Fcompra;

   MqlRates v[];
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, v) != 1) return;

   double zona  = PrecioNivel(NivelZona);
   double inval = PrecioNivel(NivelInvalidacion);

   // 1. La mecha entra en la zona y el cierre la rechaza
   bool rechazaZona = compra ? (v[0].low  <= zona && v[0].close > zona)
                             : (v[0].high >= zona && v[0].close < zona);
   if(!rechazaZona) return;

   // 2. El precio no ha superado el nivel de invalidación (vela actual incluida)
   if(DiaInvalidado(inval, compra)) return;

   // 3. Vela con tamaño suficiente para no operar ruido
   double atr[];
   if(CopyBuffer(hATR, 0, 1, 1, atr) != 1) return;
   if(v[0].high - v[0].low < TamanoMinATR * atr[0]) return;

   // 4. Patrón de rechazo en la dirección de la ruptura
   ENUM_PATRON patron = ClasificarVela(v[0], compra);
   if(patron == PATRON_NINGUNO) return;

   double margen = MargenSLPuntos * _Point;
   double sl     = (ModoSL == SL_NIVEL) ? inval : (compra ? v[0].low : v[0].high);
   sl = NormalizeDouble(compra ? sl - margen : sl + margen, _Digits);
   double tp     = NormalizeDouble(PrecioNivel(NivelTP), _Digits);
   double precio = compra ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(compra ? (sl >= precio || tp <= precio) : (sl <= precio || tp >= precio)) return;
   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(MathAbs(precio - sl) <= stopsLevel || MathAbs(tp - precio) <= stopsLevel) return;

   double lotes = CalcularLotes(MathAbs(precio - sl));
   if(lotes <= 0) return;

   string comentario = "Fluidez " + EnumToString(patron);
   bool ok = compra ? trade.Buy(lotes, _Symbol, 0, sl, tp, comentario)
                    : trade.Sell(lotes, _Symbol, 0, sl, tp, comentario);
   if(!ok)
      PrintFormat("Fluidez: fallo al abrir %s (%u %s)", compra ? "compra" : "venta",
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
  }

ENUM_PATRON ClasificarVela(const MqlRates &v, bool alcista)
  {
   double rango = v.high - v.low;
   if(rango <= 0) return(PATRON_NINGUNO);

   double cuerpo   = MathAbs(v.close - v.open) / rango * 100;
   double mechaInf = (MathMin(v.open, v.close) - v.low) / rango * 100;
   double mechaSup = (v.high - MathMax(v.open, v.close)) / rango * 100;
   double rechazo  = alcista ? mechaInf : mechaSup;
   double opuesta  = alcista ? mechaSup : mechaInf;

   if(rechazo < MechaMinPct || cuerpo > CuerpoMaxPct || opuesta > MechaOpuestaMaxPct)
      return(PATRON_NINGUNO);
   if(cuerpo <= DojiMaxPct)
      return(alcista ? PATRON_LIBELULA : PATRON_LAPIDA);
   return(alcista ? PATRON_MARTILLO : PATRON_ESTRELLA_FUGAZ);
  }

// true si alguna vela M5 cerrada desde HoraInicioEntrada superó el nivel de invalidación
bool DiaInvalidado(double inval, bool compra)
  {
   MqlRates r[];
   int n = CopyRates(_Symbol, PERIOD_M5, DiaActual + HoraInicioEntrada * 3600,
                     iTime(_Symbol, PERIOD_M5, 1), r);
   if(n < 0) return(true);                      // sin datos fiables: no operar
   for(int i = 0; i < n; i++)
      if(compra ? r[i].low < inval : r[i].high > inval) return(true);
   return(false);
  }

double PrecioNivel(double nivel)
  {
   double origen  = Fcompra ? HighLevel : LowLevel;
   double destino = Fcompra ? LowLevel  : HighLevel;
   return(origen + (destino - origen) * nivel);
  }

#endif

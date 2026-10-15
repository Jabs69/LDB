#ifndef FLUIDEZ_GESTION_MQH
#define FLUIDEZ_GESTION_MQH

double CalcularLotes(double distancia)
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double paso      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tickValue <= 0 || tickSize <= 0 || paso <= 0 || distancia <= 0) return(0);

   double riesgo = AccountInfoDouble(ACCOUNT_BALANCE) * RiesgoPct / 100.0;
   double lotes  = MathFloor(riesgo / (distancia / tickSize * tickValue) / paso) * paso;
   if(lotes < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return(0); // no arriesgar más de lo pedido

   int decimales = (int)MathMax(0, -MathFloor(MathLog10(paso)));
   return(NormalizeDouble(MathMin(lotes, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)), decimales));
  }

void CerrarPosiciones()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MN) trade.OrderDelete(ticket);
     }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MN) trade.PositionClose(ticket);
     }
  }

// Sustituye a LibroDeOrdenes(MN): posiciones + pendientes de este EA y símbolo
int OperacionesAbiertas()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MN) n++;
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MN) n++;
     }
   return(n);
  }

// Lee el historial de deals: sobrevive a reinicios, a diferencia de un flag en memoria
bool OperoHoy(datetime dia)
  {
   if(!HistorySelect(dia, dia + 86400)) return(false);
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(deal, DEAL_MAGIC) == MN &&
         HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN) return(true);
     }
   return(false);
  }

#endif

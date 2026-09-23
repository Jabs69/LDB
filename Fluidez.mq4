//+------------------------------------------------------------------+
//|                                                      Fluidez.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include "..\\Libraries\\FuncionesEstandar.mq4"
bool HaveBreakEven = false,
ActiveTS = false,
Fcompra = false,
Fventa = false,
FiboIsSet = false;
int MN = 2022,
Barras,
Barras_5m,
Riesgo = 1;
double Lotes = 0,
Stoploss = 0.00300,
Takeprofit = 0.01500,
base = 10000,
LowLevel = 0,
HighLevel = 0,
Levels[6] = {0.0,0.750,0.788,0.888,1,1.10},
Prices[6];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
    Barras = iBars(NULL,PERIOD_H1);
    Barras_5m = iBars(NULL,PERIOD_M5);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(Barras != iBars(NULL,PERIOD_H1) && Hour() <= 11) {
   
      Barras = iBars(NULL,PERIOD_H1);
      
      if(Hour() == 7) {
      
         int IndexLowLevel = iLowest(NULL,PERIOD_H1,MODE_LOW,8,0),
         IndexHighLevel = iHighest(NULL,PERIOD_H1,MODE_HIGH,8,0);         
         
         LowLevel = iLow(NULL,PERIOD_H1,IndexLowLevel);
         HighLevel = iHigh(NULL,PERIOD_H1,IndexHighLevel);
         
         ObjectCreate(0,"Linea_High",OBJ_HLINE,0,0,HighLevel);
         
         ObjectCreate(0,"Linea_Low",OBJ_HLINE,0,0,LowLevel);
         
      }
      
      else if(Hour() > 7) {
      
         if(iHigh(NULL,PERIOD_H1,1) > HighLevel) {
         
            HighLevel = iHigh(NULL,PERIOD_H1,1);
         
            ObjectSet("Linea_High",OBJPROP_PRICE1,HighLevel);
         
            Fcompra = true;  
         
         }
         
         if(iLow(NULL,PERIOD_H1,1) < LowLevel) {
         
            LowLevel = iLow(NULL,PERIOD_H1,1);
         
            ObjectSet("Linea_Low",OBJPROP_PRICE1,LowLevel);
         
            Fventa = true;
         
         }
         
      }
      
   } 
 
   else if(Barras_5m != iBars(NULL,PERIOD_M5) && Hour() > 10 && Hour() < 20) {
   
     Barras_5m = iBars(NULL,PERIOD_M5);
   
     if(Fcompra && !Fventa) {
      
         if(!FiboIsSet) {
         
            for(int i = 0; i < 6; i++) Prices[i] = HighLevel + ((LowLevel - HighLevel) * Levels[i]);
            
            SetFibo();
         
         }
         
         else if(LibroDeOrdenes(MN) == 0) BuscarEntrada();
         
     }
      
     else if (Fventa && !Fcompra) {
        
        if(!FiboIsSet) {
            
            for(int i = 0; i < 6; i++) Prices[i] = LowLevel + ((HighLevel - LowLevel) * Levels[i]);
            
            SetFibo();
        
        }
      
        else if(LibroDeOrdenes(MN) == 0) BuscarEntrada();
     
     }
   
   }
   
   else if (Hour() >= 20) {
   
      ObjectDelete("Fibo");
      ObjectsDeleteAll(0,OBJ_HLINE);
      Fcompra = false;
      Fventa = false;
      FiboIsSet = false;
   
   }
   
}
//+------------------------------------------------------------------+

void BuscarEntrada () {

   

}

void SetFibo () {

   if(Fcompra) {
   
      ObjectCreate("Fibo",OBJ_FIBO,0,Time[0],High[0],Time[0],Low[0]);
   
      ObjectSet("Fibo",OBJPROP_PRICE1,LowLevel);
      ObjectSet("Fibo",OBJPROP_PRICE2,HighLevel);
      
      ObjectSet("Fibo",OBJPROP_FIBOLEVELS,7);
      
      for(int i = 0; i < 6; i++) ObjectSet("Fibo",OBJPROP_FIRSTLEVEL + i,Levels[i]);
      
      for(int i = 0; i < 6; i++) ObjectSetFiboDescription("Fibo",i,"%$");
      
      FiboIsSet = true;
      
   }
   
   else if(Fventa) {
   
      ObjectCreate("Fibo",OBJ_FIBO,0,Time[0],High[0],Time[0],Low[0]);
   
      ObjectSet("Fibo",OBJPROP_PRICE1,HighLevel);
      ObjectSet("Fibo",OBJPROP_PRICE2,LowLevel);
      
      ObjectSet("Fibo",OBJPROP_FIBOLEVELS,7);
      
      for(int i = 0; i < 6; i++) ObjectSet("Fibo",OBJPROP_FIRSTLEVEL + i,Levels[i]);
      
      for(int i = 0; i < 6; i++) ObjectSetFiboDescription("Fibo",i,"%$");
      
      FiboIsSet = true;
   
   }

}
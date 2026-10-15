#ifndef FLUIDEZ_GRAFICOS_MQH
#define FLUIDEZ_GRAFICOS_MQH

void Dibujar(datetime barH1)
  {
   int hora = Hora(barH1);

   if(!RangoValido || hora >= HoraFin)
     {
      ObjectsDeleteAll(0, OBJ_PREFIJO);
      FiboIsSet = false;
      ChartRedraw();
      return;
     }

   LineaH(OBJ_PREFIJO + "High", HighLevel);
   LineaH(OBJ_PREFIJO + "Low",  LowLevel);

   if(Fcompra != Fventa && hora >= HoraInicioEntrada)
     {
      for(int i = 0; i < 6; i++) Prices[i] = PrecioNivel(Levels[i]);
      SetFibo(DiaActual, barH1);
      FiboIsSet = true;
     }
   else
     {
      ObjectDelete(0, OBJ_PREFIJO + "Fibo");
      FiboIsSet = false;
     }
   ChartRedraw();
  }

void SetFibo(datetime t1, datetime t2)
  {
   string nombre = OBJ_PREFIJO + "Fibo";
   // Nivel 1.0 en el punto 1 (lado contrario), nivel 0.0 en el punto 2 (extremo roto)
   double p1 = Fcompra ? LowLevel  : HighLevel;
   double p2 = Fcompra ? HighLevel : LowLevel;

   if(ObjectFind(0, nombre) < 0)
      ObjectCreate(0, nombre, OBJ_FIBO, 0, t1, p1, t2, p2);
   else
     {
      ObjectMove(0, nombre, 0, t1, p1);
      ObjectMove(0, nombre, 1, t2, p2);
     }

   ObjectSetInteger(0, nombre, OBJPROP_LEVELS, 6);
   for(int i = 0; i < 6; i++)
     {
      ObjectSetDouble(0, nombre, OBJPROP_LEVELVALUE, i, Levels[i]);
      ObjectSetString(0, nombre, OBJPROP_LEVELTEXT, i, "%$");
     }
  }

void LineaH(string nombre, double precio)
  {
   if(ObjectFind(0, nombre) < 0)
      ObjectCreate(0, nombre, OBJ_HLINE, 0, 0, precio);
   else
      ObjectSetDouble(0, nombre, OBJPROP_PRICE, 0, precio);
  }

int Hora(datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return(s.hour);
  }

#endif

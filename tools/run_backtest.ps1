# Compila un EA y lo pasa por el Strategy Tester de MT5 sin abrir la interfaz.
# Uso: .\tools\run_backtest.ps1 -Source LondonBreakout.mq5 -Name LB_v181 [-From 2021.01.01] [-To 2026.02.01] [-Delay 0]
param(
    [Parameter(Mandatory)] [string]$Source,     # archivo .mq5
    [Parameter(Mandatory)] [string]$Name,       # nombre de la corrida (EA compilado e informe)
    [string]$Symbol   = "EURUSD",
    [string]$Period   = "H1",
    [string]$From     = "2021.01.01",
    [string]$To       = "2026.02.01",
    [int]$Model       = 4,                       # 4 = cada tick basado en ticks reales
    [int]$Delay       = 0,                       # 0 = sin delay, -1 = delay aleatorio, >0 = ms fijos
    [int]$Deposit     = 10000,
    [string]$Terminal = "C:\Program Files\MetaTrader 5 IC Markets Global",
    [string]$DataDir  = "$env:APPDATA\MetaQuotes\Terminal\010E047102812FC0C18890992854220E"
)
$ErrorActionPreference = "Stop"

$expertsDir = Join-Path $DataDir "MQL5\Experts\LDB_tests"
$reportsDir = Join-Path $DataDir "reports"
New-Item -ItemType Directory -Force $expertsDir, $reportsDir | Out-Null

# 1. Compilar
$mq5 = Join-Path $expertsDir "$Name.mq5"
Copy-Item $Source $mq5 -Force
$log = Join-Path $expertsDir "$Name.log"
Start-Process -FilePath (Join-Path $Terminal "metaeditor64.exe") -ArgumentList "/compile:`"$mq5`"", "/log:`"$log`"" -Wait
$resultado = Get-Content $log -Encoding Unicode | Select-String "^Result:"
Write-Host "Compilación: $resultado"
if ($resultado -notmatch "^Result: 0 errors") { throw "La compilación falló, revisa $log" }

# 2. Configuración del tester
$ini = Join-Path $expertsDir "$Name.ini"
@"
[Tester]
Expert=LDB_tests\$Name.ex5
Symbol=$Symbol
Period=$Period
Model=$Model
ExecutionMode=$Delay
Optimization=0
FromDate=$From
ToDate=$To
Deposit=$Deposit
Currency=USD
Leverage=1:100
Visual=0
Report=reports\$Name
ReplaceReport=1
ShutdownTerminal=1
"@ | Set-Content $ini -Encoding ASCII

# 3. Ejecutar y esperar a que el terminal se cierre
$inicio = Get-Date
Start-Process -FilePath (Join-Path $Terminal "terminal64.exe") -ArgumentList "/config:`"$ini`"" -Wait
$informe = Join-Path $reportsDir "$Name.htm"
if (-not (Test-Path $informe) -or (Get-Item $informe).LastWriteTime -lt $inicio) { throw "No se generó el informe $informe" }
Write-Host ("Informe: {0}  ({1:N1} min)" -f $informe, ((Get-Date) - $inicio).TotalMinutes)

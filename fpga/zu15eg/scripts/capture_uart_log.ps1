param(
    [Parameter(Mandatory = $true)]
    [string]$PortName,
    [int]$BaudRate = 115200,
    [int]$DurationSeconds = 180,
    [string]$OutFile = "",
    [int]$ReadTimeoutMs = 200
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zu15egDir = Resolve-Path (Join-Path $scriptDir "..")
$outDir = Join-Path $zu15egDir "out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutFile = Join-Path $outDir "uart_${PortName}_$timestamp.log"
}

$serial = [System.IO.Ports.SerialPort]::new($PortName, $BaudRate, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.ReadTimeout = $ReadTimeoutMs
$serial.NewLine = "`n"

$writer = [System.IO.StreamWriter]::new($OutFile, $false, [System.Text.Encoding]::ASCII)
$start = Get-Date

try {
    $serial.Open()
    Write-Host "Capturing $PortName at $BaudRate baud for $DurationSeconds seconds"
    Write-Host "UART log: $OutFile"
    $writer.WriteLine("# UART_CAPTURE port=$PortName baud=$BaudRate start=$($start.ToString("o"))")

    while (((Get-Date) - $start).TotalSeconds -lt $DurationSeconds) {
        try {
            $line = $serial.ReadLine()
            $clean = $line.TrimEnd("`r", "`n")
            $writer.WriteLine($clean)
            $writer.Flush()
            Write-Host $clean
        } catch [System.TimeoutException] {
            $writer.Flush()
        }
    }
} finally {
    $stop = Get-Date
    $writer.WriteLine("# UART_CAPTURE stop=$($stop.ToString("o"))")
    $writer.Dispose()
    if ($serial.IsOpen) {
        $serial.Close()
    }
    $serial.Dispose()
}

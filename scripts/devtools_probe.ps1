$wsUrl = 'ws://127.0.0.1:9222/devtools/page/95B18395D6D2C515250A3A06D6D33F58'
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$enc=[System.Text.Encoding]::UTF8
$outFile = "$PSScriptRoot\devtools_probe.out.txt"
Remove-Item -ErrorAction SilentlyContinue $outFile
try {
  $ws.ConnectAsync([Uri]$wsUrl,[Threading.CancellationToken]::None).Wait(3000)
  if ($ws.State -ne 'Open') { "$((Get-Date).ToString()) Connect failed: $($ws.State)" | Out-File -FilePath $outFile -Append; exit 1 }
  $send = {
    param($obj)
    $msg=(ConvertTo-Json $obj -Compress)
    $bytes=$enc.GetBytes($msg)
    $ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait(2000)
  }
  & $send @{ id = 1; method = 'Runtime.enable' }
  & $send @{ id = 2; method = 'Runtime.evaluate'; params = @{ expression = 'document.title'; returnByValue = $true } }
  & $send @{ id = 3; method = 'Runtime.evaluate'; params = @{ expression = '(typeof window.updateMarkdown) + "|" + (window.HexoPreview?window.HexoPreview.version:null)'; returnByValue = $true } }

  $buffer = New-Object byte[] 8192
  $seg = New-Object System.ArraySegment[byte] $buffer
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt 6) {
    $res = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None)
    $res.Wait(2500)
    if ($res.Result.Count -gt 0) {
      $s = $enc.GetString($buffer,0,$res.Result.Count)
      "$((Get-Date).ToString()) :: $s" | Out-File -FilePath $outFile -Append
    }
    Start-Sleep -Milliseconds 100
  }
  $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,'bye',[Threading.CancellationToken]::None).Wait(2000)
} catch { "ERR: $_" | Out-File -FilePath $outFile -Append } finally { $ws.Dispose() }
Write-Output "WROTE: $outFile"
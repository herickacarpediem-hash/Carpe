$port = 8080
$endpoint = [System.Net.IPAddress]::Any
$listener = New-Object System.Net.Sockets.TcpListener($endpoint, $port)
$listener.Start()

Write-Host "CarpeDesafio Server running on port $port for ALL hostnames and IP addresses"

$baseDir = Get-Location

while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        
        $requestLine = $reader.ReadLine()
        if (-not $requestLine) {
            $client.Close()
            continue
        }

        # Consume remaining request headers
        while ($true) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { break }
        }

        $parts = $requestLine.Split(" ")
        if ($parts.Length -ge 2) {
            $rawPath = $parts[1].Split("?")[0].TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($rawPath)) {
                $rawPath = "index.html"
            }

            $filePath = Join-Path $baseDir $rawPath

            if (Test-Path $filePath -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                
                $contentType = switch ($ext) {
                    ".html" { "text/html; charset=utf-8" }
                    ".css"  { "text/css; charset=utf-8" }
                    ".js"   { "application/javascript; charset=utf-8" }
                    ".json" { "application/json; charset=utf-8" }
                    ".png"  { "image/png" }
                    ".jpg"  { "image/jpeg" }
                    ".svg"  { "image/svg+xml" }
                    default { "application/octet-stream" }
                }

                $headerStr = "HTTP/1.1 200 OK`r`n" +
                             "Content-Type: $contentType`r`n" +
                             "Content-Length: $($bytes.Length)`r`n" +
                             "Access-Control-Allow-Origin: *`r`n" +
                             "Connection: close`r`n`r`n"

                $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerStr)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($bytes, 0, $bytes.Length)
            } else {
                $notFoundStr = "404 Not Found"
                $notFoundBytes = [System.Text.Encoding]::UTF8.GetBytes($notFoundStr)
                $headerStr = "HTTP/1.1 404 Not Found`r`n" +
                             "Content-Type: text/plain`r`n" +
                             "Content-Length: $($notFoundBytes.Length)`r`n" +
                             "Connection: close`r`n`r`n"
                
                $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerStr)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($notFoundBytes, 0, $notFoundBytes.Length)
            }
        }
        $stream.Flush()
        $client.Close()
    } catch {
        # Ignore client disconnects
    }
}

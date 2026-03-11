$port = 8000
$path = $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "Iniciando servidor local en http://localhost:$port/"
Write-Host "Presiona Ctrl+C para detener el servidor"

# Abrir el navegador automáticamente
Start-Process "http://localhost:$port/"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $localPath = $request.Url.LocalPath
        if ($localPath -eq "/") {
            $localPath = "/index.html"
        }

        # Manejar API de descarga de YouTube
        if ($localPath.StartsWith("/api/yt-download")) {
            try {
                if ($request.HttpMethod -eq "POST") {
                    $reader = New-Object IO.StreamReader($request.InputStream, [Text.Encoding]::UTF8)
                    $body = $reader.ReadToEnd()
                    $json = $body | ConvertFrom-Json
                    $url = $json.url
                    $type = $json.type # "video", "video-noaudio", "audio"
                    $quality = $json.quality # "best", "1080", "720", etc.

                    $toolsPath = Join-Path $path "bin"
                    if (-not (Test-Path $toolsPath)) { New-Item -ItemType Directory -Force -Path $toolsPath | Out-Null }
                    $ytdlp = Join-Path $toolsPath "yt-dlp.exe"

                    if (-not (Test-Path $ytdlp)) {
                        Write-Host "Descargando yt-dlp.exe por primera vez..."
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytdlp
                    }

                    $downloadsPath = Join-Path $path "downloads"
                    if (-not (Test-Path $downloadsPath)) { New-Item -ItemType Directory -Force -Path $downloadsPath | Out-Null }

                    # Download FFmpeg if not present (required to merge high-res video and audio)
                    $ffmpegExe = Join-Path $toolsPath "ffmpeg.exe"
                    if (-not (Test-Path $ffmpegExe)) {
                        Write-Host "Descargando FFmpeg (necesario para alta calidad / combinar audio y video)..."
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-win32-x64" -OutFile $ffmpegExe
                    }

                    $format = switch ($type) {
                        "video-noaudio" {
                            if ($quality -eq "best") { "bestvideo[ext=mp4]/bestvideo" }
                            else { "bestvideo[height<=$quality][ext=mp4]/bestvideo[height<=$quality]/bestvideo" }
                        }
                        "audio" {
                            "bestaudio[ext=m4a]/bestaudio/best"
                        }
                        default { # video with audio
                            if ($quality -eq "best") { "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best" }
                            else { "bestvideo[height<=$quality][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$quality]+bestaudio/best[height<=$quality]" }
                        }
                    }

                    $outputTemplate = Join-Path $downloadsPath "%(title)s_%(id)s.%(ext)s"

                    Write-Host "Procesando descarga: $url ($type, $quality)"
                    $ytArgs = @("--ffmpeg-location", $ffmpegExe, "--print", "after_move:filepath", "--no-playlist", "--no-warnings", "-o", $outputTemplate, "-f", $format, $url)
                    $result = & $ytdlp $ytArgs

                    $downloadedFile = $result | Where-Object { $_ -match "\S" } | Select-Object -Last 1

                    if ($downloadedFile -and (Test-Path $downloadedFile)) {
                        $relativePath = $downloadedFile.Replace($path, "").Replace("\", "/")
                        if (-not $relativePath.StartsWith("/")) { $relativePath = "/$relativePath" }

                        $responseObj = @{ success = $true; fileUrl = $relativePath; title = [System.IO.Path]::GetFileNameWithoutExtension($downloadedFile) }
                        $resBody = $responseObj | ConvertTo-Json
                        $response.StatusCode = 200
                        $response.ContentType = "application/json"
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes($resBody)
                        $response.ContentLength64 = $bytes.Length
                        $response.OutputStream.Write($bytes, 0, $bytes.Length)
                    } else {
                        throw "No se pudo descargar el archivo o la URL no es válida."
                    }
                }
            } catch {
                Write-Host "Error en la API: $_"
                $responseObj = @{ success = $false; error = $_.Exception.Message }
                $resBody = $responseObj | ConvertTo-Json
                $response.StatusCode = 500
                $response.ContentType = "application/json"
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($resBody)
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            $response.Close()
            continue
        }

        # Manejar API de conversión de documentos
        if ($localPath.StartsWith("/api/convert-doc")) {
            try {
                if ($request.HttpMethod -eq "POST") {
                    $reader = New-Object IO.StreamReader($request.InputStream, [Text.Encoding]::UTF8)
                    $body = $reader.ReadToEnd()
                    $json = $body | ConvertFrom-Json
                    
                    $fileName = $json.fileName
                    $contentBase64 = $json.content
                    $type = $json.type # "pdf2docx" o "docx2pdf"
                    
                    # Decodificar y guardar temporalmente
                    $tempDir = Join-Path $path "bin\temp"
                    if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Force -Path $tempDir | Out-Null }
                    
                    $downloadsPath = Join-Path $path "downloads"
                    if (-not (Test-Path $downloadsPath)) { New-Item -ItemType Directory -Force -Path $downloadsPath | Out-Null }

                    $inputPath = Join-Path $tempDir $fileName
                    $bytes = [Convert]::FromBase64String($contentBase64)
                    [System.IO.File]::WriteAllBytes($inputPath, $bytes)
                    
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                    $outExt = if ($type -eq "pdf2docx") { ".docx" } else { ".pdf" }
                    $outputName = $baseName + $outExt
                    $outputPath = Join-Path $downloadsPath $outputName
                    
                    $pythonScript = Join-Path $path "bin\doc_converter.py"
                    
                    Write-Host "Ejecutando conversión con Python: $type"
                    
                    # Comprobar Python
                    if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
                        throw "Python no está instalado o no está en el PATH de Windows."
                    }
                    
                    # Intentar instalar dependencias si fallan
                    $checkDeps = & python -c "import docx2pdf; import pdf2docx" 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Instalando dependencias de Python (docx2pdf, pdf2docx)..."
                        & python -m pip install docx2pdf pdf2docx pywin32
                    }
                    
                    # Ejecutar Python
                    $pyArgs = @($pythonScript, $type, $inputPath, $outputPath)
                    $pyResult = & python $pyArgs 2>&1
                    
                    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPath)) {
                        throw "Error en Python: $pyResult"
                    }
                    
                    # Limpiar input
                    Remove-Item $inputPath -Force
                    
                    $relativePath = $outputPath.Replace($path, "").Replace("\", "/")
                    if (-not $relativePath.StartsWith("/")) { $relativePath = "/$relativePath" }

                    $responseObj = @{ success = $true; fileUrl = $relativePath; outputName = $outputName }
                    $resBody = $responseObj | ConvertTo-Json
                    $response.StatusCode = 200
                    $response.ContentType = "application/json"
                    $outBytes = [System.Text.Encoding]::UTF8.GetBytes($resBody)
                    $response.ContentLength64 = $outBytes.Length
                    $response.OutputStream.Write($outBytes, 0, $outBytes.Length)
                }
            } catch {
                Write-Host "Error en Doc API: $_"
                $responseObj = @{ success = $false; error = $_.Exception.Message }
                $resBody = $responseObj | ConvertTo-Json
                $response.StatusCode = 500
                $response.ContentType = "application/json"
                $outBytes = [System.Text.Encoding]::UTF8.GetBytes($resBody)
                $response.ContentLength64 = $outBytes.Length
                $response.OutputStream.Write($outBytes, 0, $outBytes.Length)
            }
            $response.Close()
            continue
        }

        $filePath = Join-Path $path $localPath

        if (Test-Path $filePath -PathType Leaf) {
            $content = [System.IO.File]::ReadAllBytes($filePath)
            
            # Establecer un Content-Type básico
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            switch ($ext) {
                ".html" { $response.ContentType = "text/html; charset=utf-8" }
                ".css"  { $response.ContentType = "text/css" }
                ".js"   { $response.ContentType = "application/javascript" }
                ".png"  { $response.ContentType = "image/png" }
                ".jpg"  { $response.ContentType = "image/jpeg" }
                ".svg"  { $response.ContentType = "image/svg+xml" }
                ".mp4"  { $response.ContentType = "video/mp4" }
                ".m4a"  { $response.ContentType = "audio/mp4" }
                ".webm" { $response.ContentType = "video/webm" }
                ".mp3"  { $response.ContentType = "audio/mpeg" }
                default { $response.ContentType = "application/octet-stream" }
            }
            
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
        } else {
            $response.StatusCode = 404
            $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
        }
        
        $response.Close()
    }
}
catch {
    Write-Host "Servidor detenido."
}
finally {
    $listener.Stop()
}

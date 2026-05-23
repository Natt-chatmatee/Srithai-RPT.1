$port = if ($args[0]) { $args[0] } else { 3000 }
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css'
    '.js'   = 'application/javascript'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.ico'  = 'image/x-icon'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()

Write-Host "Server running at http://localhost:$port"
[Console]::Out.Flush()

while ($listener.IsListening) {
    try {
        $ctx  = $listener.GetContext()
        $req  = $ctx.Request
        $resp = $ctx.Response

        $urlPath = $req.Url.LocalPath
        if ($urlPath -eq '/' -or $urlPath -eq '') { $urlPath = '/index.html' }

        $file = Join-Path $root $urlPath.TrimStart('/')

        if (Test-Path $file -PathType Leaf) {
            $ext  = [System.IO.Path]::GetExtension($file)
            $type = if ($mime[$ext]) { $mime[$ext] } else { 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $resp.ContentType   = $type
            $resp.ContentLength64 = $bytes.Length
            $resp.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $msg   = [System.Text.Encoding]::UTF8.GetBytes("Not found: $urlPath")
            $resp.StatusCode      = 404
            $resp.ContentType     = 'text/plain'
            $resp.ContentLength64 = $msg.Length
            $resp.OutputStream.Write($msg, 0, $msg.Length)
        }
        $resp.OutputStream.Close()
    } catch {}
}

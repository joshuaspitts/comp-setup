$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:3400/')
$listener.Start()
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $content = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot "todo.html"))
    $ctx.Response.ContentType = 'text/html; charset=utf-8'
    $ctx.Response.ContentLength64 = $content.Length
    $ctx.Response.OutputStream.Write($content, 0, $content.Length)
    $ctx.Response.OutputStream.Close()
}

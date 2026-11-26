# Markdown → DOCX (Windows PowerShell). Requires pandoc + mermaid-filter on PATH.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputMd,
    [Parameter(Position = 1)]
    [string]$OutputDocx = "",
    [switch]$NoMermaid,
    [switch]$Verify
)

$ErrorActionPreference = "Stop"

function Find-Exe([string]$Name) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

if ($Verify) {
    if (-not (Test-Path $InputMd)) { throw "missing $InputMd" }
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $InputMd))
    try {
        $e = $zip.GetEntry("word/document.xml")
        $sr = New-Object System.IO.StreamReader($e.Open())
        $xml = $sr.ReadToEnd()
        $sr.Close()
        $omml = ([regex]::Matches($xml, "m:oMath")).Count
        $media = ($zip.Entries | Where-Object { $_.FullName -like "word/media/*" }).Count
        Write-Output "file: $InputMd"
        Write-Output "omml_blocks: $omml"
        Write-Output "media_entries: $media"
    } finally { $zip.Dispose() }
    exit 0
}

$pandoc = if ($env:PANDOC) { $env:PANDOC } else { Find-Exe "pandoc" }
if (-not $pandoc) { throw "Pandoc not found. Install from https://pandoc.org or set `$env:PANDOC" }

$filter = $null
if (-not $NoMermaid) {
    $filter = if ($env:MERMAID_FILTER) { $env:MERMAID_FILTER } else { Find-Exe "mermaid-filter" }
    if (-not $filter) { throw "mermaid-filter not on PATH. npm i -g mermaid-filter or use -NoMermaid" }
}

$src = Resolve-Path $InputMd
$dir = Split-Path $src -Parent
$base = [System.IO.Path]::GetFileNameWithoutExtension($src)
if (-not $OutputDocx) { $OutputDocx = Join-Path $dir "$base.docx" }

$w = if ($env:MERMAID_FILTER_WIDTH) { $env:MERMAID_FILTER_WIDTH } else { "2400" }
$s = if ($env:MERMAID_FILTER_SCALE) { $env:MERMAID_FILTER_SCALE } else { "2.5" }
$prep = [System.IO.Path]::GetTempFileName() + ".md"
$content = Get-Content -LiteralPath $src -Raw
$content = $content -replace '(?m)^```mermaid$', "```{.mermaid width=$w scale=$s}"
Set-Content -LiteralPath $prep -Value $content -NoNewline -Encoding UTF8

$from = if ($env:PANDOC_FROM) { $env:PANDOC_FROM } else { "markdown+tex_math_dollars" }
$args = @($prep, "--from=$from", "--to=docx", "--standalone", "-o", $OutputDocx, "--resource-path=.:..")
if ($filter) { $args += "--filter=$filter" }

Push-Location $dir
try {
    & $pandoc @args
} finally {
    Pop-Location
    Remove-Item -LiteralPath $prep -Force -ErrorAction SilentlyContinue
}

Write-Output "written: $OutputDocx"
& $PSScriptRoot/md-to-docx.ps1 -InputMd $OutputDocx -Verify
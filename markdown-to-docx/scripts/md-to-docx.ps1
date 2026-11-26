# Markdown → DOCX (Windows PowerShell 5.1+ / PowerShell 7). Requires pandoc + mermaid-filter on PATH.
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

function Invoke-Verify([string]$Docx) {
    if (-not (Test-Path -LiteralPath $Docx)) { throw "missing $Docx" }
    # Windows PowerShell 5.1 does not load this assembly by default
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $full = (Resolve-Path -LiteralPath $Docx).Path
    $zip = [System.IO.Compression.ZipFile]::OpenRead($full)
    try {
        $e = $zip.GetEntry("word/document.xml")
        $sr = New-Object System.IO.StreamReader($e.Open())
        try { $xml = $sr.ReadToEnd() } finally { $sr.Close() }
        # Each formula is exactly one <m:oMath> (display math also wraps it in <m:oMathPara>)
        $omml = ([regex]::Matches($xml, "<m:oMath>")).Count
        $disp = ([regex]::Matches($xml, "<m:oMathPara>")).Count
        $media = @($zip.Entries | Where-Object { $_.FullName -like "word/media/*" }).Count
        Write-Output "file: $Docx"
        Write-Output "omml_blocks: $omml (display: $disp)"
        Write-Output "media_entries: $media"
    } finally { $zip.Dispose() }
}

if ($Verify) {
    Invoke-Verify $InputMd
    exit 0
}

$pandoc = if ($env:PANDOC) { $env:PANDOC } else { Find-Exe "pandoc" }
if (-not $pandoc) { throw "Pandoc not found. Install from https://pandoc.org or set `$env:PANDOC" }

$filter = $null
if (-not $NoMermaid) {
    $filter = if ($env:MERMAID_FILTER) { $env:MERMAID_FILTER } else { Find-Exe "mermaid-filter" }
    if (-not $filter) { throw "mermaid-filter not on PATH. npm i -g mermaid-filter or use -NoMermaid" }
}

$src = (Resolve-Path -LiteralPath $InputMd).Path
$dir = Split-Path $src -Parent
$base = [System.IO.Path]::GetFileNameWithoutExtension($src)
if (-not $OutputDocx) {
    $OutputDocx = Join-Path $dir "$base.docx"
} else {
    # Resolve relative to the caller's cwd, not the source dir pandoc runs in
    $OutputDocx = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDocx)
}

$w = if ($env:MERMAID_FILTER_WIDTH) { $env:MERMAID_FILTER_WIDTH } else { "2400" }
$s = if ($env:MERMAID_FILTER_SCALE) { $env:MERMAID_FILTER_SCALE } else { "2.5" }
$env:MERMAID_FILTER_WIDTH = $w
$env:MERMAID_FILTER_SCALE = $s
if (-not $env:MERMAID_FILTER_FORMAT) { $env:MERMAID_FILTER_FORMAT = "png" }
if (-not $env:MERMAID_FILTER_BACKGROUND) { $env:MERMAID_FILTER_BACKGROUND = "white" }
if (-not $env:MERMAID_FILTER_LOC) { $env:MERMAID_FILTER_LOC = "inline" }

$tmp = [System.IO.Path]::GetTempFileName()
$prep = "$tmp.md"
$content = [System.IO.File]::ReadAllText($src)
# ```mermaid / ~~~mermaid fences, tolerating CRLF and trailing spaces.
# Single-quoted replacement: backticks are literal (in double quotes they are PS escapes).
$replacement = '${fence}{.mermaid width=' + $w + ' scale=' + $s + '}'
$content = $content -replace '(?m)^(?<fence>`{3,}|~{3,})[ \t]*mermaid[ \t]*(?=\r?$)', $replacement
# UTF-8 without BOM
[System.IO.File]::WriteAllText($prep, $content, (New-Object System.Text.UTF8Encoding($false)))

$from = if ($env:PANDOC_FROM) { $env:PANDOC_FROM } else { "markdown+tex_math_dollars" }
# pandoc on Windows separates --resource-path entries with ';'
$pandocArgs = @($prep, "--from=$from", "--to=docx", "--standalone", "-o", $OutputDocx, "--resource-path=.;..")
if ($filter) { $pandocArgs += "--filter=$filter" }
if ($env:PANDOC_REFERENCE_DOC) {
    if (-not (Test-Path -LiteralPath $env:PANDOC_REFERENCE_DOC)) { throw "PANDOC_REFERENCE_DOC not found: $env:PANDOC_REFERENCE_DOC" }
    $pandocArgs += "--reference-doc=$((Resolve-Path -LiteralPath $env:PANDOC_REFERENCE_DOC).Path)"
}

Push-Location $dir
try {
    & $pandoc @pandocArgs
    if ($LASTEXITCODE -ne 0) { throw "pandoc failed (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $prep, $tmp -Force -ErrorAction SilentlyContinue
}

Write-Output "written: $OutputDocx"
Invoke-Verify $OutputDocx

<#
.SYNOPSIS
  Genera los Supporting Objects (APEXlang) de una app a partir de apps/<app>/install/install.sql.

.DESCRIPTION
  - Cada bloque "prompt == <Sección>" de install.sql se convierte en un installScript.
  - Los archivos referenciados con @@ se concatenan en
    apps/<app>/apexlang/supporting-objects/install-scripts/NN_<seccion>.sql
  - install/deinstall.sql se copia a supporting-objects/deinstall-script.sql
  - Reescribe supporting-objects/supporting-objects.apx
  Todo se escribe en UTF-8 sin BOM y con LF (requisito de APEXlang).

.EXAMPLE
  .\tools\build-supporting-objects.ps1 -App adm
#>
param(
    [Parameter(Mandatory = $true)][string]$App
)

$ErrorActionPreference = 'Stop'
$root      = Split-Path -Parent $PSScriptRoot
$appDir    = Join-Path $root "apps\$App"
$installDir= Join-Path $appDir 'install'
$soDir     = Join-Path $appDir 'apexlang\supporting-objects'
$scriptsDir= Join-Path $soDir 'install-scripts'
$utf8      = New-Object System.Text.UTF8Encoding($false)

function Write-Lf([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), $utf8)
}

function Get-Slug([string]$text) {
    $n = $text.Normalize([Text.NormalizationForm]::FormD)
    $n = -join ($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    return ($n.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
}

if (-not (Test-Path $soDir)) { throw "No existe $soDir (genere primero la app APEXlang)" }
if (Test-Path $scriptsDir) { Remove-Item -Recurse -Force $scriptsDir }
New-Item -ItemType Directory -Force $scriptsDir | Out-Null

# Parsear install.sql en secciones ------------------------------------------
$sections = New-Object System.Collections.ArrayList
$current  = $null
foreach ($line in Get-Content (Join-Path $installDir 'install.sql') -Encoding UTF8) {
    if ($line -match '^prompt\s+==\s+(.+)$') {
        $current = [pscustomobject]@{ Name = $Matches[1].Trim(); Files = New-Object System.Collections.ArrayList }
        [void]$sections.Add($current)
    }
    elseif ($line -match '^@@(.+)$' -and $current) {
        [void]$current.Files.Add((Join-Path $installDir $Matches[1].Trim()))
    }
}

# Generar scripts + .apx -----------------------------------------------------
$apx = New-Object Text.StringBuilder
[void]$apx.AppendLine('supportingObject (')
[void]$apx.AppendLine('    deinstall {')
[void]$apx.AppendLine('        scriptFile: deinstall-script.sql')
[void]$apx.AppendLine('    }')
[void]$apx.AppendLine('    advanced {')
[void]$apx.AppendLine('        includeInAppExport: true')
[void]$apx.AppendLine('    }')

$seq = 0
foreach ($s in $sections | Where-Object { $_.Files.Count -gt 0 }) {
    $seq += 10
    $slug = Get-Slug $s.Name
    $file = '{0:D2}_{1}.sql' -f ($seq / 10), $slug

    $body = New-Object Text.StringBuilder
    [void]$body.AppendLine("-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/$App/database)")
    foreach ($f in $s.Files) {
        $rel = (Resolve-Path $f).Path.Substring($root.Length + 1) -replace '\\', '/'
        [void]$body.AppendLine("`n-- >>> $rel")
        [void]$body.AppendLine(([IO.File]::ReadAllText((Resolve-Path $f), $utf8)).TrimEnd())
    }
    Write-Lf (Join-Path $scriptsDir $file) $body.ToString()

    [void]$apx.AppendLine('')
    [void]$apx.AppendLine("    installScript $slug (")
    [void]$apx.AppendLine('        execution {')
    [void]$apx.AppendLine("            sequence: $seq")
    [void]$apx.AppendLine('        }')
    [void]$apx.AppendLine('        script {')
    [void]$apx.AppendLine("            contentFile: $file")
    [void]$apx.AppendLine('        }')
    [void]$apx.AppendLine('    )')
    Write-Host ("  {0,-30} {1} archivo(s)" -f $file, $s.Files.Count)
}
[void]$apx.AppendLine(')')

Write-Lf (Join-Path $soDir 'supporting-objects.apx') $apx.ToString()
Write-Lf (Join-Path $soDir 'deinstall-script.sql') ([IO.File]::ReadAllText((Join-Path $installDir 'deinstall.sql'), $utf8))
Write-Host "Supporting Objects de '$App' generados en $soDir"

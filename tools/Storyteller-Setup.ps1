# Dead Days: Storyteller - setup helper.
#
#   .\Storyteller-Setup.ps1 -ClientCopy
#       Copy the mod into your own game client (C:\Users\<you>\Zomboid\mods) so you can
#       join a server running it, or play it in single player.
#
#   .\Storyteller-Setup.ps1 -PrepareWorkshop
#       Build Zomboid\Workshop\DeadDaysStoryteller so you can publish it from the
#       game's main menu (Workshop > Create/Update). Players need it from the
#       Workshop to join a public server running it.
#
#   .\Storyteller-Setup.ps1 -EnableOnServer [-WorkshopId 1234567890]
#       Edit data\Server\DeadDays.ini: remove QuestSystem, add DeadDaysStoryteller
#       after ProjectALifeNPCs. With -WorkshopId, also swaps QuestSystem's workshop
#       item for yours. Makes a timestamped backup of the ini first.
#       Stop the server before running this.

param(
    [switch]$ClientCopy,
    [switch]$PrepareWorkshop,
    [switch]$EnableOnServer,
    [string]$WorkshopId
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$mod = Join-Path $root 'data\mods\DeadDaysStoryteller'
$zomboid = Join-Path $env:USERPROFILE 'Zomboid'

if (-not (Test-Path $mod)) { throw "Mod not found at $mod" }

if ($ClientCopy) {
    $dest = Join-Path $zomboid 'mods\DeadDaysStoryteller'
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item -Recurse $mod $dest
    Write-Host "Copied to $dest"
}

if ($PrepareWorkshop) {
    $ws = Join-Path $zomboid 'Workshop\DeadDaysStoryteller'
    $contents = Join-Path $ws 'Contents\mods\DeadDaysStoryteller'
    if (Test-Path $contents) { Remove-Item -Recurse -Force $contents }
    New-Item -ItemType Directory -Force $contents | Out-Null
    Copy-Item -Recurse (Join-Path $mod '*') $contents
    $preview = Join-Path $ws 'preview.png'
    if (-not (Test-Path $preview)) {
        Add-Type -AssemblyName System.Drawing
        $bmp = New-Object System.Drawing.Bitmap 256, 256
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::FromArgb(18, 18, 20))
        $amber = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 168, 56))
        $light = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(236, 232, 220))
        $big = New-Object System.Drawing.Font 'Arial', 25, ([System.Drawing.FontStyle]::Bold)
        $small = New-Object System.Drawing.Font 'Arial', 15
        $g.DrawString('DEAD DAYS', $big, $amber, 18, 92)
        $g.DrawString('STORYTELLER', $small, $light, 22, 132)
        $bmp.Save($preview, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
    }
    $txt = Join-Path $ws 'workshop.txt'
    if (-not (Test-Path $txt)) {
        @(
            'version=1',
            'title=Dead Days: Storyteller',
            'description=A story director for Project Zomboid built on Project A-Life NPCs. A unique saga per world, branching dialogue, buddies, daily ops and convoys.',
            'tags=Build 42;Multiplayer;Realistic',
            'visibility=unlisted'
        ) | Set-Content -Path $txt -Encoding ascii
    }
    Write-Host "Workshop folder ready: $ws"
    Write-Host "In game: Main Menu > Workshop > Create and update items > DeadDaysStoryteller."
}

if ($EnableOnServer) {
    $ini = Join-Path $root 'data\Server\DeadDays.ini'
    $running = Get-NetUDPEndpoint -LocalPort 16261 -ErrorAction SilentlyContinue
    if ($running) { throw 'Port 16261 is in use - stop Dead Days first.' }
    Copy-Item $ini "$ini.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    $lines = Get-Content $ini
    $out = foreach ($line in $lines) {
        if ($line -match '^Mods=(.*)$') {
            $mods = $matches[1].Split(';') | Where-Object { $_ -and $_ -ne 'QuestSystem' -and $_ -ne 'DeadDaysStoryteller' }
            $list = New-Object System.Collections.ArrayList
            foreach ($m in $mods) { [void]$list.Add($m); if ($m -eq 'ProjectALifeNPCs') { [void]$list.Add('DeadDaysStoryteller') } }
            if (-not $list.Contains('DeadDaysStoryteller')) { [void]$list.Add('DeadDaysStoryteller') }
            'Mods=' + ($list -join ';')
        } elseif ($line -match '^WorkshopItems=(.*)$' -and $WorkshopId) {
            $items = $matches[1].Split(';') | Where-Object { $_ -and $_ -ne '3794041246' -and $_ -ne $WorkshopId }
            'WorkshopItems=' + (($items + $WorkshopId) -join ';')
        } else { $line }
    }
    [IO.File]::WriteAllLines($ini, $out, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host 'DeadDays.ini updated:'
    Select-String -Path $ini -Pattern '^(Mods|WorkshopItems)=' | ForEach-Object { '  ' + $_.Line }
    if (-not $WorkshopId) { Write-Host 'Note: no -WorkshopId given. Players without a local copy of the mod cannot join until it is on the Workshop.' }
}

if (-not ($ClientCopy -or $PrepareWorkshop -or $EnableOnServer)) {
    Get-Help $MyInvocation.MyCommand.Path
}

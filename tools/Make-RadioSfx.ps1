# Synthesises the radio sound effects into the mod's common/media/sound folder.
$ErrorActionPreference = 'Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'DdsAudio.cs')
$out = Join-Path $PSScriptRoot '..\data\mods\DeadDaysStoryteller\common\media\sound\dds_radio'
$out = [IO.Path]::GetFullPath($out)
[DdsAudio]::MakeSfx($out)
Get-ChildItem $out | Select-Object Name, Length

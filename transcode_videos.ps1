# Transcode iPhone .MOV demo videos -> Android+iOS-compatible H.264 .mp4
# HDR(BT.2020/Dolby Vision) tonemapped to SDR(BT.709), 720p, audio dropped.
# Deletes each .MOV only after its .mp4 converts successfully.

$ff = Get-ChildItem -Path "C:\ffmpeg","$HOME\Downloads" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $ff) { Write-Host "ffmpeg.exe not found - extract the zip first."; exit 1 }
Write-Host "Using ffmpeg: $ff"

$dir = "C:\Nam career\Projects\Vinafit_mobile\assets\video"
$ok = 0; $fail = 0
Get-ChildItem -Path $dir -Filter *.MOV | ForEach-Object {
  $in  = $_.FullName
  $out = [System.IO.Path]::ChangeExtension($in, ".mp4")
  Write-Host "Converting $($_.Name) ..."
  & $ff -hide_banner -loglevel error -y -i "$in" -map 0:v:0 -vf "scale=-2:720,zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p" -c:v libx264 -profile:v high -crf 23 -preset slow -an -movflags +faststart "$out"
  if ($LASTEXITCODE -eq 0) { Remove-Item "$in"; $ok++ } else { Write-Host "  FAILED: $($_.Name)"; $fail++ }
}
Write-Host "Done. Converted: $ok  Failed: $fail"

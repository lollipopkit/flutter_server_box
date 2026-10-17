param(
  [Parameter(Mandatory = $true)]
  [string]$BundleDirectory,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$bundle = (Resolve-Path -LiteralPath $BundleDirectory).Path
$files = @(Get-ChildItem -LiteralPath $bundle -File -Recurse | Sort-Object FullName)
if ($files.Count -eq 0) { throw "No bundle files found in $bundle" }

$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
$stream = [IO.File]::Open($output, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
try {
  foreach ($file in $files) {
    $entryName = [IO.Path]::GetRelativePath($bundle, $file.FullName).Replace('\', '/')
    $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
    $input = [IO.File]::OpenRead($file.FullName)
    $entryStream = $entry.Open()
    try {
      $input.CopyTo($entryStream)
    } finally {
      $entryStream.Dispose()
      $input.Dispose()
    }
  }
} finally {
  $archive.Dispose()
  $stream.Dispose()
}
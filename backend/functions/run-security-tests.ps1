$ErrorActionPreference = 'Stop'

$javaCandidates = @(
  'C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot',
  'C:\Program Files\Java\jdk-26.0.2',
  'C:\Program Files\Java\jdk-21'
)

$javaHome = $javaCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $javaHome) {
  throw 'JDK 21+ is required to run Firebase emulators.'
}

$env:JAVA_HOME = $javaHome
$env:PATH = "$javaHome\bin;$env:PATH"

$scriptDir = $PSScriptRoot
Push-Location $scriptDir
try {
  & npx firebase emulators:exec --project demo-labomba-rules --only firestore "node --test test/firestore-rules.test.js"
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}

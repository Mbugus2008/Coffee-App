$ErrorActionPreference = "Stop"
$endpoint = "http://test.trimline.co.ke:4548/BC240/ODataV4/Company('INUKA')/Items"
$defaultUom = "LTRS"
$pair = "Philip:Password@2030"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$authHeader = @{ Authorization = "Basic $b64"; Accept = "application/json"; "Content-Type" = "application/json" }

function Parse-DoubleSafe([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return 0 }
  $t = $v.Trim()
  if ($t -eq "NULL") { return 0 }
  $n = 0.0
  if ([double]::TryParse($t, [ref]$n)) { return $n }
  return 0
}

function Parse-IntSafe([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return 0 }
  $t = $v.Trim()
  if ($t -eq "NULL") { return 0 }
  $n = 0
  if ([int]::TryParse($t, [ref]$n)) { return $n }
  return 0
}

function Normalize-Uom([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return $defaultUom }
  $t = $v.Trim()
  if ($t -eq "NULL") { return $defaultUom }
  return $t
}

function Normalize-Description([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return "" }
  $t = $v.Trim()
  if ($t.Length -gt 100) { return $t.Substring(0, 100) }
  return $t
}

function Is-UomError($errorRecord) {
  $msg = ""
  try { $msg = $errorRecord.Exception.Message } catch {}
  if ($errorRecord.ErrorDetails -and $errorRecord.ErrorDetails.Message) {
    $msg = "$msg $($errorRecord.ErrorDetails.Message)"
  }
  return ($msg -like "*Unit of Measure with Code*")
}

$query = @"
SET NOCOUNT ON;
SELECT
  CAST([No] AS nvarchar(50)) AS [No],
  CAST([Description] AS nvarchar(250)) AS [Description],
  CAST([Base Unit of Measure] AS nvarchar(20)) AS [Base_Unit_of_Measure],
  CAST([Unit Cost] AS nvarchar(50)) AS [Unit_Cost],
  CAST([Unit Price] AS nvarchar(50)) AS [Unit_Price]
FROM dbo.Items
WHERE [No] IS NOT NULL AND LTRIM(RTRIM([No])) <> '';
"@

$raw = sqlcmd -S localhost -E -d Autoweigh -Q $query -W -s "|" -h -1
$rows = @()
foreach ($line in $raw) {
  if ([string]::IsNullOrWhiteSpace($line) -or $line -like "*rows affected*") { continue }
  $p = $line.Split("|")
  if ($p.Count -lt 5) { continue }
  $rows += [pscustomobject]@{
    No = $p[0].Trim()
    Description = $p[1].Trim()
    Base_Unit_of_Measure = $p[2].Trim()
    Unit_Cost = Parse-DoubleSafe $p[3]
    Unit_Price = Parse-DoubleSafe $p[4]
  }
}

$created = 0
$updated = 0
$failed = 0
$fallbackUomCount = 0
$trimmedDescriptionCount = 0

foreach ($r in $rows) {
  $normalizedUom = Normalize-Uom $r.Base_Unit_of_Measure
  $normalizedDescription = Normalize-Description $r.Description
  if ($normalizedDescription -ne $r.Description) { $trimmedDescriptionCount++ }

  $key = [Uri]::EscapeDataString($r.No)
  $itemUri = "$endpoint('$key')"
  $payload = @{
    No = $r.No
    Description = $normalizedDescription
    Base_Unit_of_Measure = $normalizedUom
    Unit_Cost = $r.Unit_Cost
    Unit_Price = $r.Unit_Price
  } | ConvertTo-Json

  try {
    Invoke-RestMethod -Method Get -Uri $itemUri -Headers @{ Authorization = "Basic $b64"; Accept = "application/json" } | Out-Null
    Invoke-RestMethod -Method Patch -Uri $itemUri -Headers (@{ Authorization = "Basic $b64"; Accept = "application/json"; "Content-Type" = "application/json"; "If-Match" = "*" }) -Body $payload | Out-Null
    $updated++
  }
  catch {
    $status = $null
    try { $status = $_.Exception.Response.StatusCode.value__ } catch {}

    if ($status -eq 404) {
      try {
        Invoke-RestMethod -Method Post -Uri $endpoint -Headers $authHeader -Body $payload | Out-Null
        $created++
      }
      catch {
        if ((Is-UomError $_) -and ($normalizedUom -ne $defaultUom)) {
          try {
            $payloadFallback = @{
              No = $r.No
              Description = $normalizedDescription
              Base_Unit_of_Measure = $defaultUom
              Unit_Cost = $r.Unit_Cost
              Unit_Price = $r.Unit_Price
            } | ConvertTo-Json
            Invoke-RestMethod -Method Post -Uri $endpoint -Headers $authHeader -Body $payloadFallback | Out-Null
            $created++
            $fallbackUomCount++
            continue
          }
          catch {}
        }

        $failed++
        $msg = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        try {
          $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
          $body = $reader.ReadToEnd()
          if ($body) { $msg = "$msg | $body" }
        }
        catch {}
        Write-Warning "POST failed for $($r.No): $msg"
      }
    }
    else {
      if ((Is-UomError $_) -and ($normalizedUom -ne $defaultUom)) {
        try {
          $payloadFallback = @{
            No = $r.No
            Description = $normalizedDescription
            Base_Unit_of_Measure = $defaultUom
            Unit_Cost = $r.Unit_Cost
            Unit_Price = $r.Unit_Price
          } | ConvertTo-Json
          Invoke-RestMethod -Method Patch -Uri $itemUri -Headers (@{ Authorization = "Basic $b64"; Accept = "application/json"; "Content-Type" = "application/json"; "If-Match" = "*" }) -Body $payloadFallback | Out-Null
          $updated++
          $fallbackUomCount++
          continue
        }
        catch {}
      }

      $failed++
      $msg = $_.Exception.Message
      if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
      try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $reader.ReadToEnd()
        if ($body) { $msg = "$msg | $body" }
      }
      catch {}
      Write-Warning "UPSERT failed for $($r.No): $msg"
    }
  }
}

Write-Output "Done. Source=$($rows.Count) Created=$created Updated=$updated Failed=$failed UomFallbacks=$fallbackUomCount DescTrimmed=$trimmedDescriptionCount"

$ErrorActionPreference = "Stop"

$bcUrl = "http://test.trimline.co.ke:4547/BC240/WS/INUKA/Page/Items"
$sourceServer = "localhost"
$sourceDb = "Autoweigh"

$username = "Philip"
$password = "Password@2030"
$pair = "$username`:$password"
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/atom+xml,application/xml"; "Content-Type" = "application/atom+xml;type=entry" }

# Read source rows
$query = @"
SET NOCOUNT ON;
SELECT
  CAST([No] AS nvarchar(50)) AS [No],
  CAST([Description] AS nvarchar(250)) AS [Description],
  CAST([Base Unit of Measure] AS nvarchar(20)) AS [BaseUnit],
  CAST([Last Direct Cost] AS float) AS [LastDirectCost],
  CAST([Unit Cost] AS float) AS [UnitCost],
  CAST([Unit Price] AS float) AS [UnitPrice],
  CAST([Inventory] AS float) AS [Inventory],
  CAST([Prevent_Negative_Inventory] AS int) AS [PreventNegative]
FROM dbo.Items
WHERE [No] IS NOT NULL AND LTRIM(RTRIM([No])) <> '';
"@

$raw = sqlcmd -S $sourceServer -E -d $sourceDb -Q $query -W -s "|" -h -1
$rows = @()
foreach ($line in $raw) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  if ($line -like "*rows affected*") { continue }
  $parts = $line.Split('|')
  if ($parts.Count -lt 8) { continue }
  $rows += [pscustomobject]@{
    No = $parts[0].Trim()
    Description = $parts[1].Trim()
    BaseUnit = $parts[2].Trim()
    LastDirectCost = $parts[3].Trim()
    UnitCost = $parts[4].Trim()
    UnitPrice = $parts[5].Trim()
    Inventory = $parts[6].Trim()
    PreventNegative = $parts[7].Trim()
  }
}

if ($rows.Count -eq 0) {
  Write-Output "No items found in Autoweigh.dbo.Items"
  exit 0
}

function Build-EntryXml {
  param(
    [string]$No,
    [string]$Description,
    [string]$BaseUnit,
    [string]$LastDirectCost,
    [string]$UnitCost,
    [string]$UnitPrice,
    [string]$Inventory,
    [string]$PreventNegative
  )

  $enc = [System.Security.SecurityElement]::Escape
  return @"
<entry xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" xmlns="http://www.w3.org/2005/Atom">
  <content type="application/xml">
    <m:properties>
      <d:No>$($enc.Invoke($No))</d:No>
      <d:Description>$($enc.Invoke($Description))</d:Description>
      <d:Base_Unit_of_Measure>$($enc.Invoke($BaseUnit))</d:Base_Unit_of_Measure>
      <d:Last_Direct_Cost m:type="Edm.Double">$LastDirectCost</d:Last_Direct_Cost>
      <d:Unit_Cost m:type="Edm.Double">$UnitCost</d:Unit_Cost>
      <d:Unit_Price m:type="Edm.Double">$UnitPrice</d:Unit_Price>
      <d:Inventory m:type="Edm.Double">$Inventory</d:Inventory>
      <d:Prevent_Negative_Inventory m:type="Edm.Int32">$PreventNegative</d:Prevent_Negative_Inventory>
    </m:properties>
  </content>
</entry>
"@
}

$created = 0
$updated = 0
$failed = 0

foreach ($r in $rows) {
  $key = [Uri]::EscapeDataString($r.No)
  $itemUri = "$bcUrl('$key')"

  $ldc = if ([string]::IsNullOrWhiteSpace($r.LastDirectCost)) { "0" } else { $r.LastDirectCost }
  $uc = if ([string]::IsNullOrWhiteSpace($r.UnitCost)) { "0" } else { $r.UnitCost }
  $up = if ([string]::IsNullOrWhiteSpace($r.UnitPrice)) { "0" } else { $r.UnitPrice }
  $inv = if ([string]::IsNullOrWhiteSpace($r.Inventory)) { "0" } else { $r.Inventory }
  $pni = if ([string]::IsNullOrWhiteSpace($r.PreventNegative)) { "0" } else { $r.PreventNegative }

  $body = Build-EntryXml -No $r.No -Description $r.Description -BaseUnit $r.BaseUnit -LastDirectCost $ldc -UnitCost $uc -UnitPrice $up -Inventory $inv -PreventNegative $pni

  try {
    Invoke-WebRequest -Method Get -Uri $itemUri -Headers @{ Authorization = "Basic $auth"; Accept = "application/atom+xml,application/xml" } -UseBasicParsing | Out-Null

    # Exists -> MERGE update
    Invoke-WebRequest -Method Post -Uri $itemUri -Headers (@{ Authorization = "Basic $auth"; Accept = "application/atom+xml,application/xml"; "Content-Type" = "application/atom+xml;type=entry"; "If-Match" = "*"; "X-HTTP-Method" = "MERGE" }) -Body $body -UseBasicParsing | Out-Null
    $updated++
  }
  catch {
    $status = $null
    try { $status = $_.Exception.Response.StatusCode.value__ } catch {}

    if ($status -eq 404) {
      try {
        Invoke-WebRequest -Method Post -Uri $bcUrl -Headers $headers -Body $body -UseBasicParsing | Out-Null
        $created++
      }
      catch {
        $failed++
        Write-Warning "Create failed for item '$($r.No)': $($_.Exception.Message)"
      }
    }
    else {
      $failed++
      Write-Warning "Lookup/Update failed for item '$($r.No)': $($_.Exception.Message)"
    }
  }
}

Write-Output "Done. Source rows: $($rows.Count), Created: $created, Updated: $updated, Failed: $failed"

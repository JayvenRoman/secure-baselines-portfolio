<#Essential Eight Compliance Demo Script
This script is specifically targeting AppLocker, Office Macros, IE 11, WDigest, and SMBv1#>

Write-Host "Enable Default AppLocker Rules"
New-ApplockerPolicy -DefaultRule -XMLPolicy "$env:TEMP\applocker.xml"
Set-ApplockerPolicy "$env:TEMP\applocker.xml" -Merge

Write-Host "Blocking Office Macros (VBAWarnings = 4)"
New-Item -Path HKCU:\Software\Microsoft\Office\16.0\Word\Security -Force | Out-Null
Set-ItemProperty ` 
    -Path HKCU:\Software\Microsoft\Office\16.0\Word\Security
    -Name VBAWarnings -Value 4

Write-Host "Disabling IE ver. 11"
$arch = $env:PROCESSOR_ARCHITECTURE
$featureName = "Internet-Explorer-Optional-$arch"
$featureStatus = Get-WindowsOptionalFeature -Online -FeatureName $featureName

try {
    $status = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction Stop
    if ($status.State -eq 'Enabled') {
        Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart
        Write-Host "    IE11 disabled."
    } else {
        Write-Host "    IE11 already disabled."
    }
} catch {
    Write-Warning "    Optional feature '$featureName' not found; skipping."
}

Write-Host "Diabling WDigest credential caching"
Set-ItemProperty `
  -Path HKLM:\System\CurrentControlSet\Control\SecurityProviders\WDigest `
  -Name UseLogonCredential -Value 0 -Type DWord

Write-Host "Disabling SMBv1"
Set-SmbServerCofiguration -EnableSMB1Protocol $false -Force

Write-Host "Essential Eight hardening complete"
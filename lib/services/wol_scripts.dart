import 'dart:convert';

part 'wol_linux_scripts.dart';

/// Script builders for 4-layer Wake-on-LAN diagnostics and remediation on
/// Windows (PowerShell / WMI / WinRM) and Linux (Bash / Python3 ioctl / systemd).
///
/// Every generated script emits a single machine-readable line prefixed with
/// [outputPrefix] so non-fatal warnings never break JSON parsing.
class WolScripts {
  WolScripts._();

  static const String outputPrefix = 'JA_WOL_JSON:';

  /// Builds a PowerShell script to inspect or optimize 4-layer WoL readiness.
  ///
  /// Set [allowAdapterRestart] to `true` ONLY for local UAC execution; keep it
  /// `false` over WinRM so resetting the NIC does not drop the remote session.
  static String buildWindowsScript({
    required bool applyFix,
    required bool allowAdapterRestart,
  }) {
    final fixLit = applyFix ? r'$true' : r'$false';
    final restartLit = allowAdapterRestart ? r'$true' : r'$false';
    return '''
\$ErrorActionPreference = 'Continue'
\$ProgressPreference = 'SilentlyContinue'
\$applyFix = $fixLit
\$allowRestart = $restartLit
${_windowsScriptBody()}
''';
  }

  /// Builds a single-line POSIX command that runs the 4-layer Linux WoL
  /// check/fix script over SSH, passing an optional [sudoPassword] cleanly.
  static String buildLinuxScript({
    required bool applyFix,
    String? sudoPassword,
  }) => _buildLinuxCommand(applyFix: applyFix, sudoPassword: sudoPassword);

  static String _windowsScriptBody() {
    return r'''
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$actions = New-Object 'System.Collections.Generic.List[string]'

$cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$hostName = if ($cs -and $cs.Name) { [string]$cs.Name } else { $env:COMPUTERNAME }
$modelStr = if ($cs) { ("{0} {1}" -f $cs.Manufacturer, $cs.Model).Trim() } else { '' }
$biosStr = if ($bios) { ("{0} {1}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion).Trim() } else { '' }

if ($applyFix -and (-not $isAdmin)) {
  $res = [ordered]@{
    os = 'windows'
    host = $hostName
    model = $modelStr
    bios = $biosStr
    isAdmin = $false
    authRequired = $true
    error = 'Administrator rights required to apply WoL changes on Windows.'
  }
  Write-Output ('JA_WOL_JSON:' + ($res | ConvertTo-Json -Compress -Depth 4))
  exit 0
}

$biosWmiSupported = $false
$biosPasswordSet = $false
$biosWolSetting = $null
$biosS5PowerSaving = $null
$biosNeedsReboot = $false

try {
  $pwList = @(Get-CimInstance -Namespace root\hp\instrumentedbios -ClassName HP_BIOSPassword -ErrorAction Stop)
  if ($pwList.Count -gt 0) {
    $biosWmiSupported = $true
    foreach ($pw in $pwList) {
      if ($pw.Name -eq 'Setup Password' -and [int]$pw.IsSet -ne 0) { $biosPasswordSet = $true }
    }
  }
} catch {}

$hpBiosList = @()
try {
  $hpBiosList = @(Get-CimInstance -Namespace root\hp\instrumentedbios -ClassName HP_BIOSSetting -ErrorAction Stop)
  if ($hpBiosList.Count -gt 0) { $biosWmiSupported = $true }
} catch {}

if ($hpBiosList.Count -gt 0) {
  $wolObj = $hpBiosList | Where-Object { $_.Name -eq 'Wake On LAN' } | Select-Object -First 1
  if ($wolObj) { $biosWolSetting = [string]$wolObj.CurrentValue }
  $s5Obj = $hpBiosList | Where-Object { $_.Name -eq 'S5 Maximum Power Savings' } | Select-Object -First 1
  if ($s5Obj) { $biosS5PowerSaving = [string]$s5Obj.CurrentValue }

  if ($applyFix -and $isAdmin -and (-not $biosPasswordSet)) {
    $biosIface = Get-CimInstance -Namespace root\hp\instrumentedbios -ClassName HP_BIOSSettingInterface -ErrorAction SilentlyContinue
    if ($biosIface) {
      if ($s5Obj -and ([string]$s5Obj.CurrentValue -match '^Enable')) {
        try {
          $r = Invoke-CimMethod -InputObject $biosIface -MethodName SetBIOSSetting -Arguments @{ Name = 'S5 Maximum Power Savings'; Value = 'Disable'; Password = '' } -ErrorAction Stop
          if ($r.Return -eq 0) { $biosS5PowerSaving = 'Disable'; $biosNeedsReboot = $true; $actions.Add('BIOS: S5 Maximum Power Savings -> Disable') }
        } catch {}
      }
      if ($wolObj -and ([string]$wolObj.CurrentValue -match '^Disable')) {
        $targetVal = if ($wolObj.PossibleValues -contains 'Boot to Hard Drive') { 'Boot to Hard Drive' } elseif ($wolObj.PossibleValues -contains 'Enable') { 'Enable' } elseif ($wolObj.PossibleValues -contains 'Boot to Normal Boot Order') { 'Boot to Normal Boot Order' } else { $null }
        if ($targetVal) {
          try {
            $r = Invoke-CimMethod -InputObject $biosIface -MethodName SetBIOSSetting -Arguments @{ Name = 'Wake On LAN'; Value = $targetVal; Password = '' } -ErrorAction Stop
            if ($r.Return -eq 0) { $biosWolSetting = $targetVal; $biosNeedsReboot = $true; $actions.Add("BIOS: Wake On LAN -> $targetVal") }
          } catch {}
        }
      }
    }
  }
}

$pcie = @(Get-NetAdapter -IncludeHidden:$false -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface -eq $true -and $_.PhysicalMediaType -eq '802.3' -and $_.PnPDeviceID -like 'PCI*' })
$usbLan = @(Get-NetAdapter -IncludeHidden:$false -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface -eq $true -and $_.PhysicalMediaType -eq '802.3' -and $_.PnPDeviceID -like 'USB*' })
$target = $pcie | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $target) { $target = $pcie | Select-Object -First 1 }

$usbOnly = ($null -eq $target) -and ($usbLan.Count -gt 0)
$inspected = if ($target) { $target } else { ($usbLan | Select-Object -First 1) }

function Set-JaNicProp($name, $key, $val, $label, $acts) {
  $p = Get-NetAdapterAdvancedProperty -Name $name -IncludeHidden -RegistryKeyword $key -ErrorAction SilentlyContinue
  if ($null -eq $p) { return }
  if ((($p.RegistryValue -join ',') -eq "$val")) { return }
  if ($p.ValidRegistryValues -and ($p.ValidRegistryValues -notcontains "$val")) { return }
  try {
    Set-NetAdapterAdvancedProperty -Name $name -IncludeHidden -RegistryKeyword $key -RegistryValue "$val" -NoRestart -ErrorAction Stop
    $acts.Add("NIC ${label} (${key}) -> ${val}")
  } catch {}
}

$powerRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'

if ($applyFix -and $isAdmin -and $target) {
  Set-JaNicProp $target.Name '*WakeOnMagicPacket' 1 'MagicPacket' $actions
  Set-JaNicProp $target.Name 'S5WakeOnLan' 1 'S5WoL' $actions
  Set-JaNicProp $target.Name 'EnablePME' 1 'EnablePME' $actions
  Set-JaNicProp $target.Name 'ReduceSpeedOnPowerDown' 1 'ReduceSpeed' $actions
  Set-JaNicProp $target.Name 'WolShutdownLinkSpeed' 0 'ShutdownLink10M' $actions
  Set-JaNicProp $target.Name '*WakeOnPattern' 0 'WakePattern' $actions
  Set-JaNicProp $target.Name '*EEE' 0 'EEE' $actions
  Set-JaNicProp $target.Name 'EEELinkAdvertisement' 0 'IntelEEE' $actions
  Set-JaNicProp $target.Name 'EnableGreenEthernet' 0 'GreenEth' $actions
  Set-JaNicProp $target.Name 'GreenEthernet' 0 'GreenEth' $actions
  Set-JaNicProp $target.Name 'PowerSavingMode' 0 'PowerSave' $actions
  Set-JaNicProp $target.Name 'ULPMode' 0 'ULPMode' $actions

  try {
    $pmBefore = Get-NetAdapterPowerManagement -Name $target.Name -ErrorAction SilentlyContinue
    if ($null -eq $pmBefore -or "$($pmBefore.WakeOnMagicPacket)" -ne 'Enabled' -or "$($pmBefore.WakeOnPattern)" -ne 'Disabled') {
      Set-NetAdapterPowerManagement -Name $target.Name -WakeOnMagicPacket Enabled -WakeOnPattern Disabled -NoRestart -ErrorAction Stop
      $actions.Add('PowerMgmt: WakeOnMagicPacket=Enabled, WakeOnPattern=Disabled')
    }
  } catch {}

  try {
    foreach ($inst in @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue | Where-Object { ([string]$_.InstanceName).StartsWith([string]$target.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) })) {
      if (-not $inst.Enable) { $inst | Set-CimInstance -Property @{ Enable = $true } -ErrorAction Stop; $actions.Add('WMI: MSPower_DeviceEnable=True') }
    }
    foreach ($inst in @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceWakeEnable -ErrorAction SilentlyContinue | Where-Object { ([string]$_.InstanceName).StartsWith([string]$target.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) })) {
      if (-not $inst.Enable) { $inst | Set-CimInstance -Property @{ Enable = $true } -ErrorAction Stop; $actions.Add('WMI: MSPower_DeviceWakeEnable=True') }
    }
    foreach ($inst in @(Get-CimInstance -Namespace root\wmi -ClassName MSNdis_DeviceWakeOnMagicPacketOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceName -eq $target.InterfaceDescription -or ([string]$_.InstanceName).StartsWith([string]$target.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) })) {
      if (-not $inst.EnableWakeOnMagicPacketOnly) { $inst | Set-CimInstance -Property @{ EnableWakeOnMagicPacketOnly = $true } -ErrorAction Stop; $actions.Add('WMI: WakeOnMagicPacketOnly=True') }
    }
  } catch {}

  try {
    $hb = (Get-ItemProperty -Path $powerRegPath -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($hb -ne 0) {
      Set-ItemProperty -Path $powerRegPath -Name HiberbootEnabled -Value 0 -Type DWord -ErrorAction Stop
      $actions.Add("OS: HiberbootEnabled ${hb} -> 0")
    }
  } catch {}

  try {
    & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    & powercfg.exe /setactive SCHEME_CURRENT | Out-Null
    $actions.Add('OS: PCIe ASPM AC -> Off')
  } catch {}

  if ($allowRestart) {
    try {
      Restart-NetAdapter -Name $target.Name -ErrorAction Stop
      for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 1
        $curA = Get-NetAdapter -Name $target.Name -ErrorAction SilentlyContinue
        if ($curA -and $curA.Status -eq 'Up') { break }
      }
      $actions.Add("NIC: Restarted $($target.Name)")
    } catch {}
  }

  try {
    & powercfg.exe /deviceenablewake "$($target.InterfaceDescription)" | Out-Null
    $actions.Add('OS: powercfg /deviceenablewake')
  } catch {}
}

$macNorm = ''
$ipStr = ''
$linkUp = $false
$wakeMagic = $null
$s5Wol = $null
$eeeOff = $null
$wmiWake = $null
$wakeArmed = $false

if ($inspected) {
  $live = Get-NetAdapter -Name $inspected.Name -ErrorAction SilentlyContinue
  if ($live) { $inspected = $live }
  $rawMac = (([string]$inspected.MacAddress) -replace '[:.\-]', '').ToUpperInvariant()
  if ($rawMac.Length -eq 12) {
    $macNorm = ($rawMac -replace '(.{2})(?=.)', '$1-')
  } else {
    $macNorm = [string]$inspected.MacAddress
  }
  $ipStr = [string](Get-NetIPAddress -InterfaceIndex $inspected.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1 -ExpandProperty IPAddress)
  $linkUp = ($inspected.Status -eq 'Up')

  $pm = Get-NetAdapterPowerManagement -Name $inspected.Name -ErrorAction SilentlyContinue
  $advMagic = Get-NetAdapterAdvancedProperty -Name $inspected.Name -IncludeHidden -RegistryKeyword '*WakeOnMagicPacket' -ErrorAction SilentlyContinue
  $advEnabled = if ($advMagic) { (($advMagic.RegistryValue -join '') -eq '1') } else { $null }
  $pmEnabled = if ($pm) { ("$($pm.WakeOnMagicPacket)" -eq 'Enabled') } else { $null }
  if ($null -ne $advEnabled -and $null -ne $pmEnabled) {
    $wakeMagic = ($advEnabled -and $pmEnabled)
  } elseif ($null -ne $advEnabled) {
    $wakeMagic = $advEnabled
  } elseif ($null -ne $pmEnabled) {
    $wakeMagic = $pmEnabled
  }

  $advS5 = Get-NetAdapterAdvancedProperty -Name $inspected.Name -IncludeHidden -RegistryKeyword 'S5WakeOnLan' -ErrorAction SilentlyContinue
  if ($advS5) { $s5Wol = (($advS5.RegistryValue -join '') -eq '1') }

  $eeeKeys = @('*EEE', 'EEELinkAdvertisement', 'EnableGreenEthernet', 'GreenEthernet', 'PowerSavingMode', 'ULPMode')
  $eeeProps = @(Get-NetAdapterAdvancedProperty -Name $inspected.Name -IncludeHidden -ErrorAction SilentlyContinue | Where-Object { $eeeKeys -contains $_.RegistryKeyword })
  if ($eeeProps.Count -gt 0) {
    $eeeOff = $true
    foreach ($ep in $eeeProps) {
      if (($ep.RegistryValue -join '') -eq '1') { $eeeOff = $false }
    }
  }

  try {
    $wmiInst = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceWakeEnable -ErrorAction Stop | Where-Object { ([string]$_.InstanceName).StartsWith([string]$inspected.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    if ($wmiInst) { $wmiWake = [bool]$wmiInst.Enable }
  } catch {}

  try {
    $armedLines = @(& powercfg.exe /devicequery wake_armed)
    foreach ($line in $armedLines) {
      if ($line.Trim() -like "*$($inspected.InterfaceDescription)*" -or ($inspected.InterfaceDescription -like "*$($line.Trim())*" -and $line.Trim().Length -gt 3)) {
        $wakeArmed = $true
      }
    }
  } catch {}
}

$hbVal = (Get-ItemProperty -Path $powerRegPath -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
$fastStartupOff = if ($null -ne $hbVal) { ([int]$hbVal -eq 0) } else { $true }

$aspmDisabled = $null
try {
  $aspmOut = (& powercfg.exe /q SCHEME_CURRENT SUB_PCIEXPRESS ASPM) -join "`n"
  $m = [regex]::Match($aspmOut, 'Current AC Power Setting Index:\s*(0x[0-9a-fA-F]+)')
  if ($m.Success) { $aspmDisabled = ($m.Groups[1].Value -eq '0x00000000') }
} catch {}

$out = [ordered]@{
  os = 'windows'
  host = $hostName
  model = $modelStr
  bios = $biosStr
  isAdmin = $isAdmin
  biosWmiSupported = $biosWmiSupported
  biosPasswordSet = $biosPasswordSet
  biosWolSetting = $biosWolSetting
  biosS5PowerSaving = $biosS5PowerSaving
  biosNeedsReboot = $biosNeedsReboot
  hasPcieNic = ($null -ne $target)
  usbOnlyNic = $usbOnly
  adapterName = if ($inspected) { [string]$inspected.Name } else { '' }
  adapterDesc = if ($inspected) { [string]$inspected.InterfaceDescription } else { '' }
  mac = $macNorm
  ip = $ipStr
  linkUp = $linkUp
  wakeOnMagicPacket = $wakeMagic
  s5WakeOnLan = $s5Wol
  eeeDisabled = $eeeOff
  wmiWakeEnabled = $wmiWake
  wakeArmed = $wakeArmed
  fastStartupDisabled = $fastStartupOff
  aspmDisabled = $aspmDisabled
  actions = @($actions)
}
Write-Output ('JA_WOL_JSON:' + ($out | ConvertTo-Json -Compress -Depth 5))
''';
  }
}

#
# Simple script to deploy and update Sysmon
# Files are served from our DC.
#
# Configurable stuff, the script expects "sysmon-<version>" directories at $PathToSysmonDeployment
# For instance: \\adc1\Files\sysmon-10.42
# It strips of the version and checks against the installed version. If they differ, upgrade.
#
# Configurable stuff

$PathToSysmonDeployment = "\\adc1\Files"
$PathToSysmonConfig = "\\adc1\Files\sysmonconfig\sysmonconfig-export.xml"
$PathToSysmonEXE = "$env:windir\sysmon.exe"
$ServiceName = "Sysmon"

# Find out latest version on ADC
Try {
  $LastVersionDirObject = Get-ChildItem -path \\adc1\Files | Where-Object {$_.FullName -match "sysmon-"} | sort | Select-Object -Last 1
  $LastVersion = $LastVersionDirObject.Name.Split("-")[1]
  Write-Output "Last available version on DC is: $LastVersion"
}

Catch {
  Write-Output "Could not determine latest version."
  Exit
}


function Install-Sysmon($Version) {
  Write-Output "Installing Sysmon"
  Copy-Item -Path $PathToSysmonConfig -Destination "$env:windir\sysmonconfig.xml"
  & "$PathToSysmonDeployment\sysmon-$Version\sysmon.exe" -accepteula -i c:\windows\sysmonconfig.xml 2>&1 | %{ "$_" }

}

function UnInstall-Sysmon {
  Write-Output "Uninstalling Sysmon"
  & $PathToSysmonEXE -u 2>&1 | %{ "$_" }
  # Try {
  #   Remove-Item -Path $PathToSysmonEXE
  #   Remove-Item -Path $PathToSysmonConfig
  # }
  # Catch {
  #   Write-Output "Could not delete remaining files"
  # }
}

# Find out if the Sysmon service is installed
if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue -ErrorVariable WindowsServiceExistsError) {
  Write-Output "Sysmon is installed, checking is upgrade is needed"
  
  # Check for latest Sysmon version on the ADC.
  # Get-ChildItem -path $PathToSysmonDeployment | Where-Object {$_.FullName -match "sysmon"}
  Try {
    $InstalledVersion = (Get-Item -Path $PathToSysmonEXE).VersionInfo.ProductVersion
  }
  
  Catch {
    Write-Host "Game over man, game over!"
  }    

  if($LastVersion -gt $InstalledVersion) {
    Write-Output "Latest version on $PathToSysmonDeployment is: $LastVersion"
    Write-Output "Installed version on $PathToSysmonEXE is: $InstalledVersion"

    # We need to upgrade
    UnInstall-Sysmon
    Install-Sysmon -Version $LastVersion
    
  } else {
    Write-Output "No upgrade needed"
  }
  
} else {
  Write-Output "No sysmon installed: $LastVersion"
  Install-Sysmon -Version $LastVersion

}
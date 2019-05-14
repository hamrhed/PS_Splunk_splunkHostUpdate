# #############################################################################
# SCRIPT - POWERSHELL
# NAME: splunkHostUpdate.ps1
# 
# AUTHOR:  	Don Garrison
# DATE:  	4/23/2019
# EMAIL: 	hamrhed@gmail.com
# 
# COMMENT:  This script updates INPUTS.CONF to reflect the correct HOST.
#
# VERSION HISTORY
# 	0.1 BETA: PoC
# 	0.2 BETA: Added features, currently testing
# 
# LOGGING INFO:
# 	Event Log = Application
#	Channel = SplunkHostUpdate
#	EventID = 1337  
#
# TO ADD: <nothing at this time>
#
#  
# #############################################################################


#FILES: (note: path includes trailing \)
$ChkFilePath = "c:\program files\SplunkUniversalForwarder\etc\system\local\"
$ChkFilename = "inputs.conf"
$TempFilename = "inputs.conf.temp"
$OldPath = $ChkFilePath+$ChkFilename
$TempPath = $ChkFilePath+$TempFilename


#EVENT LOG: Create new SOURCE
if (-not [System.Diagnostics.EventLog]::SourceExists("SplunkHostUpdate")){
	New-EventLog -LogName Application -Source "SplunkHostUpdate"
}
Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Information -EventID 1337 -Message "`n`n`tSplunkHostUpdate Started."


#USER: Verify member of local ADMINISTRATORS group
If ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){
} else {
	write-warning "This application must be run as an administrator."  
	Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Error -EventID 1337 -Message "`nERROR - SplunkHostUpdate must be run as a member of the local ADMINISTRATORS group.  PROCESS ABORTED"
	exit
}


#FILES: Confirm INPUTS.CONF exists
Try {$FileExists = Test-Path ($OldPath)}
Catch 
	{
		Write-warning "ERROR - Unable to edit file INPUTS.CONF." 
		Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Error -EventID 1337 -Message "`nERROR - Unable to edit file INPUTS.CONF."
		exit
	}

#FILES: Purge any existing INPUTS.CONF.TEMP from a prior execution
Try{ $FileExists = Test-Path ($TempPath) }
Catch 
	{
		Write-warning "ERROR - Unable to find INPUTS.CONF.TEMP." 
		Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Error -EventID 1337 -Message "`nERROR - Unable to find INPUTS.CONF.TEMP."
		exit
	}

If ($FileExists -eq $True) {
	Try {Remove-Item $TempPath}
	Catch 
	{
		Write-warning "ERROR - Unable to delete temporary file INPUTS.CONF.TEMP." 
		Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Error -EventID 1337 -Message "`nERROR - Unable to delete temporary file INPUTS.CONF.TEMP."
		exit
	}
} 


############################################
# ASSUMPTIONS: 
#	INPUTS.CONF exists at default install path (can be changed using variable above)
#	INPUTS.CONF.TEMP does not exist
#	User = Member of ADMINISTRATORS local group
############################################


#FILES: Backup existing INPUTS.CONF to INPUTS.CONF.YYYY-MM-DD__HH-mm-ss
Try
{
	copy-item  ($ChkFilePath+$ChkFilename) -Destination $ChkFilePath"inputs.conf.$(get-date -f yyyy-MM-dd__HH_mm_ss)" -ErrorAction Stop
}
Catch
{
	Write-warning "ERROR - Unable to backup INPUTS.CONF.  Please run as an administrator." 
	Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Error -EventID 1337 -Message "`nERROR - Unable to backup file INPUTS.CONF.  `n`n`t Please run as an administrator."
	exit
}

#LOCAL COMPUTER: Set hostname
$hostname = hostname
$oldHostname = ""


#UPDATE: Parse old INPUTS.CONF and save to INPUTS.CONF.TEMP, line by line.  If has "host" in it, then update that line to include the current computername
$FoundHost = 0
$LineNumber = 0
foreach($line in Get-Content $OldPath) {
    if(($line -like "* host *") -or ($line -like "host=*") -or ($line -like " host=*") -or ($line -like "host *")){
		$txtArray = $line.split("{=}")
		$oldHostname = $txtArray[1].trim()
		$line = "host = "+$hostname
		$tempLine = $line
		$FoundHost = 1
	}
		
	if ($oldHostname.ToUpper() -eq $hostname.ToUpper()){
		$error = "`n`n`tHostname already correctly set as "+$hostname.ToUpper()+"`n`n`tFINISHED`n"
		Write-Host $error -ForegroundColor green
		Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Information -EventID 1337 -Message "$error"
		exit
	} elseif ($line -like "host *"){
		$error = "`n`n`tUpdating file INPUTS.CONF:`n`n`t  HOST found on line = "+$LineNumber+"`n`n`t  Old Host = "+$OldHostname.ToUpper()+"`n`t  New Host = "+$hostname.ToUpper()
		Write-Host $error -ForegroundColor green
		Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Information -EventID 1337 -Message "$error"
	}
	$LineNumber++
	Add-Content $TempPath $line
}

#STATUS BAR
for($I = 1; $I -lt 100; $I+=5 )
{
    Write-Progress -Activity "Updating Splunk Host" -Status "Progress->" -PercentComplete $I  
}

#UPDATE: Add HOST if one didn't exist in the original INPUTS.Confirm
if (-not $FoundHost){
	Add-Content $TempPath $tempLine
}

#FILES: Delete old INPUTS.CONF	
Remove-Item $OldPath

#FILES: Rename temp to real
Rename-Item $TempPath $OldPath

#SERVICE: Restart splunkforwarder service
Write-Host "`n`tRestarting Splunk UniversalForwarder Service...`n" -ForegroundColor green
$WarningPreference='silentlycontinue'
Restart-Service -Name "SplunkForwarder Service"

#DISPLAY: Display confirmation
$error = "`n`tFINISHED`n"
Write-Host $error -ForegroundColor green
Write-EventLog -LogName Application -Source "SplunkHostUpdate" -EntryType Information -EventID 1337 -Message "$error"



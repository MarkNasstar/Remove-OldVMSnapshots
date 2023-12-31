##################################################################################
# _______________            ________       _________                    
# ___    |__  __/_______________  __ )_____ ______  /______ _____________
# __  /| |_  /_ __  ___/  __ \_  __  |  __ `/  __  /__  __ `/  _ \_  ___/
# _  ___ |  __/ _  /   / /_/ /  /_/ // /_/ // /_/ / _  /_/ //  __/  /    
# /_/  |_/_/    /_/    \____//_____/ \__,_/ \__,_/  _\__, / \___//_/     
#                                                  /____/               
##################################################################################
#################### mark.seymour@gmail.com #######################################
##################################################################################
###
##
## This script checks on VM snapshots and removes any that are x days old.  It also checks for
## any that belong to SQL Servers are deleted sooner
##
##
##

## Following Module are used to perform the scripts actions.
Import-Module VMware.VimAutomation.Core, KCOM.VMware, KCOM.General


#Static Variables
$HtmlReport = ""
$ReportWorthy = $false


#Email Variables
$smtpSrv = "smtp.mistral.net"
$from = "$env:computername@mspnet.pro"
$to = "cloudengineeringinfrastructureteam@nasstar.com"
#$to = "mark.seymour@nasstar.com"
$DebugPreference = "Continue"

#CSV import for multiple vCeters
$vcenters = Import-Csv "$psscriptroot\config\VsphereDetails.csv"


## Debug settings
#### No snapshots are deleted when safety is $true. ########
$safetyswitch = $true
#### Log file
$logfile = "$env:USERPROFILE\Purge-VMSnapshots.log"


# Function email if connection to vCenter fails
Function Watch-VcConnection ($status)
{
    $Subject = "$global:Product - ESXi Build Version Report - Error"
    [string]$body = "<P>vCenter: $($status.vcenter)</P>" + "</P><P>$($status.ErrorException.message)</P>" + "</P><P>$($status.message)</P>" 
    if ($status.connection -eq $false)
    {
        Send-NasstarMail -to $global:to -from $global:from -body $body -subject $Subject -BodyAsHtml
        exit
    }
    
}


####  MAIN SCRIPT #####

foreach ($vc in $vcenters)
{
    # Connects to vCenter
	Watch-VcConnection (Connect-Vcenter $vc.ipaddress $vc.user)
	$HtmlReport = @()
	
    # Initiates logging
    if (!(test-path $logfile))
	{
		$datetime = Get-Date -Format "dd-MMM-yyyy hh:mm"
		Write-Output "***  Script Started: $datetime ***`n" | Out-File $logfile
	}
	else
	{
		$datetime = Get-Date -Format "dd-MMM-yyyy hh:mm"
		Write-Output "***  Script Started: $datetime ***`n" | Out-File $logfile -Append
	}

	# Obtains arrays of VMs in different fillter categories
    $Allsnapshots = Get-VM | Get-Snapshot
	$21DayOldSnapshots = $Allsnapshots | Where-Object {$_.Created -le (Get-Date).AddDays(-21)}
	$21to14DayOldsnapshots = $Allsnapshots | Where-Object {$_.Created -ge (Get-Date).AddDays(-21) -and $_.Created -le (Get-Date).AddDays(-14)}
	
    ## HTML Report header is created
	$HtmlReport += ("<H1> {0} : VMware Snapshot Report</H1>" -f ($vc.name.Split(".")[0]))
    if ($safetyswitch) {$HtmlReport += "<H2>TESTING - No Snapshots have been deleted.</H2>"}
	$HtmlReport += "<H2> All Snapshots older that 21 Days</H2>"
	
    
    ## Checks to see if there are any snapshot older than 21 days
    if (!($null -eq $21DayOldSnapshots))
	{
		$ReportWorthy = $true
		$HtmlReport += "<P>The following snapshots have be deleted today</P>"
		$HtmlReport += Get-SnapShotInfo $21DayOldSnapshots | Select-Object VM,Name,"Created By","Days Old",SizeGB | Sort-Object "Days Old" -Descending | ConvertTo-Html -Fragment
		Write-Output "Deleting Snapshots" | Out-File $logfile -Append
        # Each snapshot is deleted if $saftyswitch is not $true
		foreach ($snap in $21DayOldSnapshots)
		{
            # Snapshot is logged before deletio
			Get-SnapshotInfo $snap | Select-Object VM,Name,"Created By","Days Old",SizeGB | Out-File $logfile -Append
			if (!($safetyswitch))
			{
                # SNAPSHOT DELETED!
    			$snap | Remove-Snapshot -Confirm:$false
			}
			else
			{
                # SAfty is on snapshot is NOT deleted and log written
			    Write-Output "Safety is on: Snapshot not deleted" | Out-File $logfile -Append
  			}
		}
	}
	else
	{
	$HtmlReport += "<P>No snapshots to delete</P>"
	}
	$HtmlReport += "<H2>Database Snapshots older that 14 Days</H2>"
	
	$HtmlReport += "<H2>All Snapshots older that 14 Days</H2>"


	if (!($null -eq $21to14DayOldsnapshots))
	{
		$HtmlReport += "<P>The following snapshots will be deleted next week</P>"
		$ReportWorthy = $true
		$HtmlReport += Get-SnapShotInfo $21to14DayOldsnapshots | Select-Object VM,Name,"Created By","Days Old",SizeGB | Sort-Object "Days Old" -Descending | ConvertTo-Html -Fragment
	}
	else
	{
	$HtmlReport += "<H2><P>No snapshots to delete</P></H2>"
	}


    # Checks to see if there us anything to report.
	if ($ReportWorthy -eq $true)
	{
        # Formats email depending on $saftyswitch status
		[string]$htmlbody = $HtmlReport
		if ($safetyswitch -eq $true)
        {
            $subject = ("{0}:VMware Snapshot Purge Report - TEST" -f ($vc.name.Split(".")[0]))
        }
		else {$subject = ("{0}:VMware Snapshot Purge Report" -f ($vc.name.Split(".")[0]))}
		Send-NasstarMail -smtpsvr $smtpSrv -From $from -To $to -Subject $subject -BodyAsHtml -Body $htmlbody
	}

	$datetime = Get-Date -Format "dd-MMM-yyyy hh:mm"
	Write-Output "***  Script Ended: $datetime ***`n" | Out-File $logfile -Append

	Disconnect-VIServer * -Confirm:$false
}
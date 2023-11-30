# Remove-OldVMSnapshots

This is a simple script that will report and delete Snapshots that are within a given time window.  The default is 21 days.

The script is set to run on a weekly basis and will report via email (html) what snapshots have been deleted and which will be deleted next week.

MODULES
This script requires the following modules
VMware.VimAutomation.Core (PowerShell Gallery)
KCOM.VMware (GitHub MarkNassstar)
KCOM.General (GitHub MarkNassstar)

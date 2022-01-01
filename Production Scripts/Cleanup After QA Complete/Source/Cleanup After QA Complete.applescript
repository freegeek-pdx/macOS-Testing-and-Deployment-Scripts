-- By: Pico Mitchell
-- For: MacLand @ Free Geek
--
-- MIT License
--
-- Copyright (c) 2021 Free Geek
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--

-- Version: 2021.12.30-1

-- App Icon is “Broom” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

use AppleScript version "2.4"
use scripting additions

repeat -- dialogs timeout when screen is asleep or locked (just in case)
	set isAwake to true
	try
		set isAwake to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :0:IOPowerManagement:CurrentPowerState' /dev/stdin <<< \"$(ioreg -arc IODisplayWrangler -k IOPowerManagement -d 1)\"") is equal to "4")
	end try
	
	set isUnlocked to true
	try
		set isUnlocked to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :IOConsoleUsers:0:CGSSessionScreenIsLocked' /dev/stdin <<< \"$(ioreg -ac IORegistryEntry -k IOConsoleUsers -d 1)\"") is not equal to "true")
	end try
	
	if (isAwake and isUnlocked) then
		exit repeat
	else
		delay 1
	end if
end repeat

set currentBundleIdentifier to "UNKNOWN"

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Cleanup After QA Complete" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
	try
		do shell script ("/usr/libexec/PlistBuddy -c 'Print :FGBuiltByMacLandScriptBuilder' " & (quoted form of infoPlistPath))
		((((POSIX path of (path to me)) & "Contents/MacOS/" & intendedAppName) as POSIX file) as alias)
	on error
		try
			activate
		end try
		display alert "
“" & (name of me) & "” must be built by the “MacLand Script Builder” script." buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end try
	
	set AppleScript's text item delimiters to "-"
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as string))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as string)
	if (currentBundleIdentifier is not equal to intendedBundleIdentifier) then error "“" & (name of me) & "” does not have the correct Bundle Identifier.


Current Bundle Identifier:
	" & currentBundleIdentifier & "

Intended Bundle Identifier:
	" & intendedBundleIdentifier
on error checkInfoPlistError
	if (checkInfoPlistError does not start with "Can’t make file") then
		try
			activate
		end try
		display alert checkInfoPlistError buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try

try
	set mainScptPath to ((POSIX path of (path to me)) & "Contents/Resources/Scripts/main.scpt")
	((mainScptPath as POSIX file) as alias)
	do shell script "osadecompile " & (quoted form of mainScptPath)
	error "
“" & (name of me) & "” must be exported as a Run-Only Script."
on error checkReadOnlyErrorMessage
	if ((checkReadOnlyErrorMessage does not contain "errOSASourceNotAvailable") and (checkReadOnlyErrorMessage does not start with "Can’t make file")) then
		try
			activate
		end try
		display alert checkReadOnlyErrorMessage buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try


set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"
set demoPassword to "freegeek"


if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
		set isMontereyOrNewer to (systemVersion ≥ "12.0")
	end considering
	
	set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
	
	try
		set automationGuideAppPath to "/Users/" & demoUsername & "/Applications/Automation Guide.app"
		((automationGuideAppPath as POSIX file) as alias)
		
		if (application automationGuideAppPath is running) then
			-- If Automation Guide is currently running, report the Accessibility permissions status and quit since Automation Guide is checking that it's safe to continue.
			
			try
				do shell script "mkdir " & (quoted form of buildInfoPath)
			end try
			
			if (isMojaveOrNewer) then
				try
					tell application "System Events" to every window -- To prompt for Automation access on Mojave
				on error automationAccessErrorMessage number automationAccessErrorNumber
					if (automationAccessErrorNumber is equal to -1743) then
						try
							do shell script ("tccutil reset AppleEvents " & currentBundleIdentifier) -- Clear AppleEvents (Automation) for this app in case user denied access in a previous attempt.
						end try
					end if
				end try
			end if
			
			set hasAccessibilityPermissions to false
			try
				tell application "System Events" to tell application process "Finder" to (get windows)
				set hasAccessibilityPermissions to true
			end try
			
			try
				do shell script ("echo " & hasAccessibilityPermissions & " > " & (quoted form of (buildInfoPath & ".fgAutomationGuideAccessibilityStatus-" & currentBundleIdentifier))) user name adminUsername password adminPassword with administrator privileges
			end try
		else
			-- If Automation Guide hasn't been run yet, launch it.
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script ("open -n -a " & (quoted form of automationGuideAppPath))
			end try
		end if
		
		quit
		delay 10
	end try
	
	set dialogIconName to "applet"
	try
		((((POSIX path of (path to me)) & "Contents/Resources/" & (name of me) & ".icns") as POSIX file) as alias)
		set dialogIconName to (name of me)
	end try
	
	if (isMojaveOrNewer) then
		set needsAutomationAccess to false
		try
			tell application "System Events" to every window -- To prompt for Automation access on Mojave
		on error automationAccessErrorMessage number automationAccessErrorNumber
			if (automationAccessErrorNumber is equal to -1743) then set needsAutomationAccess to true
		end try
		try
			tell application "Finder" to every window -- To prompt for Automation access on Mojave
		on error automationAccessErrorMessage number automationAccessErrorNumber
			if (automationAccessErrorNumber is equal to -1743) then set needsAutomationAccess to true
		end try
		
		if (needsAutomationAccess) then
			try
				tell application "System Preferences"
					try
						activate
					end try
					reveal ((anchor "Privacy") of (pane id "com.apple.preference.security"))
				end tell
			end try
			try
				activate
			end try
			try
				display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “System Events” and “Finder” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “System Events” and “Finder” checkboxes underneath it.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' &> /dev/null &"
				end try
			end try
			quit
			delay 10
		end if
	end if
	
	try
		tell application "System Events" to tell application process "Finder" to (get windows)
		
		-- If launched by Automation Guide, Accessibility permissions should already be granted, but we still want to check for System Preferences Automation permission.
		(((buildInfoPath & ".fgAutomationGuideRunning") as POSIX file) as alias)
		error "fgAutomationGuideRunning" -- throw this error if file DOES exist.
	on error (assistiveAccessTestErrorMessage)
		if (((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) or (assistiveAccessTestErrorMessage is equal to "fgAutomationGuideRunning")) then
			if (isMojaveOrNewer) then
				try
					tell application "System Preferences" to every window -- To prompt for Automation access on Mojave
				on error automationAccessErrorMessage number automationAccessErrorNumber
					if (automationAccessErrorNumber is equal to -1743) then
						try
							tell application "System Preferences"
								try
									activate
								end try
								reveal ((anchor "Privacy") of (pane id "com.apple.preference.security"))
							end tell
						end try
						try
							activate
						end try
						try
							display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “System Preferences” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “System Preferences” checkbox underneath it.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
							try
								do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' &> /dev/null &"
							end try
						end try
						quit
						delay 10
					end if
				end try
				try
					with timeout of 1 second
						tell application "System Preferences" to quit
					end timeout
				end try
			end if
			
			if (assistiveAccessTestErrorMessage is not equal to "fgAutomationGuideRunning") then
				try
					tell application "Finder" to reveal (path to me)
				end try
				try
					tell application "System Preferences"
						try
							activate
						end try
						reveal ((anchor "Privacy_Accessibility") of (pane id "com.apple.preference.security"))
					end tell
				end try
				try
					activate
				end try
				try
					display dialog "“" & (name of me) & "” must be allowed to control this computer using Accessibility Features to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Accessibility” in the source list on the left.

• Click the Lock icon at the bottom left of the window, enter the administrator username and password, and then click Unlock.

• Find “" & (name of me) & "” in the list on the right and turn on the checkbox next to it. If “" & (name of me) & "” IS NOT in the list, drag-and-drop the app icon from Finder into the list.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
					try
						do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' &> /dev/null &"
					end try
				end try
				quit
				delay 10
			end if
		end if
	end try
	
	
	set fgSetupName to "Free Geek Setup"
	
	try
		(((buildInfoPath & ".fgAutomationGuideRunning") as POSIX file) as alias)
		
		try
			do shell script ("touch " & (quoted form of (buildInfoPath & ".fgAutomationGuideDid-" & currentBundleIdentifier))) user name adminUsername password adminPassword with administrator privileges
		end try
		
		try
			(((buildInfoPath & ".fgAutomationGuideDid-org.freegeek.Free-Geek-Demo-Helper") as POSIX file) as alias)
			
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app"))
			end try
		on error
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app"))
			end try
		end try
		
		quit
		delay 10
	end try
	
	try
		(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
		((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
		
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script ("open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app'")
		end try
		
		quit
		delay 10
	end try
	
	try
		((("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app") as POSIX file) as alias)
		try
			activate
		end try
		display alert "“" & fgSetupName & "” Hasn't Finished Running" message "Please wait for “" & fgSetupName & "” to finish and then try running “" & (name of me) & "” again." buttons {"Quit"} default button 1 as critical giving up after 15
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app"))
		end try
		quit
		delay 10
	end try
	
	set needsTrimEnabled to false
	
	set AppleScript's text item delimiters to ""
	set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
	set driveInfoPath to tmpPath & "driveInfo.plist"
	repeat 30 times
		try
			do shell script "system_profiler -xml SPSerialATADataType SPNVMeDataType > " & (quoted form of driveInfoPath)
			tell application "System Events" to tell property list file driveInfoPath
				repeat with i from 1 to (number of property list items)
					set thisDataTypeProperties to (item i of property list items)
					set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as string)
					if ((thisDataType is equal to "SPSerialATADataType") or (thisDataType is equal to "SPNVMeDataType")) then
						set sataItems to (property list item "_items" of thisDataTypeProperties)
						repeat with j from 1 to (number of property list items in sataItems)
							set thisSataController to (property list item j of sataItems)
							set thisSataControllerName to ((value of property list item "_name" of thisSataController) as string)
							if (thisSataControllerName does not contain "Thunderbolt") then
								set thisSataControllerItems to (property list item "_items" of thisSataController)
								repeat with k from 1 to (number of property list items in thisSataControllerItems)
									try
										set thisSataControllerItem to (property list item k of thisSataControllerItems)
										set thisSataItemTrimSupport to "Yes" -- Default to Yes since drive may not be SSD and also don't want to get stuck in reboot loop if there's an error.
										
										if (thisDataType is equal to "SPNVMeDataType") then
											set thisSataItemTrimSupport to ((value of property list item "spnvme_trim_support" of thisSataControllerItem) as string)
										else
											set thisSataItemMediumType to ((value of property list item "spsata_medium_type" of thisSataControllerItem) as string)
											if (thisSataItemMediumType is equal to "Solid State") then set thisSataItemTrimSupport to ((value of property list item "spsata_trim_support" of thisSataControllerItem) as string)
										end if
										
										if (thisSataItemTrimSupport is not equal to "Yes") then
											set needsTrimEnabled to true
											exit repeat
										end if
									end try
								end repeat
							end if
							if (needsTrimEnabled) then exit repeat
						end repeat
					end if
				end repeat
			end tell
			exit repeat
		on error
			do shell script "rm -f " & (quoted form of driveInfoPath) -- Delete incase User Canceled
			delay 1 -- Wait and try again because it seems to fail sometimes when run on login.
		end try
	end repeat
	do shell script "rm -f " & (quoted form of driveInfoPath)
	
	if (needsTrimEnabled) then
		display alert "This Mac has an SSD installed,
but TRIM is not enabled." message "
This SHOULD NOT have happened and may indicate that there was an issue with the first boot automation.

This Mac CANNOT BE SOLD in its current state, please set this Mac aside and inform Free Geek I.T." buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
	
	set cleanupDialogButton to "   Cleanup & Shut Down   "
	-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
	if (isCatalinaOrNewer) then set cleanupDialogButton to "Cleanup & Shut Down      "
	
	try
		activate
	end try
	display dialog "Are you sure you're ready to Cleanup After QA Complete?

You should only Cleanup After QA Complete after you've:
	⁃ Finished the entire QA process.
	⁃ Logged this Mac as QA Complete in QA Helper.
	⁃ Set this Mac’s Product in PCs for People CRM.


The following actions will be peformed:
	⁃ Check if Remote Management is enabled on this Mac.
	⁃ Quit all running apps.
	⁃ Clear Clipboard contents.
	⁃ Reset Safari to factory settings.
	⁃ Erase Terminal history.
	⁃ Remove all printers.
	⁃ Remove all shared folders.
	⁃ Delete all Touch ID fingerprints.
	⁃ Move RAM Stress Test Logs to the “Build Info” folder.
	⁃ Empty the trash.
	⁃ Rename internal drive to “Macintosh HD”.
	⁃ Remove “FG Reuse” from preferred Wi-Fi networks.
	⁃ Turn on Wi-Fi.
	⁃ Set Power On and Shutdown schedules.
	⁃ Remove “QA Helper” alias from Desktop.
	⁃ Delete “Cleanup After QA Complete” app.
	⁃ Turn off “Screen Lock” setting in “System Preferences”.
	⁃ Set startup disk to internal disk in “System Preferences”.
	
This process cannot be undone.

THIS MAC WILL BE SHUT DOWN AFTER THE PROCESS IS COMPLETE." buttons {"Don't Cleanup After QA Complete Yet", cleanupDialogButton} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
	
	try
		activate
	end try
	display alert "It is very important that you do not click anything or disturb this Mac during this cleanup process." message "Towards the end of the cleanup process, “Screen Lock” will be disabled and the startup disk will be set to the internal disk by launching “System Preferences” and automatically clicking buttons and entering passwords." buttons {"OK, I will not disturb this Mac during Cleanup After QA Complete!"} default button 1 as critical giving up after 45
	
	set serialNumber to ""
	try
		set serialNumber to (do shell script "/usr/libexec/PlistBuddy -c 'Print 0:IOPlatformSerialNumber' /dev/stdin <<< \"$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)\"")
	end try
	
	if (serialNumber is not equal to "") then
		try
			repeat
				try
					do shell script "ping -t 5 -c 1 www.apple.com" -- Require that Internet is connected DEP status to get checked.
					exit repeat
				on error
					try
						display dialog "You must be connected to the Internet to be able to check for Remote Management.

The rest of “Cleanup After QA Complete” cannot be run and this Mac CANNOT BE SOLD until it has been confirmed that Remote Management is not enabled on this Mac.


Make sure you're connected to either the “Free Geek” or “FG Reuse” Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the Internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Quit", "Try Again"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName giving up after 30
					on error
						quit
						delay 10
					end try
				end try
			end repeat
			
			set progress total steps to -1
			set progress description to "
🔒	Checking for Remote Management"
			delay 0.5
			
			set remoteManagementOutput to ""
			try
				try
					set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" user name adminUsername password adminPassword with administrator privileges)
				on error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
					if (profilesShowDefaultUserErrorNumber is not equal to -60007) then error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
					try
						activate
					end try
					display alert "Would you like to check for
Remote Management (DEP/MDM)?" message "Remote Management check will be skipped in 10 seconds." buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 10
					if (gave up of result) then error number -128
					set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" with prompt "Administrator Permission is required
to check for Remote Management (DEP/MDM)." with administrator privileges)
				end try
			end try
			
			if (remoteManagementOutput is not equal to "") then
				try
					set AppleScript's text item delimiters to {linefeed, return}
					set remoteManagementOutputParts to (every text item of remoteManagementOutput)
					
					if ((count of remoteManagementOutputParts) > 3) then
						set progress description to "
⚠️	Remote Management IS Enabled"
						set remoteManagementOrganizationName to "\"Unknown Organization\""
						set remoteManagementOrganizationContactInfo to {}
						
						repeat with thisRemoteManagementOutputPart in remoteManagementOutputParts
							set organizationNameOffset to (offset of "OrganizationName = \"" in thisRemoteManagementOutputPart)
							set organizationDepartmentOffset to (offset of "OrganizationDepartment = \"" in thisRemoteManagementOutputPart)
							set organizationEmailOffset to (offset of "OrganizationEmail = \"" in thisRemoteManagementOutputPart)
							set organizationPhoneOffset to (offset of "OrganizationPhone = \"" in thisRemoteManagementOutputPart)
							set organizationSupportPhoneOffset to (offset of "OrganizationSupportPhone = \"" in thisRemoteManagementOutputPart)
							
							if (organizationNameOffset > 0) then
								set remoteManagementOrganizationName to (text (organizationNameOffset + 19) thru -2 of thisRemoteManagementOutputPart)
							else if (organizationDepartmentOffset > 0) then
								set remoteManagementOrganizationDepartment to (text (organizationDepartmentOffset + 26) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationDepartment is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationDepartment)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationDepartment
							else if (organizationEmailOffset > 0) then
								set remoteManagementOrganizationEmail to (text (organizationEmailOffset + 21) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationEmail
							else if (organizationPhoneOffset > 0) then
								set remoteManagementOrganizationPhone to (text (organizationPhoneOffset + 21) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationPhone
							else if (organizationSupportPhoneOffset > 0) then
								set remoteManagementOrganizationSupportPhone to (text (organizationSupportPhoneOffset + 28) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationSupportPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportPhone
							end if
						end repeat
						
						set remoteManagementOrganizationContactInfoDisplay to "NO CONTACT INFORMATION"
						if ((count of remoteManagementOrganizationContactInfo) > 0) then
							set AppleScript's text item delimiters to "
		"
							set remoteManagementOrganizationContactInfoDisplay to (remoteManagementOrganizationContactInfo as string)
						end if
						
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff"
						end try
						set remoteManagementDialogButton to "                                                       Shut Down                                                       "
						-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
						if (isCatalinaOrNewer) then set remoteManagementDialogButton to "Shut Down                                                                                                              "
						display dialog "	     ⚠️     REMOTE MANAGEMENT IS ENABLED ON THIS MAC     ⚠️

❌     MACS WITH REMOTE MANAGEMENT ENABLED CANNOT BE SOLD     ❌



🔒	THIS MAC IS MANAGED BY " & remoteManagementOrganizationName & "

🔑	ONLY " & remoteManagementOrganizationName & " CAN DISABLE REMOTE MANAGEMENT

☎️	" & remoteManagementOrganizationName & " MUST BE CONTACTED BY A MANAGER:
		" & remoteManagementOrganizationContactInfoDisplay & "

🆔	THE SERIAL NUMBER FOR THIS MAC IS \"" & serialNumber & "\"



		    👉 ‼️ INFORM AN INSTRUCTOR OR MANAGER ‼️ 👈" buttons {remoteManagementDialogButton} with title "Remote Management Enabled"
						tell application "System Events" to shut down with state saving preference
						
						quit
						delay 10
					else
						set progress description to "
👍	Remote Management IS NOT Enabled"
						delay 2
					end if
				end try
			else
				set progress description to "
❌	FAILED to Check for Remote Management"
				delay 2
			end if
		end try
	end if
	
	set progress total steps to -1
	set progress description to "
🔄	Cleaning Up After QA Complete"
	set progress additional description to ""
	
	-- QUIT ALL APPS
	try
		tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Demo Helper") and (short name is not (name of me))))
		if ((count of listOfRunningApps) > 0) then
			try
				repeat with thisAppName in listOfRunningApps
					try
						if (application thisAppName is running) then
							with timeout of 1 second
								tell application thisAppName to quit
							end timeout
						end if
					end try
				end repeat
			end try
			delay 3
			try
				tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Demo Helper") and (short name is not (name of me))))
				repeat with thisAppName in listOfRunningApps
					repeat 2 times
						try
							do shell script "pkill -f " & (quoted form of thisAppName)
						end try
					end repeat
				end repeat
			end try
		end if
	end try
	
	-- CLEAR THE CLIPBOARD CONTENTS
	try
		tell application "System Events" to set the clipboard to ""
	end try
	
	-- RESET SAFARI & TERMINAL
	try
		do shell script ("rm -rf /Users/" & adminUsername & "/Library/Safari; " & ¬
			"rm -rf '/Users/" & adminUsername & "/Library/Caches/Apple - Safari - Safari Extensions Gallery'; " & ¬
			"rm -rf /Users/" & adminUsername & "/Library/Caches/Metadata/Safari; " & ¬
			"rm -rf /Users/" & adminUsername & "/Library/Caches/com.apple.Safari; " & ¬
			"rm -rf /Users/" & adminUsername & "/Library/Caches/com.apple.WebKit.PluginProcess; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Cookies/Cookies.binarycookies; " & ¬
			"rm -rf '/Users/" & adminUsername & "/Library/Preferences/Apple - Safari - Safari Extensions Gallery'; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.LSSharedFileList.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.RSS.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.SafeBrowsing.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.SandboxBroker.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.SafariBookmarksSyncAgent.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.SafariCloudHistoryPushAgent.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.WebFoundation.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.WebKit.PluginHost.plist; " & ¬
			"rm -f /Users/" & adminUsername & "/Library/Preferences/com.apple.WebKit.PluginProcess.plist; " & ¬
			"rm -rf /Users/" & adminUsername & "/Library/PubSub/Database; " & ¬
			"rm -rf '/Users/" & adminUsername & "/Library/Saved Application State/com.apple.Safari.savedState'; " & ¬
			"rm -f /Users/" & adminUsername & "/.bash_history; " & ¬
			"rm -rf /Users/" & adminUsername & "/.bash_sessions; " & ¬
			"rm -f /Users/" & adminUsername & "/.zsh_history; " & ¬
			"rm -f '/Users/" & adminUsername & "/Desktop/QA Helper - Computer Specs.txt'; " & ¬
			"rm -rf '/Users/" & adminUsername & "/Desktop/Relocated Items'") user name adminUsername password adminPassword with administrator privileges
	end try
	try
		do shell script ("rm -rf /Users/" & demoUsername & "/Library/Safari; " & ¬
			"rm -rf '/Users/" & demoUsername & "/Library/Caches/Apple - Safari - Safari Extensions Gallery'; " & ¬
			"rm -rf /Users/" & demoUsername & "/Library/Caches/Metadata/Safari; " & ¬
			"rm -rf /Users/" & demoUsername & "/Library/Caches/com.apple.Safari; " & ¬
			"rm -rf /Users/" & demoUsername & "/Library/Caches/com.apple.WebKit.PluginProcess; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Cookies/Cookies.binarycookies; " & ¬
			"rm -rf '/Users/" & demoUsername & "/Library/Preferences/Apple - Safari - Safari Extensions Gallery'; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.LSSharedFileList.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.RSS.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.SafeBrowsing.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.SandboxBroker.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.SafariBookmarksSyncAgent.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.SafariCloudHistoryPushAgent.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.WebFoundation.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.WebKit.PluginHost.plist; " & ¬
			"rm -f /Users/" & demoUsername & "/Library/Preferences/com.apple.WebKit.PluginProcess.plist; " & ¬
			"rm -rf /Users/" & demoUsername & "/Library/PubSub/Database; " & ¬
			"rm -rf '/Users/" & demoUsername & "/Library/Saved Application State/com.apple.Safari.savedState'; " & ¬
			"rm -f /Users/" & demoUsername & "/.bash_history; " & ¬
			"rm -rf /Users/" & demoUsername & "/.bash_sessions; " & ¬
			"rm -f /Users/" & demoUsername & "/.zsh_history")
	end try
	
	-- DELETE ALL PRINTERS
	try
		set printerIDsText to (do shell script "lpstat -p | awk '{ print $2 }'")
		set AppleScript's text item delimiters to {linefeed, return}
		repeat with thisPrinterID in (every text item of printerIDsText)
			try
				do shell script ("lpadmin -x " & thisPrinterID)
			end try
		end repeat
	end try
	
	-- REMOVE ALL SHARED FOLDERS & SHAREPOINT GROUPS
	try
		set sharedFolderNames to (do shell script "sharing -l | grep 'name:		' | cut -c 8-")
		set AppleScript's text item delimiters to {linefeed, return}
		repeat with thisSharedFolderName in (every text item of sharedFolderNames)
			try
				do shell script ("sharing -r " & (quoted form of thisSharedFolderName)) user name adminUsername password adminPassword with administrator privileges
			end try
		end repeat
	end try
	try
		set sharePointGroups to (do shell script "dscl . -list /Groups | grep com.apple.sharepoint.group")
		set AppleScript's text item delimiters to {linefeed, return}
		repeat with thisSharePointGroupName in (every text item of sharePointGroups)
			try
				do shell script ("dseditgroup -o delete " & (quoted form of thisSharePointGroupName)) user name adminUsername password adminPassword with administrator privileges
			end try
		end repeat
	end try
	
	-- DELETING ALL TOUCH ID FINGERPRINTS
	try
		do shell script "bioutil -p -s <<< 'Y'" user name adminUsername password adminPassword with administrator privileges
	end try
	
	-- MUTE VOLUME WHILE FILES ARE MOVED AND TRASH IS EMPTIED
	try
		set volume output volume 0 with output muted
	end try
	try
		set volume alert volume 0
	end try
	
	-- TRASH DESKTOP FILES WITH FINDER INSTEAD OF RM SO FOLDER ACCESS IS NOT NECESSARY ON CATALINA AND NEWER
	try
		tell application "Finder"
			try
				delete file ((("/Users/" & demoUsername & "/Desktop/QA Helper - Computer Specs.txt") as POSIX file) as alias)
			end try
			try
				delete folder ((("/Users/" & demoUsername & "/Desktop/Relocated Items") as POSIX file) as alias)
			end try
		end tell
	end try
	
	-- MOVE MEMTEST LOG
	try
		tell application "Finder"
			try
				((buildInfoPath as POSIX file) as alias)
			on error
				try
					make new folder at (path to shared documents folder) with properties {name:"Build Info"}
				end try
			end try
			
			try
				((buildInfoPath as POSIX file) as alias)
				move (every file of (folder (path to desktop folder from user domain)) whose name extension is "log") to (buildInfoPath as POSIX file) with replacing
			end try
		end tell
	end try
	
	-- EMPTY THE TRASH
	try
		tell application "Finder"
			set warns before emptying of trash to false
			try
				empty the trash
			end try
			set warns before emptying of trash to true
		end tell
	end try
	
	-- RENAME HARD DRIVE
	try
		set intendedDriveName to "Macintosh HD"
		set currentDriveName to intendedDriveName
		tell application "System Events" to set currentDriveName to (name of startup disk)
		if (currentDriveName is not equal to intendedDriveName) then
			do shell script "/usr/sbin/diskutil rename " & (quoted form of currentDriveName) & " " & (quoted form of intendedDriveName) user name adminUsername password adminPassword with administrator privileges
			if (isCatalinaOrNewer) then do shell script "/usr/sbin/diskutil rename " & (quoted form of (currentDriveName & " - Data")) & " " & (quoted form of (intendedDriveName & " - Data")) user name adminUsername password adminPassword with administrator privileges
		end if
	end try
	
	-- FORGET "FG Reuse" AND TURN ON WI-FI
	set wirelessNetworkPasswordsToDelete to {}
	try
		set AppleScript's text item delimiters to ""
		tell application "System Events" to tell current location of network preferences
			repeat with thisActiveNetworkService in (every service whose active is true)
				if (((name of interface of thisActiveNetworkService) as string) is equal to "Wi-Fi") then
					set thisWiFiInterfaceID to ((id of interface of thisActiveNetworkService) as string)
					try
						set preferredWirelessNetworks to (paragraphs of (do shell script ("networksetup -listpreferredwirelessnetworks " & thisWiFiInterfaceID)))
						try
							set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & thisWiFiInterfaceID)
							set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
							if (getWiFiNetworkColonOffset > 0) then
								set (end of preferredWirelessNetworks) to ("	" & (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput))
							end if
						end try
						repeat with thisPreferredWirelessNetwork in preferredWirelessNetworks
							if (thisPreferredWirelessNetwork starts with "	") then
								set thisPreferredWirelessNetwork to ((characters 2 thru -1 of thisPreferredWirelessNetwork) as string)
								if (thisPreferredWirelessNetwork is not equal to "Free Geek") then
									try
										do shell script "networksetup -setairportpower " & thisWiFiInterfaceID & " off"
									end try
									try
										do shell script ("networksetup -removepreferredwirelessnetwork " & thisWiFiInterfaceID & " " & (quoted form of thisPreferredWirelessNetwork)) user name adminUsername password adminPassword with administrator privileges
									end try
									set (end of wirelessNetworkPasswordsToDelete) to thisPreferredWirelessNetwork
								end if
							end if
						end repeat
					end try
					try
						do shell script "networksetup -setairportpower " & thisWiFiInterfaceID & " on"
					end try
					try
						-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
						do shell script "networksetup -setairportnetwork " & thisWiFiInterfaceID & " 'Free Geek'" user name adminUsername password adminPassword with administrator privileges
					end try
				end if
			end repeat
		end tell
	end try
	-- "networksetup -removepreferredwirelessnetwork" does not remove the saved passwords from the Keychain, so do that too.
	repeat with thisWirelessNetworkPasswordsToDelete in wirelessNetworkPasswordsToDelete
		try -- Run without Admin to delete from Login keychain
			do shell script "security delete-generic-password -s 'AirPort' -l " & (quoted form of thisWirelessNetworkPasswordsToDelete)
		end try
		try -- Run WITH Admin to delete from System keychain
			do shell script "security delete-generic-password -s 'AirPort' -l " & (quoted form of thisWirelessNetworkPasswordsToDelete) user name adminUsername password adminPassword with administrator privileges
		end try
	end repeat
	try
		do shell script "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport prefs RememberRecentNetworks=NO" user name adminUsername password adminPassword with administrator privileges
	end try
	
	-- SET POWER ON AND SHUTDOWN SCHEDULE
	try
		do shell script "pmset repeat poweron TWRFSU 9:45:00 shutdown TWRFSU 18:10:00" user name adminUsername password adminPassword with administrator privileges
	end try
	
	-- IF ON MOJAVE, CATALINA UPDATE WAS HIDDEN. UN-HIDE IT SO CUSTOMER CAN UPDATE
	if (isMojaveOrNewer) then
		try
			do shell script "softwareupdate --reset-ignored" user name adminUsername password adminPassword with administrator privileges
		end try
	end if
	
	-- TURN OFF SCREEN LOCK
	try
		activate
	end try
	repeat 15 times
		try
			tell application "System Preferences"
				repeat 180 times -- Wait for Security pane to load
					try
						activate
					end try
					reveal ((anchor "General") of (pane id "com.apple.preference.security"))
					delay 1
					if ((name of window 1) is "Security & Privacy") then exit repeat
				end repeat
			end tell
			tell application "System Events" to tell application process "System Preferences"
				set screenLockCheckbox to (checkbox 1 of tab group 1 of window 1)
				if ((screenLockCheckbox's value as boolean) is true) then
					set frontmost to true
					click screenLockCheckbox
					repeat 180 times -- Wait for password prompt
						delay 0.5
						if ((number of sheets of window (number of windows)) is 1) then exit repeat
						delay 0.5
					end repeat
					set frontmost to true
					delay 0.5
					keystroke demoPassword & return
					repeat 180 times -- Wait for confirmation prompt
						delay 0.5
						if ((number of sheets of window (number of windows)) is 1) then exit repeat
						delay 0.5
					end repeat
					set frontmost to true
					
					repeat with thisSheetButton in (buttons of sheet 1 of window (number of windows))
						if ((name of thisSheetButton) is equal to "Turn Off Screen Lock") then
							set frontmost to true
							click thisSheetButton
						end if
					end repeat
					
					delay 1
				end if
				set screenLockCheckboxValue to (screenLockCheckbox's value as boolean)
			end tell
			if (screenLockCheckboxValue is false) then
				exit repeat
			end if
		end try
	end repeat
	
	-- SET STARTUP DISK
	set nameOfCurrentStartupDisk to "UNKNOWN"
	tell application "System Events" to set nameOfCurrentStartupDisk to (name of startup disk)
	
	if (nameOfCurrentStartupDisk is not equal to "UNKNOWN") then
		set didSetStartUpDisk to false
		
		repeat 15 times
			try
				tell application "System Preferences"
					repeat 180 times -- Wait for Security pane to load
						try
							activate
						end try
						reveal (pane id "com.apple.preference.startupdisk")
						delay 1
						if ((name of window 1) is "Startup Disk") then exit repeat
					end repeat
				end tell
				if (isCatalinaOrNewer) then
					-- On Catalina, a SecurityAgent alert with "System Preferences wants to make changes." will appear IF an Encrypted Disk is present.
					-- OR if Big Sur is installed on some drive, whose Sealed System Volume is unable to be mounted (ERROR -69808) and makes System Preferences think it needs to try again with admin privileges.
					-- In this case, we can just cancel out of that alert to continue on without displaying the Encrypted Disk or the Big Sur installation in the Startup Disk options.
					
					try
						do shell script "diskutil apfs list | grep 'Yes (Locked)\\|ERROR -69808'" -- Grep will error if not found.
						
						try -- Mute volume before key codes so it's silent if the window isn't open
							set volume output volume 0 with output muted
						end try
						try
							set volume alert volume 0
						end try
						
						set securityAgentPath to "/System/Library/Frameworks/Security.framework/Versions/A/MachServices/SecurityAgent.bundle"
						repeat 10 times -- Wait up to 10 seconds for SecurityAgent to launch since it can take a moment, but the script will stall if we go past this before it launches. 
							delay 1
							try
								if (application securityAgentPath is running) then
									exit repeat
								end if
							end try
						end repeat
						repeat 60 times
							delay 1
							try
								if (application securityAgentPath is running) then
									with timeout of 2 seconds -- Adding timeout to copy style of dismissing UserNotificationCenter for consistency.
										tell application "System Events" to tell application process "SecurityAgent"
											set frontmost to true
											key code 53 -- Cannot reliably get SecurityAgent windows, so if it's running (for decryption prompts) just hit escape until it quits (or until 60 seconds passes)
										end tell
									end timeout
								else
									exit repeat
								end if
							end try
						end repeat
						
						try
							set volume output volume 75 without output muted
						end try
						try
							set volume alert volume 100
						end try
					end try
				end if
				tell application "System Events" to tell application process "System Preferences"
					repeat 30 times -- Wait for startup disk list to populate
						delay 1
						try
							if (isBigSurOrNewer) then
								if ((number of groups of list 1 of scroll area 1 of window 1) is not 0) then exit repeat
							else
								if ((number of (radio buttons of (radio group 1 of scroll area 1 of group 1 of splitter group 1 of window 1))) is not 0) then exit repeat
							end if
						end try
					end repeat
					repeat with thisButton in (buttons of window 1)
						if (((name of thisButton) is equal to "Click the lock to make changes.") or ((name of thisButton) is equal to "Authenticating…")) then
							set frontmost to true
							click thisButton
							
							repeat 60 times -- Wait for password prompt
								delay 0.5
								set frontmost to true
								if ((number of sheets of window (number of windows)) is equal to 1) then exit repeat
								delay 0.5
							end repeat
							
							if ((number of sheets of window (number of windows)) is equal to 1) then
								set frontmost to true
								if (isMontereyOrNewer) then
									-- This sheet has been redesigned on Monterey and the username is now "text field 1"
									set value of (text field 1 of sheet 1 of window (number of windows)) to adminUsername
									-- As of beta 1, for some reason this sheet on Monterey will only show that it has 1 text field until the 2nd password text field has been focused, so focus it by tabbing.
									set frontmost to true
									keystroke tab
									set value of (text field 2 of sheet 1 of window (number of windows)) to adminPassword
								else
									set value of (text field 2 of sheet 1 of window (number of windows)) to adminUsername
									
									set frontmost to true
									set focused of (text field 1 of sheet 1 of window (number of windows)) to true -- Seems to not accept the password if the field is never focused.
									set frontmost to true
									set value of (text field 1 of sheet 1 of window (number of windows)) to adminPassword
								end if
								repeat with thisSheetButton in (buttons of sheet 1 of window (number of windows))
									if ((name of thisSheetButton) is equal to "Unlock") then
										set frontmost to true
										click thisSheetButton
									end if
								end repeat
								
								repeat 10 times -- Wait for password prompt to close
									delay 0.5
									if ((number of sheets of window (number of windows)) is equal to 0) then exit repeat
									delay 0.5
								end repeat
								
								if ((number of sheets of window (number of windows)) is equal to 1) then
									set frontmost to true
									key code 53 -- Press ESCAPE in case something went wrong and the password prompt is still up.
								end if
							end if
							
							exit repeat
						else if ((name of thisButton) is equal to "Click the lock to prevent further changes.") then
							exit repeat
						end if
					end repeat
					
					repeat with thisButton in (buttons of window 1)
						if ((name of thisButton) is equal to "Click the lock to prevent further changes.") then
							if (isBigSurOrNewer) then
								repeat (number of groups of list 1 of scroll area 1 of window 1) times
									-- Can't click elements in new fancy Startup Disk list, but I can arrow through them.
									set frontmost to true
									set focused of (scroll area 1 of window 1) to true
									set frontmost to true
									key code 124 -- Press RIGHT ARROW Key
									
									if (value of static text 1 of window 1) ends with ("“" & nameOfCurrentStartupDisk & ".”") then
										set didSetStartUpDisk to true
										
										exit repeat
									end if
									
									delay 0.5
								end repeat
							else
								repeat with thisStartUpDiskRadioButton in (radio buttons of (radio group 1 of scroll area 1 of group 1 of splitter group 1 of window 1))
									if ((name of thisStartUpDiskRadioButton) is equal to nameOfCurrentStartupDisk) then
										set frontmost to true
										click thisStartUpDiskRadioButton
										
										set didSetStartUpDisk to true
										
										exit repeat
									end if
								end repeat
							end if
							
							exit repeat
						end if
					end repeat
				end tell
				
				if (didSetStartUpDisk) then
					exit repeat
				end if
			end try
		end repeat
	end if
	
	try
		with timeout of 1 second
			tell application "System Preferences" to quit
		end timeout
	end try
	
	-- DELETE DESKTOP APP SYMLINKS
	-- TRASH DESKTOP FILES WITH FINDER INSTEAD OF RM SO FOLDER ACCESS IS NOT NECESSARY ON CATALINA AND NEWER
	try
		tell application "Finder" to delete (every file of (folder (path to desktop folder from user domain)) whose name extension is "app")
	on error deleteFilesWithFinderErrorMessage number deleteFilesWithFinderErrorNumber
		-- GET RID OF THIS ALERT AND CATCH IF IT WORKS NOW!
		try
			activate
		end try
		try
			display alert "STILL Failed to Trash Desktop Apps with Finder" message ("Will try another delete method after you click OK.
On Catalina, you will have to allow Desktop access.

Please send the following error message to Pico:
" & deleteFilesWithFinderErrorMessage & "
Error Number: " & deleteFilesWithFinderErrorNumber) as critical
		end try
		try
			-- This would prompt for Desktop Folder access on Catalina (but hopefully this won't happen) and would fail completely without prompting on Big Sur, but should work if Finder failed to delete the files on High Sierra.
			-- Had one report of a MacBook8,1 that was repeatedly failing to delete the Cleanup symlink on Desktop in High Sierra.
			-- Hopefully this will fix that case, not sure why it only happened on one computer, and was even repeatable on that computer.
			do shell script "rm -rf /Users/" & demoUsername & "/Desktop/*.app"
		end try
	end try
	
	try
		do shell script ("rm -f /memtest.log; rm -f /Users/Shared/memtest.log") user name adminUsername password adminPassword with administrator privileges -- Just in case memtest was canceled.
	end try
	
	-- EMPTY THE TRASH
	try
		tell application "Finder"
			set warns before emptying of trash to false
			try
				empty the trash
			end try
			set warns before emptying of trash to true
		end tell
	end try
	
	-- RESET DEFAULT VOLUME
	try
		set volume output volume 50 without output muted
	end try
	try
		set volume alert volume 100
	end try
	
	try
		activate
	end try
	
	set progress description to "
✅	Finished Cleaning Up After QA Complete"
	
	set modelName to (text 19 thru -1 of (do shell script "system_profiler SPHardwareDataType | grep '      Model Name: '"))
	set isHeadlessMac to ((modelName is equal to "Mac mini") or (modelName is equal to "Mac Pro"))
	
	delay 0.5
	
	try
		do shell script "afplay /System/Library/Sounds/Glass.aiff"
	on error
		beep
	end try
	
	-- Not sure why, but calling "activate" is failing after this point on 10.15.4 (even in "tell current application" block)
	
	set designedForSnapshotReset to false
	if (isCatalinaOrNewer) then
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
			set designedForSnapshotReset to true
		on error
			try
				(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
				set designedForSnapshotReset to true -- Still don't want to move Setup to Shared for fgreset even if the reset Snapshot was lost since fgreset still should not be used if the Snapshot reset was intended.
			end try
		end try
	end if
	
	if ((not designedForSnapshotReset) and isCatalinaOrNewer and (not isBigSurOrNewer)) then -- Catalina installs using the cloning method are the only ones the sticker is needed for. New Catalina installs using the startosinstall method can be Snapshot reset.
		try
			activate
		end try
		display alert "Remember to add a solid color sticker to the Keeper Label so that Free Geek Sales staff know that this Mac has macOS 10.15 “Catalina” installed on it." message "Free Geek Sales staff need to know when macOS 10.15 “Catalina” is installed onto a Mac so that they can include a handout with important setup information for our customers." buttons {"I've added a solid color sticker to the Keeper Label"} default button 1
	end if
	
	if (isHeadlessMac) then
		set resetMethod to "“fgreset”"
		if designedForSnapshotReset then set resetMethod to "Snapshot Reset"
		try
			activate
		end try
		display dialog "You've got one more step since you've refurbished a " & modelName & "!

Since this computer will not be turned on and running in The Free Geek Store, we need to perform " & resetMethod & " here in MacLand before delivering it to The Free Geek Store.

" & resetMethod & " is only performed in MacLand for Mac Pro's and Mac mini's, it should not be run in MacLand for any other kinds of Macs unless instructed to do so.

For help with performing " & resetMethod & ", please consult an instructor." with title ("Remember to Perform " & resetMethod) buttons {"OK"} default button 1
	end if
	
	try
		try
			activate
		end try
		set tabOrLinebreaks to "	"
		if (isBigSurOrNewer) then set tabOrLinebreaks to "

"
		display alert "✅" & tabOrLinebreaks & "Finished Cleaning Up
	After QA Complete" message "
This Mac will Shut Down in 15 Seconds…" buttons {"Don't Shut Down", "Shut Down Now"} cancel button 1 default button 2 giving up after 15
		
		tell application "System Events" to shut down with state saving preference
	end try
	
	try
		do shell script "rm -rf '/Users/" & demoUsername & "/Applications/Cleanup After QA Complete.app'"
	end try
else
	try
		activate
	end try
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
end if

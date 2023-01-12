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

-- Version: 2022.11.30-1

-- App Icon is “Broom” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

use AppleScript version "2.7"
use scripting additions

repeat -- dialogs timeout when screen is asleep or locked (just in case)
	set isAwake to true
	try
		set isAwake to ((run script "ObjC.import('CoreGraphics'); $.CGDisplayIsActive($.CGMainDisplayID())" in "JavaScript") is equal to 1)
	end try
	
	set isUnlocked to true
	try
		set isUnlocked to ((do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :IOConsoleUsers:0:CGSSessionScreenIsLocked' /dev/stdin <<< \"$(ioreg -ac IORegistryEntry -k IOConsoleUsers -d 1)\""))) is not equal to "true")
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
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as text))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as text)
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


global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate -- Needs to be accessible in doShellScriptAsAdmin function.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"
set demoPassword to "freegeek"


if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	set freeGeekUpdaterAppPath to ("/Users/" & demoUsername & "/Applications/Free Geek Updater.app")
	try
		((freeGeekUpdaterAppPath as POSIX file) as alias)
		
		if (application freeGeekUpdaterAppPath is running) then -- Quit if Updater is running so that this app can be updated if needed.
			quit
			delay 10
		end if
	end try
	
	try
		set fgSetupName to "Free Geek Setup"
		
		((("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app") as POSIX file) as alias)
		try
			activate
		end try
		display alert "“" & fgSetupName & "” Hasn't Finished Running" message "Please wait for “" & fgSetupName & "” to finish and then try running “" & (name of me) & "” again." buttons {"Quit"} default button 1 as critical giving up after 15
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -na " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & fgSetupName & ".app"))
		end try
		quit
		delay 10
	end try
	
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
		set isMontereyOrNewer to (systemVersion ≥ "12.0")
	end considering
	
	set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
	
	try
		set globalTCCdbPath to "/Library/Application Support/com.apple.TCC/TCC.db" -- For more info about the TCC.db structure, see "fg-install-os" script and https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive
		set whereAllowedOrAuthValue to "allowed = 1"
		if (isBigSurOrNewer) then set whereAllowedOrAuthValue to "auth_value = 2"
		set globalTCCallowedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of globalTCCdbPath) & " 'SELECT client,service FROM access WHERE (" & whereAllowedOrAuthValue & ")'"))) -- This SELECT command on the global TCC.db will error if "Free Geek Setup" doesn't have Full Disk Access.
		
		if (globalTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceAccessibility")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Accessibility Access")
		
		if (isMojaveOrNewer) then
			-- Full Disk Access was introduced in macOS 10.14 Mojave.
			if (globalTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceSystemPolicyAllFiles")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Full Disk Access") -- This should not be possible to hit since reading the global TCC.db would have errored if this app didn't have FDA, but check anyways.
			
			set userTCCdbPath to ((POSIX path of (path to library folder from user domain)) & "Application Support/com.apple.TCC/TCC.db")
			set userTCCallowedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of userTCCdbPath) & " 'SELECT client,service,indirect_object_identifier FROM access WHERE (" & whereAllowedOrAuthValue & ")'"))) -- This SELECT command on the user TCC.db will error if "Free Geek Setup" doesn't have Full Disk Access (but that should never happen because we couldn't get this far without FDA).
			
			if (userTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceAppleEvents|com.apple.systemevents")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED AppleEvents/Automation Access for “System Events”")
			if (userTCCallowedAppsAndServices does not contain (currentBundleIdentifier & "|kTCCServiceAppleEvents|com.apple.finder")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED AppleEvents/Automation Access for “Finder”")
		end if
	on error tccErrorMessage
		if (tccErrorMessage starts with "Error: unable to open database") then set tccErrorMessage to ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Full Disk Access (" & tccErrorMessage & ")")
		
		try
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			display alert ("CRITICAL “" & (name of me) & "” TCC ERROR:

" & tccErrorMessage) message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research if checking again does not work." buttons {"Shut Down", "Check Again"} cancel button 1 default button 2 as critical giving up after 10
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		on error
			tell application id "com.apple.systemevents" to shut down with state saving preference
		end try
		quit
		delay 10
	end try
	
	try
		(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
		((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
		
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script ("open -na '/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app'")
		end try
		
		quit
		delay 10
	end try
	
	set needsTrimEnabled to false
	
	set AppleScript's text item delimiters to ""
	set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
	set driveInfoPath to tmpPath & "driveInfo.plist"
	repeat 30 times
		try
			do shell script "system_profiler -xml SPNVMeDataType SPSerialATADataType > " & (quoted form of driveInfoPath)
			tell application id "com.apple.systemevents" to tell property list file driveInfoPath
				repeat with i from 1 to (number of property list items)
					set thisDataTypeProperties to (item i of property list items)
					set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as text)
					if ((thisDataType is equal to "SPNVMeDataType") or (thisDataType is equal to "SPSerialATADataType")) then
						set sataItems to (property list item "_items" of thisDataTypeProperties)
						repeat with j from 1 to (number of property list items in sataItems)
							set thisSataController to (property list item j of sataItems)
							set thisSataControllerName to ((value of property list item "_name" of thisSataController) as text)
							if (thisSataControllerName does not contain "Thunderbolt") then
								set thisSataControllerItems to (property list item "_items" of thisSataController)
								repeat with k from 1 to (number of property list items in thisSataControllerItems)
									try
										set thisSataControllerItem to (property list item k of thisSataControllerItems)
										set thisSataItemTrimSupport to "Yes" -- Default to Yes since drive may not be SSD and also don't want to get stuck in reboot loop if there's an error.
										
										if (thisDataType is equal to "SPNVMeDataType") then
											set thisSataItemTrimSupport to ((value of property list item "spnvme_trim_support" of thisSataControllerItem) as text)
										else
											set thisSataItemMediumType to ((value of property list item "spsata_medium_type" of thisSataControllerItem) as text)
											if (thisSataItemMediumType is equal to "Solid State") then set thisSataItemTrimSupport to ((value of property list item "spsata_trim_support" of thisSataControllerItem) as text)
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
		try
			activate
		end try
		try
			do shell script "afplay /System/Library/Sounds/Basso.aiff"
		end try
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
	
	set deleteTouchIDnote to ""
	try
		if ((length of (paragraphs of doShellScriptAsAdmin("bioutil -sr"))) > 2) then -- If Touch ID exists, this output will be more than 2 lines regardless of the Touch ID config or number of fingerprints enrolled.
			set deleteTouchIDnote to "
	⁃ Delete all Touch ID fingerprints."
		end if
	end try
	
	set renameInternalDriveNote to ""
	set nameOfCurrentStartupDisk to "UNKNOWN"
	try
		tell application id "com.apple.systemevents" to set nameOfCurrentStartupDisk to (name of startup disk)
	end try
	if (nameOfCurrentStartupDisk is not equal to "Macintosh HD") then set renameInternalDriveNote to "
	⁃ Rename internal drive to “Macintosh HD”."
	
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
	⁃ Remove all shared folders." & deleteTouchIDnote & "
	⁃ Empty the trash." & renameInternalDriveNote & "
	⁃ Remove “FG Reuse” from preferred Wi-Fi networks.
	⁃ Turn on Wi-Fi.
	⁃ Set Power On and Shutdown schedules.
	⁃ Remove “QA Helper” alias from Desktop.
	⁃ Delete “" & (name of me) & "” app.
	
This process cannot be undone.

THIS MAC WILL BE SHUT DOWN AFTER THE PROCESS IS COMPLETE." buttons {"Don't Cleanup After QA Complete Yet", cleanupDialogButton} cancel button 1 default button 2 with title (name of me) with icon note
	
	try -- Don't check Remote Management if "TESTING" flag folder exists on desktop
		((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	on error
		set serialNumber to ""
		try
			set serialNumber to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< \"$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)\"")))
		end try
		
		if (serialNumber is not equal to "") then
			try
				repeat
					try
						do shell script "ping -t 5 -c 1 www.apple.com" -- Require that internet is connected DEP status to get checked.
						exit repeat
					on error
						try
							display dialog "You must be connected to the internet to be able to check for Remote Management.

The rest of “" & (name of me) & "” cannot be run and this Mac CANNOT BE SOLD until it has been confirmed that Remote Management is not enabled on this Mac.


Make sure you're connected to either the “Free Geek” or “FG Reuse” Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Quit", "Try Again"} cancel button 1 default button 2 with title (name of me) with icon caution giving up after 30
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
						set remoteManagementOutput to doShellScriptAsAdmin("profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0")
					on error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
						if (profilesShowDefaultUserErrorNumber is not equal to -60007) then error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
						try
							activate
						end try
						display alert "Would you like to check for
Remote Management (ADE/DEP/MDM)?" message "Remote Management check will be skipped in 10 seconds." buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 10
						if (gave up of result) then error number -128
						set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" with prompt "Administrator Permission is required
to check for Remote Management (ADE/DEP/MDM)." with administrator privileges)
					end try
				end try
				
				if (remoteManagementOutput contains " - Request too soon.") then -- macOS 12.3 adds client side "profiles show" rate limiting of once every 23 hours: https://derflounder.wordpress.com/2022/03/22/profiles-command-includes-client-side-rate-limitation-for-certain-functions-on-macos-12-3/
					try
						set remoteManagementOutput to (do shell script ("cat " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))))
					end try
				else if (remoteManagementOutput is not equal to "") then -- So always cache the last "profiles show" output so we can show the last valid results in case it's checked again within 23 hours.
					try
						do shell script ("mkdir " & (quoted form of buildInfoPath))
					end try
					try
						do shell script ("echo " & (quoted form of remoteManagementOutput) & " > " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))) with administrator privileges -- DO NOT specify username and password in case it was prompted for. This will still work within 5 minutes of the last authenticated admin permissions run though.
					end try
				end if
				
				if (remoteManagementOutput contains " - Request too soon.") then -- Don't allow completion if rate limited and there was no previous cached output to use.
					set progress description to "
❌	UNABLE to Check for Remote Management"
					try
						activate
					end try
					try
						do shell script "afplay /System/Library/Sounds/Basso.aiff"
					end try
					set nextAllowedProfilesShowTime to "23 hours after last successful check"
					try
						set nextAllowedProfilesShowTime to ("at " & (do shell script "date -jv +23H -f '%FT%TZ %z' \"$(plutil -extract lastProfilesShowFetchTime raw /private/var/db/ConfigurationProfiles/Settings/.profilesFetchTimerCheck) +0000\" '+%-I:%M:%S %p on %D'"))
					end try
					display alert ("Cannot Cleanup After QA Complete

Unable to Check Remote Management Because of Once Every 23 Hours Rate Limiting

Next check will be allowed " & nextAllowedProfilesShowTime & ".") message "This should not have happened, please inform Free Geek I.T." buttons {"Shut Down"} as critical
					tell application id "com.apple.systemevents" to shut down with state saving preference
					
					quit
					delay 10
				else if (remoteManagementOutput is not equal to "") then
					try
						set remoteManagementOutputParts to (paragraphs of remoteManagementOutput)
						
						if ((count of remoteManagementOutputParts) > 3) then
							set progress description to "
⚠️	Remote Management IS Enabled"
							set remoteManagementOrganizationName to "\"Unknown Organization\""
							set remoteManagementOrganizationContactInfo to {}
							
							repeat with thisRemoteManagementOutputPart in remoteManagementOutputParts
								set organizationNameOffset to (offset of "OrganizationName = " in thisRemoteManagementOutputPart)
								set organizationDepartmentOffset to (offset of "OrganizationDepartment = " in thisRemoteManagementOutputPart)
								set organizationEmailOffset to (offset of "OrganizationEmail = " in thisRemoteManagementOutputPart)
								set organizationSupportEmailOffset to (offset of "OrganizationSupportEmail = " in thisRemoteManagementOutputPart)
								set organizationPhoneOffset to (offset of "OrganizationPhone = " in thisRemoteManagementOutputPart)
								set organizationSupportPhoneOffset to (offset of "OrganizationSupportPhone = " in thisRemoteManagementOutputPart)
								
								if (organizationNameOffset > 0) then
									set remoteManagementOrganizationName to (text (organizationNameOffset + 19) thru -2 of thisRemoteManagementOutputPart) -- Leave quotes around Organization Name.
									if ((remoteManagementOrganizationName does not start with "\"") or (remoteManagementOrganizationName does not end with "\"")) then set remoteManagementOrganizationName to ("\"" & remoteManagementOrganizationName & "\"") -- Or add quotes if somehow they don't exist.
								else if (organizationDepartmentOffset > 0) then
									set remoteManagementOrganizationDepartment to (text (organizationDepartmentOffset + 25) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationDepartment starts with "\"") and (remoteManagementOrganizationDepartment ends with "\"")) then set remoteManagementOrganizationDepartment to (text 2 thru -2 of remoteManagementOrganizationDepartment) -- Quotes may or may not exist around this vaue depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationDepartment is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationDepartment)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationDepartment
								else if (organizationEmailOffset > 0) then
									set remoteManagementOrganizationEmail to (text (organizationEmailOffset + 20) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationEmail starts with "\"") and (remoteManagementOrganizationEmail ends with "\"")) then set remoteManagementOrganizationEmail to (text 2 thru -2 of remoteManagementOrganizationEmail) -- Quotes may or may not exist around this vaue depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationEmail
								else if (organizationSupportEmailOffset > 0) then
									set remoteManagementOrganizationSupportEmail to (text (organizationSupportEmailOffset + 27) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationSupportEmail starts with "\"") and (remoteManagementOrganizationSupportEmail ends with "\"")) then set remoteManagementOrganizationSupportEmail to (text 2 thru -2 of remoteManagementOrganizationSupportEmail) -- Quotes may or may not exist around this vaue depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationSupportEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportEmail
								else if (organizationPhoneOffset > 0) then
									set remoteManagementOrganizationPhone to (text (organizationPhoneOffset + 20) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationPhone starts with "\"") and (remoteManagementOrganizationPhone ends with "\"")) then set remoteManagementOrganizationPhone to (text 2 thru -2 of remoteManagementOrganizationPhone) -- Quotes may or may not exist around this vaue depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationPhone
								else if (organizationSupportPhoneOffset > 0) then
									set remoteManagementOrganizationSupportPhone to (text (organizationSupportPhoneOffset + 27) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationSupportPhone starts with "\"") and (remoteManagementOrganizationSupportPhone ends with "\"")) then set remoteManagementOrganizationSupportPhone to (text 2 thru -2 of remoteManagementOrganizationSupportPhone) -- Quotes may or may not exist around this vaue depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationSupportPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportPhone
								end if
							end repeat
							
							set remoteManagementOrganizationContactInfoDisplay to "NO CONTACT INFORMATION"
							if ((count of remoteManagementOrganizationContactInfo) > 0) then
								set AppleScript's text item delimiters to (linefeed & tab & tab)
								set remoteManagementOrganizationContactInfoDisplay to (remoteManagementOrganizationContactInfo as text)
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
							tell application id "com.apple.systemevents" to shut down with state saving preference
							
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
	end try
	
	set progress total steps to -1
	set progress description to "
🔄	Cleaning Up After QA Complete"
	set progress additional description to ""
	
	-- QUIT ALL APPS
	try -- Don't quit apps if "TESTING" flag folder exists on desktop
		((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	on error
		try
			tell application id "com.apple.systemevents" to set listOfRunningAppIDs to (bundle identifier of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not "org.freegeek.Free-Geek-Demo-Helper") and (bundle identifier is not (id of me))))
			if ((count of listOfRunningAppIDs) > 0) then
				try
					repeat with thisAppID in listOfRunningAppIDs
						try
							if (application id thisAppID is running) then
								with timeout of 1 second
									tell application id thisAppID to quit without saving
								end timeout
							end if
						end try
					end repeat
				end try
				delay 3
				try
					set AppleScript's text item delimiters to space
					tell application id "com.apple.systemevents" to set allRunningAppPIDs to ((unix id of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not "org.freegeek.Free-Geek-Demo-Helper") and (bundle identifier is not (id of me)))) as text)
					if (allRunningAppPIDs is not equal to "") then
						do shell script ("kill " & allRunningAppPIDs)
					end if
				end try
			end if
		end try
	end try
	
	-- CLEAR THE CLIPBOARD CONTENTS
	try
		tell application id "com.apple.systemevents" to set the clipboard to ""
	end try
	
	-- RESET SAFARI & TERMINAL
	-- AND DELETE DESKTOP FILES WITH RM SINCE THIS APP WILL ALWAYS HAVE FULL DISK ACCESS SO IT WON'T NEED TO PROMPT FOR LOGGED IN USER DESKTOP ACCESS ON ON CATALINA AND NEWER
	try
		doShellScriptAsAdmin("rm -rf /Users/" & adminUsername & "/Library/Safari " & ¬
			"'/Users/" & adminUsername & "/Library/Caches/Apple - Safari - Safari Extensions Gallery' " & ¬
			"/Users/" & adminUsername & "/Library/Caches/Metadata/Safari " & ¬
			"/Users/" & adminUsername & "/Library/Caches/com.apple.Safari " & ¬
			"/Users/" & adminUsername & "/Library/Caches/com.apple.WebKit.PluginProcess " & ¬
			"/Users/" & adminUsername & "/Library/Cookies/Cookies.binarycookies " & ¬
			"'/Users/" & adminUsername & "/Library/Preferences/Apple - Safari - Safari Extensions Gallery' " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.LSSharedFileList.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.RSS.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.SafeBrowsing.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.Safari.SandboxBroker.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.SafariBookmarksSyncAgent.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.SafariCloudHistoryPushAgent.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.WebFoundation.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.WebKit.PluginHost.plist " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/com.apple.WebKit.PluginProcess.plist " & ¬
			"/Users/" & adminUsername & "/Library/PubSub/Database " & ¬
			"'/Users/" & adminUsername & "/Library/Saved Application State/com.apple.Safari.savedState' " & ¬
			"/Users/" & adminUsername & "/.bash_history " & ¬
			"/Users/" & adminUsername & "/.bash_sessions " & ¬
			"/Users/" & adminUsername & "/.zsh_history " & ¬
			"/Users/" & adminUsername & "/.zsh_sessions " & ¬
			"'/Users/" & adminUsername & "/Desktop/QA Helper - Computer Specs.txt' " & ¬
			"'/Users/" & adminUsername & "/Desktop/Relocated Items'")
	end try
	
	try -- Put this in a "try" block since deleting Safari stuff may results in "Operation not permitted", but the rest will work and don't want to cause a script error.
		do shell script ("rm -rf /Users/" & demoUsername & "/Library/Safari " & ¬
			"'/Users/" & demoUsername & "/Library/Caches/Apple - Safari - Safari Extensions Gallery' " & ¬
			"/Users/" & demoUsername & "/Library/Caches/Metadata/Safari " & ¬
			"/Users/" & demoUsername & "/Library/Caches/com.apple.Safari " & ¬
			"/Users/" & demoUsername & "/Library/Caches/com.apple.WebKit.PluginProcess " & ¬
			"/Users/" & demoUsername & "/Library/Cookies/Cookies.binarycookies " & ¬
			"'/Users/" & demoUsername & "/Library/Preferences/Apple - Safari - Safari Extensions Gallery' " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.LSSharedFileList.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.RSS.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.SafeBrowsing.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.Safari.SandboxBroker.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.SafariBookmarksSyncAgent.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.SafariCloudHistoryPushAgent.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.WebFoundation.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.WebKit.PluginHost.plist " & ¬
			"/Users/" & demoUsername & "/Library/Preferences/com.apple.WebKit.PluginProcess.plist " & ¬
			"/Users/" & demoUsername & "/Library/PubSub/Database " & ¬
			"'/Users/" & demoUsername & "/Library/Saved Application State/com.apple.Safari.savedState' " & ¬
			"/Users/" & demoUsername & "/.bash_history " & ¬
			"/Users/" & demoUsername & "/.bash_sessions " & ¬
			"/Users/" & demoUsername & "/.zsh_history " & ¬
			"/Users/" & demoUsername & "/.zsh_sessions " & ¬
			"'/Users/" & demoUsername & "/Desktop/QA Helper - Computer Specs.txt' " & ¬
			"'/Users/" & demoUsername & "/Desktop/Relocated Items'")
	end try
	
	-- DELETE ALL PRINTERS
	try
		set printerIDsText to (do shell script "lpstat -p | awk '{ print $2 }'")
		repeat with thisPrinterID in (paragraphs of printerIDsText)
			try
				do shell script ("lpadmin -x " & thisPrinterID)
			end try
		end repeat
	end try
	
	-- REMOVE ALL SHARED FOLDERS & SHAREPOINT GROUPS
	try
		set sharedFolderNames to (do shell script "sharing -l | grep 'name:		' | cut -c 8-")
		repeat with thisSharedFolderName in (paragraphs of sharedFolderNames)
			try
				doShellScriptAsAdmin("sharing -r " & (quoted form of thisSharedFolderName))
			end try
		end repeat
	end try
	try
		set sharePointGroups to (do shell script "dscl . -list /Groups | grep com.apple.sharepoint.group")
		repeat with thisSharePointGroupName in (paragraphs of sharePointGroups)
			try
				doShellScriptAsAdmin("dseditgroup -o delete " & (quoted form of thisSharePointGroupName))
			end try
		end repeat
	end try
	
	-- DELETING ALL TOUCH ID FINGERPRINTS
	try
		doShellScriptAsAdmin("echo 'Y' | bioutil -p -s")
	end try
	
	-- MUTE VOLUME WHILE TRASH IS EMPTIED
	try
		set volume output volume 0 with output muted
	end try
	try
		set volume alert volume 0
	end try
	
	-- EMPTY THE TRASH (in case it's full)
	try
		tell application id "com.apple.finder"
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
	
	-- RENAME HARD DRIVE
	try
		set intendedDriveName to "Macintosh HD"
		set currentDriveName to intendedDriveName
		tell application id "com.apple.systemevents" to set currentDriveName to (name of startup disk)
		if (currentDriveName is not equal to intendedDriveName) then
			doShellScriptAsAdmin("diskutil rename " & (quoted form of currentDriveName) & " " & (quoted form of intendedDriveName))
			if (isCatalinaOrNewer) then doShellScriptAsAdmin("diskutil rename " & (quoted form of (currentDriveName & " - Data")) & " " & (quoted form of (intendedDriveName & " - Data")))
		end if
	end try
	
	-- FORGET "FG Reuse" AND TURN ON WI-FI
	set wirelessNetworkPasswordsToDelete to {}
	try
		set AppleScript's text item delimiters to ""
		tell application id "com.apple.systemevents" to tell current location of network preferences
			repeat with thisActiveNetworkService in (every service whose active is true)
				if (((name of interface of thisActiveNetworkService) as text) is equal to "Wi-Fi") then
					set thisWiFiInterfaceID to ((id of interface of thisActiveNetworkService) as text)
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
								set thisPreferredWirelessNetwork to ((characters 2 thru -1 of thisPreferredWirelessNetwork) as text)
								if (thisPreferredWirelessNetwork is not equal to "Free Geek") then
									try
										do shell script "networksetup -setairportpower " & thisWiFiInterfaceID & " off"
									end try
									try
										doShellScriptAsAdmin("networksetup -removepreferredwirelessnetwork " & thisWiFiInterfaceID & " " & (quoted form of thisPreferredWirelessNetwork))
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
						doShellScriptAsAdmin("networksetup -setairportnetwork " & thisWiFiInterfaceID & " 'Free Geek'")
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
			doShellScriptAsAdmin("security delete-generic-password -s 'AirPort' -l " & (quoted form of thisWirelessNetworkPasswordsToDelete))
		end try
	end repeat
	try
		doShellScriptAsAdmin("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport prefs RememberRecentNetworks=NO")
	end try
	
	-- SET POWER ON AND SHUTDOWN SCHEDULE
	try
		doShellScriptAsAdmin("pmset repeat poweron TWRFSU 9:45:00 shutdown TWRFSU 18:10:00")
	end try
	
	-- DELETE DESKTOP APP SYMLINKS WITH RM SINCE THIS APP WILL ALWAYS HAVE FULL DISK ACCESS SO IT WON'T NEED TO PROMPT FOR DESKTOP ACCESS ON ON CATALINA AND NEWER
	try
		do shell script "rm -rf /Users/" & demoUsername & "/Desktop/*.app"
	end try
	
	try
		activate
	end try
	
	set progress description to "
✅	Finished Cleaning Up After QA Complete"
	
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
	
	set resetMethod to "“fgreset”"
	if designedForSnapshotReset then set resetMethod to "Snapshot Reset"
	try
		activate
	end try
	display alert "Don't forget to " & resetMethod & " this Mac!" message "Since this computer will not be turned on and running in The Free Geek Store, " & resetMethod & " must be done before delivering it to The Free Geek Store."
	
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
		
		tell application id "com.apple.systemevents" to shut down with state saving preference
	end try
	
	try
		set pathToMe to (POSIX path of (path to me))
		if ((offset of ".app" in pathToMe) > 0) then
			do shell script ("tccutil reset All " & currentBundleIdentifier & "; rm -rf " & (quoted form of pathToMe)) -- Resetting TCC for specific bundle IDs should work on Mojave and newer, but does not actually work on Mojave because of a bug (http://www.openradar.me/6813106), but that's ok since we don't install Mojave and all TCC permissions will get reset by "fgreset" on High Sierra (or Mojave).
		end if
	end try
else
	try
		activate
	end try
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
end if

on doShellScriptAsAdmin(command)
	-- "do shell script with administrator privileges" caches authentication for 5 minutes: https://developer.apple.com/library/archive/technotes/tn2065/_index.html#//apple_ref/doc/uid/DTS10003093-CH1-TNTAG1-HOW_DO_I_GET_ADMINISTRATOR_PRIVILEGES_FOR_A_COMMAND_ & https://developer.apple.com/library/archive/releasenotes/AppleScript/RN-AppleScript/RN-10_4/RN-10_4.html#//apple_ref/doc/uid/TP40000982-CH104-SW10
	-- And, it takes reasonably longer to run "do shell script with administrator privileges" when credentials are passed vs without.
	-- In testing, 100 iteration with credentials took about 30 seconds while 100 interations without credentials after authenticated in advance took only 2 seconds.
	-- So, this function makes it easy to call "do shell script with administrator privileges" while only passing credentials when needed.
	-- Also, from testing, this 5 minute credential caching DOES NOT seem to be affected by any custom "sudo" timeout set in the sudoers file.
	-- And, from testing, unlike "sudo" the timeout DOES NOT keep extending from the last "do shell script with administrator privileges" without credentials but only from the last time credentials were passed.
	-- To be safe, "do shell script with administrator privileges" will be re-authenticated with the credentials every 4.5 minutes.
	-- NOTICE: "do shell script" calls are intentionally NOT in "try" blocks since detecting and catching those errors may be critical to the code calling the "doShellScriptAsAdmin" function.
	
	if ((lastDoShellScriptAsAdminAuthDate is equal to 0) or ((current date) ≥ (lastDoShellScriptAsAdminAuthDate + 270))) then -- 270 seconds = 4.5 minutes.
		set commandOutput to (do shell script command user name adminUsername password adminPassword with administrator privileges)
		set lastDoShellScriptAsAdminAuthDate to (current date)
	else
		set commandOutput to (do shell script command with administrator privileges)
	end if
	
	return commandOutput
end doShellScriptAsAdmin

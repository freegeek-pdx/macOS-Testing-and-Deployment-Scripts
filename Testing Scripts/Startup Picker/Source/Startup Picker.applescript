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

-- Version: 2022.4.11-1

-- App Icon is “Green Apple” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

use AppleScript version "2.7"
use scripting additions

repeat -- dialogs timeout when screen is asleep or locked (just in case)
	set isAwake to true
	try
		set isAwake to ((do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:IOPowerManagement:CurrentPowerState' /dev/stdin <<< \"$(ioreg -arc IODisplayWrangler -k IOPowerManagement -d 1)\""))) is equal to "4")
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

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Startup Picker" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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


set currentUsername to (short user name of (system info))

if (((currentUsername is equal to "Tester") or (currentUsername is equal to "restorer")) and ((POSIX path of (path to me)) is equal to ("/Applications/" & (name of me) & ".app/"))) then
	set dialogIconName to "applet"
	try
		((((POSIX path of (path to me)) & "Contents/Resources/" & (name of me) & ".icns") as POSIX file) as alias)
		set dialogIconName to (name of me)
	end try
	
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
	end considering
	
	if (isMojaveOrNewer) then
		set needsAutomationAccess to false
		try
			tell application "System Events" to every window -- To prompt for Automation access on Mojave
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
				display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “System Events” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “System Events” checkbox underneath it.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
			end try
			quit
			delay 10
		end if
	end if
	
	try
		tell application "System Events" to tell application process "Finder" to (get windows)
	on error (assistiveAccessTestErrorMessage)
		if ((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) then
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
								do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
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
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
			end try
			quit
			delay 10
		end if
	end try
	
	
	set adminUsername to "Staff"
	if (isCatalinaOrNewer) then set adminUsername to "staff"
	set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"
	
	
	set AppleScript's text item delimiters to ""
	set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
	
	set supportsHighSierra to false
	set supportsCatalina to false
	set supportsBigSur to false
	set supportsMonterey to false
	
	set modelInfoPath to tmpPath & "modelInfo.plist"
	try
		do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of modelInfoPath)
		tell application "System Events" to tell property list file modelInfoPath
			set hardwareItems to (first property list item of property list item "_items" of first property list item)
			set shortModelName to ((value of property list item "machine_name" of hardwareItems) as string)
			set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as string)
			set modelIdentifierNumber to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -dc '[:digit:],'")
			set AppleScript's text item delimiters to ","
			set modelNumberParts to (every text item of modelIdentifierNumber)
			set modelIdentifierMajorNumber to ((item 1 of modelNumberParts) as number)
			
			if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 10)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 3)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 4)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 5)) or (shortModelName is equal to "iMac Pro")) then set supportsHighSierra to true
			
			if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 13)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 9)) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 5)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro")) then set supportsCatalina to true
			
			if (((shortModelName is equal to "iMac") and ((modelIdentifierNumber is equal to "14,4") or (modelIdentifierMajorNumber ≥ 15))) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 11)) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 7)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro")) then set supportsBigSur to true
			
			if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 16)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 9)) or ((shortModelName is equal to "MacBook Pro") and ((modelIdentifierNumber is equal to "11,4") or (modelIdentifierNumber is equal to "11,5") or (modelIdentifierMajorNumber ≥ 12))) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 7)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 7)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro") or (shortModelName is equal to "Mac Studio")) then set supportsMonterey to true
		end tell
	on error (modelInfoErrorMessage)
		log "Model Info Error: " & modelInfoErrorMessage
	end try
	do shell script "rm -f " & (quoted form of modelInfoPath)
	
	set supportedOS to "OS X 10.11 “El Capitan”"
	if (supportsMonterey) then
		set supportedOS to "macOS 12 “Monterey”"
	else if (supportsBigSur) then
		set supportedOS to "macOS 11 “Big Sur”"
	else if (supportsCatalina) then
		set supportedOS to "macOS 10.15 “Catalina”"
	else if (supportsHighSierra) then
		set supportedOS to "macOS 10.13 “High Sierra”"
	end if
	
	set nameOfCurrentStartupDisk to "UNKNOWN"
	tell application "System Events" to set nameOfCurrentStartupDisk to (name of startup disk)
	
	set shouldSetStartupDisk to false
	set selectedStartupDiskName to "UNKNOWN"
	set selectedStartupDiskVersion to "0"
	
	repeat
		set shouldSetStartupDisk to false
		set selectedStartupDiskName to "UNKNOWN"
		set selectedStartupDiskVersion to "0"
		
		set systemVersionPlists to (paragraphs of (do shell script "ls /Volumes/*/System/Library/CoreServices/SystemVersion.plist | sort"))
		
		set hdStartupDiskOptions to {}
		set testBootStartupDiskOptions to {}
		set installerStartupDiskOptions to {}
		set otherStartupDiskOptions to {}
		set incompatibleStartupDiskOptions to {}
		
		repeat with thisSystemVersionPlist in systemVersionPlists
			try
				set osVersion to "UNKNOWN"
				set osDarwinMajorVersion to "00"
				
				try
					tell application "System Events" to tell property list file thisSystemVersionPlist
						try
							set osVersion to ((value of property list item "ProductUserVisibleVersion") as string)
						on error
							try
								set osVersion to ((value of property list item "ProductVersion") as string)
							end try
						end try
						try
							set osDarwinMajorVersion to (text 1 thru 2 of ((value of property list item "ProductBuildVersion") as string))
						end try
					end tell
				end try
				
				set startupDiskIsCompatibleWithMac to true
				
				set macOSname to "Mac OS X"
				considering numeric strings
					if (osVersion ≥ "10.12") then
						set macOSname to "macOS"
						if ((osVersion ≥ "12.0") and (not supportsMonterey)) then
							set startupDiskIsCompatibleWithMac to false
						else if ((osVersion ≥ "11.0") and (not supportsBigSur)) then
							set startupDiskIsCompatibleWithMac to false
						else if ((osVersion ≥ "10.14") and (not supportsCatalina)) then -- Catalina supports same as Mojave
							set startupDiskIsCompatibleWithMac to false
						else if ((osVersion ≥ "10.13") and (not supportsHighSierra)) then
							set startupDiskIsCompatibleWithMac to false
						end if
					else if (osVersion ≥ "10.8") then
						set macOSname to "OS X"
					end if
				end considering
				
				set thisDriveName to (name of (info for (text 1 thru -48 of thisSystemVersionPlist)))
				if (nameOfCurrentStartupDisk is not equal to thisDriveName) then
					set thisStartupDiskDisplay to (osDarwinMajorVersion & ":" & thisDriveName & " (" & macOSname & " " & osVersion & ")")
					
					if (startupDiskIsCompatibleWithMac) then
						if (thisDriveName contains " HD") then
							set (end of hdStartupDiskOptions) to thisStartupDiskDisplay
						else if ((thisDriveName starts with "Install ")) then
							set (end of installerStartupDiskOptions) to thisStartupDiskDisplay
						else if (thisDriveName contains " Test Boot") then
							set (end of testBootStartupDiskOptions) to thisStartupDiskDisplay
						else
							set (end of otherStartupDiskOptions) to thisStartupDiskDisplay
						end if
					else
						set (end of incompatibleStartupDiskOptions) to thisStartupDiskDisplay
					end if
				end if
			end try
		end repeat
		
		set defaultStartupDiskSelection to ""
		
		set startupDiskOptions to {}
		if ((count of hdStartupDiskOptions) > 0) then
			set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as string)
			set hdStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (hdStartupDiskOptions as string)) & " | sort -urn | cut -d ':' -f 2")))
			
			set defaultStartupDiskSelection to (first item of hdStartupDiskOptions)
			
			set startupDiskOptions to hdStartupDiskOptions
		end if
		
		set separatorLine to "———————————————————————"
		
		if ((count of otherStartupDiskOptions) > 0) then
			set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as string)
			set otherStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (otherStartupDiskOptions as string)) & " | sort -urn | cut -d ':' -f 2")))
			
			if ((count of startupDiskOptions) > 0) then
				set startupDiskOptions to startupDiskOptions & {separatorLine} & otherStartupDiskOptions
			else
				set startupDiskOptions to otherStartupDiskOptions
			end if
		end if
		
		if ((count of installerStartupDiskOptions) > 0) then
			set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as string)
			set installerStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (installerStartupDiskOptions as string)) & " | sort -urn | cut -d ':' -f 2")))
			
			if (defaultStartupDiskSelection is equal to "") then set defaultStartupDiskSelection to (first item of installerStartupDiskOptions)
			
			if ((count of startupDiskOptions) > 0) then
				set startupDiskOptions to startupDiskOptions & {separatorLine} & installerStartupDiskOptions
			else
				set startupDiskOptions to installerStartupDiskOptions
			end if
		end if
		
		if ((count of testBootStartupDiskOptions) > 0) then
			set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as string)
			set testBootStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (testBootStartupDiskOptions as string)) & " | sort -urn | cut -d ':' -f 2")))
			
			if (defaultStartupDiskSelection is equal to "") then set defaultStartupDiskSelection to (first item of testBootStartupDiskOptions)
			
			if ((count of startupDiskOptions) > 0) then
				set startupDiskOptions to startupDiskOptions & {separatorLine} & testBootStartupDiskOptions
			else
				set startupDiskOptions to testBootStartupDiskOptions
			end if
		end if
		
		set incompatibleStartupDisksNote to ""
		if ((incompatibleStartupDiskOptions count) > 0) then
			set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as string)
			set incompatibleStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (incompatibleStartupDiskOptions as string)) & " | sort -urn | cut -d ':' -f 2")))
			
			set pluralizeDisks to ""
			if ((incompatibleStartupDiskOptions count) > 1) then set pluralizeDisks to "s"
			set AppleScript's text item delimiters to (linefeed & tab)
			set incompatibleStartupDisksNote to "Excluded Incompatible Startup Disk" & pluralizeDisks & ":
	" & (incompatibleStartupDiskOptions as string)
		end if
		
		if ((count of startupDiskOptions) is equal to 0) then
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			try
				set noStartupDisksTitle to "
No Startup Disks Detected"
				if (incompatibleStartupDisksNote is not equal to "") then set noStartupDisksTitle to "No Compatible Startup Disks Detected"
				
				display alert noStartupDisksTitle message incompatibleStartupDisksNote buttons {"Quit", "Try Again"} cancel button 1 default button 2 as critical
			on error
				exit repeat
			end try
		else
			if (incompatibleStartupDisksNote is not equal to "") then set incompatibleStartupDisksNote to (incompatibleStartupDisksNote & "

")
			try
				activate
			end try
			set selectedStartupDisk to (choose from list startupDiskOptions default items defaultStartupDiskSelection with prompt "This Mac Supports " & supportedOS & "

" & incompatibleStartupDisksNote & "Select Drive to Set as Startup Disk:" OK button name "Select Startup Disk" cancel button name "Quit" with title "Startup Picker")
			if (selectedStartupDisk is not equal to false) then
				if ((selectedStartupDisk as string) is equal to separatorLine) then
					-- Just display list again since user selected separator line.
				else if ((last word of (selectedStartupDisk as string)) starts with "1") then
					set AppleScript's text item delimiters to " ("
					set selectedStartupDiskParts to (every text item of (selectedStartupDisk as string))
					set selectedStartupDiskName to ((text items 1 thru -2 of selectedStartupDiskParts) as string)
					set selectedStartupDiskVersion to (do shell script "echo " & (quoted form of ((last text item of selectedStartupDiskParts) as string)) & " | tr -dc '[:digit:].'")
					try
						try
							activate
						end try
						display alert "
Are you sure you want to set “" & selectedStartupDiskName & "” as the startup disk?" buttons {"Quit", "Change Selection", "Set “" & selectedStartupDiskName & "” as Startup Disk"} cancel button 2 default button 3
						if ((button returned of result) is not equal to "Quit") then
							set shouldSetStartupDisk to true
						end if
						
						exit repeat
					end try
				else
					try
						activate
					end try
					try
						do shell script "afplay /System/Library/Sounds/Basso.aiff"
					end try
					try
						display alert "
Error Selecting Drive to Set as Startup Disk" buttons {"Quit", "Start Over"} cancel button 1 default button 2 as critical
					on error
						exit repeat
					end try
				end if
			else
				exit repeat
			end if
		end if
	end repeat
	
	if (shouldSetStartupDisk and (selectedStartupDiskName is not equal to "UNKNOWN")) then
		set didSetStartUpDisk to false
		set didNotTryToSetStartupDisk to false
		
		considering numeric strings
			if (selectedStartupDiskVersion ≥ "11.0") then
				-- macOS 11 Big Sur and newer installers do not show up in Startup Disk, so do not waste time trying to set them.
				set didNotTryToSetStartupDisk to true
			end if
		end considering
		
		if (not didNotTryToSetStartupDisk) then
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
									set value of (text field 2 of sheet 1 of window (number of windows)) to adminUsername
									
									set frontmost to true
									set focused of (text field 1 of sheet 1 of window (number of windows)) to true -- Seems to not accept the password if the field is never focused.
									set frontmost to true
									set value of (text field 1 of sheet 1 of window (number of windows)) to adminPassword
									
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
										
										if (value of static text 1 of window 1) ends with ("“" & selectedStartupDiskName & ".”") then
											set didSetStartUpDisk to true
											
											exit repeat
										end if
										
										delay 0.5
									end repeat
								else
									repeat with thisStartUpDiskRadioButton in (radio buttons of (radio group 1 of scroll area 1 of group 1 of splitter group 1 of window 1))
										if ((name of thisStartUpDiskRadioButton) is equal to selectedStartupDiskName) then
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
					
					exit repeat -- Big Sur Installers are not listed for some reason, so exit if if didSetStartUpDisk is false but we checked them all without erroring. This repeat is just to try again if an error occurs.
				end try
			end repeat
			
			try
				with timeout of 1 second
					tell application "System Preferences" to quit
				end timeout
			end try
		end if
		
		try
			try
				if (didSetStartUpDisk) then
					do shell script "afplay /System/Library/Sounds/Glass.aiff"
				else if (didNotTryToSetStartupDisk) then
					do shell script "afplay /System/Library/Sounds/Pop.aiff"
				else
					do shell script "afplay /System/Library/Sounds/Basso.aiff"
				end if
			end try
			
			try
				activate
			end try
			
			if (didSetStartUpDisk) then
				try
					-- Make sure this Mac won't just boot into Startup Manager if that has been set previously.
					do shell script "nvram -d manufacturing-enter-picker" user name adminUsername password adminPassword with administrator privileges
				end try
				
				display alert "The startup disk has been set to “" & selectedStartupDiskName & "”.

Do you want to reboot into “" & selectedStartupDiskName & "” right now?" message "
This Mac will automatically reboot into “" & selectedStartupDiskName & "” in 30 seconds…" buttons {"Don't Reboot", "Reboot Into “" & selectedStartupDiskName & "” Now"} cancel button 1 default button 2 giving up after 30
			else
				display alert "Unable to set the startup disk to “" & selectedStartupDiskName & "”.

Instead, this computer can be rebooted into Startup Manager for you to be able to choose to boot into “" & selectedStartupDiskName & "” from there.

Do you want to reboot into Startup Manager right now?" message "
You will not need to hold the Option key to boot into Startup Manager, it will be done automatically if you choose to reboot into Startup Manager now.

This Mac will automatically reboot into Startup Manager in 30 seconds…" buttons {"Don't Reboot", "Reboot Into Startup Manager Now"} cancel button 1 default button 2 giving up after 30
				
				try
					-- https://osxdaily.com/2021/02/26/make-intel-mac-boot-startup-manager/
					do shell script "nvram manufacturing-enter-picker=true" user name adminUsername password adminPassword with administrator privileges
				end try
			end if
			
			-- Quit all apps before rebooting
			try
				tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not (name of me))))
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
						tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not (name of me))))
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
			
			tell application "System Events" to restart with state saving preference
		end try
	end if
else
	try
		activate
	end try
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Applications/” and run from the “Tester” or “restorer” user accounts." buttons {"Quit"} default button 1 as critical
end if

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

-- Version: 2023.9.12-2

-- App Icon is “Green Apple” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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



set freeGeekUpdaterAppPath to "/Applications/Free Geek Updater.app"
set freeGeekUpdaterIsRunning to false
try
	((freeGeekUpdaterAppPath as POSIX file) as alias)
	set freeGeekUpdaterIsRunning to (application freeGeekUpdaterAppPath is running)
end try

set adminUsername to "Staff"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")

try
	(((buildInfoPath & ".fgSetupSkipped") as POSIX file) as alias)
	
	try
		do shell script ("mkdir " & (quoted form of buildInfoPath))
	end try
	try
		set AppleScript's text item delimiters to "-"
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as text)))) user name adminUsername password adminPassword with administrator privileges
	end try
	
	if (not freeGeekUpdaterIsRunning) then
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -na '/Applications/Test Boot Setup.app'"
		end try
	end if
	
	quit
	delay 10
end try

if (freeGeekUpdaterIsRunning) then -- Quit if Updater is running so that this app can be updated if needed.
	quit
	delay 10
end if


set systemVersion to (system version of (system info))
considering numeric strings
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
	set isBigSurOrNewer to (systemVersion ≥ "11.0")
	set isMontereyOrNewer to (systemVersion ≥ "12.0")
	set isVenturaOrNewer to (systemVersion ≥ "13.0")
	set isVenturaThirteenDotThreeOrNewer to (systemVersion ≥ "13.3")
	set isSonomaOrNewer to (systemVersion ≥ "14.0")
end considering

if (isMojaveOrNewer) then
	set needsAutomationAccess to false
	try
		tell application id "com.apple.systemevents" to every window -- To prompt for Automation access on Mojave
	on error automationAccessErrorMessage number automationAccessErrorNumber
		if (automationAccessErrorNumber is equal to -1743) then set needsAutomationAccess to true
	end try
	
	if (needsAutomationAccess) then
		try
			tell application id "com.apple.systempreferences" to activate
		end try
		try
			open location "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" -- The "Privacy_Automation" anchor is not exposed/accessible via AppleScript, but can be accessed via URL Scheme.
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

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		end try
		quit
		delay 10
	end if
end if

try
	tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.finder") to (get windows)
on error (assistiveAccessTestErrorMessage)
	if ((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) then
		if (isMojaveOrNewer) then
			try
				tell application id "com.apple.systempreferences" to every window -- To prompt for Automation access on Mojave
			on error automationAccessErrorMessage number automationAccessErrorNumber
				if (automationAccessErrorNumber is equal to -1743) then
					try
						tell application id "com.apple.systempreferences" to activate
					end try
					try
						open location "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" -- The "Privacy_Automation" anchor is not exposed/accessible via AppleScript, but can be accessed via URL Scheme.
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

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
						try
							do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
						end try
					end try
					quit
					delay 10
				end if
			end try
			try
				with timeout of 1 second
					tell application id "com.apple.systempreferences" to quit
				end timeout
			end try
		end if
		
		try
			tell application id "com.apple.finder" to reveal (path to me)
		end try
		try
			tell application id "com.apple.systempreferences"
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

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		end try
		quit
		delay 10
	end if
end try


set AppleScript's text item delimiters to ""
set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.

set supportsHighSierra to false
set supportsCatalina to false
set supportsBigSur to false
set supportsMonterey to false
set supportsVentura to false

set modelInfoPath to tmpPath & "modelInfo.plist"
try
	do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of modelInfoPath)
	tell application id "com.apple.systemevents" to tell property list file modelInfoPath
		set hardwareItems to (first property list item of property list item "_items" of first property list item)
		set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as text)
		set modelIdentifierName to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -d '[:digit:],'") -- Need use this whenever comparing along with Model ID numbers since there could be false matches for the newer "MacXX,Y" style Model IDs if I used shortModelName in those conditions instead (which I used to do).
		set modelIdentifierNumber to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -dc '[:digit:],'")
		set AppleScript's text item delimiters to ","
		set modelNumberParts to (every text item of modelIdentifierNumber)
		set modelIdentifierMajorNumber to ((item 1 of modelNumberParts) as number)
		
		if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 10)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 3)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 4)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 5)) or (modelIdentifierName is equal to "iMacPro")) then set supportsHighSierra to true
		
		if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 13)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 9)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 5)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro")) then set supportsCatalina to true
		
		if (((modelIdentifierName is equal to "iMac") and ((modelIdentifierNumber is equal to "14,4") or (modelIdentifierMajorNumber ≥ 15))) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 11)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 7)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro")) then set supportsBigSur to true
		
		if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 16)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 9)) or ((modelIdentifierName is equal to "MacBookPro") and ((modelIdentifierNumber is equal to "11,4") or (modelIdentifierNumber is equal to "11,5") or (modelIdentifierMajorNumber ≥ 12))) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 7)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 7)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set supportsMonterey to true
		
		if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 18)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 10)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 14)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 7)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set supportsVentura to true
	end tell
on error (modelInfoErrorMessage)
	log "Model Info Error: " & modelInfoErrorMessage
end try
do shell script "rm -f " & (quoted form of modelInfoPath)

set supportedOS to "OS X 10.11 El Capitan"
if (supportsVentura) then
	set supportedOS to "macOS 13 Ventura"
else if (supportsMonterey) then
	set supportedOS to "macOS 12 Monterey"
else if (supportsBigSur) then
	set supportedOS to "macOS 11 Big Sur"
else if (supportsCatalina) then
	set supportedOS to "macOS 10.15 Catalina"
else if (supportsHighSierra) then
	set supportedOS to "macOS 10.13 High Sierra"
end if

set nameOfBootedDisk to ""
try
	tell application id "com.apple.systemevents" to set nameOfBootedDisk to (name of startup disk)
end try

set shouldSetStartupDisk to false
set chosenStartupDiskName to ""
set chosenStartupDiskVersion to "0"

repeat
	set shouldSetStartupDisk to false
	set chosenStartupDiskName to ""
	set chosenStartupDiskVersion to "0"
	
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
				tell application id "com.apple.systemevents" to tell property list file thisSystemVersionPlist
					try
						set osVersion to ((value of property list item "ProductUserVisibleVersion") as text)
					on error
						try
							set osVersion to ((value of property list item "ProductVersion") as text)
						end try
					end try
					try
						set osDarwinMajorVersion to (text 1 thru 2 of ((value of property list item "ProductBuildVersion") as text))
					end try
				end tell
			end try
			
			set startupDiskIsCompatibleWithMac to true
			
			set macOSname to "Mac OS X"
			considering numeric strings
				if (osVersion ≥ "10.12") then
					set macOSname to "macOS"
					if ((osVersion ≥ "13.0") and (not supportsVentura)) then
						set startupDiskIsCompatibleWithMac to false
					else if ((osVersion ≥ "12.0") and (not supportsMonterey)) then
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
			if (nameOfBootedDisk is not equal to thisDriveName) then
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
		set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as text)
		set hdStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (hdStartupDiskOptions as text)) & " | sort -urV | cut -d ':' -f 2-")))
		
		set defaultStartupDiskSelection to (first item of hdStartupDiskOptions)
		
		set startupDiskOptions to hdStartupDiskOptions
	end if
	
	set separatorLine to "———————————————————————"
	
	if ((count of otherStartupDiskOptions) > 0) then
		set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as text)
		set otherStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (otherStartupDiskOptions as text)) & " | sort -urV | cut -d ':' -f 2-")))
		
		if ((count of startupDiskOptions) > 0) then
			set startupDiskOptions to startupDiskOptions & {separatorLine} & otherStartupDiskOptions
		else
			set startupDiskOptions to otherStartupDiskOptions
		end if
	end if
	
	if ((count of installerStartupDiskOptions) > 0) then
		set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as text)
		set installerStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (installerStartupDiskOptions as text)) & " | sort -urV | cut -d ':' -f 2-")))
		
		if (defaultStartupDiskSelection is equal to "") then set defaultStartupDiskSelection to (first item of installerStartupDiskOptions)
		
		if ((count of startupDiskOptions) > 0) then
			set startupDiskOptions to startupDiskOptions & {separatorLine} & installerStartupDiskOptions
		else
			set startupDiskOptions to installerStartupDiskOptions
		end if
	end if
	
	if ((count of testBootStartupDiskOptions) > 0) then
		set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as text)
		set testBootStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (testBootStartupDiskOptions as text)) & " | sort -urV | cut -d ':' -f 2-")))
		
		if (defaultStartupDiskSelection is equal to "") then set defaultStartupDiskSelection to (first item of testBootStartupDiskOptions)
		
		if ((count of startupDiskOptions) > 0) then
			set startupDiskOptions to startupDiskOptions & {separatorLine} & testBootStartupDiskOptions
		else
			set startupDiskOptions to testBootStartupDiskOptions
		end if
	end if
	
	set incompatibleStartupDisksNote to ""
	if ((incompatibleStartupDiskOptions count) > 0) then
		set AppleScript's text item delimiters to linefeed -- Must set delimiter for (array as text)
		set incompatibleStartupDiskOptions to (paragraphs of (do shell script ("echo " & (quoted form of (incompatibleStartupDiskOptions as text)) & " | sort -urV | cut -d ':' -f 2-")))
		
		set pluralizeDisks to ""
		if ((incompatibleStartupDiskOptions count) > 1) then set pluralizeDisks to "s"
		set AppleScript's text item delimiters to (linefeed & tab)
		set incompatibleStartupDisksNote to "Excluded Incompatible Startup Disk" & pluralizeDisks & ":
	" & (incompatibleStartupDiskOptions as text)
	end if
	
	if ((count of startupDiskOptions) is equal to 0) then
		try
			activate
		end try
		try
			do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
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
		set chosenStartupDisk to (choose from list startupDiskOptions default items defaultStartupDiskSelection with prompt "This Mac Supports " & supportedOS & "

" & incompatibleStartupDisksNote & "Select Drive to Set as Startup Disk:" OK button name "Select Startup Disk" cancel button name "Quit" with title "Startup Picker")
		if (chosenStartupDisk is not equal to false) then
			if ((chosenStartupDisk as text) is equal to separatorLine) then
				-- Just display list again since user selected separator line.
			else if ((last word of (chosenStartupDisk as text)) starts with "1") then
				set AppleScript's text item delimiters to " ("
				set chosenStartupDiskParts to (every text item of (chosenStartupDisk as text))
				set chosenStartupDiskName to ((text items 1 thru -2 of chosenStartupDiskParts) as text)
				set chosenStartupDiskVersion to (do shell script "echo " & (quoted form of ((last text item of chosenStartupDiskParts) as text)) & " | tr -dc '[:digit:].'")
				try
					try
						activate
					end try
					display alert "
Are you sure you want to set “" & chosenStartupDiskName & "” as the startup disk?" buttons {"Quit", "Change Selection", "Set “" & chosenStartupDiskName & "” as Startup Disk"} cancel button 2 default button 3
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
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
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

if (shouldSetStartupDisk and (chosenStartupDiskName is not equal to "")) then
	set nameOfCurrentlySelectedStartupDisk to ""
	try
		set nameOfCurrentlySelectedStartupDisk to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :VolumeName' /dev/stdin <<< \"$(diskutil info -plist \"$(bless --getBoot)\")\"")))
	end try
	
	set didSetStartUpDisk to (nameOfCurrentlySelectedStartupDisk is equal to chosenStartupDiskName)
	
	set didNotTryToSetStartupDisk to false
	considering numeric strings
		if (chosenStartupDiskVersion ≥ "11.0") then
			-- macOS 11 Big Sur and newer installers do not show up in Startup Disk, so do not waste time trying to set them.
			set didNotTryToSetStartupDisk to true
		end if
	end considering
	
	if ((not didSetStartUpDisk) and (not didNotTryToSetStartupDisk)) then
		set securityAgentPath to "/System/Library/Frameworks/Security.framework/Versions/A/MachServices/SecurityAgent.bundle"
		set securityAgentID to (id of application securityAgentPath)
		
		repeat 15 times
			try
				with timeout of 1 second
					tell application id "com.apple.systempreferences" to quit
				end timeout
			end try
			try
				tell application id "com.apple.systempreferences"
					repeat 180 times -- Wait for Security pane to load
						try
							activate
						end try
						try
							reveal (pane id "com.apple.preference.startupdisk")
						on error
							try -- As of macOS 13 Ventura, all of the AppleScript capability of the new System Settings apps to reveal anchors and panes no longer works, so use this URL Scheme instead which gets us directly to the same place as before.
								tell me to open location "x-apple.systempreferences:com.apple.preference.startupdisk" -- Ventura adds a new URL Scheme for the same section (com.apple.Startup-Disk-Settings.extension), but this old one still works too (oddly, this old one doesn't seem to work in Monterey, haven't tested on older though but shouldn't matter since Monterey and older should never get here).
							end try
						end try
						delay 1
						if ((name of window 1) is "Startup Disk") then exit repeat
					end repeat
				end tell
				
				if (isCatalinaOrNewer and (not isVenturaOrNewer)) then
					-- On Catalina, a SecurityAgent alert with "System Preferences wants to make changes." will appear IF an Encrypted Disk is present.
					-- OR if Big Sur is installed on some drive, whose Sealed System Volume is unable to be mounted (ERROR -69808) and makes System Preferences think it needs to try again with admin privileges.
					-- In this case, we can just cancel out of that alert to continue on without displaying the Encrypted Disk or the Big Sur installation in the Startup Disk options.
					-- BUT, on Ventura the disk must instead be manually unlocked before being able to choose it as a startup disk, so no prompt will appear automatically.
					
					try
						do shell script "diskutil apfs list | grep 'Yes (Locked)\\|ERROR -69808'" -- Grep will error if not found.
						
						try -- Mute volume before key codes so it's silent if the window isn't open
							set volume output volume 0 with output muted
						end try
						try
							set volume alert volume 0
						end try
						
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
										tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
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
				
				set numberOfStartupDisks to 0
				set currentlySelectedStartupDiskValue to ""
				set leftOrRightArrowKeyCode to 124 -- RIGHT ARROW Key
				if (isVenturaOrNewer) then
					tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
						repeat 30 times -- Wait for startup disk list to populate
							delay 1
							try
								if (isSonomaOrNewer) then
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								else
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								end if
								set numberOfStartupDisks to (number of groups of list 1 of scroll area 1 of startupDisksSelectionGroup)
								if (numberOfStartupDisks is not 0) then
									delay 3 -- Wait a few more seconds for disks to load since it's possible that not all startup disks are actually loaded yet.
									set numberOfStartupDisks to (number of groups of list 1 of scroll area 1 of startupDisksSelectionGroup)
									
									set currentlySelectedStartupDiskValue to (value of static text 2 of startupDisksSelectionGroup) -- Check if the internal drive is already set as the Startup Disk.
									if (currentlySelectedStartupDiskValue ends with ("“" & chosenStartupDiskName & "”.")) then
										set didSetStartUpDisk to true
									else
										if (currentlySelectedStartupDiskValue is not equal to "") then -- If some startup disk is already selected, figure out if the internal disk is to the right or left of that.
											set foundSelectedStartupDisk to false
											repeat with thisStartupDiskGroup in (groups of list 1 of scroll area 1 of startupDisksSelectionGroup)
												set thisStartDiskName to (value of static text 1 of thisStartupDiskGroup)
												if (currentlySelectedStartupDiskValue ends with ("“" & thisStartDiskName & "”.")) then
													exit repeat -- If we found the selected startup disk and have not found the internal disk yet, they means it must be to the RIGHT, which leftOrRightArrowKeyCode is already set to.
												else if (thisStartDiskName is equal to selectedStartupDiskName) then
													-- If we're at the internal disk and we HAVE NOT already passed the selected disk (since we haven't exited to loop yet), we need to move LEFT from the selected disk.
													set leftOrRightArrowKeyCode to 123 -- LEFT ARROW Key
													exit repeat
												end if
											end repeat
										end if
									end if
									exit repeat
								end if
							end try
						end repeat
					end tell
					
					if (not didSetStartUpDisk) then -- If it's already selected, no need to unlock and re-select it.
						set didAuthenticateStartupDisk to false
						
						repeat numberOfStartupDisks times -- The loop should be exited before even getting through numberOfStartupDisks, but want some limit so we don't get stuck in an infinite loop if something goes very wrong.
							tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
								-- Can't click elements in new fancy Startup Disk list, but I can arrow through them.
								set frontmost to true
								if (isSonomaOrNewer) then
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								else
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								end if
								set focused of (scroll area 1 of startupDisksSelectionGroup) to true
								set currentlySelectedStartupDiskValue to (value of static text 2 of startupDisksSelectionGroup)
								repeat 5 times -- Click up to 5 times until the selected startup disk changed (in case some clicks get lost)
									set frontmost to true
									key code leftOrRightArrowKeyCode
									delay 0.25
									if (currentlySelectedStartupDiskValue is not equal to (value of static text 2 of startupDisksSelectionGroup)) then exit repeat
								end repeat
							end tell
							
							if (not didAuthenticateStartupDisk) then
								set didTryToAuthenticateStartupDisk to false
								if (isVenturaThirteenDotThreeOrNewer) then
									-- Starting on macOS 13.3 Ventura, the System Settings password authentication prompt is now handled by "LocalAuthenticationRemoteService" XPC service within a regular sheet of the System Setting app instead of the "SecurityAgent.bundle" which presented a separate app prompt window.
									tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
										repeat 60 times -- Wait for password prompt
											delay 0.5
											set frontmost to true
											if ((number of sheets of window (number of windows)) is equal to 1) then exit repeat
											delay 0.5
										end repeat
										
										if ((number of sheets of window (number of windows)) is equal to 1) then
											repeat with thisSheetButton in (buttons of sheet 1 of window (number of windows))
												if (((name of thisSheetButton) is equal to "Unlock") or ((name of thisSheetButton) is equal to "Modify Settings")) then -- The button title is usually "Unlock" but I have occasionally seen it be "Modify Settings" during my testing and I'm not sure why, but check for either title.
													set value of (text field 1 of sheet 1 of window (number of windows)) to adminUsername
													set value of (text field 2 of sheet 1 of window (number of windows)) to adminPassword
													click thisSheetButton
													set didTryToAuthenticateStartupDisk to true
													exit repeat
												end if
											end repeat
										end if
									end tell
									
									if (isSonomaOrNewer) then -- On macOS 14 Sonoma beta 1 through RC, ANOTHER standalone SecurityAgent auth prompt comes up AFTER the initial LocalAuthenticationRemoteService XPC sheet prompt WHEN RUNNING AS A STANDARD USER.
										set didTryToAuthenticateStartupDisk to false
										repeat 10 times -- Wait up to 10 seconds for SecurityAgent to launch and present the admin auth prompt since it can take a moment.
											delay 1
											try
												if (application securityAgentPath is running) then
													tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
														if ((number of windows) is 1) then -- In previous code I've written, I commented that I could not reliably get any SecurityAgent windows or UI elements, but this seems to work well in Ventura and I also tested getting the contents of a SecurityAgent window on Monterey and it worked as well, so not certain what OS it didn't work for in the past (didn't bother testing older OSes or updating any other SecurityAgent code).
															repeat with thisSecurityAgentButton in (buttons of window 1)
																if ((title of thisSecurityAgentButton) is equal to "OK") then
																	set value of (text field 1 of window 1) to adminUsername
																	set value of (text field 2 of window 1) to adminPassword
																	click thisSecurityAgentButton
																	set didTryToAuthenticateStartupDisk to true
																	exit repeat
																end if
															end repeat
														end if
														exit repeat
													end tell
												end if
											end try
										end repeat
									end if
								else
									repeat 10 times -- Wait up to 10 seconds for SecurityAgent to launch and present the admin auth prompt since it can take a moment.
										delay 1
										try
											if (application securityAgentPath is running) then
												tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
													if ((number of windows) is 1) then -- In previous code I've written, I commented that I could not reliably get any SecurityAgent windows or UI elements, but this seems to work well in Ventura and I also tested getting the contents of a SecurityAgent window on Monterey and it worked as well, so not certain what OS it didn't work for in the past (didn't bother testing older OSes or updating any other SecurityAgent code).
														repeat with thisSecurityAgentButton in (buttons of window 1)
															if (((title of thisSecurityAgentButton) is equal to "Unlock") or ((title of thisSecurityAgentButton) is equal to "Modify Settings")) then -- The button title is usually "Unlock" but I have occasionally seen it be "Modify Settings" during my testing and I'm not sure why, but check for either title.
																set value of (text field 1 of window 1) to adminUsername
																set value of (text field 2 of window 1) to adminPassword
																click thisSecurityAgentButton
																set didTryToAuthenticateStartupDisk to true
																exit repeat
															end if
														end repeat
													end if
													exit repeat
												end tell
											end if
										end try
									end repeat
								end if
								
								if (didTryToAuthenticateStartupDisk) then
									repeat 10 times -- Wait up to 10 seconds for sheet to close on 13.3+ (of for SecurityAgent to exit or close the admin auth prompt on 13.2.1-) to be sure the authentication was successful.
										delay 1
										try
											if (isVenturaThirteenDotThreeOrNewer) then
												tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
													if ((number of sheets of window (number of windows)) is equal to 0) then
														set didAuthenticateStartupDisk to true
														exit repeat
													end if
												end tell
												
												if (isSonomaOrNewer) then -- See comments above about SECOND SecurityAgent auth prompt on macOS 14 Sonoma beta 1 through RC.
													set didAuthenticateStartupDisk to false
													if (application securityAgentPath is running) then
														tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
															if ((number of windows) is 0) then
																set didAuthenticateStartupDisk to true
																exit repeat
															end if
														end tell
													else
														set didAuthenticateStartupDisk to true
														exit repeat
													end if
												end if
											else
												if (application securityAgentPath is running) then
													tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
														if ((number of windows) is 0) then
															set didAuthenticateStartupDisk to true
															exit repeat
														end if
													end tell
												else
													set didAuthenticateStartupDisk to true
													exit repeat
												end if
											end if
										end try
									end repeat
								end if
							end if
							
							if (didAuthenticateStartupDisk) then
								tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
									if (isSonomaOrNewer) then
										set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
									else
										set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
									end if
									if ((enabled of button 1 of startupDisksSelectionGroup) and ((value of static text 2 of startupDisksSelectionGroup) ends with ("“" & chosenStartupDiskName & "”."))) then
										set didSetStartUpDisk to true
										exit repeat
									end if
								end tell
							else
								if (isVenturaThirteenDotThreeOrNewer) then
									tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
										if ((number of sheets of window (number of windows)) is equal to 1) then
											set frontmost to true
											key code 53 -- Press ESCAPE in case something went wrong and the password prompt is still up.
										end if
									end tell
									
									if (isSonomaOrNewer) then -- The SECOND SecurityAgent prompt on macOS 14 Sonoma beta 1 through RC DOES NOT close on its own when System Settings is quit.
										if (application securityAgentPath is running) then
											tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
												if ((number of windows) is 1) then
													set frontmost to true
													key code 53 -- Press ESCAPE in case something went wrong and the password prompt is still up.
												end if
											end tell
										end if
									end if
								end if -- Do not need to cancel the SecurityAgent prompt since it will just be closed when System Settings is quit and will not block quitting.
								
								exit repeat -- If did not authenticate, better to exit this loop and start all over with System Settings being quit and re-launched instead of continuing to arrow through the Startup Disks.
							end if
						end repeat
					end if
				else
					tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
						repeat 30 times -- Wait for startup disk list to populate
							delay 1
							try
								if (isBigSurOrNewer) then
									set numberOfStartupDisks to (number of groups of list 1 of scroll area 1 of window 1)
									if (numberOfStartupDisks is not 0) then
										delay 3 -- Wait a few more seconds for disks to load since it's possible that not all startup disks are actually loaded yet.
										set numberOfStartupDisks to (number of groups of list 1 of scroll area 1 of window 1)
										
										set currentlySelectedStartupDiskValue to (value of static text 1 of window 1)
										if ((value of static text 1 of window 1) ends with ("“" & chosenStartupDiskName & ".”")) then -- Check if the internal drive is already set as the Startup Disk.
											set didSetStartUpDisk to true
										else
											if (currentlySelectedStartupDiskValue is not equal to "") then -- If some startup disk is already selected, figure out if the internal disk is to the right or left of that.
												set foundSelectedStartupDisk to false
												repeat with thisStartupDiskGroup in (groups of list 1 of scroll area 1 of window 1)
													set thisStartDiskName to (value of static text 1 of thisStartupDiskGroup)
													if (currentlySelectedStartupDiskValue ends with ("“" & thisStartDiskName & ".”")) then
														exit repeat -- If we found the selected startup disk and have not found the internal disk yet, they means it must be to the RIGHT, which leftOrRightArrowKeyCode is already set to.
													else if (thisStartDiskName is equal to selectedStartupDiskName) then
														-- If we're at the internal disk and we HAVE NOT already passed the selected disk (since we haven't exited to loop yet), we need to move LEFT from the selected disk.
														set leftOrRightArrowKeyCode to 123 -- LEFT ARROW Key
														exit repeat
													end if
												end repeat
											end if
										end if
										
										exit repeat
									end if
								else
									if ((number of radio buttons of radio group 1 of scroll area 1 of group 1 of splitter group 1 of window 1) is not 0) then
										delay 3 -- Wait a few more seconds for disks to load since it's possible that not all startup disks are actually loaded yet.
										set didSetStartUpDisk to ((value of static text 2 of group 1 of splitter group 1 of window 1) ends with ("“" & chosenStartupDiskName & ".”")) -- Check if the internal drive is already set as the Startup Disk.
										
										exit repeat
									end if
								end if
							end try
						end repeat
						
						if (not didSetStartUpDisk) then -- If it's already selected, no need to unlock and re-select it.
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
											-- For some reason this sheet on Monterey will only show that it has 1 text field until the 2nd password text field has been focused, so focus it by tabbing.
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
												exit repeat
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
										repeat numberOfStartupDisks times
											-- Can't click elements in new fancy Startup Disk list, but I can arrow through them.
											set frontmost to true
											set focused of (scroll area 1 of window 1) to true
											set currentlySelectedStartupDiskValue to (value of static text 1 of window 1)
											repeat 5 times -- Click up to 5 times until the selected startup disk changed (in case some clicks get lost)
												set frontmost to true
												key code leftOrRightArrowKeyCode
												delay 0.25
												if (currentlySelectedStartupDiskValue is not equal to (value of static text 1 of window 1)) then exit repeat
											end repeat
											
											if ((value of static text 1 of window 1) ends with ("“" & chosenStartupDiskName & ".”")) then
												set didSetStartUpDisk to true
												exit repeat
											end if
										end repeat
									else
										repeat with thisStartUpDiskRadioButton in (radio buttons of radio group 1 of scroll area 1 of group 1 of splitter group 1 of window 1)
											if ((name of thisStartUpDiskRadioButton) is equal to chosenStartupDiskName) then
												set frontmost to true
												click thisStartUpDiskRadioButton
												delay 0.25
												if ((value of static text 2 of group 1 of splitter group 1 of window 1) ends with ("“" & chosenStartupDiskName & ".”")) then -- If this text didn't get set, then something went wrong and we need to try again.
													set didSetStartUpDisk to true
													exit repeat
												end if
											end if
										end repeat
									end if
									
									exit repeat
								end if
							end repeat
						end if
					end tell
				end if
				if (didSetStartUpDisk) then
					-- If didSetStartUpDisk, double-check by getting the name of the disk specified by "bless --getBoot" which seems to get updated shortly after System Preferences/Settings has QUIT.
					try
						with timeout of 1 second
							tell application id "com.apple.systempreferences" to quit
						end timeout
					end try
					
					set didVerifyStartUpDisk to false
					repeat 15 times
						try
							delay 1
							if (chosenStartupDiskName is equal to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :VolumeName' /dev/stdin <<< \"$(diskutil info -plist \"$(bless --getBoot)\")\"")))) then
								set didVerifyStartUpDisk to true
								exit repeat
							end if
						end try
					end repeat
					
					if (didVerifyStartUpDisk) then
						exit repeat
					else
						set didSetStartUpDisk to false -- If the startup disk name was not verified by "bless --getBoot" after 15 seconds, try again.
					end if
				end if
			end try
		end repeat
		try
			with timeout of 1 second
				tell application id "com.apple.systempreferences" to quit
			end timeout
		end try
	end if
	
	try
		try
			if (didSetStartUpDisk) then
				do shell script "afplay /System/Library/Sounds/Glass.aiff > /dev/null 2>&1 &"
			else if (didNotTryToSetStartupDisk) then
				do shell script "afplay /System/Library/Sounds/Pop.aiff > /dev/null 2>&1 &"
			else
				do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
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
			
			display alert "The startup disk has been set to “" & chosenStartupDiskName & "”.

Do you want to reboot into “" & chosenStartupDiskName & "” right now?" message "
This Mac will automatically reboot into “" & chosenStartupDiskName & "” in 30 seconds…" buttons {"Don't Reboot", "Reboot Into “" & chosenStartupDiskName & "” Now"} cancel button 1 default button 2 giving up after 30
		else
			display alert "Unable to set the startup disk to “" & chosenStartupDiskName & "”.

Instead, this computer can be rebooted into Startup Manager for you to be able to choose to boot into “" & chosenStartupDiskName & "” from there.

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
			tell application id "com.apple.systemevents" to set listOfRunningAppIDs to (bundle identifier of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not (id of me))))
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
					tell application id "com.apple.systemevents" to set allRunningAppPIDs to ((unix id of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not (id of me)))) as text)
					if (allRunningAppPIDs is not equal to "") then
						do shell script ("kill " & allRunningAppPIDs)
					end if
				end try
			end if
		end try
		
		tell application id "com.apple.systemevents" to restart with state saving preference
	end try
end if

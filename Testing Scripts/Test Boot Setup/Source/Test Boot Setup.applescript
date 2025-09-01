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

-- Version: 2025.8.28-1

-- Build Flag: LSUIElement
-- Build Flag: IncludeSignedLauncher

use AppleScript version "2.7"
use scripting additions
use framework "AppKit"

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
		try
			tell application id "com.apple.systemevents"
				if (running of screen saver preferences) then key code 53 -- If screen saver is activate, simulate Escape key to end it.
			end tell
		end try
		
		delay 1
	end if
end repeat

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Test Boot Setup" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
	try
		do shell script ("/usr/libexec/PlistBuddy -c 'Print :FGBuiltByMacLandScriptBuilder' " & (quoted form of infoPlistPath))
		((((POSIX path of (path to me)) & "Contents/MacOS/" & intendedAppName) as POSIX file) as alias)
	on error
		activate
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
		activate
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
		activate
		display alert checkReadOnlyErrorMessage buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try

set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")

set freeGeekUpdaterExists to false
set freeGeekUpdaterAppPath to "/Applications/Free Geek Updater.app"
try
	((freeGeekUpdaterAppPath as POSIX file) as alias)
	set freeGeekUpdaterExists to true
	
	if (application freeGeekUpdaterAppPath is running) then -- Quit if Updater is running (and did not just finish) so that this app can be updated if needed.
		try
			(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- If Updater just finished, continue even if it's still running since it launches Setup when it's done.
		on error
			quit
			delay 10
		end try
	end if
end try


global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate -- Needs to be accessible in doShellScriptAsAdmin function.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "Staff"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set currentUsername to (short user name of (system info))

if ((currentUsername is equal to "Tester") and ((POSIX path of (path to me)) is equal to ("/Applications/" & (name of me) & ".app/"))) then
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
	end considering
	
	if (isMojaveOrNewer) then
		set needsAutomationAccess to false
		try
			tell application id "com.apple.systemevents" to every window -- To prompt for Automation access on Mojave
		on error automationAccessErrorMessage number automationAccessErrorNumber
			if (automationAccessErrorNumber is equal to -1743) then set needsAutomationAccess to true
		end try
		try
			tell application id "com.apple.finder" to every window -- To prompt for Automation access on Mojave
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
				display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “System Events” and “Finder” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “System Events” and “Finder” checkboxes underneath it.

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
	
	
	set thisDriveName to "Mac Test Boot"
	
	-- Always create ".fgSetupSkipped" on launch. It will be deleted when this app has finished a full run.
	try
		do shell script "mkdir " & (quoted form of buildInfoPath)
	end try
	try
		doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgSetupSkipped")))
	end try
	
	set startupDiskCapacity to 0 -- This is for checking if is source drive.
	try
		tell application id "com.apple.systemevents" to set startupDiskCapacity to ((capacity of startup disk) as number)
	end try
	
	set macScopeAppExists to false
	try
		(("/Applications/Mac Scope.app" as POSIX file) as alias) -- This should only error if previously determined MTB was outdated for some reason and Mac Scope was deleted.
		set macScopeAppExists to true
	end try
	
	try
		-- Only check if outdated if just updated (to be sure the checks are done with the latest version of this app) and do not offer to skip if just finished running Updater
		-- (since Setup already offered to skip before launching Updater) or if Mac Scope doesn't exist (which indicates the drive was previously determined to be outdated.
		if (macScopeAppExists) then (((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
		
		try
			-- Check if this is an outdated Mac Test Boot (or Catalina Restore Boot) drive and delete all testing apps and alert if so.
			if (not macScopeAppExists) then error "NO MAC SCOPE"
			
			-- The MTB version is NOT stored in a user accessable location so that it cannot be super easily manually edited.
			set currentMTBversion to doShellScriptAsAdmin("cat '/private/var/root/.mtbVersion'") -- If the file doesn't exist, it's older than 20220726 which was the first version to include this file (version 20220705 stored the file at "/Users/Shared/.mtbVersion" and no MTB version file existed before that).
			
			set validMTBversions to {"20250820"}
			if (validMTBversions does not contain currentMTBversion) then error "OUTDATED"
		on error
			set serialNumber to ""
			try
				set serialNumber to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< \"$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)\"")))
			end try
			if ((startupDiskCapacity > 3.3E+10) or (serialNumber is not equal to "C02R49Y5G8WP")) then -- Never delete anything on Source drive no matter what.
				try
					doShellScriptAsAdmin("
rm -rf '/Applications/AmorphousDiskMark.app' '/Applications/Audio Test.app' '/Applications/Blackmagic Disk Speed Test.app' '/Applications/Breakaway.app' '/Applications/Camera Test.app' '/Applications/coconutBattery.app' '/Applications/coconutID.app' '/Applications/CPU Stress Test.app' '/Applications/CPUTest.app' '/Applications/DriveDx.app' '/Applications/FingerMgmt.app' '/Applications/Firmware Checker.app' '/Applications/Free Geek Updater.app' '/Applications/Geekbench 5.app' '/Applications/GPU Stress Test.app' '/Applications/GpuTest_OSX_x64_0.7.0' '/Applications/GpuTest_OSX_x64' '/Applications/Internet Test.app' '/Applications/Keyboard Test.app' '/Applications/KeyboardCleanTool.app' '/Applications/Mac Scope.app' '/Applications/Mactracker.app' '/Applications/Microphone Test.app' '/Applications/PiXel Check.app' '/Applications/Restore OS.app' '/Applications/Screen Test.app' '/Applications/SilentKnight.app' '/Applications/Startup Picker.app' '/Applications/Test CD.app' '/Applications/Test DVD.app' '/Applications/Trackpad Test.app' '/Applications/XRG.app' '/Users/Tester/Applications' '/Users/Shared/OS Updates' '/Users/Shared/Restore OS Images'
if [ -d '/Volumes/fgMIB' ]; then
	rm -rf '/Volumes/fgMIB/install-packages' '/Volumes/fgMIB/customization-resources'
	echo '#!/bin/bash
echo \"
This " & thisDriveName & " Drive Is Outdated

Deliver this " & thisDriveName & " drive to Free Geek I.T.
\"' > '/Volumes/fgMIB/fg-install-os'
	chmod +x '/Volumes/fgMIB/fg-install-os'
fi
")
				end try
				
				try
					activate
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
				end try
				display alert ("
This " & thisDriveName & " Drive Is Outdated") message ("Deliver this " & thisDriveName & " drive to Free Geek I.T.
") buttons {"Shut Down"} default button 1 as critical
				
				tell application id "com.apple.systemevents" to shut down with state saving preference
				
				quit
				delay 10
			else
				try
					activate
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
				end try
				try
					display alert ("This " & thisDriveName & " Drive Is Outdated") message ("But, this is the SOURCE MTB drive so nothing will be deleted.

If you are seeing this message during production, SHUT DOWN and notify Free Geek I.T. since THIS DRIVE MUST NOT BE USED!") buttons {"Shut Down", "Continue with Setup"} cancel button 1 default button 2 as critical
				on error
					tell application id "com.apple.systemevents" to shut down with state saving preference
					
					quit
					delay 10
				end try
			end if
		end try
	on error
		try
			activate
		end try
		try
			display alert ("Skip " & thisDriveName & " Setup to Only Use Diagnostic Tools?") message "Setup can be skipped if you just need to use the Diagnostic Tools.

Setup will be run if you launch any of the standard test apps.

Setup will continue in 5 seconds…" buttons {"Skip Setup", "Continue with Setup"} cancel button 1 default button 2 giving up after 5
		on error
			quit
			delay 10
		end try
	end try
	
	try
		activate
	end try
	set progress total steps to -1
	set progress completed steps to 0
	set progress description to "🚧	Setting Up " & thisDriveName & "…"
	set progress additional description to "
🚫	DO NOT TOUCH THIS MAC WHILE IT IS BEING SET UP"
	
	try
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as text) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as text) is equal to "NSProgressIndicator") then
							(thisWindow's setLevel:(current application's NSScreenSaverWindowLevel))
						else if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Stop")) then
							(thisProgressWindowSubView's setEnabled:false)
						end if
					end repeat
				end if
			end if
		end repeat
	end try
	
	try
		(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
	on error
		delay 3 -- Add some delay so system stuff can get going on login. (Don't delay again if launched for a second time after Free Geek Updater just finished.)
	end try
	
	
	try
		tell application id "com.apple.systemevents" to delete login item (name of me)
	end try
	
	set userLaunchAgentsPath to ((POSIX path of (path to library folder from user domain)) & "LaunchAgents/")
	
	set testBootSetupLaunchAgentLabel to "org.freegeek.Test-Boot-Setup"
	set testBootSetupLaunchAgentPlistName to (testBootSetupLaunchAgentLabel & ".plist")
	set testBootSetupUserLaunchAgentPlistPath to (userLaunchAgentsPath & testBootSetupLaunchAgentPlistName)
	
	try
		((userLaunchAgentsPath as POSIX file) as alias)
	on error
		try
			tell application id "com.apple.finder" to make new folder at (path to library folder from user domain) with properties {name:"LaunchAgents"}
		end try
	end try
	
	-- NOTE: The following LaunchAgent is setup to run a signed script which launches the app and has "AssociatedBundleIdentifiers" specified to be properly displayed in the "Login Items" list in "System Settings" on macOS 13 Ventura and newer.
	-- BUT, this is just done for consistency with other code since this particular script will never run on macOS 13 Ventura, but the "AssociatedBundleIdentifiers" will just be ignored and the signed launcher script will behave just as if we ran "/usr/bin/open" directly via the LaunchAgent.
	set testBootSetupUserLaunchAgentPlistContents to (do shell script "
echo '<dict/>' | # NOTE: Starting with this plist fragment '<dict/>' is a way to create an empty plist with root type of dictionary. This is effectively same as starting with 'plutil -create xml1 -' (which can be verified by comparing the output to 'echo '<dict/>' | plutil -convert xml1 -o - -') but the 'plutil -create' option is only available on macOS 12 Monterey and newer.
	plutil -insert 'Label' -string " & (quoted form of testBootSetupLaunchAgentLabel) & " -o - - | # Using a pipeline of 'plutil' commands reading from stdin and outputting to stdout is a clean way of creating a plist string without needing to hardcode the plist contents and without creating a file (which would be required if PlistBuddy was used).
	plutil -insert 'Program' -string " & (quoted form of ("/Applications/Test Boot Setup.app/Contents/Resources/Launch Test Boot Setup")) & " -o - - | # Even though doing this is technically less efficient vs just hard coding a plist string, it makes for cleaner and smaller code.
	plutil -insert 'AssociatedBundleIdentifiers' -string " & (quoted form of testBootSetupLaunchAgentLabel) & " -o - - |
	plutil -insert 'StandardOutPath' -string '/dev/null' -o - - |
	plutil -insert 'StandardErrorPath' -string '/dev/null' -o - - |
	plutil -insert 'RunAtLoad' -bool true -o - -
" without altering line endings) -- "without altering line endings" MUST be used since "do shell script" replaces "\n" with "\r" line breaks by default which we DO NOT want in the plist file we are creating.
	
	set needsToWriteTestBootSetupUserLaunchAgentPlistFile to false
	try
		((testBootSetupUserLaunchAgentPlistPath as POSIX file) as alias)
		set currentTestBootSetupUserLaunchAgentPlistContents to (read (testBootSetupUserLaunchAgentPlistPath as POSIX file))
		if (currentTestBootSetupUserLaunchAgentPlistContents is not equal to testBootSetupUserLaunchAgentPlistContents) then
			set needsToWriteTestBootSetupUserLaunchAgentPlistFile to true
			try
				do shell script ("launchctl bootout gui/$(id -u " & demoUsername & ")/" & testBootSetupLaunchAgentLabel)
			end try
		end if
	on error
		set needsToWriteTestBootSetupUserLaunchAgentPlistFile to true
		try
			tell application id "com.apple.finder" to make new file at (userLaunchAgentsPath as POSIX file) with properties {name:testBootSetupLaunchAgentPlistName}
		end try
	end try
	if (needsToWriteTestBootSetupUserLaunchAgentPlistFile) then
		try
			set openedTestBootSetupUserLaunchAgentPlistFile to open for access (testBootSetupUserLaunchAgentPlistPath as POSIX file) with write permission
			set eof of openedTestBootSetupUserLaunchAgentPlistFile to 0
			write testBootSetupUserLaunchAgentPlistContents to openedTestBootSetupUserLaunchAgentPlistFile starting at eof
			close access openedTestBootSetupUserLaunchAgentPlistFile
		on error
			try
				close access (testBootSetupUserLaunchAgentPlistPath as POSIX file)
			end try
		end try
		try
			do shell script "launchctl bootstrap gui/$(id -u " & demoUsername & ") " & (quoted form of testBootSetupUserLaunchAgentPlistPath)
		end try
	end if
	
	set serialNumber to "UNKNOWNSERIAL-" & (random number from 100 to 999)
	
	try
		set AppleScript's text item delimiters to ""
		set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
		set hardwareInfoPath to tmpPath & "hardwareInfo.plist"
		repeat 30 times
			try
				do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of hardwareInfoPath)
				tell application id "com.apple.systemevents" to tell property list file hardwareInfoPath
					set hardwareItems to (first property list item of property list item "_items" of first property list item)
					set serialNumber to ((value of property list item "serial_number" of hardwareItems) as text)
					if (serialNumber is equal to "Not Available") then
						try
							set serialNumber to ((value of property list item "riser_serial_number" of hardwareItems) as text)
							set serialNumber to (do shell script "echo '" & serialNumber & "' | tr -d '[:space:]'")
						on error
							set serialNumber to "UNKNOWNSERIAL-" & (random number from 100 to 999)
						end try
					end if
				end tell
				exit repeat
			on error
				do shell script "rm -f " & (quoted form of hardwareInfoPath) -- Delete incase User Canceled
				delay 1 -- Wait and try again because it seems to fail sometimes when run on login.
			end try
		end repeat
		do shell script "rm -f " & (quoted form of hardwareInfoPath)
	end try
	
	if ((startupDiskCapacity ≤ 3.3E+10) and (serialNumber is equal to "C02R49Y5G8WP")) then
		set serialNumber to "Source" -- Don't include any computer serial number for the source drive.
		
		-- Run EFIcheck if on source drive to keep the AllowList up-to-date.
		try
			do shell script "defaults delete eficheck"
		end try
		try
			((("/usr/libexec/firmwarecheckers/eficheck/eficheck") as POSIX file) as alias) -- "eficheck" binary has been removed on macOS 14 Sonoma.
			set efiCheckPID to doShellScriptAsAdmin("/usr/libexec/firmwarecheckers/eficheck/eficheck --integrity-check > /dev/null 2>&1 & echo $!")
			delay 1
			set efiCheckIsRunning to ((do shell script ("ps -p " & efiCheckPID & " > /dev/null 2>&1; echo $?")) as number)
			if (efiCheckIsRunning is equal to 0) then
				repeat
					try -- EFIcheck may open UserNotificationCenter with a "Your computer has detected a potential problem" alert if EFI Firmware is out-of-date.
						if (application id "com.apple.UserNotificationCenter" is running) then
							tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.UserNotificationCenter")
								repeat 60 times
									set clickedDontSendButton to false
									repeat with thisUNCWindow in windows
										if ((count of buttons of thisUNCWindow) ≥ 3) then
											repeat with thisUNCButton in (buttons of thisUNCWindow)
												if (title of thisUNCButton is "Don’t Send") then
													click thisUNCButton
													set clickedDontSendButton to true
													exit repeat
												end if
											end repeat
										end if
									end repeat
									if (not clickedDontSendButton) then exit repeat
									delay 0.5
								end repeat
							end tell
						end if
					end try
					
					set efiCheckIsRunning to ((do shell script ("ps -p " & efiCheckPID & " > /dev/null 2>&1; echo $?")) as number)
					delay 0.5
					if (efiCheckIsRunning is not equal to 0) then exit repeat
				end repeat
			end if
		end try
	else
		try
			-- DO NOT clear NVRAM if TRIM has been enabled on Catalina with "trimforce enable" because clearing NVRAM will undo it. (The TRIM flag is not stored in NVRAM before Catalina.)
			doShellScriptAsAdmin("nvram EnableTRIM") -- This will error if the flag does not exist.
		on error
			try -- Clear NVRAM if we're not on the source drive (just for house cleaning purposes, this doesn't clear SIP).
				doShellScriptAsAdmin("nvram -c")
			end try
		end try
	end if
	
	-- HIDE ADMIN USER
	try
		if ((do shell script ("dscl -plist . -read /Users/" & adminUsername & " IsHidden | xmllint --xpath 'string(//string)' -; exit 0")) is not equal to "1") then
			doShellScriptAsAdmin("dscl . -create /Users/" & adminUsername & " IsHidden 1")
		end if
	end try
	
	try
		doShellScriptAsAdmin("
# DISABLE SLEEP
pmset -a sleep 0 displaysleep 0

# SET GLOBAL LANGUAGE AND LOCALE
defaults write '/Library/Preferences/.GlobalPreferences' AppleLanguages -array 'en-US'
defaults write '/Library/Preferences/.GlobalPreferences' AppleLocale -string 'en_US'
defaults write '/Library/Preferences/.GlobalPreferences' AppleMeasurementUnits -string 'Inches'
defaults write '/Library/Preferences/.GlobalPreferences' AppleMetricUnits -bool false
defaults write '/Library/Preferences/.GlobalPreferences' AppleTemperatureUnit -string 'Fahrenheit'
defaults write '/Library/Preferences/.GlobalPreferences' AppleTextDirection -bool false
")
	end try
	
	-- SET USER LANGUAGE AND LOCALE
	do shell script "
defaults write NSGlobalDomain AppleLanguages -array 'en-US'
defaults write NSGlobalDomain AppleLocale -string 'en_US'
defaults write NSGlobalDomain AppleMeasurementUnits -string 'Inches'
defaults write NSGlobalDomain AppleMetricUnits -bool false
defaults write NSGlobalDomain AppleTemperatureUnit -string 'Fahrenheit'
defaults write NSGlobalDomain AppleTextDirection -bool false
"
	
	-- DELETING ALL TOUCH ID FINGERPRINTS
	try
		doShellScriptAsAdmin("echo 'Y' | bioutil -p -s")
	end try
	
	-- DELETE ALL LOCAL SNAPSHOTS
	if (isCatalinaOrNewer) then
		try
			do shell script "tmutil deletelocalsnapshots /" -- Can delete all Snapshots at mountpoint on Catalina or newer
		end try
	else
		try
			set allLocalSnapshots to do shell script "tmutil listlocalsnapshots / | cut -d '.' -f 4"
			repeat with thisLocalSnapshot in (paragraphs of allLocalSnapshots)
				try
					-- Have to delete each Snapshot individually on High Sierra
					do shell script ("tmutil deletelocalsnapshots " & (quoted form of (thisLocalSnapshot as text)))
				end try
			end repeat
		end try
	end if
	
	-- ENABLE NETWORK TIME AND SET MENUBAR CLOCK FORMAT
	try
		doShellScriptAsAdmin("systemsetup -setusingnetworktime on")
	end try
	do shell script "defaults write com.apple.menuextra.clock FlashDateSeparators -bool false; defaults write com.apple.menuextra.clock IsAnalog -bool false"
	set currentClockFormat to "UNKNOWN CLOCK FORMAT"
	set intendedClockFormat to "EEE MMM d  h:mm:ss a"
	try
		set currentClockFormat to do shell script "defaults read com.apple.menuextra.clock DateFormat"
	end try
	if (currentClockFormat is not equal to intendedClockFormat) then
		if (isBigSurOrNewer) then
			-- Need to set these keys AND DateFormat on macOS 11 Big Sur, but older versions of macOS only use DateFormat.
			do shell script "
defaults write com.apple.menuextra.clock Show24Hour -bool false
defaults write com.apple.menuextra.clock ShowAMPM -bool true
defaults write com.apple.menuextra.clock ShowDayOfMonth -bool true
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock ShowSeconds -bool true
" -- Must still set format after setting these prefs (and seconds won't get updated if we ONLY set the format).
		end if
		
		do shell script ("
defaults write com.apple.menuextra.clock DateFormat -string " & (quoted form of intendedClockFormat) & "
defaults export com.apple.menuextra.clock -") -- Seems that restarting SystemUIServer or ControlCenter does not always update the menubar clock. Exporting the prefs (just to stdout) may help to forcibly sync the prefs to make the restart work better.
		
		try
			if (isBigSurOrNewer) then
				do shell script "killall ControlCenter" -- Restarting ControlCenter is required to make changes take effect immediately on macOS 11 Big Sur or newer.
			else
				do shell script "killall SystemUIServer" -- Restarting SystemUIServer is required to make changes take effect immediately on macOS 10.15 Catalina or older.
			end if
		end try
	end if
	
	-- DISABLE REOPEN WINDOWS ON LOGIN
	try
		do shell script "defaults write com.apple.loginwindow TALLogoutSavesState -bool false"
	end try
	
	-- DISABLE AUTOMATIC OS & APP STORE UPDATES
	-- Keeping AutomaticCheckEnabled and AutomaticDownload enabled is required for EFIAllowListAll to be able to be updated when EFIcheck is run by our scripts, the rest should be disabled.
	try
		doShellScriptAsAdmin("
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticCheckEnabled -bool true
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticDownload -bool true
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' ConfigDataInstall -bool false
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' CriticalUpdateInstall -bool false
defaults write '/Library/Preferences/com.apple.commerce' AutoUpdate -bool false
")
		if (isMojaveOrNewer) then
			doShellScriptAsAdmin("defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticallyInstallMacOSUpdates -bool false")
		else
			doShellScriptAsAdmin("defaults write '/Library/Preferences/com.apple.commerce' AutoUpdateRestartRequired -bool false")
		end if
	end try
	
	-- DO NOT SHOW INTERNAL/BOOT DRIVE ON DESKTOP AND SET NEW FINDER WINDOWS TO COMPUTER
	tell application id "com.apple.finder" to tell Finder preferences
		set desktop shows hard disks to false
		set desktop shows external hard disks to true
		set desktop shows removable media to true
		set desktop shows connected servers to true
	end tell
	do shell script "defaults delete com.apple.finder NewWindowTargetPath; defaults write com.apple.finder NewWindowTarget -string 'PfCm'"
	
	-- SET SCREEN ZOOM TO USE SCROLL GESTURE WITH MODIFIER KEY, ZOOM FULL SCREEN, AND MOVE CONTINUOUSLY WITH POINTER
	-- This can only work on High Sierra, the pref is protected on Mojave and newer: https://eclecticlight.co/2020/03/04/how-macos-10-14-and-later-overrides-write-permission-on-some-files/
	if (not isMojaveOrNewer) then
		do shell script "
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess closeViewZoomMode -int 0
defaults write com.apple.universalaccess closeViewPanningMode -int 0
"
	end if
	
	-- SET DESIRED MOUSE SETTINGS
	try
		repeat with buttonNumber from 1 to 3
			set currentMouseButton to "UNKNOWN"
			try
				set currentMouseButton to (do shell script ("defaults read com.apple.driver.AppleHIDMouse Button" & buttonNumber))
			end try
			
			if (currentMouseButton is not equal to (buttonNumber as text)) then
				try
					do shell script ("defaults write com.apple.driver.AppleHIDMouse Button" & buttonNumber & " -int " & buttonNumber)
				end try
			end if
		end repeat
	end try
	
	-- HIDE ANY SYSTEM PREFERENCES BADGES FOR ANY OS UPDATES
	try
		do shell script "defaults delete com.apple.systempreferences AttentionPrefBundleIDs"
		-- NOTE: Can just delete the "AttentionPrefBundleIDs" without checking if it exists since it will just error if not which will get caught by the try block.
		-- Also, NOT running "killall Dock" after deleting since System Preferences is not always shown in the Dock (unless it is running).
		-- But still deleting the key so that the "Update" tag is not shown in the Apple menu (and so the badge is not shown WITHIN System Preferences in the prefPane icon).
	end try
	
	-- SET TOUCH BAR SETTINGS TO *NOT* BE "App Controls" (because AppleScript alert buttons don't update properly)
	try
		set currentTouchBarPresentationModeGlobal to "UNKNOWN"
		try
			set currentTouchBarPresentationModeGlobal to (do shell script "defaults read com.apple.touchbar.agent PresentationModeGlobal")
		end try
		
		set currentTouchBarPresentationModeFnModes to "UNKNOWN"
		try
			set currentTouchBarPresentationModeFnModes to (do shell script "defaults read com.apple.touchbar.agent PresentationModeFnModes")
		end try
		
		if ((currentTouchBarPresentationModeGlobal is not equal to "fullControlStrip") or (currentTouchBarPresentationModeFnModes does not contain "fullControlStrip = functionKeys")) then
			try
				do shell script "
defaults write com.apple.touchbar.agent PresentationModeGlobal fullControlStrip
defaults write com.apple.touchbar.agent PresentationModeFnModes -dict fullControlStrip functionKeys
killall ControlStrip
"
			end try
		end if
	end try
	
	-- DISABLE DICTATION (Don't want to alert to turn on dictation when clicking Fn multiple times)
	try
		set currentHIToolboxAppleDictationAutoEnable to "UNKNOWN"
		try
			set currentHIToolboxAppleDictationAutoEnable to (do shell script "defaults read com.apple.HIToolbox AppleDictationAutoEnable")
		end try
		
		if (currentHIToolboxAppleDictationAutoEnable is not equal to "0") then
			do shell script "defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 0"
		end if
	end try
	
	-- SET MACTRACKER TO OPEN TO "This Mac" SECTION AND TO NOT SHOW ALERT IF THE MODEL ID MATCHED MULTIPLE MODELS ON FIRST OPEN OF THE "This Mac" SECTION
	try
		set currentMactrackerWindowLocations to "UNKNOWN"
		try
			set currentMactrackerWindowLocations to (do shell script "defaults read 'com.mactrackerapp.Mactracker' 'WindowLocations'")
		end try
		
		set currentMactrackerMultipleFindMyMac to "UNKNOWN"
		try
			set currentMactrackerMultipleFindMyMac to (do shell script "defaults read 'com.mactrackerapp.Mactracker' 'MultipleFindMyMac'")
		end try
		
		if ((currentMactrackerWindowLocations does not contain "LastSelection = 2;") or (currentMactrackerMultipleFindMyMac is not equal to "0")) then
			do shell script "
defaults write 'com.mactrackerapp.Mactracker' 'WindowLocations' -dict 'MainWindow' \"$(echo '<dict/>' | plutil -insert 'LastSelection' -integer '2' -o - -)\"
defaults write 'com.mactrackerapp.Mactracker' 'MultipleFindMyMac' -bool false
"
		end if
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
	
	set currentComputerName to "Free Geek - " & thisDriveName & " - Source"
	try
		set currentComputerName to (do shell script "scutil --get ComputerName")
	end try
	set intendedComputerName to ("Free Geek - " & thisDriveName & " - " & serialNumber)
	if (currentComputerName is not equal to intendedComputerName) then
		try
			set AppleScript's text item delimiters to ""
			set intendedLocalHostName to "FreeGeek-" & ((words of thisDriveName) as text) & "-" & serialNumber
			doShellScriptAsAdmin("
scutil --set ComputerName " & (quoted form of intendedComputerName) & "
scutil --set LocalHostName " & (quoted form of intendedLocalHostName))
		end try
	end if
	
	try
		tell current application to set volume output volume 0 with output muted -- Must "tell current application to set volume" when using AppKit framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 0
	end try
	
	set wirelessNetworkPasswordsToDelete to {}
	
	tell application id "com.apple.systemevents"
		try
			if ((name of startup disk) is not equal to thisDriveName) then
				tell me to doShellScriptAsAdmin("diskutil rename / " & (quoted form of thisDriveName))
				if (isCatalinaOrNewer) then tell me to doShellScriptAsAdmin("diskutil rename /System/Volumes/Data " & (quoted form of (thisDriveName & " - Data")))
			end if
		end try
		
		try
			set delay interval of screen saver preferences to 0
		end try
		
		try
			tell dock preferences to set autohide to false
		end try
		
		tell current desktop
			try
				((("/Users/" & adminUsername & "/Public/" & thisDriveName & " Desktop Picture.png") as POSIX file) as alias)
				set picture to ("/Users/" & adminUsername & "/Public/" & thisDriveName & " Desktop Picture.png")
			on error
				try
					(("/Library/Desktop Pictures/Solid Colors/Solid Aqua Blue.png" as POSIX file) as alias)
					set picture to "/Library/Desktop Pictures/Solid Colors/Solid Aqua Blue.png"
				on error
					try
						set picture to "/System/Library/Desktop Pictures/Solid Colors/Cyan.png"
					end try
				end try
			end try
		end tell
		
		try
			set AppleScript's text item delimiters to ""
			tell current location of network preferences
				repeat with thisActiveNetworkService in (every service whose active is true)
					if (((name of interface of thisActiveNetworkService) as text) is equal to "Wi-Fi") then
						set thisWiFiInterfaceID to ((id of interface of thisActiveNetworkService) as text)
						try
							set preferredWirelessNetworks to (paragraphs of (do shell script ("networksetup -listpreferredwirelessnetworks " & thisWiFiInterfaceID)))
							try
								set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & thisWiFiInterfaceID)
								set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
								if (getWiFiNetworkColonOffset > 0) then
									set (end of preferredWirelessNetworks) to (tab & (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput))
								else if (getWiFiNetworkOutput is equal to "You are not associated with an AirPort network.") then -- "networksetup -getairportnetwork" always returns "You are not associated with an AirPort network." on macOS 15 Sequoia (presuably because of privacy reasons), but the current Wi-Fi network is still available from "system_profiler SPAirPortDataType"
									set connectedWiFiNetworkName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:_items:0:spairport_airport_interfaces:0:spairport_current_network_information:_name' /dev/stdin <<< \"$(system_profiler -xml SPAirPortDataType)\" 2> /dev/null")))
									if (connectedWiFiNetworkName is not equal to "") then
										set (end of preferredWirelessNetworks) to (tab & connectedWiFiNetworkName)
									end if
								end if
							end try
							repeat with thisPreferredWirelessNetwork in preferredWirelessNetworks
								if (thisPreferredWirelessNetwork starts with tab) then
									set thisPreferredWirelessNetwork to ((characters 2 thru -1 of thisPreferredWirelessNetwork) as text)
									if ((thisPreferredWirelessNetwork is not equal to "FG Staff") and (thisPreferredWirelessNetwork is not equal to "Free Geek")) then
										try
											do shell script ("networksetup -setairportpower " & thisWiFiInterfaceID & " off")
										end try
										try
											tell me to doShellScriptAsAdmin("networksetup -removepreferredwirelessnetwork " & thisWiFiInterfaceID & " " & (quoted form of thisPreferredWirelessNetwork))
										end try
										set (end of wirelessNetworkPasswordsToDelete) to thisPreferredWirelessNetwork
									end if
								end if
							end repeat
						end try
						try
							do shell script ("networksetup -setairportpower " & thisWiFiInterfaceID & " on")
						end try
						try
							-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
							tell me to doShellScriptAsAdmin("networksetup -setairportnetwork " & thisWiFiInterfaceID & " 'FG Staff' " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]"))
						end try
					end if
				end repeat
			end tell
		end try
		
		try
			set the clipboard to ""
		end try
	end tell
	
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
	
	try
		do shell script "defaults delete eficheck; tccutil reset SystemPolicyAllFiles"
	end try
	
	try
		doShellScriptAsAdmin("rm -rf /private/var/db/softwareupdate/journal.plist " & ¬
			"'/Users/Shared/Relocated Items' " & ¬
			"'/Users/" & adminUsername & "/Library/Application Support/App Store/updatejournal.plist' " & ¬
			"/Users/" & adminUsername & "/Library/Preferences/ByHost/* " & ¬
			"/Users/" & adminUsername & "/.bash_history " & ¬
			"/Users/" & adminUsername & "/.bash_sessions " & ¬
			"/Users/" & adminUsername & "/.zsh_history " & ¬
			"/Users/" & adminUsername & "/.zsh_sessions " & ¬
			"/Users/" & adminUsername & "/_geeks3d_gputest_log.txt " & ¬
			"'/Users/" & adminUsername & "/Library/Application Support/keyboard-test'* " & ¬
			"'/Users/" & adminUsername & "/Desktop/QA Helper - Computer Specs.txt' " & ¬
			"'/Users/" & adminUsername & "/Desktop/Relocated Items'")
	end try
	
	try
		do shell script ("rm -rf '/Users/" & currentUsername & "/Library/Application Support/App Store/updatejournal.plist' " & ¬
			"/Users/" & currentUsername & "/Library/Preferences/ByHost/* " & ¬
			"/Users/" & currentUsername & "/.bash_history " & ¬
			"/Users/" & currentUsername & "/.bash_sessions " & ¬
			"/Users/" & currentUsername & "/.zsh_history " & ¬
			"/Users/" & currentUsername & "/.zsh_sessions " & ¬
			"/Users/" & currentUsername & "/_geeks3d_gputest_log.txt " & ¬
			"'/Users/" & currentUsername & "/Library/Application Support/keyboard-test'*")
	end try
	
	-- TRASH DESKTOP FILES WITH FINDER INSTEAD OF RM SO FOLDER ACCESS IS NOT NECESSARY ON CATALINA AND NEWER
	try
		with timeout of 5 seconds -- Timeout so that we don't wait if Finder prompts for permissions to trash a file/folder
			tell application id "com.apple.finder"
				try
					delete file ((("/Users/" & currentUsername & "/Desktop/QA Helper - Computer Specs.txt") as POSIX file) as alias)
				end try
				try
					delete folder ((("/Users/" & currentUsername & "/Desktop/Relocated Items") as POSIX file) as alias)
				end try
			end tell
		end timeout
	end try
	
	try
		tell application id "com.apple.finder"
			set warns before emptying of trash to false
			try
				empty the trash
			end try
			set warns before emptying of trash to true
		end tell
	end try
	
	-- DISABLE NOTIFICATIONS
	try
		do shell script "
defaults -currentHost write com.apple.notificationcenterui dndEnabledDisplayLock -bool true
defaults -currentHost write com.apple.notificationcenterui dndEnabledDisplaySleep -bool true
defaults -currentHost write com.apple.notificationcenterui dndMirroring -bool true
defaults -currentHost write com.apple.notificationcenterui dndEnd -float 1439
defaults -currentHost write com.apple.notificationcenterui dndStart -float 0
defaults -currentHost write com.apple.notificationcenterui doNotDisturb -bool false
killall usernoted
"
	end try
	try
		with timeout of 1 second
			tell application id "com.apple.notificationcenterui" to quit
		end timeout
	end try
	
	-- LOCK DOCK CONTENTS, SIZE, AND POSITION AND HIDE RECENTS IN DOCK ON MOJAVE OR NEWER
	set needToRelaunchDock to false
	repeat with thisDockImmutablePreferenceKey in {"contents", "size", "position"}
		set currentDockImmutableValue to "UNKNOWN"
		try
			set currentDockImmutableValue to (do shell script ("defaults read com.apple.dock " & thisDockImmutablePreferenceKey & "-immutable"))
		end try
		try
			if ((currentDockImmutableValue is not equal to "1")) then
				do shell script "defaults write com.apple.dock " & thisDockImmutablePreferenceKey & "-immutable -bool true"
				set needToRelaunchDock to true
			end if
		end try
	end repeat
	if (isMojaveOrNewer) then
		set currentShowRecentsInDock to "UNKNOWN"
		try
			set currentShowRecentsInDock to (do shell script "defaults read com.apple.dock show-recents")
		end try
		
		try
			if ((currentShowRecentsInDock is not equal to "0")) then
				do shell script "defaults write com.apple.dock show-recents -bool false"
				set needToRelaunchDock to true
			end if
		end try
	end if
	try
		if (needToRelaunchDock) then do shell script "killall Dock"
	end try
	
	try -- Mute volume again before key codes to be sure it's silent.
		tell current application to set volume output volume 0 with output muted -- Must "tell current application to set volume" when using AppKit framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 0
	end try
	
	try
		tell application id "com.apple.systemevents"
			-- Turn Brightness all the way up.
			repeat 50 times
				-- Undocumented key code to turn up brightness that works on 10.13+
				key code 144
			end repeat
		end tell
	end try
	
	try -- Mute volume again before key codes to be sure it's silent.
		tell current application to set volume output volume 0 with output muted -- Must "tell current application to set volume" when using AppKit framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 0
	end try
	
	try
		with timeout of 1 second
			tell application id "com.apple.KeyboardSetupAssistant" to quit
		end timeout
	end try
	
	try
		do shell script "diskutil apfs list | grep 'Yes (Locked)'" -- Grep will error if not found.
		
		try
			set securityAgentPath to "/System/Library/Frameworks/Security.framework/Versions/A/MachServices/SecurityAgent.bundle"
			set securityAgentID to (id of application securityAgentPath)
			repeat 60 times
				if (application securityAgentPath is running) then
					delay 1
					with timeout of 2 seconds -- Adding timeout to copy style of dismissing UserNotificationCenter for consistency.
						tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
							set frontmost to true
							key code 53 -- Cannot reliably get SecurityAgent windows, so if it's running (for decryption prompts) just hit escape until it quits (or until 60 seconds passes)
						end tell
					end timeout
				else
					exit repeat
				end if
			end repeat
		end try
	end try
	
	try
		if (application id "com.apple.UserNotificationCenter" is running) then
			repeat 60 times
				set clickedIgnoreCancelDontSendButton to false
				with timeout of 2 seconds -- Adding timeout because maybe this could be where things are getting hung sometimes.
					tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.UserNotificationCenter")
						repeat with thisUNCWindow in windows
							if ((count of buttons of thisUNCWindow) ≥ 2) then
								repeat with thisUNCButton in (buttons of thisUNCWindow)
									if ((title of thisUNCButton is "Ignore") or (title of thisUNCButton is "Cancel") or (title of thisUNCButton is "Don’t Send")) then
										click thisUNCButton
										set clickedIgnoreCancelDontSendButton to true
										exit repeat
									end if
								end repeat
							end if
						end repeat
					end tell
				end timeout
				if (not clickedIgnoreCancelDontSendButton) then exit repeat
				delay 0.5
			end repeat
		end if
	end try
	
	try
		if (application "/System/Library/CoreServices/backupd.bundle/Contents/Resources/TMHelperAgent.app" is running) then -- if application id "com.apple.TMHelperAgent" is used then compilation could fail if TMHelperAgent hasn't been run yet this boot.
			repeat 60 times
				set clickedDontUseButton to false
				with timeout of 2 seconds -- Adding timeout to copy style of dismissing UserNotificationCenter for consistency.
					tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.TMHelperAgent")
						repeat with thisTMHAWindow in windows
							if ((count of buttons of thisTMHAWindow) ≥ 2) then
								repeat with thisTMHAButton in (buttons of thisTMHAWindow)
									if (title of thisTMHAButton is "Don't Use") then
										click thisTMHAButton
										set clickedDontUseButton to true
										exit repeat
									end if
								end repeat
							end if
						end repeat
					end tell
				end timeout
				if (not clickedDontUseButton) then exit repeat
				delay 0.5
			end repeat
		end if
	end try
	
	if ((year of the (current date)) < 2023) then
		try
			doShellScriptAsAdmin("systemsetup -setusingnetworktime off; systemsetup -setusingnetworktime on")
		end try
	end if
	
	try -- Don't quit apps if "TESTING" flag folder exists on desktop
		((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	on error
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
	end try
	
	try
		-- Previous brightness key codes may end with a file on the Desktop selected, so clear it
		tell application id "com.apple.finder" to set selection to {} of desktop
	end try
	
	try
		tell current application to set volume output volume 75 without output muted -- Must "tell current application to set volume" when using AppKit framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 100
	end try
	
	try
		if ((do shell script "csrutil status") is not equal to "System Integrity Protection status: enabled.") then
			try
				activate
			end try
			display dialog "⚠️	System Integrity Protection (SIP) IS NOT enabled.   ⚠️


👉  System Integrity Protection (SIP) MUST be re-enabled.


🚫  DON'T TOUCH ANYTHING WHILE ENABLING SIP!  🚫


🔄  This Mac will reboot itself after SIP has been enabled." with title "SIP Must Be Enabled" buttons {"OK, Enable SIP"} default button 1 giving up after 15
			
			set progress description to "🚧	SIP is being enabled on this Mac…"
			set progress additional description to "
🚫  DON'T TOUCH ANYTHING WHILE ENABLING SIP!


🔄  This Mac will reboot itself after SIP has been enabled."
			
			delay 0.2 -- Delay to make sure progress gets updated.
			
			try
				doShellScriptAsAdmin("csrutil clear") -- "csrutil clear" can run from full macOS (Recovery is not required) but still needs a reboot to take affect.
			end try
			
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
			
			quit
			delay 10
		end if
	end try
	
	try
		(("/Applications/Breakaway.app" as POSIX file) as alias)
		if (application id ("com.mutablecode." & "breakaway") is not running) then do shell script "open -a '/Applications/Breakaway.app'" -- Break up App ID or else build will fail if not found during compilation when app is not installed.
	end try
	
	try
		if (freeGeekUpdaterExists) then
			(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- If just ran updater, then continue with launching next app. If not, we will launch updater. 
		end if
		
		set launchedFlagSpecifiedApp to false
		try
			((buildInfoPath as POSIX file) as alias)
			
			try
				set buildInfoFGflags to (paragraphs of (do shell script ("ls " & (quoted form of (buildInfoPath & ".fg")) & "*")))
				
				repeat with thisBuildInfoFGflag in buildInfoFGflags
					if (thisBuildInfoFGflag starts with (buildInfoPath & ".fgLaunchAfterSetup-")) then
						set thisLauncherFlagBundleId to (text 46 thru -1 of thisBuildInfoFGflag)
						set thisLauncherFlagContents to (do shell script "cat " & (quoted form of thisBuildInfoFGflag))
						
						if (thisLauncherFlagContents is equal to "") then -- If flag file is empty, delete it. If not, leave if for the specified app to read and then delete itself.
							try
								doShellScriptAsAdmin("rm -f " & (quoted form of thisBuildInfoFGflag))
							end try
						end if
						
						try
							if (thisLauncherFlagBundleId starts with "org.freegeek.") then
								set AppleScript's text item delimiters to space
								do shell script "open -na " & (quoted form of ("/Applications/" & ((words of (text 14 thru -1 of thisLauncherFlagBundleId)) as text) & ".app"))
							else
								do shell script "open -nb " & thisLauncherFlagBundleId
							end if
							set launchedFlagSpecifiedApp to true
						end try
					else -- Delete any other flag files (THIS IS WHERE ".fgSetupSkipped" WILL GET DELETED)
						try
							doShellScriptAsAdmin("rm -f " & (quoted form of thisBuildInfoFGflag))
						end try
					end if
				end repeat
			end try
			
			try
				do shell script (do shell script ("ls " & (quoted form of (buildInfoPath & ".fg")) & "*"))
			on error -- Only delete "Build Info" if no more .fg flag files are left.
				try
					doShellScriptAsAdmin("rm -rf " & (quoted form of buildInfoPath))
				end try
			end try
		end try
		
		if (not launchedFlagSpecifiedApp) then
			try
				do shell script "open -na '/Applications/Mac Scope.app'"
			end try
		end if
	on error
		try
			if (freeGeekUpdaterExists) then
				-- Wait for internet before launching Free Geek Updater to ensure that updates can be retrieved.
				repeat 60 times
					try
						do shell script "ping -c 1 www.google.com"
						exit repeat
					on error
						set progress additional description to "
📡	WAITING FOR INTERNET (Connect to Wi-Fi or Ethernet)…"
						delay 5
					end try
				end repeat
				
				do shell script ("open -na " & (quoted form of freeGeekUpdaterAppPath))
			end if
		end try
	end try
else
	activate
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Applications/” and run from the “Tester” user account." buttons {"Quit"} default button 1 as critical
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
	
	set currentDate to (current date)
	if ((lastDoShellScriptAsAdminAuthDate is equal to 0) or (currentDate ≥ (lastDoShellScriptAsAdminAuthDate + 270))) then -- 270 seconds = 4.5 minutes.
		set commandOutput to (do shell script command user name adminUsername password adminPassword with administrator privileges)
		set lastDoShellScriptAsAdminAuthDate to currentDate -- Set lastDoShellScriptAsAdminAuthDate to date *BEFORE* command was run since the command itself could have updated the date and the 5 minute timeout started when the command started, not when it finished.
	else
		set commandOutput to (do shell script command with prompt "This “" & (name of me) & "” password prompt should not have been displayed.

Please inform Free Geek I.T. that you saw this password prompt.

You can just press “Cancel” below to continue." with administrator privileges)
	end if
	
	return commandOutput
end doShellScriptAsAdmin

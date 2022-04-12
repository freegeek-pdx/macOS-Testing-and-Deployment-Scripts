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

-- Version: 2022.4.11-2

-- Build Flag: LSUIElement

use AppleScript version "2.7"
use scripting additions

set currentBundleIdentifier to "UNKNOWN"

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Free Geek Demo Helper" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
	
	-- demoUsername will be made an Admin and have it's Full Name changed temporarily during Automation Guide and will be changed back in Automation Guide.
	-- But still, double check here that it got reset to it's correct state (in case Automation Guide was force quit or something weird/sneaky).
	set demoUsernameIsAdmin to true
	try
		set demoUsernameIsAdmin to ((do shell script ("dsmemberutil checkmembership -U " & (quoted form of demoUsername) & " -G 'admin'")) is equal to "user is a member of the group")
	end try
	if (demoUsernameIsAdmin) then
		try
			do shell script "dseditgroup -o edit -d " & (quoted form of demoUsername) & " -t user admin" user name adminUsername password adminPassword with administrator privileges
		end try
	end if
	
	set demoUsernameIsCorrect to false
	try
		set demoUsernameIsCorrect to ((do shell script ("id -F " & (quoted form of demoUsername))) is equal to "Free Geek Demo User")
	end try
	if (not demoUsernameIsCorrect) then
		try
			do shell script "dscl . -create " & (quoted form of ("/Users/" & demoUsername)) & " RealName 'Free Geek Demo User'" user name adminUsername password adminPassword with administrator privileges
		end try
	end if
	
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
	
	
	try
		(((buildInfoPath & ".fgAutomationGuideRunning") as POSIX file) as alias)
		
		try
			do shell script ("touch " & (quoted form of (buildInfoPath & ".fgAutomationGuideDid-" & currentBundleIdentifier))) user name adminUsername password adminPassword with administrator privileges
		end try
		
		try
			(((buildInfoPath & ".fgAutomationGuideDid-org.freegeek.Cleanup-After-QA-Complete") as POSIX file) as alias)
			
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Setup.app'"
			end try
		on error
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/Cleanup After QA Complete.app"))
			end try
		end try
		
		quit
		delay 10
	end try
	
	
	set userLaunchAgentsPath to ((POSIX path of (path to library folder from user domain)) & "LaunchAgents/")
	set demoHelperLaunchAgentPlistName to "org.freegeek.Free-Geek-Demo-Helper.plist"
	set demoHelperLaunchAgentPlistPath to userLaunchAgentsPath & demoHelperLaunchAgentPlistName
	
	set qaCompleteHasRun to true
	try
		set cleanupAfterQACompleteDesktopPath to ("/Users/" & demoUsername & "/Desktop/Cleanup After QA Complete.app")
		((cleanupAfterQACompleteDesktopPath as POSIX file) as alias)
		set qaCompleteHasRun to false
		
		-- Touch desktop symlink to make sure icons stay correct (sometimes they go generic).
		try
			do shell script "touch -h " & (quoted form of ("/Users/" & demoUsername & "/Desktop/QA Helper.app")) & " " & (quoted form of cleanupAfterQACompleteDesktopPath)
		end try
		
		-- Set desktop app icon positions since they can lose their positions a restart.
		tell application "Finder"
			try
				set desktop position of alias file "QA Helper.app" of desktop to {100, 110}
			end try
			try
				set desktop position of alias file "Cleanup After QA Complete.app" of desktop to {250, 110}
			end try
		end tell
	end try
	
	set setupLaunchedDemoHelper to false
	try
		(((buildInfoPath & ".fgSetupLaunchedDemoHelper") as POSIX file) as alias)
		
		try -- If did all apps, delete all Automation Guide flags and continue setup
			do shell script ("rm -f " & (quoted form of (buildInfoPath & ".fgSetupLaunchedDemoHelper"))) user name adminUsername password adminPassword with administrator privileges
		end try
		
		set setupLaunchedDemoHelper to true
	end try
	
	set idleTime to 1800
	set upTenMinsOrLess to false
	
	if (not setupLaunchedDemoHelper) then
		try
			set idleTime to (((do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:HIDIdleTime' /dev/stdin <<< \"$(ioreg -arc IOHIDSystem -k HIDIdleTime -d 1)\""))) as number) / 1000 / 1000 / 1000)
		end try
		
		try
			set currentUnixTime to ((do shell script "date '+%s'") as number)
			set bootUnixTime to ((do shell script "sysctl -n kern.boottime | awk -F 'sec = |, usec' '{ print $2; exit }'") as number)
			set upTenMinsOrLess to (((currentUnixTime - bootUnixTime) / 60) ≤ 10)
		end try
	end if
	
	if (upTenMinsOrLess) then
		try
			(("/Users/Shared/.fg-snapshot-preserver" as POSIX file) as alias)
			
			-- If just booted, run fg-snapshot-preserver so that it can mount the reset Snapshot.
			-- fg-snapshot-preserver will have already run once very early on boot via global LaunchDaemon,
			-- but Free Geek Snapshot Helper would not have been able to mount the reset Snapshot during that run.
			-- Running here makes sure the reset Snapshot gets mounted as soon as possible (without needing to create a seperate LaunchAgent to run fg-snapshot-preserver on login as well).
			
			-- THIS IS NO LONGER REALLY NECESSARY SINCE fg-snapshot-preserver WILL NOW WAIT UNTIL LOGIN TO TRY TO RUN Free Geek Snapshot Helper AGAIN AS SOON AS POSSIBLE.
			-- BUT DOESN'T HURT TO CONTINUE LAUNCHING fg-snapshot-preserver HERE JUST IN CASE SINCE fg-snapshot-preserver WILL JUST EXIT IF ANOTHER INSTANCE IS ALREADY RUNNING.
			
			do shell script "/Users/Shared/.fg-snapshot-preserver/fg-snapshot-preserver.sh" user name adminUsername password adminPassword with administrator privileges
		end try
	end if
	
	if (setupLaunchedDemoHelper or upTenMinsOrLess or (idleTime ≥ 900)) then
		set modelID to "Mac"
		set serialNumber to "UNKNOWNSERIAL-" & (random number from 100 to 999)
		
		try
			set AppleScript's text item delimiters to ""
			set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
			set hardwareInfoPath to tmpPath & "hardwareInfo.plist"
			repeat 30 times
				try
					do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of hardwareInfoPath)
					tell application "System Events" to tell property list file hardwareInfoPath
						set hardwareItems to (first property list item of property list item "_items" of first property list item)
						set modelID to ((value of property list item "machine_model" of hardwareItems) as string)
						set serialNumber to ((value of property list item "serial_number" of hardwareItems) as string)
						if (serialNumber is equal to "Not Available") then
							try
								set serialNumber to ((value of property list item "riser_serial_number" of hardwareItems) as string)
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
		
		-- HIDE ADMIN USER
		try
			if ((do shell script ("dscl -plist . -read /Users/" & adminUsername & " IsHidden 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null; exit 0")) is not equal to "1") then
				do shell script ("dscl . -create /Users/" & adminUsername & " IsHidden 1") user name adminUsername password adminPassword with administrator privileges
			end if
		end try
		
		try
			do shell script "
# DISABLE SLEEP
pmset -a sleep 0 displaysleep 0

# SET GLOBAL LANGUAGE AND LOCALE
defaults write '/Library/Preferences/.GlobalPreferences' AppleLanguages -array 'en-US'
defaults write '/Library/Preferences/.GlobalPreferences' AppleLocale -string 'en_US'
defaults write '/Library/Preferences/.GlobalPreferences' AppleMeasurementUnits -string 'Inches'
defaults write '/Library/Preferences/.GlobalPreferences' AppleMetricUnits -bool false
defaults write '/Library/Preferences/.GlobalPreferences' AppleTemperatureUnit -string 'Fahrenheit'
defaults write '/Library/Preferences/.GlobalPreferences' AppleTextDirection -bool false
" user name adminUsername password adminPassword with administrator privileges
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
		
		-- DELETE ALL LOCAL SNAPSHOTS (ONLY IF reset Snapshot DOES NOT EXIST)
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
		on error
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
							do shell script ("tmutil deletelocalsnapshots " & (quoted form of (thisLocalSnapshot as string)))
						end try
					end repeat
				end try
			end if
		end try
		
		-- ENABLE NETWORK TIME
		-- Unless a reset Snapshot exists, in which case "fg-snapshot-preserver" will manage network time.
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
		on error
			try
				do shell script "systemsetup -setusingnetworktime on" user name adminUsername password adminPassword with administrator privileges
			end try
		end try
		
		-- SET MENUBAR CLOCK FORMAT
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
		
		-- DISABLE AUTOMATIC OS & APP STORE  UPDATES
		-- Keeping AutomaticCheckEnabled and AutomaticDownload enabled is required for EFIAllowListAll to be able to be updated when EFIcheck is run by our scripts, the rest should be disabled.
		try
			do shell script "
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticCheckEnabled -bool true
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticDownload -bool true
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' ConfigDataInstall -bool false
defaults write '/Library/Preferences/com.apple.SoftwareUpdate' CriticalUpdateInstall -bool false
defaults write '/Library/Preferences/com.apple.commerce' AutoUpdate -bool false
" user name adminUsername password adminPassword with administrator privileges
			if (isMojaveOrNewer) then
				do shell script "defaults write '/Library/Preferences/com.apple.SoftwareUpdate' AutomaticallyInstallMacOSUpdates -bool false" user name adminUsername password adminPassword with administrator privileges
			else
				do shell script "defaults write '/Library/Preferences/com.apple.commerce' AutoUpdateRestartRequired -bool false" user name adminUsername password adminPassword with administrator privileges
			end if
		end try
		
		-- DO NOT SHOW INTERNAL/BOOT DRIVE ON DESKTOP AND SET NEW FINDER WINDOWS TO COMPUTER
		tell application "Finder" to tell Finder preferences
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
				
				if (currentMouseButton is not equal to (buttonNumber as string)) then
					try
						do shell script ("defaults write com.apple.driver.AppleHIDMouse Button" & buttonNumber & " -int " & buttonNumber)
					end try
				end if
			end repeat
		end try
		
		-- HIDE ANY SYSTEM PREFERENCES BADGES FOR ANY UPDATES (such as Big Sur)
		try
			if ((do shell script "defaults read com.apple.systempreferences AttentionPrefBundleIDs") is not equal to "0") then
				do shell script "defaults write com.apple.systempreferences AttentionPrefBundleIDs 0; killall Dock"
			end if
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
			
			if ((currentHIToolboxAppleDictationAutoEnable is not equal to "0")) then
				do shell script "defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 0"
			end if
		end try
		
		-- REMOVE ALL SHARED FOLDERS & SHAREPOINT GROUPS
		try
			set sharedFolderNames to (do shell script "sharing -l | grep 'name:		' | cut -c 8-")
			repeat with thisSharedFolderName in (paragraphs of sharedFolderNames)
				try
					do shell script ("sharing -r " & (quoted form of thisSharedFolderName)) user name adminUsername password adminPassword with administrator privileges
				end try
			end repeat
		end try
		try
			set sharePointGroups to (do shell script "dscl . -list /Groups | grep com.apple.sharepoint.group")
			repeat with thisSharePointGroupName in (paragraphs of sharePointGroups)
				try
					do shell script ("dseditgroup -o delete " & (quoted form of thisSharePointGroupName)) user name adminUsername password adminPassword with administrator privileges
				end try
			end repeat
		end try
		
		set currentComputerName to "Free Geek - macOS - Production Restore"
		try
			set currentComputerName to (do shell script "scutil --get ComputerName")
		end try
		set intendedComputerName to "Free Geek - " & modelID & " - " & serialNumber
		if (currentComputerName is not equal to intendedComputerName) then
			try
				set newLocalHostName to "FreeGeek-" & modelID & "-" & serialNumber
				set AppleScript's text item delimiters to {",", space}
				set newLocalHostNameParts to (every text item of newLocalHostName)
				set AppleScript's text item delimiters to ""
				set newLocalHostName to (newLocalHostNameParts as string)
				do shell script ("
scutil --set ComputerName " & (quoted form of intendedComputerName) & "
scutil --set LocalHostName " & (quoted form of newLocalHostName)) user name adminUsername password adminPassword with administrator privileges
			end try
		end if
		
		try
			set volume output volume 0 with output muted
		end try
		try
			set volume alert volume 0
		end try
		
		set wirelessNetworkPasswordsToDelete to {}
		
		
		set desktopPicturesFolderPath to "/System/Library/Desktop Pictures/" -- Desktop Pictures location changed to this on Catalina and AppleScript fails to return it.
		try
			if (not isCatalinaOrNewer) then set desktopPicturesFolderPath to (POSIX path of (path to desktop pictures folder)) & "/"
		end try
		
		set dynamicDesktopPicture to "UNKNOWN"
		
		try
			(("/System/Library/CoreServices/DefaultDesktop.heic" as POSIX file) as alias)
			set dynamicDesktopPicture to (do shell script "readlink /System/Library/CoreServices/DefaultDesktop.heic")
			set desktopPicturesFolderPath to (POSIX path of ((((dynamicDesktopPicture as POSIX file) as alias) as text) & "::")) -- Get current desktopPicturesFolderPath for future-proofing.
		end try
		
		
		tell application "System Events"
			try
				set intendedDriveName to "Macintosh HD"
				set currentDriveName to (name of startup disk)
				if (currentDriveName is not equal to intendedDriveName) then
					do shell script "/usr/sbin/diskutil rename " & (quoted form of currentDriveName) & " " & (quoted form of intendedDriveName) user name adminUsername password adminPassword with administrator privileges
					if (isCatalinaOrNewer) then do shell script "/usr/sbin/diskutil rename " & (quoted form of (currentDriveName & " - Data")) & " " & (quoted form of (intendedDriveName & " - Data")) user name adminUsername password adminPassword with administrator privileges
				end if
			end try
			
			try
				if (running of screen saver preferences) then key code 53 -- simulate Escape key because "stop current screen saver" seems to not always work and doesn't reset the system idle time?
			end try
			
			try
				tell dock preferences to set autohide to false
			end try
			
			
			try
				tell current desktop
					try
						((desktopPicturesFolderPath as POSIX file) as alias)
						
						if (pictures folder is not desktopPicturesFolderPath) then set pictures folder to desktopPicturesFolderPath
						
						try
							if (dynamicDesktopPicture is equal to "UNKNOWN") then error "UNKNOWN dynamicDesktopPicture"
							((dynamicDesktopPicture as POSIX file) as alias)
							
							if (picture rotation is not 0) then set picture rotation to 0
							if (random order is true) then set random order to false
							if (picture is not dynamicDesktopPicture) then set picture to dynamicDesktopPicture
						on error
							if (picture rotation is not 1) then set picture rotation to 1
							if (random order is false) then set random order to true
						end try
						if (change interval is not 3600) then set change interval to 3600
					end try
				end tell
			end try
			
			try
				set AppleScript's text item delimiters to ""
				tell current location of network preferences
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
										if ((thisPreferredWirelessNetwork is not equal to "FG Reuse") and (thisPreferredWirelessNetwork is not equal to "Free Geek")) then
											try
												do shell script ("networksetup -setairportpower " & thisWiFiInterfaceID & " off")
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
								do shell script ("networksetup -setairportpower " & thisWiFiInterfaceID & " on")
							end try
							try
								if (qaCompleteHasRun) then
									-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
									do shell script "networksetup -setairportnetwork " & thisWiFiInterfaceID & " 'Free Geek'" user name adminUsername password adminPassword with administrator privileges
								else
									-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
									do shell script "networksetup -setairportnetwork " & thisWiFiInterfaceID & " 'FG Reuse' " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]") user name adminUsername password adminPassword with administrator privileges
								end if
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
				do shell script "security delete-generic-password -s 'AirPort' -l " & (quoted form of thisWirelessNetworkPasswordsToDelete) user name adminUsername password adminPassword with administrator privileges
			end try
		end repeat
		
		try
			do shell script "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport prefs RememberRecentNetworks=NO" user name adminUsername password adminPassword with administrator privileges
		end try
		
		try
			do shell script "defaults delete eficheck"
		end try
		
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
			-- DO NOT reset Full Disk Access if reset Snapshot exists since Snapshot Helper will have been granted Full Disk Access to mount the reset Snapshot.
		on error
			try
				(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
				-- ALSO do not reset Full Disk Access if Snapshot was lost so that we can see that Snapshot Helper not having Full Disk Access wasn't the issue.
			on error
				try
					do shell script "tccutil reset SystemPolicyAllFiles"
				end try
			end try
		end try
		
		try
			do shell script ("rm -rf /private/var/db/softwareupdate/journal.plist " & ¬
				"'/Users/Shared/Relocated Items' " & ¬
				"'/Users/" & adminUsername & "/Library/Application Support/App Store/updatejournal.plist' " & ¬
				"/Users/" & adminUsername & "/.bash_history " & ¬
				"/Users/" & adminUsername & "/.bash_sessions " & ¬
				"/Users/" & adminUsername & "/.zsh_history " & ¬
				"/Users/" & adminUsername & "/.zsh_sessions " & ¬
				"'/Users/" & adminUsername & "/Desktop/QA Helper - Computer Specs.txt' " & ¬
				"'/Users/" & adminUsername & "/Desktop/Relocated Items'") user name adminUsername password adminPassword with administrator privileges
		end try
		
		do shell script ("rm -rf '/Users/" & demoUsername & "/Library/Application Support/App Store/updatejournal.plist' " & ¬
			"/Users/" & demoUsername & "/.bash_history " & ¬
			"/Users/" & demoUsername & "/.bash_sessions " & ¬
			"/Users/" & demoUsername & "/.zsh_history " & ¬
			"/Users/" & demoUsername & "/.zsh_sessions")
		
		-- TRASH DESKTOP FILES WITH FINDER INSTEAD OF RM SO FOLDER ACCESS IS NOT NECESSARY ON CATALINA AND NEWER
		try
			with timeout of 5 seconds -- Timeout so that we don't wait if Finder prompts for permissions to trash a file/folder
				tell application "Finder"
					try
						delete file ((("/Users/" & demoUsername & "/Desktop/QA Helper - Computer Specs.txt") as POSIX file) as alias)
					end try
					try
						delete folder ((("/Users/" & demoUsername & "/Desktop/Relocated Items") as POSIX file) as alias)
					end try
				end tell
			end timeout
		end try
		
		try
			tell application "Finder"
				set warns before emptying of trash to false
				try
					empty the trash
				end try
				set warns before emptying of trash to true
			end tell
		end try
		
		try
			do shell script "chflags hidden /Applications/fgreset /Applications/memtest /Applications/memtest_osx" user name adminUsername password adminPassword with administrator privileges
		end try
		
		-- DISABLE NOTIFICATIONS
		if (isBigSurOrNewer) then
			try
				-- In macOS 11 Big Sur, the Do Not Distrub data is stored as binary of a plist within the "dnd_prefs" of "com.apple.ncprefs": 
				-- https://www.reddit.com/r/osx/comments/ksbmay/big_sur_how_to_test_do_not_disturb_status_in/gjb72av/?utm_source=reddit&utm_medium=web2x&context=3
				do shell script "defaults write com.apple.ncprefs dnd_prefs -data \"$(echo '<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>dndDisplayLock</key>
	<true/>
	<key>dndDisplaySleep</key>
	<true/>
	<key>dndMirrored</key>
	<true/>
	<key>facetimeCanBreakDND</key>
	<false/>
	<key>repeatedFacetimeCallsBreaksDND</key>
	<false/>
	<key>scheduledTime</key>
	<dict>
		<key>enabled</key>
		<true/>
		<key>end</key>
		<real>1439</real>
		<key>start</key>
		<real>0.0</real>
	</dict>
</dict>
</plist>' | plutil -convert binary1 - -o - | xxd -p | tr -d '[:space:]')\""
			end try
		else
			do shell script "
defaults -currentHost write com.apple.notificationcenterui dndEnabledDisplayLock -bool true
defaults -currentHost write com.apple.notificationcenterui dndEnabledDisplaySleep -bool true
defaults -currentHost write com.apple.notificationcenterui dndMirroring -bool true
defaults -currentHost write com.apple.notificationcenterui dndEnd -float 1439
defaults -currentHost write com.apple.notificationcenterui dndStart -float 0
defaults -currentHost write com.apple.notificationcenterui doNotDisturb -bool false
"
		end if
		try
			do shell script "killall usernoted"
		end try
		try
			with timeout of 1 second
				tell application "NotificationCenter" to quit
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
			set volume output volume 0 with output muted
		end try
		try
			set volume alert volume 0
		end try
		
		try
			tell application "System Events"
				-- Turn Brightness all the way up.
				repeat 50 times
					-- Undocumented key code to turn up brightness that works on 10.13+
					key code 144
				end repeat
			end tell
		end try
		
		try -- Mute volume again before key codes to be sure it's silent.
			set volume output volume 0 with output muted
		end try
		try
			set volume alert volume 0
		end try
		
		try
			if (application "/System/Library/CoreServices/KeyboardSetupAssistant.app" is running) then
				with timeout of 1 second
					tell application "KeyboardSetupAssistant" to quit
				end timeout
			end if
		end try
		
		try
			do shell script "diskutil apfs list | grep 'Yes (Locked)'" -- Grep will error if not found.
			
			try
				set securityAgentPath to "/System/Library/Frameworks/Security.framework/Versions/A/MachServices/SecurityAgent.bundle"
				repeat 60 times
					if (application securityAgentPath is running) then
						delay 1
						with timeout of 2 seconds -- Adding timeout to copy style of dismissing UserNotificationCenter for consistency.
							tell application "System Events" to tell application process "SecurityAgent"
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
			if (application "/System/Library/CoreServices/UserNotificationCenter.app" is running) then
				repeat 60 times
					set clickedIgnoreCancelDontSendButton to false
					with timeout of 2 seconds -- Adding timeout because maybe this could be where things are getting hung sometimes.
						tell application "System Events" to tell application process "UserNotificationCenter"
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
			if (application "/System/Library/CoreServices/backupd.bundle/Contents/Resources/TMHelperAgent.app" is running) then
				repeat 60 times
					set clickedDontUseButton to false
					with timeout of 2 seconds -- Adding timeout to copy style of dismissing UserNotificationCenter for consistency.
						tell application "System Events" to tell application process "TMHelperAgent"
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
		
		try
			-- If "loginwindow" has any windows open, it would be an erroneous scheduled shut down prompt since if the date is set back to a reset Snapshot date during boot,
			-- and then set back to actual time when a reset Snapshot is mounted, macOS triggers the shutdown schedule since it thinks the shutdown date has just passed.
			-- So, just click the Cancel button to dismiss this window and not shut down (the shut down schedule will still take effect when the actual time arrives).
			tell application "System Events" to tell application process "loginwindow"
				repeat with thisLoginwindowWindow in windows
					if ((count of buttons of thisLoginwindowWindow) ≥ 2) then
						repeat with thisLoginwindowButton in (buttons of thisLoginwindowWindow)
							if (title of thisLoginwindowButton is "Cancel") then
								click thisLoginwindowButton
								exit repeat
							end if
						end repeat
					end if
				end repeat
			end tell
		end try
		
		try
			(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
		on error
			if ((year of the (current date)) < 2022) then
				try
					do shell script "systemsetup -setusingnetworktime off; systemsetup -setusingnetworktime on" user name adminUsername password adminPassword with administrator privileges
				end try
			end if
		end try
		
		try
			-- Previous brightness key codes may end with a file on the Desktop selected, so clear it
			tell application "Finder" to set selection to {} of desktop
		end try
		
		try
			((demoHelperLaunchAgentPlistPath as POSIX file) as alias)
			
			try -- Don't quit apps if "TESTING" flag folder exists on desktop
				((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
			on error
				if (qaCompleteHasRun) then -- Only quit apps and if Setup has finished and installed the Demo Helper LaunchAgent and Cleanup After QA Complete has been run to help not interfere with initial setup possibilities.
					try
						tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Setup") and (short name is not "QA Helper") and (short name is not (name of me))))
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
								tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Setup") and (short name is not "QA Helper") and (short name is not (name of me))))
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
				end if
			end try
			
			
			-- Wait for internet before launching QA Helper to ensure that QA Helper can always update itself to the latest version.
			repeat 60 times
				try
					do shell script "ping -c 1 www.google.com"
					exit repeat
				on error
					try
						activate
					end try
					
					set linebreakOrNot to "
"
					set tabOrLinebreaks to "	"
					if (isBigSurOrNewer) then
						set linebreakOrNot to ""
						set tabOrLinebreaks to "

"
					end if
					
					try
						display alert (linebreakOrNot & "📡" & tabOrLinebreaks & "Waiting for Internet") message ("Connect to Wi-Fi or Ethernet…" & linebreakOrNot) buttons {"Continue Without Internet", "Try Again"} cancel button 1 default button 2 giving up after 5
					on error
						exit repeat
					end try
				end try
			end repeat
			
			try -- Only launch QA Helper if Setup has finished and installed the Demo Helper LaunchAgent to help not interfere with initial setup possibilities.
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." QA Helper has LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/QA Helper.app"))
			on error
				try
					set aboutThisMacAppPath to "/System/Library/CoreServices/Applications/About This Mac.app"
					((aboutThisMacAppPath as POSIX file) as alias)
					-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." In testing, this does not open a new instance of About This Mac even if it's already open.
					do shell script "open -n -a " & (quoted form of aboutThisMacAppPath)
				on error
					try
						tell application "System Events" to click menu item "About This Mac" of menu 1 of menu bar item "Apple" of menu bar 1 of application process "Finder"
					end try
				end try
			end try
		end try
	end if
	
	try
		(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
		((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
		
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
				tell application "System Events"
					if (running of screen saver preferences) then key code 53 -- If screen saver is active, simulate Escape key to end it.
				end tell
				
				delay 1
			end if
		end repeat
		
		tell application "System Events"
			try
				if (running of screen saver preferences) then key code 53 -- simulate Escape key because "stop current screen saver" seems to not always work and doesn't reset the system idle time?
			end try
			try
				set delay interval of screen saver preferences to 0
			end try
		end tell
		
		try
			tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Setup") and (short name is not (name of me))))
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
					tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Setup") and (short name is not (name of me))))
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
		
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script ("open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app'")
		end try
		
		quit
		delay 10
	end try
	
	if (qaCompleteHasRun) then
		try
			set volume output volume 50 without output muted
		end try
		try
			set volume alert volume 100
		end try
		try
			set isConnectedToInternet to false
			repeat 60 times
				try
					do shell script "ping -c 1 www.google.com"
					set isConnectedToInternet to true
					exit repeat
				on error
					try
						activate
					end try
					
					set linebreakOrNot to "
"
					set tabOrLinebreaks to "	"
					if (isBigSurOrNewer) then
						set linebreakOrNot to ""
						set tabOrLinebreaks to "

"
					end if
					
					try
						display alert (linebreakOrNot & "📡" & tabOrLinebreaks & "Waiting for Internet") message ("Connect to Wi-Fi or Ethernet…" & linebreakOrNot) buttons {"Continue Without Internet", "Try Again"} cancel button 1 default button 2 giving up after 5
					on error
						exit repeat
					end try
				end try
			end repeat
			
			set isOnFreeGeekNetwork to false
			if (isConnectedToInternet) then
				try
					tell application "System Events" to tell current location of network preferences
						repeat with thisActiveNetworkService in (every service whose active is true)
							if (((name of interface of thisActiveNetworkService) as string) is equal to "Wi-Fi") then
								try
									set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & ((id of interface of thisActiveNetworkService) as string))
									set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
									if (getWiFiNetworkColonOffset > 0) then
										set currentWiFiNetwork to (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput)
										set isOnFreeGeekNetwork to ((currentWiFiNetwork is equal to "Free Geek") or (currentWiFiNetwork is equal to "FG Reuse"))
										
										if (isOnFreeGeekNetwork) then exit repeat
									end if
								end try
							end if
						end repeat
					end tell
				end try
				
				if (not isOnFreeGeekNetwork) then
					try
						do shell script "ping -c 1 -t 5 data.fglan" -- Will error if not wired FG network.
						set isOnFreeGeekNetwork to true
					end try
				end if
			end if
			
			if (not isOnFreeGeekNetwork) then
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
						tell application "System Events"
							if (running of screen saver preferences) then key code 53 -- If screen saver is active, simulate Escape key to end it.
						end tell
						
						delay 1
					end if
				end repeat
				
				tell application "System Events"
					try
						if (running of screen saver preferences) then key code 53 -- simulate Escape key because "stop current screen saver" seems to not always work and doesn't reset the system idle time?
					end try
					try
						set delay interval of screen saver preferences to 0
					end try
				end tell
				
				try
					tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Setup") and (short name is not (name of me))))
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
							tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Free Geek Setup") and (short name is not (name of me))))
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
				
				try
					activate
				end try
				set contactFreeGeekDialogButton to "                                                 Shut Down                                                 "
				-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
				if (isCatalinaOrNewer) then set contactFreeGeekDialogButton to "Shut Down                                                                                                  "
				display dialog "PLEASE STOP AND CONTACT FREE GEEK TECH SUPPORT!
THIS MAC IS NOT READY FOR PERSONAL USE!

It appears you've purchased (or been granted) a Mac from Free Geek that was not reset to be ready for you to use.

This was our mistake, we apologize for the inconvenience.

This can be fixed over the phone, so you won't need to bring this Mac back to Free Geek.

	CONTACT FREE GEEK TECH SUPPORT
	Hours:	Tues - Sat @ 10am - 5:45pm
	Phone:	(503) 232-9350 extension 6
	Email:	support@freegeek.org


This Mac is currently set up with custom settings that are not ideal for personal use. A reset process must be run to remove these custom settings and prepare the Mac for you to create your own account.

If you save your personal information on this Mac before running the reset process, it will be permanently deleted once the reset is performed.

You should not use this Mac until you've contacted Free Geek so that we can guide you through running the reset process.

The reset process is only a few steps and will take less than 10 minutes." buttons {contactFreeGeekDialogButton} default button 1 with title (name of me) with icon dialogIconName
				
				tell application "System Events" to shut down with state saving preference
				
				quit
				delay 10
			end if
		end try
		
		set screenSaverRunning to false
		try
			tell application "System Events"
				if (running of screen saver preferences) then set screenSaverRunning to true
			end tell
		end try
		
		if ((not screenSaverRunning) or (idleTime ≥ 900)) then
			set shuffleScreenSaversList to {}
			set hasILifeSlideshows to false
			set photoFolders to {}
			
			tell application "System Events"
				repeat with thisScreenSaverName in (get name of screen savers)
					set thisScreenSaverName to (thisScreenSaverName as string)
					if (thisScreenSaverName is equal to "iLifeSlideshows") then
						set hasILifeSlideshows to true
					else if ((thisScreenSaverName is not equal to "FloatingMessage") and (thisScreenSaverName is not equal to "Computer Name") and (thisScreenSaverName is not equal to "iTunes Artwork") and (thisScreenSaverName is not equal to "Album Artwork") and (thisScreenSaverName is not equal to "Random") and (thisScreenSaverName is not equal to "screensaver.shuffle")) then
						set end of shuffleScreenSaversList to thisScreenSaverName
					end if
				end repeat
			end tell
			
			if (isCatalinaOrNewer and (not hasILifeSlideshows)) then
				try -- iLifeSlideshows does not show up in the System Events screen savers list on 10.15 Catalina, so check that the path exists and we will manually set the prefs below.
					(("/System/Library/Frameworks/ScreenSaver.framework/PlugIns/iLifeSlideshows.appex" as POSIX file) as alias)
					set hasILifeSlideshows to true
				end try
			end if
			
			tell application "Finder"
				try
					repeat with thisPhotoCollectionFolder in (get folders of (folder (("/Library/Screen Savers/Default Collections/" as POSIX file) as alias)))
						set end of photoFolders to (POSIX path of (thisPhotoCollectionFolder as string))
					end repeat
				on error (getPhotoCollectionsErrorMessage)
					try -- For Catalina
						repeat with thisPhotoCollectionFolder in (get folders of (folder (("/System/Library/Screen Savers/Default Collections/" as POSIX file) as alias)))
							set end of photoFolders to (POSIX path of (thisPhotoCollectionFolder as string))
						end repeat
					on error (getPhotoCollectionsErrorMessage)
						log getPhotoCollectionsErrorMessage
					end try
				end try
				try
					set desktopPicturesWithoutSolidColorsPath to ((POSIX path of (path to pictures folder)) & "Desktop Pics for Screen Saver")
					((desktopPicturesWithoutSolidColorsPath as POSIX file) as alias)
					set end of photoFolders to desktopPicturesWithoutSolidColorsPath
				on error (getDesktopPicturesWithoutSolidColorsErrorMessage)
					log getDesktopPicturesWithoutSolidColorsErrorMessage
					try
						set desktopPicturesPath to "/System/Library/Desktop Pictures/" -- Desktop Pictures location changed to this on Catalina and AppleScript fails to return it.
						try
							if (not isCatalinaOrNewer) then set desktopPicturesPath to (POSIX path of (path to desktop pictures folder)) & "/"
						end try
						((desktopPicturesPath as POSIX file) as alias)
						set end of photoFolders to desktopPicturesPath
					on error (getDesktopPicturesErrorMessage)
						log getDesktopPicturesErrorMessage
					end try
				end try
				try
					set freeGeekPromoPicsPath to ((POSIX path of (path to pictures folder)) & "Free Geek Promo Pics")
					((freeGeekPromoPicsPath as POSIX file) as alias)
					set end of photoFolders to freeGeekPromoPicsPath
				on error (getFreeGeekPromoPicsErrorMessage)
					log getFreeGeekPromoPicsErrorMessage
				end try
			end tell
			
			if (hasILifeSlideshows and ((count of photoFolders) > 0)) then
				repeat with thisSlideShowStyle in {"Floating", "Flipup", "Reflections", "Origami", "ShiftingTiles", "SlidingPanels", "PhotoMobile", "HolidayMobile", "PhotoWall", "VintagePrints", "KenBurns", "Classic"}
					set end of shuffleScreenSaversList to "iLifeSlideshows{iLS}" & thisSlideShowStyle
				end repeat
			end if
			
			if ((count of shuffleScreenSaversList) > 0) then
				tell application "System Events"
					if (running of screen saver preferences) then key code 53 -- simulate Escape key because "stop current screen saver" seems to not always work and doesn't reset the system idle time?
				end tell
				
				try
					set randomScreenSaverName to ((text item (random number from 1 to (count of shuffleScreenSaversList)) of shuffleScreenSaversList) as string)
					
					set AppleScript's text item delimiters to "{iLS}"
					set randomScreenSaverNameParts to (every text item of randomScreenSaverName)
					if ((count of randomScreenSaverNameParts) is equal to 2) then
						set randomScreenSaverName to (first item of randomScreenSaverNameParts)
						set iLifeSlideShowStyleKey to (item 2 of randomScreenSaverNameParts)
						
						set photoFolderPath to ((text item (random number from 1 to (count of photoFolders)) of photoFolders) as string)
						if ((last character of photoFolderPath) is equal to "/") then set photoFolderPath to (text 1 thru -2 of photoFolderPath)
						
						do shell script ("
defaults -currentHost write com.apple.ScreenSaverPhotoChooser ShufflesPhotos -bool YES
defaults -currentHost write com.apple.ScreenSaver.iLifeSlideShows styleKey " & (quoted form of iLifeSlideShowStyleKey) & "
defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedFolderPath " & (quoted form of photoFolderPath))
						
						set AppleScript's text item delimiters to "/"
						set photoFolderPathParts to (every text item of photoFolderPath)
						set photoFolderName to ((last text item of photoFolderPathParts) as string)
						set photoParentFolderName to ((text item -2 of photoFolderPathParts) as string)
						try
							if (photoParentFolderName is equal to "Default Collections") then
								do shell script "
defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedSource -int 3
defaults -currentHost delete com.apple.ScreenSaverPhotoChooser CustomFolderDict
"
							else
								do shell script "
defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedSource -int 4
defaults -currentHost write com.apple.ScreenSaverPhotoChooser CustomFolderDict '<dict>
	<key>name</key>
	<string>" & photoFolderName & "</string>
	<key>identifier</key>
	<string>" & photoFolderPath & "</string>
</dict>'
"
							end if
						end try
						try
							do shell script "defaults -currentHost delete com.apple.ScreenSaverPhotoChooser SelectedMediaGroup"
						end try
					end if
					
					try
						tell application "System Events"
							tell screen saver preferences
								if (running is true) then key code 53 -- make sure screen saver is stopped
								if (show clock is true) then set show clock to false
								if (delay interval is not 300) then set delay interval to 300
							end tell
							
							if (isCatalinaOrNewer and (randomScreenSaverName is equal to "iLifeSlideshows")) then
								-- For some reason iLifeSlideshows is not in the list of screen savers in Catalina and therefore cannot be set with AppleScript.
								-- So lets set the preferences manually.
								do shell script "
defaults -currentHost write com.apple.screensaver moduleDict '<dict>
	<key>moduleName</key>
	<string>iLifeSlideshows</string>
	<key>path</key>
	<string>/System/Library/Frameworks/ScreenSaver.framework/PlugIns/iLifeSlideshows.appex</string>
	<key>type</key>
	<string>0</string>
</dict>'
"
								set screenSaverDescription to randomScreenSaverName
							else
								set current screen saver to (screen saver named randomScreenSaverName)
								set screenSaverDescription to ((get name of current screen saver) as string)
							end if
							
							if (upTenMinsOrLess or (idleTime ≥ 900)) then
								set wasDarkMode to false
								try
									set wasDarkMode to (get dark mode of appearance preferences)
								end try
								try
									if ((random number from 0 to 1) is equal to 1) then
										tell appearance preferences to set dark mode to not dark mode
									end if
								end try
								try
									((("/Users/" & demoUsername & "/Applications/QA Helper.app") as POSIX file) as alias) -- Will error if QA Helper does not exist.
									
									if (wasDarkMode is not equal to (get dark mode of appearance preferences)) then
										-- Need to un-focus and then re-focus QA Helper for it to switch it's theme to the newly changed dark or light theme.
										try
											tell application "Finder" to activate
										end try
										try -- Instead of just activating QA Helper, re-launch it in case it was quit, which will also just activate it if it's already running.
											-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." QA Helper has LSMultipleInstancesProhibited to this will not actually ever open a new instance.
											do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/QA Helper.app"))
										end try
									end if
								end try
							end if
						end tell
						
						if (screenSaverDescription is equal to "iLifeSlideshows") then set screenSaverDescription to screenSaverDescription & " | " & iLifeSlideShowStyleKey & " | " & photoFolderName
						if (not isFreeGeekSystem) then
							display notification with title (name of me) subtitle screenSaverDescription
						end if
						return screenSaverDescription
					on error (setScreenSaverErrorMessage)
						log setScreenSaverErrorMessage
					end try
				on error (setRandomScreenSaverError)
					log setRandomScreenSaverError
				end try
			end if
		end if
	else
		try
			tell application "System Events" to set delay interval of screen saver preferences to 0
		end try
		
		try
			set volume output volume 75 without output muted
		end try
		try
			set volume alert volume 100
		end try
	end if
else
	try
		activate
	end try
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
end if

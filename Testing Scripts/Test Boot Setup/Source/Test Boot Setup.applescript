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

-- Version: 2022.4.7-1

-- Build Flag: LSUIElement

use AppleScript version "2.7"
use scripting additions
use framework "Cocoa"

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
		try
			tell application "System Events"
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
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as string))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as string)
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
	
	
	set thisDriveName to "Mac Test Boot"
	
	
	set adminUsername to "Staff"
	set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"
	
	set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
	
	
	try
		-- Quit if Updater is running (and did not just finish), since it will launch Setup when it's done.
		(("/Applications/Free Geek Updater.app" as POSIX file) as alias)
		if (application "/Applications/Free Geek Updater.app" is running) then
			try
				(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
			on error
				quit
				delay 10
			end try
		end if
	end try
	
	
	-- Always create ".fgSetupSkipped" on launch. It will be deleted when this app has finished a full run.
	try
		do shell script "mkdir " & (quoted form of buildInfoPath)
	end try
	try
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgSetupSkipped"))) user name adminUsername password adminPassword with administrator privileges
	end try
	
	-- Check if this is an old Mac Test Boot or Catalina Restore Boot drive an alert if so.
	
	set firmwareCheckerAppExists to false
	try
		(("/Applications/Firmware Checker.app" as POSIX file) as alias)
		set firmwareCheckerAppExists to true
	on error
		try
			do shell script "defaults read com.apple.dock persistent-apps | grep -q Firmware-Checker"
			set firmwareCheckerAppExists to true
		end try
	end try
	
	try
		(("/Users/Shared/OS Updates" as POSIX file) as alias)
		set firmwareCheckerAppExists to true
		
		try -- Delete old OS Updates if they exist.
			do shell script "rm -rf '/Users/Shared/OS Updates'" user name adminUsername password adminPassword with administrator privileges
		end try
	end try
	
	set restoreOSappExists to false
	try
		(("/Applications/Restore OS.app" as POSIX file) as alias)
		set restoreOSappExists to true
	on error
		try
			do shell script "defaults read com.apple.dock persistent-apps | grep -q Restore-OS"
			set restoreOSappExists to true
		end try
	end try
	
	try
		(("/Users/Shared/Restore OS Images" as POSIX file) as alias)
		set restoreOSappExists to true
		
		try -- Delete old Restore OS Images if they exist.
			do shell script "rm -rf '/Users/Shared/Restore OS Images'" user name adminUsername password adminPassword with administrator privileges
		end try
	end try
	
	if (firmwareCheckerAppExists or restoreOSappExists) then
		try
			activate
		end try
		try
			do shell script "afplay /System/Library/Sounds/Basso.aiff"
		end try
		display alert ("
This " & thisDriveName & " Drive Is Outdated") message ("Deliver this " & thisDriveName & " drive to Free Geek I.T.
") buttons {"Shut Down"} as critical
		
		tell application "System Events" to shut down with state saving preference
		
		quit
		delay 10
	end if
	
	try
		(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- Do not offer to skip if just finished running Updater (since Setup already offered to skip before launching Updater.).
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
				if (((thisWindow's title()) as string) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as string) is equal to "NSProgressIndicator") then
							(thisWindow's setLevel:(current application's NSScreenSaverWindowLevel))
						else if (((thisProgressWindowSubView's className()) as string) is equal to "NSButton" and ((thisProgressWindowSubView's title() as string) is equal to "Stop")) then
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
		tell application "System Events" to delete login item (name of me)
	end try
	
	set userLaunchAgentsPath to ((POSIX path of (path to library folder from user domain)) & "LaunchAgents/")
	
	set testBootSetupLaunchAgentPlistName to "org.freegeek.Test-Boot-Setup.plist"
	set testBootSetupUserLaunchAgentPlistPath to (userLaunchAgentsPath & testBootSetupLaunchAgentPlistName)
	
	try
		((userLaunchAgentsPath as POSIX file) as alias)
	on error
		try
			tell application "Finder" to make new folder at (path to library folder from user domain) with properties {name:"LaunchAgents"}
		end try
	end try
	
	set testBootSetupUserLaunchAgentPlistContents to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>Label</key>
	<string>org.freegeek.Test-Boot-Setup</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-n</string>
		<string>-a</string>
		<string>/Applications/Test Boot Setup.app</string>
	</array>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>"
	set needsToWriteTestBootSetupUserLaunchAgentPlistFile to false
	try
		((testBootSetupUserLaunchAgentPlistPath as POSIX file) as alias)
		set currentTestBootSetupUserLaunchAgentPlistContents to (read (testBootSetupUserLaunchAgentPlistPath as POSIX file))
		if (currentTestBootSetupUserLaunchAgentPlistContents is not equal to testBootSetupUserLaunchAgentPlistContents) then
			set needsToWriteTestBootSetupUserLaunchAgentPlistFile to true
			try
				do shell script "launchctl unload " & (quoted form of testBootSetupUserLaunchAgentPlistPath)
			end try
		end if
	on error
		set needsToWriteTestBootSetupUserLaunchAgentPlistFile to true
		try
			tell application "Finder" to make new file at (userLaunchAgentsPath as POSIX file) with properties {name:testBootSetupLaunchAgentPlistName}
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
			do shell script "launchctl load " & (quoted form of testBootSetupUserLaunchAgentPlistPath)
		end try
	end if
	
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
	
	set startupDiskCapacity to 0
	try
		tell application "System Events" to set startupDiskCapacity to ((capacity of startup disk) as number)
	end try
	if ((startupDiskCapacity ≤ 3.3E+10) and (serialNumber is equal to "C02R49Y5G8WP")) then
		set serialNumber to "Source" -- Don't include any computer serial number for the source drive.
		
		-- Run EFIcheck if on source drive to keep the AllowList up-to-date.
		try
			do shell script "defaults delete eficheck"
		end try
		try
			set efiCheckPID to (do shell script "/usr/libexec/firmwarecheckers/eficheck/eficheck --integrity-check > /dev/null 2>&1 & echo $!" user name adminUsername password adminPassword with administrator privileges)
			delay 1
			set efiCheckIsRunning to ((do shell script ("ps -p " & efiCheckPID & " > /dev/null 2>&1; echo $?")) as number)
			if (efiCheckIsRunning is equal to 0) then
				repeat
					try -- EFIcheck may open UserNotificationCenter with a "Your computer has detected a potential problem" alert if EFI Firmware is out-of-date.
						if (application "/System/Library/CoreServices/UserNotificationCenter.app" is running) then
							tell application "System Events" to tell application process "UserNotificationCenter"
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
			do shell script "nvram EnableTRIM" user name adminUsername password adminPassword with administrator privileges -- This will error if the flag does not exist.
		on error
			try -- Clear NVRAM if we're not on the source drive (just for house cleaning purposes, this doesn't clear SIP).
				do shell script "nvram -c" user name adminUsername password adminPassword with administrator privileges
			end try
		end try
	end if
	
	-- HIDE ADMIN USER
	try
		if ((do shell script ("dscl -plist . -read /Users/" & adminUsername & " IsHidden | xmllint --xpath '//string[1]/text()' -; exit 0")) is not equal to "1") then
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
					do shell script ("tmutil deletelocalsnapshots " & (quoted form of (thisLocalSnapshot as string)))
				end try
			end repeat
		end try
	end if
	
	-- ENABLE NETWORK TIME AND SET MENUBAR CLOCK FORMAT
	try
		do shell script "systemsetup -setusingnetworktime on" user name adminUsername password adminPassword with administrator privileges
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
	
	set currentComputerName to "Free Geek - " & thisDriveName & " - Source"
	try
		set currentComputerName to (do shell script "scutil --get ComputerName")
	end try
	set intendedComputerName to ("Free Geek - " & thisDriveName & " - " & serialNumber)
	if (currentComputerName is not equal to intendedComputerName) then
		try
			set AppleScript's text item delimiters to ""
			set intendedLocalHostName to "FreeGeek-" & ((words of thisDriveName) as string) & "-" & serialNumber
			do shell script ("
scutil --set ComputerName " & (quoted form of intendedComputerName) & "
scutil --set LocalHostName " & (quoted form of intendedLocalHostName)) user name adminUsername password adminPassword with administrator privileges
		end try
	end if
	
	try
		tell current application to set volume output volume 0 with output muted -- Must "tell current application to set volume" when using Cocoa framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 0
	end try
	
	set wirelessNetworkPasswordsToDelete to {}
	
	tell application "System Events"
		try
			set currentDriveName to (name of startup disk)
			if (currentDriveName is not equal to thisDriveName) then
				do shell script "/usr/sbin/diskutil rename " & (quoted form of currentDriveName) & " " & (quoted form of thisDriveName) user name adminUsername password adminPassword with administrator privileges
				if (isCatalinaOrNewer) then do shell script "/usr/sbin/diskutil rename " & (quoted form of (currentDriveName & " - Data")) & " " & (quoted form of (thisDriveName & " - Data")) user name adminUsername password adminPassword with administrator privileges
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
							-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
							do shell script "networksetup -setairportnetwork " & thisWiFiInterfaceID & " 'FG Reuse' " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]") user name adminUsername password adminPassword with administrator privileges
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
	
	do shell script "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport prefs RememberRecentNetworks=NO" user name adminUsername password adminPassword with administrator privileges
	
	try
		do shell script "defaults delete eficheck; tccutil reset SystemPolicyAllFiles"
	end try
	
	try
		do shell script ("rm -rf /private/var/db/softwareupdate/journal.plist " & ¬
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
			"'/Users/" & adminUsername & "/Desktop/Relocated Items'") user name adminUsername password adminPassword with administrator privileges
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
			tell application "Finder"
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
		tell application "Finder"
			set warns before emptying of trash to false
			try
				empty the trash
			end try
			set warns before emptying of trash to true
		end tell
	end try
	
	try
		do shell script "chflags hidden /Applications/memtest" user name adminUsername password adminPassword with administrator privileges
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
		tell current application to set volume output volume 0 with output muted -- Must "tell current application to set volume" when using Cocoa framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 0
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
		tell current application to set volume output volume 0 with output muted -- Must "tell current application to set volume" when using Cocoa framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 0
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
	
	if ((year of the (current date)) < 2022) then
		try
			do shell script "systemsetup -setusingnetworktime off; systemsetup -setusingnetworktime on" user name adminUsername password adminPassword with administrator privileges
		end try
	end if
	
	try -- Don't quit apps if "TESTING" flag folder exists on desktop
		((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	on error
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
	end try
	
	try
		-- Previous brightness key codes may end with a file on the Desktop selected, so clear it
		tell application "Finder" to set selection to {} of desktop
	end try
	
	try
		tell current application to set volume output volume 75 without output muted -- Must "tell current application to set volume" when using Cocoa framework to avoid a bug.
	end try
	try
		tell current application to set volume alert volume 100
	end try
	
	try
		if ((do shell script "csrutil status") is not equal to "System Integrity Protection status: enabled.") then
			try
				try
					repeat with thisWindow in (current application's NSApp's |windows|())
						if (thisWindow's isVisible() is true) then
							if (((thisWindow's title()) as string) is equal to (name of me)) then
								repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
									if (((thisProgressWindowSubView's className()) as string) is equal to "NSProgressIndicator") then
										(thisWindow's setIsVisible:false)
										
										exit repeat
									end if
								end repeat
							end if
						end if
					end repeat
				end try
				try
					activate
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff"
				end try
				set rebootDialogButton to "        Reboot Now        "
				-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
				if (isCatalinaOrNewer) then set rebootDialogButton to "Reboot Now                "
				display dialog "⚠️	System Integrity Protection IS NOT Enabled


‼️	System Integrity Protection (SIP) MUST be re-enabled.

❌	This Mac will not be sellable until SIP is enabled.

👉	The SIP setting is stored in NVRAM.

🔄	To re-enable it, all you need to do is
	reset the NVRAM by holding the
	“Option+Command+P+R” key combo
	while rebooting this Mac." buttons {"Continue without Enabling SIP", rebootDialogButton} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				
				try
					activate
				end try
				display dialog "‼️	Remember to hold the
	“Option+Command+P+R” key combo
	while this Mac reboots
	until you hear at least 2 startup sounds.


🔄	This Mac will reboot in 15 seconds…" buttons "Reboot Now" default button 1 with title (name of me) with icon dialogIconName giving up after 15
				
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
				
				quit
				delay 10
			end try
		end if
	end try
	
	try
		(("/Applications/Breakaway.app" as POSIX file) as alias)
		if (application ("Break" & "away") is not running) then do shell script "open -a '/Applications/Breakaway.app'"
	end try
	
	set freeGeekUpdaterExists to false
	try
		(("/Applications/Free Geek Updater.app" as POSIX file) as alias)
		set freeGeekUpdaterExists to true
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
								do shell script ("rm -f " & (quoted form of thisBuildInfoFGflag)) user name adminUsername password adminPassword with administrator privileges
							end try
						end if
						
						try
							if (thisLauncherFlagBundleId starts with "org.freegeek.") then
								set AppleScript's text item delimiters to space
								do shell script "open -n -a " & (quoted form of ("/Applications/" & ((words of (text 14 thru -1 of thisLauncherFlagBundleId)) as string) & ".app"))
							else
								do shell script "open -n -b " & thisLauncherFlagBundleId
							end if
							set launchedFlagSpecifiedApp to true
						end try
					else -- Delete any other flag files (THIS IS WHERE ".fgSetupSkipped" WILL GET DELETED)
						try
							do shell script ("rm -f " & (quoted form of thisBuildInfoFGflag)) user name adminUsername password adminPassword with administrator privileges
						end try
					end if
				end repeat
			end try
			
			try
				do shell script (do shell script ("ls " & (quoted form of (buildInfoPath & ".fg")) & "*"))
			on error -- Only delete "Build Info" if no more .fg flag files are left.
				try
					do shell script ("rm -rf " & (quoted form of buildInfoPath)) user name adminUsername password adminPassword with administrator privileges
				end try
			end try
		end try
		
		if (not launchedFlagSpecifiedApp) then
			try
				do shell script "open -n -a '/Applications/Mac Scope.app'"
			on error
				try
					do shell script "open -n -a '/Applications/Firmware Checker.app'"
				on error
					try
						do shell script "open -n -a '/Applications/Restore OS.app'"
					end try
				end try
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
				
				do shell script "open -n -a '/Applications/Free Geek Updater.app'"
			end if
		end try
	end try
else
	activate
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Applications/” and run from the “Tester” or “restorer” user accounts." buttons {"Quit"} default button 1 as critical
end if

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

-- Version: 2025.10.27-1

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
		delay 1
	end if
end repeat

set currentBundleIdentifier to "UNKNOWN"

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Free Geek Setup" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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


global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate, tmpPath -- Needs to be accessible in checkEFIfirmwareIsNotInAllowList function and later in code and in the doShellScriptAsAdmin function.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"
set demoPassword to "freegeek"


set AppleScript's text item delimiters to ""
set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.


if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
	
	set freeGeekUpdaterAppPath to ("/Users/" & demoUsername & "/Applications/Free Geek Updater.app")
	try
		((freeGeekUpdaterAppPath as POSIX file) as alias)
		
		if (application freeGeekUpdaterAppPath is running) then -- Quit if Updater is running (and did not just finish) so that this app can be updated if needed.
			try
				(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- If Updater just finished, continue even if it's still running since it launches Setup when it's done.
			on error
				quit
				delay 10
			end try
		end if
	end try
	
	set systemVersion to (system version of (system info))
	set osName to ("macOS " & systemVersion)
	considering numeric strings
		set isHighSierraOrNewer to (systemVersion ≥ "10.13")
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
		set isBigSurElevenDotThreeOrNewer to (systemVersion ≥ "11.3") -- For "nvram -c" on Apple Silicon
		set isMontereyOrNewer to (systemVersion ≥ "12.0")
		set isVenturaOrNewer to (systemVersion ≥ "13.0")
		set isVenturaThirteenDotThreeOrNewer to (systemVersion ≥ "13.3")
		set isSonomaOrNewer to (systemVersion ≥ "14.0")
		set isSequoiaOrNewer to (systemVersion ≥ "15.0")
		set isTahoeOrNewer to (systemVersion ≥ "16.0")
		
		if (isHighSierraOrNewer and (not isMojaveOrNewer)) then
			set osName to "macOS 10.13 High Sierra"
		else if (isMojaveOrNewer and (not isCatalinaOrNewer)) then
			set osName to "macOS 10.14 Mojave"
		else if (isCatalinaOrNewer and (not isBigSurOrNewer)) then
			set osName to "macOS 10.15 Catalina"
		else if (isBigSurOrNewer and (not isMontereyOrNewer)) then
			set osName to "macOS 11 Big Sur"
		else if (isMontereyOrNewer and (not isVenturaOrNewer)) then
			set osName to "macOS 12 Monterey"
		else if (isVenturaOrNewer and (not isSonomaOrNewer)) then
			set osName to "macOS 13 Ventura"
		else if (isSonomaOrNewer and (not isSequoiaOrNewer)) then
			set osName to "macOS 14 Sonoma"
		else if (isSequoiaOrNewer and (not isTahoeOrNewer)) then
			set osName to "macOS 15 Sequoia"
		else if (isTahoeOrNewer and (systemVersion < "27.0")) then
			set osName to "macOS 26 Tahoe"
		end if
	end considering
	
	try
		activate
	end try
	
	if (isTahoeOrNewer) then
		-- There is a bug in macOS 26 Tahoe where setting indeterminate progress at launch just displays 0 progress, EVEN IF manually running startAnimation on the NSProgressIndicator directly.
		-- To workaround this, first set determinate progress, then delay 0.01s to make sure the UI updates (without a delay the progress bar occasionally still doesn't animate), then set indeterminate progress, and THEN STILL startAnimation on the NSProgressIndicator directly.
		
		set progress total steps to 1
	else
		set progress total steps to -1
	end if
	
	set progress completed steps to 0
	set progress description to "🚧	" & (name of me) & " is Preparing " & osName & "…"
	set progress additional description to "
🚫	DO NOT TOUCH THIS MAC WHILE IT IS BEING SET UP"
	
	set progressWindowProgressBar to missing value
	
	try
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as text) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as text) is equal to "NSProgressIndicator") then
							set progressWindowProgressBar to thisProgressWindowSubView
						else if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Stop")) then
							(thisProgressWindowSubView's setEnabled:false)
						end if
					end repeat
				end if
			end if
		end repeat
	end try
	
	if (isTahoeOrNewer) then -- See comments above about macOS 26 Tahoe bug when setting indeterminate progress at launch.
		delay 0.01
		
		set progress total steps to -1
		
		try
			if (progressWindowProgressBar is not equal to missing value) then
				(progressWindowProgressBar's startAnimation:(missing value))
			end if
		end try
	end if
	
	try
		(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
	on error
		try
			(((buildInfoPath & ".fgSetupJustGrantedUserTCC") as POSIX file) as alias)
		on error
			delay 3 -- Add some delay so system stuff can get going on login. (Don't delay again if re-launched after Free Geek Updater or setting User TCC just finished.)
		end try
	end try
	
	-- Do a few important things right off the bat to be sure they are done immediately on first boot EVEN THOUGH "Free Geek Demo Helper" will also set them again later.
	
	-- CLOSE KEYBOARD SETUP APP IF IT'S OPEN
	try
		with timeout of 1 second
			tell application id "com.apple.KeyboardSetupAssistant" to quit
		end timeout
	end try
	
	if (isTahoeOrNewer) then
		-- On first boot of macOS 26 Tahoe, it seems to take a while for the Dock and desktop background become visible and the system to be fully ready and settled (unlike previous versions of macOS).
		-- So, wait for Dock Extra XPC service to launch before continuing (NOT just Dock which launches early even though it won't be visible).
		-- The Dock Extra XPC service seems to load during/after the Dock and desktop background become visible and CPU usage settles down.
		
		try
			set dockExtraXPCServicePath to "/System/Library/CoreServices/Dock.app/Contents/XPCServices/com.apple.dock.extra.xpc/Contents/MacOS/com.apple.dock.extra"
			((dockExtraXPCServicePath as POSIX file) as alias) -- Make sure file exists to not infinite loop if changes in the future.
			repeat until (application dockExtraXPCServicePath is running)
				delay 1
			end repeat
		end try
	end if
	
	-- TURN OFF SCREEN LOCK (Check for Mojave or newer since that is when the "sysadminctl -screenLock off" command was added.)
	if (isMojaveOrNewer) then
		try
			do shell script "printf '%s' " & (quoted form of demoPassword) & " | sysadminctl -screenLock off -password -"
		end try
	end if
	
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
	
	try
		(("/Users/Shared/.fgResetSnapshotLost" as POSIX file) as alias)
		((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
		
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited so this will not actually ever open a new instance.
			do shell script ("open -na '/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app'")
		end try
		
		quit
		delay 10
	end try
	
	set didJustUpdate to false
	try
		(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- If just ran updater, then continue with TCC setup etc. If not, we will launch updater.
		set didJustUpdate to true
		try
			doShellScriptAsAdmin("rm -f " & (quoted form of (buildInfoPath & ".fgUpdater")) & "*")
		end try
	end try
	
	set didJustGrantUserTCC to false
	try
		(((buildInfoPath & ".fgSetupJustGrantedUserTCC") as POSIX file) as alias)
		set didJustGrantUserTCC to true
		try
			doShellScriptAsAdmin("rm -f " & (quoted form of (buildInfoPath & ".fgSetupJustGrantedUserTCC")))
		end try
	end try
	
	if ((not didJustUpdate) and (not didJustGrantUserTCC)) then -- Do not update again if just updated or re-launching after granting TCC.
		try
			((freeGeekUpdaterAppPath as POSIX file) as alias)
			
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
			
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited so this will not actually ever open a new instance.
				do shell script ("open -na " & (quoted form of freeGeekUpdaterAppPath))
			end try
			
			quit
			delay 10
		end try
	end if
	
	set hasT2chip to false
	try
		set hasT2chip to ((do shell script "ioreg -rn 'Apple T2 Controller' -d 1") contains "Apple T2 Controller")
	end try
	
	set isAppleSilicon to false
	try
		set isAppleSilicon to ((do shell script "sysctl -in hw.optional.arm64") is equal to "1")
	end try
	
	try
		set globalTCCdbPath to "/Library/Application Support/com.apple.TCC/TCC.db" -- For more info about the TCC.db structure, see "fg-install-os" script and https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive
		set whereAllowedOrAuthValue to "allowed = 1"
		if (isBigSurOrNewer) then set whereAllowedOrAuthValue to "auth_value = 2"
		set globalTCCallowedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of globalTCCdbPath) & " 'SELECT client,service FROM access WHERE (" & whereAllowedOrAuthValue & ")'"))) -- This SELECT command on the global TCC.db will error if "Free Geek Setup" doesn't have Full Disk Access.
		
		set bundleIDofFreeGeekSetupApp to currentBundleIdentifier
		set bundleIDofFreeGeekUpdaterApp to "org.freegeek.Free-Geek-Updater"
		set bundleIDofFreeGeekSnapshotHelperApp to "org.freegeek.Free-Geek-Snapshot-Helper"
		set bundleIDofFreeGeekDemoHelperApp to "org.freegeek.Free-Geek-Demo-Helper"
		set bundleIDofFreeGeekTaskRunnerApp to "org.freegeek.Free-Geek-Task-Runner"
		set bundleIDofCleanupAfterQACompleteApp to "org.freegeek.Cleanup-After-QA-Complete"
		set bundleIDofFreeGeekResetApp to "org.freegeek.Free-Geek-Reset"
		
		if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekSetupApp & "|kTCCServiceAccessibility")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Accessibility Access")
		if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekDemoHelperApp & "|kTCCServiceAccessibility")) then error "“Free Geek Demo Helper” DOES NOT HAVE REQUIRED Accessibility Access"
		if (globalTCCallowedAppsAndServices does not contain (bundleIDofCleanupAfterQACompleteApp & "|kTCCServiceAccessibility")) then error "“Cleanup After QA Complete” DOES NOT HAVE REQUIRED Accessibility Access"
		
		if (isMojaveOrNewer) then
			-- Full Disk Access was introduced in macOS 10.14 Mojave.
			if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekSetupApp & "|kTCCServiceSystemPolicyAllFiles")) then error ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Full Disk Access") -- This should not be possible to hit since reading the global TCC.db would have errored if this app didn't have FDA, but check anyways.
			if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekDemoHelperApp & "|kTCCServiceSystemPolicyAllFiles")) then error "“Free Geek Demo Helper” DOES NOT HAVE REQUIRED Full Disk Access"
			if (globalTCCallowedAppsAndServices does not contain (bundleIDofCleanupAfterQACompleteApp & "|kTCCServiceSystemPolicyAllFiles")) then error "“Cleanup After QA Complete” DOES NOT HAVE REQUIRED Full Disk Access"
			
			set taskRunnerIsInstalled to false
			try
				((("/Users/" & demoUsername & "/Applications/Free Geek Task Runner.app") as POSIX file) as alias)
				set taskRunnerIsInstalled to true -- MUST NOT check TCC permissions in this "try" since the "error" would get caught instead of being thrown to the parent "try".
			end try
			
			if (taskRunnerIsInstalled) then
				-- "Free Geek Task Runner" may not be installed if "Free Geek Setup" is updated on an installation prior to 10/17/25 when "Free Geek Task Runner" was first added.
				-- This could happen if an old installation was set aside becuase it was Remote Managed, and then rebooted later to check Remote Management again.
				
				if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekTaskRunnerApp & "|kTCCServiceSystemPolicyAllFiles")) then error "“Free Geek Task Runner” DOES NOT HAVE REQUIRED Full Disk Access"
			end if
			
			set snapshotHelperIsInstalled to false
			try
				((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
				set snapshotHelperIsInstalled to true -- MUST NOT check TCC permissions in this "try" since the "error" would get caught instead of being thrown to the parent "try".
			end try
			
			set freeGeekResetIsInstalled to false
			try
				((("/Users/" & demoUsername & "/Applications/Free Geek Reset.app") as POSIX file) as alias)
				set freeGeekResetIsInstalled to true -- MUST NOT check TCC permissions in this "try" since the "error" would get caught instead of being thrown to the parent "try".
			end try
			
			if (snapshotHelperIsInstalled) then
				-- "Free Geek Snapshot Helper" will be installed on macOS 10.15 Catalina and newer unless the Mac is not a T2 or Apple Silicon and running macOS 12 Monterey or newer which will use the "Erase All Content & Settings" reset via "Free Geek Reset" as described below.
				
				if (isBigSurOrNewer) then
					-- When the Snapshot Reset is setup on macOS 10.15 Catalina and newer, "Free Geek Snapshot Helper" will always be installed, but it is only used to mount the reset Snapshot (which requires Full Disk Access) on macOS 11 Big Sur and newer, since mounting the Snapshot on macOS 10.15 Catalina does not help (see CAVEAT notes in "fg-snapshot-preserver" script).
					-- But, it is still installed on macOS 10.15 Catalina to be used as an alert GUI if the reset Snapshot is lost which does not needs FDA TCC permissions, and no reset Snapshot was created on macOS 10.14 Mojave and older where a custom "fgreset" script used to be used instead (but we no longer install macOS 10.14 Mojave and older anyways).
					
					if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekSnapshotHelperApp & "|kTCCServiceSystemPolicyAllFiles")) then error "“Free Geek Snapshot Helper” DOES NOT HAVE REQUIRED Full Disk Access"
				end if
			else if (freeGeekResetIsInstalled and isMontereyOrNewer and (hasT2chip or isAppleSilicon)) then
				-- "Free Geek Reset" will always be installed on macOS 10.15 Catalina or newer, but it only needs these TCC permissions on T2 or Apple Silicon Macs running macOS 12 Monterey or newer
				-- since that is where "Erase Assistant" which can perform "Erase All Content & Settings" is available, which "Free Geek Reset" automates.
				-- When running on pre-T2 Macs or when running macOS 11 Big Sur or older where "Erase All Content & Settings" is not available, "Free Geek Reset" will still be installed,
				-- but it will just show instructions for the Snapshot Reset and allow auto-rebooting into recoverOS by setting an NVRAM key, which does not require these TCC permissions.
				
				if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekResetApp & "|kTCCServiceAccessibility")) then error "“Free Geek Reset” DOES NOT HAVE REQUIRED Accessibility Access"
				if (globalTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekResetApp & "|kTCCServiceSystemPolicyAllFiles")) then error "“Free Geek Reset” DOES NOT HAVE REQUIRED Full Disk Access"
			end if
			
			set userTCCdbPath to ((POSIX path of (path to library folder from user domain)) & "Application Support/com.apple.TCC/TCC.db")
			set userTCCallowedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of userTCCdbPath) & " 'SELECT client,service,indirect_object_identifier FROM access WHERE (" & whereAllowedOrAuthValue & ")'"))) -- This SELECT command on the user TCC.db will error if "Free Geek Setup" doesn't have Full Disk Access (but that should never happen because we couldn't get this far without FDA).
			
			set bundleIDofQAHelperApp to "org.freegeek.QA-Helper"
			
			set bundleIDofSystemEventsApp to "com.apple.systemevents"
			set bundleIDofFinderApp to "com.apple.finder"
			set bundleIDofSystemPreferencesOrSettingsApp to "com.apple.systempreferences" -- The bundle ID for the new "System Settings" app in Ventura is the same as the previous "System Preferences" app.
			set bundleIDofQuickTimeApp to "com.apple.QuickTimePlayerX"
			
			try
				if (userTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekSetupApp & "|kTCCServiceAppleEvents|" & bundleIDofSystemEventsApp)) then error ("“" & (name of me) & "” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “System Events”")
				if (userTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekSetupApp & "|kTCCServiceAppleEvents|" & bundleIDofFinderApp)) then error ("“" & (name of me) & "” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “Finder”")
				if (userTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekSetupApp & "|kTCCServiceAppleEvents|" & bundleIDofSystemPreferencesOrSettingsApp)) then error ("“" & (name of me) & "”  WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “" & (name of application id bundleIDofSystemPreferencesOrSettingsApp) & "”") -- Use "name of application id" to correctly display "System Preferences" or "System Settings" depending on macOS version.
				
				if (userTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekDemoHelperApp & "|kTCCServiceAppleEvents|" & bundleIDofSystemEventsApp)) then error "“Free Geek Demo Helper” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “System Events”"
				if (userTCCallowedAppsAndServices does not contain (bundleIDofFreeGeekDemoHelperApp & "|kTCCServiceAppleEvents|" & bundleIDofFinderApp)) then error "“Free Geek Demo Helper” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “Finder”"
				
				if (userTCCallowedAppsAndServices does not contain (bundleIDofCleanupAfterQACompleteApp & "|kTCCServiceAppleEvents|" & bundleIDofSystemEventsApp)) then error "“Cleanup After QA Complete” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “System Events”"
				if (userTCCallowedAppsAndServices does not contain (bundleIDofCleanupAfterQACompleteApp & "|kTCCServiceAppleEvents|" & bundleIDofFinderApp)) then error "“Cleanup After QA Complete” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “Finder”"
				
				-- See comments below about both Microphone AND AppleEvents-QuickTime permissions for QA Helper.
				if (userTCCallowedAppsAndServices does not contain (bundleIDofQAHelperApp & "|kTCCServiceMicrophone|UNUSED")) then error "“QA Helper” WAS NOT GRANTED REQUIRED Microphone Access"
				if (userTCCallowedAppsAndServices does not contain (bundleIDofQAHelperApp & "|kTCCServiceAppleEvents|" & bundleIDofQuickTimeApp)) then error "“QA Helper” WAS NOT GRANTED REQUIRED AppleEvents/Automation Access for “System Events”"
				if (not isBigSurOrNewer) then -- See comments below about QuickTime needing manual Microphone access on Mojave and Catalina, but not Big Sur and newer.
					if (userTCCallowedAppsAndServices does not contain (bundleIDofQuickTimeApp & "|kTCCServiceMicrophone|UNUSED")) then error "“QuickTime Player” WAS NOT GRANTED REQUIRED Microphone Access"
				else if (isVenturaOrNewer and (not hasT2chip) and (not isAppleSilicon)) then
					-- See comments below about apps unneccessarily prompting for Microphone on pre-T2 Macs running Ventura.
					set userTCCunauthorizedAppsAndServices to (paragraphs of (do shell script ("sqlite3 " & (quoted form of userTCCdbPath) & " 'SELECT client,service FROM access WHERE (auth_value = 0)'"))) -- This SELECT command on the user TCC.db will error if "Free Geek Setup" doesn't have Full Disk Access (but that should never happen because we couldn't get this far without FDA).
					if (userTCCunauthorizedAppsAndServices does not contain (bundleIDofFreeGeekSetupApp & "|kTCCServiceMicrophone")) then error "“Free Geek Setup” WAS NOT DENIED Microphone Access"
					if (userTCCunauthorizedAppsAndServices does not contain (bundleIDofFreeGeekUpdaterApp & "|kTCCServiceMicrophone")) then error "“Free Geek Updater” WAS NOT DENIED Microphone Access"
					if (snapshotHelperIsInstalled and (userTCCunauthorizedAppsAndServices does not contain (bundleIDofFreeGeekSnapshotHelperApp & "|kTCCServiceMicrophone"))) then error "“Free Geek Snapshot Helper” WAS NOT DENIED Microphone Access"
					if (userTCCunauthorizedAppsAndServices does not contain (bundleIDofFreeGeekDemoHelperApp & "|kTCCServiceMicrophone")) then error "“Free Geek Demo Helper” WAS NOT DENIED Microphone Access"
					if (taskRunnerIsInstalled and (userTCCunauthorizedAppsAndServices does not contain (bundleIDofFreeGeekTaskRunnerApp & "|kTCCServiceMicrophone"))) then error "“Free Geek Task Runner” WAS NOT DENIED Microphone Access"
					if (userTCCunauthorizedAppsAndServices does not contain (bundleIDofCleanupAfterQACompleteApp & "|kTCCServiceMicrophone")) then error "“Cleanup After QA Complete” WAS NOT DENIED Microphone Access"
				end if
			on error checkUserTCCErrorMessage
				if (didJustGrantUserTCC) then error checkUserTCCErrorMessage
				
				-- The following csreq (Code Signing Requirement) hex strings were generated by https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/generate_csreq_hex_for_tcc_db.jxa
				-- See comments in the "generate_csreq_hex_for_tcc_db.jxa" script for some important detailed information about these csreq hex strings (and https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
				
				-- The following apps are the CLIENT apps that will be sending AppleEvents (or accessing the Microphone).
				-- Including the csreq for the client seems to NOT actually be required when initially setting the TCC permissions and macOS will fill them out when the app launches for the first time.
				-- But, that would reduce security by allowing any app that's first to launch with the specified Bundle Identifier to be granted the specified TCC permissions (even though fraudulent apps spoofing our Bundle IDs isn't a risk in our environment).
				set csreqForFreeGeekSetupApp to "fade0c00000000a80000000100000006000000020000001c6f72672e667265656765656b2e467265652d4765656b2d5365747570000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForFreeGeekUpdaterApp to "fade0c00000000ac0000000100000006000000020000001e6f72672e667265656765656b2e467265652d4765656b2d557064617465720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForFreeGeekSnapshotHelperApp to "fade0c00000000b4000000010000000600000002000000266f72672e667265656765656b2e467265652d4765656b2d536e617073686f742d48656c7065720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForFreeGeekDemoHelperApp to "fade0c00000000b0000000010000000600000002000000226f72672e667265656765656b2e467265652d4765656b2d44656d6f2d48656c7065720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForFreeGeekTaskRunnerApp to "fade0c00000000b0000000010000000600000002000000226f72672e667265656765656b2e467265652d4765656b2d5461736b2d52756e6e65720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForCleanupAfterQACompleteApp to "fade0c00000000b4000000010000000600000002000000266f72672e667265656765656b2e436c65616e75702d41667465722d51412d436f6d706c6574650000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForQAHelperApp to "fade0c00000000a4000000010000000600000002000000166f72672e667265656765656b2e51412d48656c7065720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				set csreqForFreeGeekResetApp to "fade0c00000000a80000000100000006000000020000001c6f72672e667265656765656b2e467265652d4765656b2d5265736574000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000"
				
				-- The following apps are the TARGET (or INDIRECT OBJECT) apps that the clients will be sending AppleEvents to.
				-- Like the csreq's for the client, they also seem to not actually be required for the target/indirect_object, BUT if the indirect_object_code_identity is omitted, the permissions DON'T show up in the TCC Automation section of System Preferences even though the permissions still work (tested on both Catalina and Monterey).
				set csreqForSystemEventsApp to "fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003"
				set csreqForFinderApp to "fade0c000000002c00000001000000060000000200000010636f6d2e6170706c652e66696e64657200000003"
				set csreqForSystemPreferencesOrSettingsApp to "fade0c00000000380000000100000006000000020000001b636f6d2e6170706c652e73797374656d707265666572656e6365730000000003" -- The csreq for the new "System Settings" app on Ventura is the same as the previous "System Preferences" app.
				set csreqForQuickTimeApp to "fade0c00000000380000000100000006000000020000001a636f6d2e6170706c652e517569636b54696d65506c6179657258000000000003"
				
				set allowedOrAuthorizedFields to "1"
				if (isBigSurOrNewer) then set allowedOrAuthorizedFields to "2,3"
				
				set currentUnixTime to (do shell script "date '+%s'")
				
				set footerFields to ""
				if (isSonomaOrNewer) then set footerFields to (",NULL,NULL,'UNUSED'," & currentUnixTime)
				
				set setUserTCCpermissionsCommands to "BEGIN TRANSACTION;"
				
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofFreeGeekSetupApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForFreeGeekSetupApp & "',NULL,0,'" & bundleIDofSystemEventsApp & "',X'" & csreqForSystemEventsApp & "',NULL," & currentUnixTime & footerFields & ");")
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofFreeGeekSetupApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForFreeGeekSetupApp & "',NULL,0,'" & bundleIDofFinderApp & "',X'" & csreqForFinderApp & "',NULL," & currentUnixTime & footerFields & ");")
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofFreeGeekSetupApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForFreeGeekSetupApp & "',NULL,0,'" & bundleIDofSystemPreferencesOrSettingsApp & "',X'" & csreqForSystemPreferencesOrSettingsApp & "',NULL," & currentUnixTime & footerFields & ");")
				
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofFreeGeekDemoHelperApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForFreeGeekDemoHelperApp & "',NULL,0,'" & bundleIDofSystemEventsApp & "',X'" & csreqForSystemEventsApp & "',NULL," & currentUnixTime & footerFields & ");")
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofFreeGeekDemoHelperApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForFreeGeekDemoHelperApp & "',NULL,0,'" & bundleIDofFinderApp & "',X'" & csreqForFinderApp & "',NULL," & currentUnixTime & footerFields & ");")
				
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofCleanupAfterQACompleteApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForCleanupAfterQACompleteApp & "',NULL,0,'" & bundleIDofSystemEventsApp & "',X'" & csreqForSystemEventsApp & "',NULL," & currentUnixTime & footerFields & ");")
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofCleanupAfterQACompleteApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForCleanupAfterQACompleteApp & "',NULL,0,'" & bundleIDofFinderApp & "',X'" & csreqForFinderApp & "',NULL," & currentUnixTime & footerFields & ");")
				
				if (freeGeekResetIsInstalled) then
					-- Always grant "Free Geek Reset" AppleEvents/Automation TCC permissions for "System Events" (even if "Full Disk Access" and "Accessibility" TCC permissions were not granted above) since it needs them to quit all apps before auto-rebooting into Recovery even if only used with the Snapshot Reset technique.
					-- And, of course, if it is used for the "Erase All Content & Settings" reset, then "System Events" AppleEvents/Automation TCC permissions are needed to automate the "Erase Assistant" app (and also to quit all apps).
					set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofFreeGeekResetApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForFreeGeekResetApp & "',NULL,0,'" & bundleIDofSystemEventsApp & "',X'" & csreqForSystemEventsApp & "',NULL," & currentUnixTime & footerFields & ");")
				end if
				
				-- On pre-T2 Macs, Java (QA Helper) can access the Microphone to be able to do the Microphone Test.
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofQAHelperApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForQAHelperApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
				-- On T2 and Apple Silcon Macs, Java (QA Helper) seems to not be able to request Microphone access and also can't even access the Microphone when permission is manually granted, so QuickTime automation will be used instead when the Microphone can't be accessed (since QuickTime can access the Microphone).
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceAppleEvents','" & bundleIDofQAHelperApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForQAHelperApp & "',NULL,0,'" & bundleIDofQuickTimeApp & "',X'" & csreqForQuickTimeApp & "',NULL," & currentUnixTime & footerFields & ");")
				-- Even though QA Helper should only need one or the other of Microphone or AppleEvents-QuickTime access, always grant both just in case (especially if things change in the future and a newer version Java can access the Microphone on T2 and Apple Silicon Macs).
				
				if (not isBigSurOrNewer) then
					-- On Mojave and Catalina, QuickTime must be manually granted Microphone access, but on Big Sur and newer it's automatically granted access by macOS.
					-- But, T2 Macs will never be allowed to install Catalina or older since the first admin cannot be prevented from being granted a Secure Token on those versions which would break Snapshot resetting, but keep this here just to be thorough since we are also always granted QA Helper AppleEvents-QuickTime access.
					set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofQuickTimeApp & "',0," & allowedOrAuthorizedFields & ",1,X'" & csreqForQuickTimeApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
				else if (isVenturaOrNewer and (not hasT2chip) and (not isAppleSilicon)) then
					-- On macOS 13 Ventura, BUT ONLY on pre-T2 Macs, certain audio-related actions are prompting for Microphone access even though they don't actually access the microphone and continue to work properly when microphone access is DENIED.
					-- So, pre-deny Microphone access for all these apps so that the technician is never interrupted with these unnecessary prompts and the apps are not granted access they do not actually need.
					-- Here are some commands I found which prompt for Microphone access but still work when access is denied: AppleScript "set volume", shell command "afplay ...", shell command "system_profiler SPAudioDataType" (and there may be others I haven't encountered).
					
					set unauthorizedFields to "0,3"
					set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofFreeGeekSetupApp & "',0," & unauthorizedFields & ",1,X'" & csreqForFreeGeekSetupApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
					set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofFreeGeekUpdaterApp & "',0," & unauthorizedFields & ",1,X'" & csreqForFreeGeekUpdaterApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
					if (snapshotHelperIsInstalled) then set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofFreeGeekSnapshotHelperApp & "',0," & unauthorizedFields & ",1,X'" & csreqForFreeGeekSnapshotHelperApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
					set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofFreeGeekDemoHelperApp & "',0," & unauthorizedFields & ",1,X'" & csreqForFreeGeekDemoHelperApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
					if (taskRunnerIsInstalled) then set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofFreeGeekTaskRunnerApp & "',0," & unauthorizedFields & ",1,X'" & csreqForFreeGeekTaskRunnerApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
					set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "REPLACE INTO access VALUES('kTCCServiceMicrophone','" & bundleIDofCleanupAfterQACompleteApp & "',0," & unauthorizedFields & ",1,X'" & csreqForCleanupAfterQACompleteApp & "',NULL,0,'UNUSED',NULL,0," & currentUnixTime & footerFields & ");")
				end if
				
				set setUserTCCpermissionsCommands to (setUserTCCpermissionsCommands & "COMMIT;")
				
				do shell script ("echo " & (quoted form of setUserTCCpermissionsCommands) & " | sqlite3 " & (quoted form of userTCCdbPath)) -- Since we're using REPLACE INTO it shouldn't matter if any rows already exists, even if they're not allowed/authorized they will be overwritten with our allowed/authorized line.
				
				try
					do shell script "mkdir " & (quoted form of buildInfoPath)
				end try
				try
					doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgSetupJustGrantedUserTCC")))
				end try
				
				-- Relaunch Free Geek Setup to be sure that it is launched with all the TCC permissions that we've just granted to it.
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
				quit
				delay 10
			end try
		end if
	on error tccErrorMessage
		if (tccErrorMessage starts with "Error: unable to open database") then set tccErrorMessage to ("“" & (name of me) & "” DOES NOT HAVE REQUIRED Full Disk Access (" & tccErrorMessage & ")")
		
		try
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
			end try
			display alert ("CRITICAL “" & (name of me) & "” TCC ERROR:

" & tccErrorMessage) message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research if trying again does not work." buttons {"Shut Down", "Try Again"} cancel button 1 default button 2 as critical giving up after 10
			-- NOTE: Allow trying again in case the error is "Error: in prepare, database is locked (5)" or "Error: near line 1: stepping, database is locked (5)" which I think indicates another process is currently editing the DB and our edits will work when it's not locked, or some other error that I'm unaware of that is also temporary.
			-- Since this error seems to not be super uncommon, but a re-attempt always works, make the alert "give up after" 15 seconds so that the technician can see the error but it also just tried again automatically so they don't need to click "Try Again" manually.
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		on error
			tell application id "com.apple.systemevents" to shut down with state saving preference
		end try
		quit
		delay 10
	end try
	
	-- Unmount any fgMIB, Install macOS, or MacLand Boot drives (this can now work on Big Sur and newer as well since this app will have Full Disk Access and access to removable drives wouldn't need to be manually approved by the technician).
	try
		do shell script "for this_installer_volume in '/Volumes/fgMIB'* '/Volumes/Install '* '/Volumes/'*' Boot'*; do if [ -d \"${this_installer_volume}\" ]; then diskutil unmountDisk \"${this_installer_volume}\" > /dev/null 2>&1 & fi done"
	end try
	
	if (isTahoeOrNewer) then
		-- Remove Desktop widgets on macOS 26 Tahoe
		-- https://macadmins.slack.com/archives/GA92U9YV9/p1750793773418789?thread_ts=1750284879.050399&cid=GA92U9YV9
		-- Modifying the preferences within the NotificationCenterUI Container requires Full Disk Access TCC privileges, so it must be done in this script on first login since it will have FDA.
		
		try
			do shell script ("
defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.notificationcenterui/Data/Library/Preferences/com.apple.notificationcenterui' widgets -dict \\
	DesktopWidgetPlacementStorage \"<data>$(plutil -create binary1 - |
		plutil -insert 'CompatibilityVersion' -integer 1 -o - - |
		plutil -insert 'NumberedDisplays' -array -o - - | base64)</data>\" \\
	instances '<array/>' \\
	vers '<integer>1</integer>'
")
		end try
		
		try
			with timeout of 1 second
				tell application id "com.apple.notificationcenterui" to quit
			end timeout
		end try
	end if
	
	do shell script ("rm -rf " & (quoted form of ("/Users/" & demoUsername & "/Desktop/" & (name of me) & ".app")))
	
	repeat with thisUserAppsToSymlinkOnDesktop in {"QA Helper", "Cleanup After QA Complete"}
		try
			((("/Users/" & demoUsername & "/Applications/" & thisUserAppsToSymlinkOnDesktop & ".app") as POSIX file) as alias)
			try
				((("/Users/" & demoUsername & "/Desktop/" & thisUserAppsToSymlinkOnDesktop & ".app") as POSIX file) as alias)
			on error
				try
					do shell script "ln -s " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & thisUserAppsToSymlinkOnDesktop & ".app")) & " " & (quoted form of ("/Users/" & demoUsername & "/Desktop/"))
				end try
			end try
		end try
	end repeat
	
	tell application id "com.apple.finder"
		try
			set desktop position of alias file "QA Helper.app" of desktop to {100, 110}
		end try
		try
			set desktop position of alias file "Cleanup After QA Complete.app" of desktop to {250, 110}
		end try
		try
			close every window
		end try
	end tell
	
	if (isVenturaThirteenDotThreeOrNewer and isAppleSilicon) then
		-- Approve "Allow accessory to connect?" prompts for Apple Silicon on macOS 13.3 Ventura or newer (this prompt is exclusive to laptops, but is a quick check regardless of device type).
		--  In our testing environment, we may have a USB Ethernet adapter connected on boot and want them to be auto-allowed without the technician needing to click the prompt.
		
		try
			if (application id "com.apple.UserNotificationCenter" is running) then
				repeat 60 times
					set clickedAllowAccessoryButton to false
					try
						with timeout of 2 seconds
							tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.UserNotificationCenter")
								repeat with thisUNCWindow in windows
									if (((count of static texts of thisUNCWindow) is equal to 2) and ((value of static text 1 of thisUNCWindow) is equal to "Allow accessory to connect?") and ((count of buttons of thisUNCWindow) ≥ 3)) then
										repeat with thisUNCButton in (buttons of thisUNCWindow)
											if (title of thisUNCButton is "Allow") then
												click thisUNCButton
												set clickedAllowAccessoryButton to true
												exit repeat
											end if
										end repeat
									end if
								end repeat
							end tell
						end timeout
					end try
					if (not clickedAllowAccessoryButton) then exit repeat -- Exit loop after NOT clicked to be sure ALL windows have been closed.
					delay 0.5
				end repeat
			end if
		end try
	end if
	
	if (isMontereyOrNewer) then
		-- In macOS 12 Monterey, the Safari Container is created upon login instead of first Safari launch.
		-- The preferences within the Safari Container don't exist until launch, but the preferences from the old location (set by "fg-prepare-o.sh") DO NOT getting migrated as they do on older versions of macOS because the Safari Container already exists.
		-- Modifying the preferences within the Safari Container requires Full Disk Access TCC privileges, so it must be done in this script on first login since it will have FDA.
		
		set currentSafariAutoFillPasswords to "UNKNOWN"
		try
			set currentSafariAutoFillPasswords to (do shell script "defaults read '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillPasswords")
		end try
		
		if (currentSafariAutoFillPasswords is not equal to "0") then
			try
				do shell script ("
killall Safari
defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillPasswords -bool false
defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillFromAddressBook -bool false
defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillCreditCardData -bool false
defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoFillMiscellaneousForms -bool false
defaults write '/Users/" & demoUsername & "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari' AutoOpenSafeDownloads -bool false
")
			end try
		end if
	end if
	
	set demoHelperAppPath to ("/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app")
	
	try
		try
			do shell script "mkdir " & (quoted form of buildInfoPath)
		end try
		try
			-- Let Demo Helper know that it was launched by Setup so that it will always open QA Helper even if idle time is too short or time since boot is too long (which shouldn't normally happen).
			doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgSetupLaunchedDemoHelper")))
		end try
		
		-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited so this will not actually ever open a new instance.
		do shell script ("open -na " & (quoted form of demoHelperAppPath)) -- Launch Demo Helper once first before any other long processes start and any situations that may cause Setup to not finish. Demo Helper will be set to auto-launch after Setup is finished.
		
		set demoHelperDidLaunch to false
		repeat 10 times
			try
				if (application demoHelperAppPath is running) then
					set demoHelperDidLaunch to true
					exit repeat
				end if
			end try
			delay 1
		end repeat
		
		if (demoHelperDidLaunch) then
			try
				repeat while (application demoHelperAppPath is running) -- Wait for Demo Helper to finish so that Setup and Demo Helper don't interfere with eachother.
					delay 0.5
				end repeat
			end try
		end if
	end try
	
	-- DISABLE CAPS LOCK IF ENABLED: https://forum.latenightsw.com/t/toggle-capslock/4319/11
	-- So that passwords are not typed in caps
	try
		run script "ObjC.import(\"IOKit\");
ObjC.import(\"CoreServices\");

(() => {
    var ioConnect = Ref();
    var keystate = Ref();

    $.IOServiceOpen(
        $.IOServiceGetMatchingService(
            $.kIOMasterPortDefault,
            $.IOServiceMatching(
                $.kIOHIDSystemClass
            )
        ),
        $.mach_task_self_,
        $.kIOHIDParamConnectType,
        ioConnect
    );
    $.IOHIDSetModifierLockState(ioConnect, $.kIOHIDCapsLockState, 0);
    $.IOServiceClose(ioConnect);
	
})();" in "JavaScript"
	end try
	
	-- TURN OFF SCREEN LOCK via GUI scripting on High Sierra (it was already done earlier for Mojave and newer with "sysadminctl -screenLock off" which didn't exist in High Sierra)
	-- NOTE: No AppleEvents/Automation TCC permissions are needed for this since it only runs on High Sierra where that TCC permissions doesn't exist (but they are needed for the Startup Disk setting code which runs on all versions of macOS).
	if (not isMojaveOrNewer) then
		try
			activate
		end try
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
						reveal ((anchor "General") of (pane id "com.apple.preference.security"))
						delay 1
						if ((name of window 1) is "Security & Privacy") then exit repeat
					end repeat
				end tell
				tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
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
								exit repeat
							end if
						end repeat
						
						delay 1
					end if
					set screenLockCheckboxValue to (screenLockCheckbox's value as boolean)
				end tell
				if (screenLockCheckboxValue is false) then
					delay 0.5
					exit repeat
				end if
			end try
		end repeat
		try
			with timeout of 1 second
				tell application id "com.apple.systempreferences" to quit
			end timeout
		end try
	end if
	
	-- CLEAR NVRAM (just for house cleaning purposes, this doesn't clear SIP).
	-- This must be done BEFORE setting the Startup Disk, since that is stored in NVRAM.
	try
		-- DO NOT clear NVRAM if TRIM has been enabled on Catalina with "trimforce enable" because clearing NVRAM will undo it. (The TRIM flag is not stored in NVRAM before Catalina.)
		doShellScriptAsAdmin("nvram EnableTRIM") -- This will error if the flag does not exist.
	on error
		if (isBigSurElevenDotThreeOrNewer or (not isAppleSilicon)) then
			-- ALSO, do not clear NVRAM on Apple Silicon IF OLDER THAN 11.3 since it will cause an error saying that macOS needs to be reinstalled (but can boot properly after re-selecting the internal drive in Startup Disk),
			-- since it deletes important NVRAM keys (such as "boot-volume") which are now protected and cannot be deleted on 11.3 and newer.
			try
				doShellScriptAsAdmin("nvram -c")
			end try
		end if
	end try
	
	-- SET STARTUP DISK
	-- Not really sure this is actually necessary since "fgrest" and "fg-snapshot-reset.sh" both clear NVRAM which would clear this setting out (when TRIM is not manually enabled on Catalina or newer or when it's not protected on Apple Silicon).
	set nameOfBootedDisk to ""
	try
		tell application id "com.apple.systemevents" to set nameOfBootedDisk to (name of startup disk)
	end try
	
	set nameOfCurrentlySelectedStartupDisk to ""
	try
		set nameOfCurrentlySelectedStartupDisk to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :VolumeName' /dev/stdin <<< \"$(diskutil info -plist \"$(bless --getBoot)\")\"")))
	end try
	
	if ((nameOfBootedDisk is not equal to "") and (nameOfBootedDisk is not equal to nameOfCurrentlySelectedStartupDisk)) then
		set didSetStartUpDisk to false
		
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
					repeat 180 times -- Wait for Startup Disk pane to load
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
								if (isTahoeOrNewer) then
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1)
								else if (isSonomaOrNewer) then
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								else
									set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								end if
								set numberOfStartupDisks to (number of groups of list 1 of scroll area 1 of startupDisksSelectionGroup)
								if (numberOfStartupDisks is not 0) then
									delay 3 -- Wait a few more seconds for disks to load since it's possible that not all startup disks are actually loaded yet.
									set numberOfStartupDisks to (number of groups of list 1 of scroll area 1 of startupDisksSelectionGroup)
									
									set currentlySelectedStartupDiskValue to (value of static text 2 of startupDisksSelectionGroup)
									if (currentlySelectedStartupDiskValue ends with ("“" & nameOfBootedDisk & "”.")) then -- Check if the internal drive is already set as the Startup Disk.
										set didSetStartUpDisk to true
									else if (currentlySelectedStartupDiskValue is not equal to "") then -- If some startup disk is already selected, figure out if the internal disk is to the right or left of that.
										repeat with thisStartupDiskGroup in (groups of list 1 of scroll area 1 of startupDisksSelectionGroup)
											set thisStartDiskName to (value of static text 1 of thisStartupDiskGroup)
											if (currentlySelectedStartupDiskValue ends with ("“" & thisStartDiskName & "”.")) then
												exit repeat -- If we found the selected startup disk and have not found the internal disk yet, they means it must be to the RIGHT, which leftOrRightArrowKeyCode is already set to.
											else if (thisStartDiskName is equal to nameOfBootedDisk) then
												-- If we're at the internal disk and we HAVE NOT already passed the selected disk (since we haven't exited to loop yet), we need to move LEFT from the selected disk.
												set leftOrRightArrowKeyCode to 123 -- LEFT ARROW Key
												exit repeat
											end if
										end repeat
									end if
									exit repeat
								end if
							end try
						end repeat
					end tell
					
					if (not didSetStartUpDisk) then -- If it's already selected, no need to unlock and re-select it.
						set didAuthenticateStartupDisk to false
						
						repeat numberOfStartupDisks times -- The loop should be exited before even getting through numberOfStartupDisks, but want some limit so we don't get stuck in an infinite loop if something goes very wrong.
							set currentlySelectedStartupDiskValue to "UNKNOWN"
							set didChangeStartupDiskSelection to false
							
							repeat 30 times
								try
									tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
										-- Can't click elements in new fancy Startup Disk list, but I can arrow through them.
										set frontmost to true
										
										if (isTahoeOrNewer) then
											set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1)
										else if (isSonomaOrNewer) then
											set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
										else
											set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
										end if
										
										if (currentlySelectedStartupDiskValue is equal to "UNKNOWN") then
											set currentlySelectedStartupDiskValue to (value of static text 2 of startupDisksSelectionGroup)
										else if (currentlySelectedStartupDiskValue is not equal to (value of static text 2 of startupDisksSelectionGroup)) then -- If not first iteration, check if previous iteration already changed the selection (see comments below about how an exception could have gotten thrown getting the changed text value after actually changing the selection).
											set didChangeStartupDiskSelection to true
										end if
										
										if (not didChangeStartupDiskSelection) then
											set focused of (scroll area 1 of startupDisksSelectionGroup) to true
											repeat 5 times -- Click up to 5 times until the selected startup disk changed (in case some clicks get lost)
												set frontmost to true
												key code leftOrRightArrowKeyCode
												delay 0.25
												if (currentlySelectedStartupDiskValue is not equal to (value of static text 2 of startupDisksSelectionGroup)) then -- On first boot of macOS 26 Tahoe during the first launch of System Settings, getting this text value here can throw an exception for some reason, so wrap the whole block in a "try" within a "repeat" loop to reattempt since it should work on next attempt without having to quit System Settings and try the whole process again. 
													set didChangeStartupDiskSelection to true
													exit repeat
												end if
											end repeat
										end if
									end tell
								end try
								
								if didChangeStartupDiskSelection then exit repeat
								delay 1
							end repeat
							
							if (not didChangeStartupDiskSelection) then
								error "FAILED to Change Startup Disk Selection"
							else if (not didAuthenticateStartupDisk) then
								set didTryToAuthenticateStartupDisk to false
								if (isVenturaThirteenDotThreeOrNewer) then
									-- Starting on macOS 13.3 Ventura, the System Settings password authentication prompt is now handled by "LocalAuthenticationRemoteService" XPC service within a regular sheet of the System Setting app instead of the "SecurityAgent.bundle" which presented a separate app prompt window.
									repeat 60 times -- Wait for password prompt
										delay 0.5
										try
											tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
												set frontmost to true
												if (((number of sheets of window (number of windows)) is equal to 1) and ((number of buttons of sheet 1 of window (number of windows)) is equal to 2) and ((number of text fields of sheet 1 of window (number of windows)) is equal to 2)) then exit repeat
											end tell
										end try
										delay 0.5
									end repeat
									
									tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
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
									
									if (isSonomaOrNewer) then -- On macOS 14 Sonoma, ANOTHER standalone SecurityAgent auth prompt comes up AFTER the initial LocalAuthenticationRemoteService XPC sheet prompt WHEN RUNNING AS A STANDARD USER.
										set didTryToAuthenticateStartupDisk to false
										repeat 30 times -- Wait up to 30 seconds for SecurityAgent to launch and present the admin auth prompt since it can take a moment.
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
															exit repeat
														end if
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
														exit repeat
													end if
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
												
												if (isSonomaOrNewer) then -- See comments above about SECOND SecurityAgent auth prompt on macOS 14 Sonoma.
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
									if (isTahoeOrNewer) then
										set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1)
									else if (isSonomaOrNewer) then
										set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
									else
										set startupDisksSelectionGroup to (group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
									end if
									if ((enabled of button 1 of startupDisksSelectionGroup) and ((value of static text 2 of startupDisksSelectionGroup) ends with ("“" & nameOfBootedDisk & "”."))) then
										set didSetStartUpDisk to true
										exit repeat
									end if
								end tell
							else
								if (isSonomaOrNewer) then -- The SECOND SecurityAgent prompt on macOS 14 Sonoma DOES NOT close on its own when System Settings is quit.
									if (application securityAgentPath is running) then
										tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is securityAgentID)
											if ((number of windows) is 1) then
												set frontmost to true
												key code 53 -- Press ESCAPE in case something went wrong and the password prompt is still up.
											end if
										end tell
									end if
								end if
								
								if (isVenturaThirteenDotThreeOrNewer) then
									tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.systempreferences")
										if ((number of sheets of window (number of windows)) is equal to 1) then
											set frontmost to true
											key code 53 -- Press ESCAPE in case something went wrong and the password prompt is still up.
										end if
									end tell
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
										if ((value of static text 1 of window 1) ends with ("“" & nameOfBootedDisk & ".”")) then -- Check if the internal drive is already set as the Startup Disk.
											set didSetStartUpDisk to true
										else
											if (currentlySelectedStartupDiskValue is not equal to "") then -- If some startup disk is already selected, figure out if the internal disk is to the right or left of that.
												repeat with thisStartupDiskGroup in (groups of list 1 of scroll area 1 of window 1)
													set thisStartDiskName to (value of static text 1 of thisStartupDiskGroup)
													if (currentlySelectedStartupDiskValue ends with ("“" & thisStartDiskName & ".”")) then
														exit repeat -- If we found the selected startup disk and have not found the internal disk yet, they means it must be to the RIGHT, which leftOrRightArrowKeyCode is already set to.
													else if (thisStartDiskName is equal to nameOfBootedDisk) then
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
										set didSetStartUpDisk to ((value of static text 2 of group 1 of splitter group 1 of window 1) ends with ("“" & nameOfBootedDisk & ".”")) -- Check if the internal drive is already set as the Startup Disk.
										
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
											
											if ((value of static text 1 of window 1) ends with ("“" & nameOfBootedDisk & ".”")) then
												set didSetStartUpDisk to true
												exit repeat
											end if
										end repeat
									else
										repeat with thisStartUpDiskRadioButton in (radio buttons of radio group 1 of scroll area 1 of group 1 of splitter group 1 of window 1)
											if ((name of thisStartUpDiskRadioButton) is equal to nameOfBootedDisk) then
												set frontmost to true
												click thisStartUpDiskRadioButton
												delay 0.25
												if ((value of static text 2 of group 1 of splitter group 1 of window 1) ends with ("“" & nameOfBootedDisk & ".”")) then -- If this text didn't get set, then something went wrong and we need to try again.
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
							if (nameOfBootedDisk is equal to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :VolumeName' /dev/stdin <<< \"$(diskutil info -plist \"$(bless --getBoot)\")\"")))) then
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
		if (hasT2chip) then
			if ((do shell script "nvram '94B73556-2197-4702-82A8-3E1337DAFBFB:AppleSecureBootPolicy'") does not end with "%02") then -- https://github.com/dortania/OpenCore-Legacy-Patcher/blob/b85256d9708a299b9f7ea15cb3456248a1a666b7/resources/utilities.py#L242 & https://macadmins.slack.com/archives/CGXNNJXJ9/p1686766296067939?thread_ts=1686766055.849109&cid=CGXNNJXJ9
				try
					activate
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
				end try
				display alert "CRITICAL “" & (name of me) & "” ERROR:

Startup Security IS REDUCED on this T2 Mac." message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Quit"} default button 1 as critical
				quit
				delay 10
			end if
		else if (isAppleSilicon) then
			if (doShellScriptAsAdmin("bputil -d") does not contain "(smb0): absent") then
				try
					activate
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
				end try
				display alert "CRITICAL “" & (name of me) & "” ERROR:

Startup Security IS REDUCED on this Apple Silicon Mac." message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Quit"} default button 1 as critical
				quit
				delay 10
			end if
		end if
	end try
	
	try
		if ((do shell script "csrutil status") is not equal to "System Integrity Protection status: enabled.") then
			try
				activate
			end try
			if (isAppleSilicon) then
				-- If on Apple Silicon, enabling SIP requires authentication from a Secure Token admin (which won't have ever existed) to enable or disable it,
				-- so it should be impossible to be enabled, and we wouldn't be able to disable it if it was.
				-- So, fully stop with an error if somehow SIP is NOT enabled on an Apple Silicon Mac.
				-- (Also, SIP will be checked during "fg-snapshot-reset" and error if it's NOT enabled.)
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
				end try
				display alert "CRITICAL “" & (name of me) & "” ERROR:

System Integrity Protection (SIP) IS NOT enabled on this Apple Silicon Mac." message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Shut Down"} default button 1 as critical
			else
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
					doShellScriptAsAdmin("csrutil clear") -- "csrutil clear" can run from full macOS (Recovery is not required) but still needs a reboot to take effect.
				end try
			end if
			
			-- Quit all apps before shutting down or rebooting
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
			
			if (isAppleSilicon) then
				tell application id "com.apple.systemevents" to shut down with state saving preference
			else
				tell application id "com.apple.systemevents" to restart with state saving preference
			end if
			quit
			delay 10
		end if
	end try
	
	-- Wait for internet before checking Remote Management and EFI Firmware since AllowList may need to be update, as well as before launching QA Helper to ensure that QA Helper can always update itself to the latest version.
	set previousProgressAdditionalDescription to (progress additional description)
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
	set progress additional description to previousProgressAdditionalDescription
	
	set currentEFIfirmwareIsNotInAllowList to false
	if ((not hasT2chip) and (not isAppleSilicon)) then
		set currentEFIfirmwareIsNotInAllowList to checkEFIfirmwareIsNotInAllowList()
	end if
	
	set serialNumber to "UNKNOWNXXXXX"
	set shortModelName to "UNKNOWN MAC"
	set modelIdentifier to "UNKNOWN MODEL ID"
	set currentEFIfirmwareVersion to "UNKNOWN-EFI-FIRMWARE-VERSION"
	set shippedWithNVMeDrive to false
	set nvmeDriveModelName to "UNKNOWN DRIVE MODEL"
	set needsTrimEnabled to false
	set internalDriveIsNVMe to false
	
	set hardwareAndDriveInfoPath to tmpPath & "hardwareAndDriveInfo.plist"
	repeat 30 times
		try
			do shell script "system_profiler -xml SPHardwareDataType SPNVMeDataType SPSerialATADataType > " & (quoted form of hardwareAndDriveInfoPath)
			tell application id "com.apple.systemevents" to tell property list file hardwareAndDriveInfoPath
				repeat with i from 1 to (number of property list items)
					set thisDataTypeProperties to (item i of property list items)
					set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as text)
					if (thisDataType is equal to "SPHardwareDataType") then
						set hardwareItems to (first property list item of property list item "_items" of thisDataTypeProperties)
						try
							set serialNumber to ((value of property list item "serial_number" of hardwareItems) as text) -- https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
							if (serialNumber is equal to "Not Available") then
								set serialNumber to "UNKNOWNXXXXX"
							else if ((length of serialNumber) < 8) then -- https://www.macrumors.com/2021/03/09/apple-randomized-serial-numbers-early-2021/
								set serialNumber to "UNKNOWNXXXXX"
							end if
						on error
							set serialNumber to "UNKNOWNXXXXX"
						end try
						set shortModelName to ((value of property list item "machine_name" of hardwareItems) as text)
						set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as text)
						set currentEFIfirmwareVersion to ((first word of ((value of property list item "boot_rom_version" of hardwareItems) as text)) as text) -- T2 Mac's have boot_rom_version's like "1037.100.362.0.0 (iBridge: 17.16.14281.0.0,0)" but we only care about the first part.
						set modelIdentifierName to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -d '[:digit:],'") -- Need use this whenever comparing along with Model ID numbers since there could be false matches for the newer "MacXX,Y" style Model IDs if I used shortModelName in those conditions instead (which I used to do).
						set modelIdentifierNumber to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -dc '[:digit:],'")
						set AppleScript's text item delimiters to ","
						set modelNumberParts to (every text item of modelIdentifierNumber)
						set modelIdentifierMajorNumber to ((item 1 of modelNumberParts) as number)
						set modelIdentifierMinorNumber to ((last item of modelNumberParts) as number)
						
						-- The iMac18,X were the first to ship with NVMe drives (Gen 5/Model L), but Late 2015 iMacs (iMac16,X & iMac17,X) that shipped with fusion drives or maybe when they shipped around at least mid 2016 started shipping with Gen 4C/Model H NVMe drives (seen first hand with in situ wiped iMac17,1), so those must be allowed as well (there were previously issues with those models getting firmware updates, probably because of these NVMe drive, but I think Apple fixed that). Reference: https://eclecticlight.co/2021/02/06/could-this-fix-firmware-updating-in-the-imac-retina-5k-27-inch-late-2015-imac171/
						if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 16)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 13)) or ((modelIdentifierName is equal to "MacBookAir") and ((modelIdentifierMajorNumber ≥ 8) or ((modelIdentifierMajorNumber = 7) and (modelIdentifierMinorNumber = 1)))) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 7)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set shippedWithNVMeDrive to true
					else if ((thisDataType is equal to "SPNVMeDataType") or (thisDataType is equal to "SPSerialATADataType")) then
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
											set internalDriveIsNVMe to true
											set nvmeDriveModelName to ((value of property list item "_name" of thisSataControllerItem) as text)
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
			do shell script "rm -f " & (quoted form of hardwareAndDriveInfoPath) -- Delete incase User Canceled
			delay 1 -- Wait and try again because it seems to fail sometimes when run on login.
		end try
	end repeat
	do shell script "rm -f " & (quoted form of hardwareAndDriveInfoPath)
	
	
	try -- Don't check Remote Management if "TESTING" flag folder exists on desktop
		((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	on error
		if ((serialNumber is not equal to "") and (serialNumber is not equal to "UNKNOWNXXXXX")) then
			try
				do shell script "ping -t 5 -c 1 www.apple.com" -- Only try to get DEP status if we have internet.
				
				repeat
					delay 0.5
					
					set checkRemoteManagedMacsLogCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED CHECK REMOTE MANAGED MACS LOG URL]") & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
					set remoteManagedMacIsAlreadyLogged to false
					try
						set remoteManagedMacIsAlreadyLogged to ((do shell script checkRemoteManagedMacsLogCommand) is equal to "ALREADY LOGGED")
					end try
					
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
					
					if (remoteManagementOutput contains " - Request too soon.") then -- Don't allow setup if rate limited and there was no previous cached output to use.
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
						end try
						set nextAllowedProfilesShowTime to "23 hours after last successful check"
						try
							set nextAllowedProfilesShowTime to ("at " & (do shell script "date -jv +23H -f '%FT%TZ %z' \"$(plutil -extract lastProfilesShowFetchTime raw /private/var/db/ConfigurationProfiles/Settings/.profilesFetchTimerCheck) +0000\" '+%-I:%M:%S %p on %D'"))
						end try
						display alert ("Cannot Continue Setup

Unable to Check Remote Management Because of Once Every 23 Hours Rate Limiting

Next check will be allowed " & nextAllowedProfilesShowTime & ".") message "This should not have happened, please inform and deliver this Mac to Free Geek I.T. for further research." buttons {"Shut Down"} as critical
						tell application id "com.apple.systemevents" to shut down with state saving preference
						
						quit
						delay 10
					else if (remoteManagementOutput is not equal to "") then
						try
							set remoteManagementOutputParts to (paragraphs of remoteManagementOutput)
							
							if ((count of remoteManagementOutputParts) > 3) then
								set remoteManagementOrganizationName to "Unknown Organization"
								set remoteManagementOrganizationContactInfo to {}
								
								set logRemoteManagedMacCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED LOG REMOTE MANAGED MAC URL]") & " --data-urlencode " & (quoted form of ("source=" & (name of me))) & " --data-urlencode " & (quoted form of ("model=" & shortModelName & " (" & modelIdentifier & ")")) & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
								
								repeat with thisRemoteManagementOutputPart in remoteManagementOutputParts
									set organizationNameOffset to (offset of "OrganizationName = " in thisRemoteManagementOutputPart)
									set organizationDepartmentOffset to (offset of "OrganizationDepartment = " in thisRemoteManagementOutputPart)
									set organizationEmailOffset to (offset of "OrganizationEmail = " in thisRemoteManagementOutputPart)
									set organizationSupportEmailOffset to (offset of "OrganizationSupportEmail = " in thisRemoteManagementOutputPart)
									set organizationPhoneOffset to (offset of "OrganizationPhone = " in thisRemoteManagementOutputPart)
									set organizationSupportPhoneOffset to (offset of "OrganizationSupportPhone = " in thisRemoteManagementOutputPart)
									
									if (organizationNameOffset > 0) then
										set remoteManagementOrganizationName to (text (organizationNameOffset + 19) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationName starts with "\"") and (remoteManagementOrganizationName ends with "\"")) then set remoteManagementOrganizationName to (text 2 thru -2 of remoteManagementOrganizationName) -- Remove quotes if they exist, which they always should since this should always be a string value.
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("organization=" & remoteManagementOrganizationName)))
									else if (organizationDepartmentOffset > 0) then
										set remoteManagementOrganizationDepartment to (text (organizationDepartmentOffset + 25) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationDepartment starts with "\"") and (remoteManagementOrganizationDepartment ends with "\"")) then set remoteManagementOrganizationDepartment to (text 2 thru -2 of remoteManagementOrganizationDepartment) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationDepartment is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationDepartment)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationDepartment
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("department=" & remoteManagementOrganizationDepartment)))
									else if (organizationEmailOffset > 0) then
										set remoteManagementOrganizationEmail to (text (organizationEmailOffset + 20) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationEmail starts with "\"") and (remoteManagementOrganizationEmail ends with "\"")) then set remoteManagementOrganizationEmail to (text 2 thru -2 of remoteManagementOrganizationEmail) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationEmail
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("email=" & remoteManagementOrganizationEmail)))
									else if (organizationSupportEmailOffset > 0) then
										set remoteManagementOrganizationSupportEmail to (text (organizationSupportEmailOffset + 27) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationSupportEmail starts with "\"") and (remoteManagementOrganizationSupportEmail ends with "\"")) then set remoteManagementOrganizationSupportEmail to (text 2 thru -2 of remoteManagementOrganizationSupportEmail) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationSupportEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportEmail
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("support_email=" & remoteManagementOrganizationSupportEmail)))
									else if (organizationPhoneOffset > 0) then
										set remoteManagementOrganizationPhone to (text (organizationPhoneOffset + 20) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationPhone starts with "\"") and (remoteManagementOrganizationPhone ends with "\"")) then set remoteManagementOrganizationPhone to (text 2 thru -2 of remoteManagementOrganizationPhone) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationPhone
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("phone=" & remoteManagementOrganizationPhone)))
									else if (organizationSupportPhoneOffset > 0) then
										set remoteManagementOrganizationSupportPhone to (text (organizationSupportPhoneOffset + 27) thru -2 of thisRemoteManagementOutputPart)
										if ((remoteManagementOrganizationSupportPhone starts with "\"") and (remoteManagementOrganizationSupportPhone ends with "\"")) then set remoteManagementOrganizationSupportPhone to (text 2 thru -2 of remoteManagementOrganizationSupportPhone) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
										if ((remoteManagementOrganizationSupportPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportPhone
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("support_phone=" & remoteManagementOrganizationSupportPhone)))
									end if
								end repeat
								
								if (not remoteManagedMacIsAlreadyLogged) then
									set remoteManagedMacID to ""
									repeat
										try
											activate
										end try
										try
											do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
										end try
										
										set invalidIDnote to ""
										
										if (remoteManagedMacID is not equal to "") then
											set invalidIDnote to "
❌	“" & remoteManagedMacID & "” IS NOT A VALID ID - TRY AGAIN
"
										end if
										
										set remoteManagedMacIDreply to (display dialog "🔒	This Mac is Remote Managed by “" & remoteManagementOrganizationName & "”
" & invalidIDnote & "
Enter the ID of this Mac below to log this Mac with the contact info for “" & remoteManagementOrganizationName & "” so that they can be contacted to remove Remote Management:" default answer remoteManagedMacID buttons {"Log Remote Managed Mac Without ID", "Log Remote Managed Mac"} default button 2)
										
										set remoteManagedMacID to (text returned of remoteManagedMacIDreply)
										
										if ((button returned of remoteManagedMacIDreply) ends with "Without ID") then
											set remoteManagedMacID to "N/A"
										end if
										
										if ((remoteManagedMacID is equal to "N/A") or ((do shell script "bash -c " & (quoted form of ("[[ " & (quoted form of remoteManagedMacID) & " =~ ^[[:alpha:]]*[[:digit:]]+\\-[[:digit:]]+$ ]]; echo $?"))) is equal to "0")) then
											set remoteManagedMacID to (do shell script "echo " & (quoted form of remoteManagedMacID) & " | tr '[:lower:]' '[:upper:]'")
											set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("pid=" & remoteManagedMacID)))
											exit repeat
										end if
									end repeat
									
									repeat
										set logRemoteManagedMacResult to "UNKNOWN ERROR"
										try
											set logRemoteManagedMacResult to (do shell script logRemoteManagedMacCommand)
											if (logRemoteManagedMacResult ends with "LOGGED") then exit repeat
										end try
										
										try
											activate
										end try
										try
											do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
										end try
										display alert "Failed to Log Remote Managed Mac

ERROR: " & logRemoteManagedMacResult & "

You must be connected to the internet to be able to log this Remote Managed Mac." message "Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Try Again"} default button 1 as critical giving up after 10
									end repeat
								else
									try
										do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
									end try
								end if
								
								set remoteManagementOrganizationContactInfoDisplay to "NO CONTACT INFORMATION"
								if ((count of remoteManagementOrganizationContactInfo) > 0) then
									set AppleScript's text item delimiters to (linefeed & tab & tab)
									set remoteManagementOrganizationContactInfoDisplay to (remoteManagementOrganizationContactInfo as text)
								end if
								
								set remoteManagementDialogButton to "                                                       Shut Down                                                       "
								-- On macOS 10.15 Catalina and newer, space padded text in DIALOG buttons (but not ALERT buttons) doesn't work as expected,
								-- and the spaces that you want to pad with on each side must be DOUBLED at the END of the text rather than equally on both sides.
								-- (On macOS 26 Tahoe and newer ALERT buttons now ALSO need the same workaround for space padded text in buttons.)
								if (isCatalinaOrNewer) then set remoteManagementDialogButton to "Shut Down                                                                                                              "
								
								try
									activate
								end try
								display dialog "	     ⚠️     REMOTE MANAGEMENT IS ENABLED ON THIS MAC     ⚠️

❌     MACS WITH REMOTE MANAGEMENT ENABLED CANNOT BE SOLD     ❌



🔒	THIS MAC IS MANAGED BY “" & remoteManagementOrganizationName & "”

🔑	ONLY “" & remoteManagementOrganizationName & "” CAN DISABLE REMOTE MANAGEMENT

☎️	“" & remoteManagementOrganizationName & "” MUST BE CONTACTED BY A MANAGER:
		" & remoteManagementOrganizationContactInfoDisplay & "

🆔	THE SERIAL NUMBER FOR THIS MAC IS “" & serialNumber & "”



	     📝     THIS MAC AND CONTACT INFO HAS BEEN LOGGED     ✅" buttons {remoteManagementDialogButton} with title "Remote Management Enabled"
								tell application id "com.apple.systemevents" to shut down with state saving preference
								
								quit
								delay 10
							else if ((remoteManagementOutput does not contain "Error fetching Device Enrollment configuration") or (remoteManagementOutput contains "Client is not DEP enabled.") or (remoteManagementOutput contains "Bad response from apsd: Connection interrupted")) then -- NOTE: This "Bad response from apsd" error will often be returned when the device IS NOT Remote Managed, so don't show it as an error so that technicians don't get confused.
								if (remoteManagedMacIsAlreadyLogged) then
									set markPreviouslyRemoteManagedMacAsRemovedCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED MARK PREVIOUSLY REMOTE MANAGED MAC AS REMOVED URL]") & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
									
									repeat
										set markPreviouslyRemoteManagedMacAsRemovedResult to "UNKNOWN ERROR"
										try
											set markPreviouslyRemoteManagedMacAsRemovedResult to (do shell script markPreviouslyRemoteManagedMacAsRemovedCommand)
											if (markPreviouslyRemoteManagedMacAsRemovedResult ends with "REMOVED") then exit repeat
										end try
										
										try
											activate
										end try
										try
											do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
										end try
										display alert "Failed to Mark Previously Remote Managed Mac As Removed

ERROR: " & markPreviouslyRemoteManagedMacAsRemovedResult & "

You must be connected to the internet to be able to mark this previously Remote Managed Mac as removed." message "Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Try Again"} default button 1 as critical giving up after 10
									end repeat
								end if
								
								exit repeat
							else
								try
									activate
								end try
								try
									do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
								end try
								try
									display alert "Cannot Continue Setup

Failed to Check Remote Management" message (remoteManagementOutput & "

This should not have happened, please inform Free Geek I.T.") buttons {"Shut Down", "Try Again"} cancel button 1 default button 2 as critical
								on error
									tell application id "com.apple.systemevents" to shut down with state saving preference
									
									quit
									delay 10
								end try
							end if
						end try
					else
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
						end try
						try
							display alert "Cannot Continue Setup

Failed to Check Remote Management" message "An UNKNOWN ERROR occurred.

This should not have happened, please inform Free Geek I.T." buttons {"Shut Down", "Try Again"} cancel button 1 default button 2 as critical
						on error
							tell application id "com.apple.systemevents" to shut down with state saving preference
							
							quit
							delay 10
						end try
					end if
				end repeat
			end try
		end if
	end try
	
	set bootFilesystemType to "apfs"
	try
		set bootFilesystemType to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :FilesystemType' /dev/stdin <<< \"$(diskutil info -plist /)\"")))
	end try
	
	if (hasT2chip and (bootFilesystemType is not equal to "apfs")) then
		try
			activate
		end try
		try
			do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
		end try
		display alert "Since this Mac has a T2 Security Chip, macOS must be installed on an “APFS” formatted drive." message "Future macOS Updates will not be able to be installed on T2 Macs with macOS installed on a “Mac OS Extended (Journaled)” formatted drive." buttons {"Shut Down"} default button 1 as critical
		
		tell application id "com.apple.systemevents" to shut down with state saving preference
		
		quit
		delay 10
	else if (internalDriveIsNVMe and (not shippedWithNVMeDrive)) then
		try
			activate
		end try
		try
			do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
		end try
		
		set wrongDriveAlertTitle to "This " & shortModelName & " (" & modelIdentifier & ") has an NVMe internal drive installed (" & nvmeDriveModelName & "), but it did not originally ship with an NVMe drive.

Since this Mac did not originally ship with an NVMe drive, it is not fully compatible with using an NVMe drive as its primary internal drive.

You MUST replace the internal drive with a non-NVMe (AHCI) drive before this Mac can be sold."
		
		set wrongDriveAlertMesssage to "The EFI Firmware will never be able to be properly updated when our customers run system updates with an NVMe drive installed as the primary internal drive."
		
		set wrongDriveAlertButtons to {"Shut Down"}
		
		if (isBigSurOrNewer and (not isVenturaOrNewer)) then
			-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
			-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
			
			display dialog (wrongDriveAlertTitle & linefeed & linefeed & linefeed & wrongDriveAlertMesssage) buttons wrongDriveAlertButtons default button 1 with title (name of me) with icon caution
		else
			display alert wrongDriveAlertTitle message wrongDriveAlertMesssage buttons wrongDriveAlertButtons default button 1 as critical
		end if
		
		tell application id "com.apple.systemevents" to shut down with state saving preference
		
		quit
		delay 10
	end if
	
	repeat while (currentEFIfirmwareIsNotInAllowList)
		try
			activate
		end try
		try
			do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
		end try
		
		set updateFirmwareAlertTitle to "macOS has reported that the current EFI Firmware (version " & currentEFIfirmwareVersion & ") IS NOT in the allowed list of EFI Firmware versions (the EFI AllowList).

The EFI Firmware or the EFI AllowList MUST be updated before this Mac can be sold."
		
		set updateFirmwareAlertMesssage to "You should not normally see this alert since the EFI Firmware should have been updated during the installation process.

Although, it is possible to see this alert on first boot if this Mac's EFI Firmware is already newer than what shipped with this version of macOS and the EFI AllowList has not yet been updated from the internet.

If the EFI Firmware version listed above starts with a NUMBER, this is likely an issue of the EFI AllowList needing to be updated. If so, you should make sure you are connected to the internet and then click the “Check Again” button below.

If the EFI Firmware version listed above starts with a LETTER, or you continue seeing this alert after multiple attempts, please inform and deliver this Mac to Free Geek I.T. for further research."
		
		set updateFirwmareAlertButtons to {"Reboot", "Shut Down", "Check Again"}
		
		try
			if (isBigSurOrNewer and (not isVenturaOrNewer)) then
				-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
				-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
				
				display dialog (updateFirmwareAlertTitle & linefeed & linefeed & linefeed & updateFirmwareAlertMesssage) buttons updateFirwmareAlertButtons cancel button 2 default button 3 with title (name of me) with icon caution
			else
				display alert updateFirmwareAlertTitle message updateFirmwareAlertMesssage buttons updateFirwmareAlertButtons cancel button 2 default button 3 as critical
			end if
			
			if ((button returned of result) is not equal to "Reboot") then
				set currentEFIfirmwareIsNotInAllowList to checkEFIfirmwareIsNotInAllowList()
				
				if (not currentEFIfirmwareIsNotInAllowList) then
					try
						do shell script "afplay /System/Library/Sounds/Glass.aiff > /dev/null 2>&1 &"
					end try
				end if
			else
				tell application id "com.apple.systemevents" to restart with state saving preference
				
				quit
				delay 10
			end if
		on error
			tell application id "com.apple.systemevents" to shut down with state saving preference
			
			quit
			delay 10
		end try
	end repeat
	
	if (needsTrimEnabled) then
		try
			activate
		end try
		display dialog "⚠️   This Mac has an internal SSD without TRIM enabled.   ⚠️

👉  TRIM must be enabled for the internal SSD on on this Mac.


🚫  DON'T TOUCH ANYTHING WHILE TRIM IS ENABLING!  🚫


🔄  This Mac will reboot itself after TRIM has been enabled." with title "TRIM Must Be Enabled for Internal SSD" buttons {"OK, Enable TRIM"} default button 1 giving up after 15
		
		set progress description to "🚧	TRIM is being enabled for the internal SSD on this Mac…"
		set progress additional description to "
🚫  DON'T TOUCH ANYTHING WHILE TRIM IS ENABLING!


🔄  This Mac will reboot itself after TRIM has been enabled."
		
		delay 0.2 -- Delay to make sure progress gets updated.
		
		try
			doShellScriptAsAdmin("echo 'y" & linefeed & "y' | trimforce enable")
		end try
	else
		if (modelIdentifier starts with "iMac12,") then
			-- NOTE: DID NOT PRE-REQUEST "Safari" ACCESS ON LAUNCH, since it Safari is only automated for iMac12,Xs which only support up to High Sierra.
			
			try
				try
					activate
				end try
				set highFansAlertReply to display alert "🔊 Can you hear the fans in this iMac running at high speeds?" message "
If this iMac had its hard drive replaced with one that does not have the proper temperature sensor, the fans will be running at full speed. To work around this issue, you can install “SSD Fan Control” to manage fan speeds through software.

If the hard drive was not replaced, and the fans are running high, there may be another issue with this iMac.


	👉 ‼️ PLEASE CONSULT AN INSTRUCTOR BEFORE CONTINUING ‼️ 👈" buttons {"No, Just Close Alert", "Yes, Open “SSD Fan Control” Website"} cancel button 1 default button 2 as critical
				if ((button returned of highFansAlertReply) is equal to "Yes, Open “SSD Fan Control” Website") then
					tell application id "com.apple.Safari"
						try
							activate
						end try
						close every window without saving
					end tell
					
					tell application id "com.apple.systemevents" to keystroke "n" using {shift down, command down} -- Open New Private Window
					
					repeat 10 times
						delay 1
						tell application id "com.apple.Safari"
							if ((count of windows) ≥ 1) then exit repeat -- Make sure New Private Window is Open
						end tell
					end repeat
					
					tell application id "com.apple.systemevents" to keystroke tab -- Tab to take focus out of address field
					
					tell application id "com.apple.Safari"
						set ssdFanControlWebsite to "https://exirion.net/ssdfanctrl/"
						if (application id "com.apple.Safari" is not running) then
							open location ssdFanControlWebsite
							try
								activate
							end try
						else
							try
								activate
							end try
							try
								set URL of front document to ssdFanControlWebsite
							on error
								open location ssdFanControlWebsite
							end try
						end if
						try
							activate
						end try
					end tell
				end if
			end try
		end if
		
		set userLaunchAgentsPath to ((POSIX path of (path to library folder from user domain)) & "LaunchAgents/")
		
		try
			((userLaunchAgentsPath as POSIX file) as alias)
		on error
			try
				tell application id "com.apple.finder" to make new folder at (path to library folder from user domain) with properties {name:"LaunchAgents"}
			end try
		end try
		
		try
			do shell script "mkdir " & (quoted form of buildInfoPath)
		end try
		try
			-- Let Demo Helper know that it was launched by Setup so that it will always open QA Helper even if idle time is too short or time since boot is too long (which shouldn't normally happen).
			doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgSetupLaunchedDemoHelper")))
		end try
		
		-- NOTE: The following LaunchAgent is setup to run a signed script which launches the app and has "AssociatedBundleIdentifiers" specified to be properly displayed in the "Login Items" list in "System Settings" on macOS 13 Ventura and newer.
		-- On macOS 12 Monterey and older, the "AssociatedBundleIdentifiers" will just be ignored and the signed launcher script will behave just as if we ran "/usr/bin/open" directly via the LaunchAgent.
		
		set demoHelperLaunchAgentLabel to "org.freegeek.Free-Geek-Demo-Helper"
		set demoHelperLaunchAgentPlistName to (demoHelperLaunchAgentLabel & ".plist")
		set demoHelperUserLaunchAgentPlistPath to (userLaunchAgentsPath & demoHelperLaunchAgentPlistName)
		try
			do shell script ("
/usr/libexec/PlistBuddy \\
	-c 'Add :Label string " & demoHelperLaunchAgentLabel & "' \\
	-c \"Add :Program string " & (quoted form of (demoHelperAppPath & "/Contents/Resources/Launch Free Geek Demo Helper")) & "\" \\
	-c 'Add :AssociatedBundleIdentifiers string " & demoHelperLaunchAgentLabel & "' \\
	-c 'Add :RunAtLoad bool true' \\
	-c 'Add :StartInterval integer 1800' \\
	-c 'Add :StandardOutPath string /dev/null' \\
	-c 'Add :StandardErrorPath string /dev/null' \\
	" & (quoted form of demoHelperUserLaunchAgentPlistPath) & "

launchctl bootstrap gui/$(id -u " & demoUsername & ") " & (quoted form of demoHelperUserLaunchAgentPlistPath))
		end try
		
		set demoHelperDidLaunch to false
		repeat 10 times
			try
				if (application demoHelperAppPath is running) then
					set demoHelperDidLaunch to true
					exit repeat
				end if
			end try
			delay 1
		end repeat
		
		if (demoHelperDidLaunch) then
			try
				repeat while (application demoHelperAppPath is running) -- Wait for Demo Helper to finish so that Setup and Demo Helper don't interfere with eachother.
					delay 0.5
				end repeat
			end try
		end if
		
		do shell script ("launchctl bootout gui/$(id -u " & demoUsername & ")/org.freegeek.Free-Geek-Setup; rm -f " & (quoted form of (userLaunchAgentsPath & "org.freegeek.Free-Geek-Setup.plist")))
		
		try
			set pathToMe to (POSIX path of (path to me))
			if ((offset of ".app" in pathToMe) > 0) then
				do shell script ("tccutil reset All " & currentBundleIdentifier & "; rm -rf " & (quoted form of pathToMe)) -- Resetting TCC for specific bundle IDs should work on Mojave and newer, but does not actually work on Mojave because of a bug (http://www.openradar.me/6813106), but that's ok since we no longer install Mojave or older anyways.
			end if
		end try
	end if
else
	try
		activate
	end try
	display alert "Cannot Run “" & (name of me) & "”" message "“" & (name of me) & "” must be installed at
“/Users/" & demoUsername & "/Applications/” and run from the “" & demoUsername & "” user account." buttons {"Quit"} default button 1 as critical
end if

on checkEFIfirmwareIsNotInAllowList()
	set efiFirmwareIsNotInAllowList to false
	
	set efiCheckOutputPath to (tmpPath & "efiCheckOutput.txt")
	do shell script "defaults delete eficheck; rm -f " & (quoted form of efiCheckOutputPath)
	try
		((("/usr/libexec/firmwarecheckers/eficheck/eficheck") as POSIX file) as alias) -- "eficheck" binary has been removed on macOS 14 Sonoma.
		set efiCheckPID to doShellScriptAsAdmin("/usr/libexec/firmwarecheckers/eficheck/eficheck --integrity-check > " & (quoted form of efiCheckOutputPath) & " 2>&1 & echo $!")
		delay 1
		set efiCheckIsRunning to ((do shell script ("ps -p " & efiCheckPID & " > /dev/null 2>&1; echo $?")) as number)
		if (efiCheckIsRunning is equal to 0) then
			repeat
				try -- EFIcheck may open UserNotificationCenter with a "Your computer has detected a potential problem" alert if EFI Firmware is out-of-date.
					if (application id "com.apple.UserNotificationCenter" is running) then
						repeat 60 times
							set clickedDontSendButton to false
							try
								with timeout of 2 seconds
									tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.UserNotificationCenter")
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
									end tell
								end timeout
							end try
							if (not clickedDontSendButton) then exit repeat -- Exit loop after NOT clicked to be sure ALL windows have been closed.
							delay 0.5
						end repeat
					end if
				end try
				
				set efiCheckIsRunning to ((do shell script ("ps -p " & efiCheckPID & " > /dev/null 2>&1; echo $?")) as number)
				delay 0.5
				if (efiCheckIsRunning is not equal to 0) then exit repeat
			end repeat
		end if
	end try
	try
		((efiCheckOutputPath as POSIX file) as alias)
		set efiCheckOutput to (do shell script "cat " & (quoted form of efiCheckOutputPath))
		if ((efiCheckOutput is not equal to "") and (efiCheckOutput does not contain "Bad CPU type") and (efiCheckOutput does not contain "system is not supported by eficheck") and ((efiCheckOutput does not contain "Primary allowlist version match found. No changes detected in primary hashes.") or ((efiCheckOutput contains "SEC Version") and (efiCheckOutput does not contain "SEC allowlist version match found. No changes detected in SEC hashes.")))) then
			set efiFirmwareIsNotInAllowList to true
		end if
	end try
	do shell script "rm -f " & (quoted form of efiCheckOutputPath)
	
	return efiFirmwareIsNotInAllowList
end checkEFIfirmwareIsNotInAllowList

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

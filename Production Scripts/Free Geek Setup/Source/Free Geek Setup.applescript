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


global adminUsername, adminPassword, tmpPath -- Needs to be accessible in checkEFIfirmwareIsNotInAllowList function and later in code.

set adminUsername to "fg-admin"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set demoUsername to "fg-demo"
set demoPassword to "freegeek"

set AppleScript's text item delimiters to ""
set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.


if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
		set isBigSurElevenDotThreeOrNewer to (systemVersion ≥ "11.3") -- For "nvram -c" on Apple Silicon
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
		
		-- If launched by Automation Guide, Accessibility permissions should already be granted, but we still want to check for System Preferences Automation permission.
		(((buildInfoPath & ".fgAutomationGuideRunning") as POSIX file) as alias)
		error "fgAutomationGuideRunning" -- throw this error if file DOES exist.
	on error (assistiveAccessTestErrorMessage)
		if (((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) or (assistiveAccessTestErrorMessage is equal to "fgAutomationGuideRunning")) then
			if (isMojaveOrNewer) then
				-- NOTE: DO NOT NEED TO REQUEST "Safari" ACCESS, since it Safari is only automated for iMac12,Xs which only support up to High Sierra.
				
				if (isBigSurOrNewer) then
					-- NOTE: Only need to automate System Preferences when reset Snapshot created, and on Big Sur or newer (since mounting Snapshot does not help on Catalina).
					try
						(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias)
						
						try
							tell application "System Preferences" to every window
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
					end try
				end if
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
						do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
					end try
				end try
				quit
				delay 10
			end if
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
				(((buildInfoPath & ".fgAutomationGuideDid-org.freegeek.Free-Geek-Demo-Helper") as POSIX file) as alias)
				
				try -- If did all apps, delete all Automation Guide flags and continue setup
					do shell script ("rm -f " & (quoted form of (buildInfoPath & ".fgAutomationGuide")) & "*") user name adminUsername password adminPassword with administrator privileges
				end try
			on error
				try
					-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
					do shell script "open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app'"
				end try
			end try
		on error
			try
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a " & (quoted form of ("/Users/" & demoUsername & "/Applications/Cleanup After QA Complete.app"))
			end try
		end try
		
		(((buildInfoPath & ".fgAutomationGuideRunning") as POSIX file) as alias) -- Will error and not quit if flag no longer exists if we're done with the Automation Guide cycle.
		
		quit
		delay 10
	end try
	
	
	try
		activate
	end try
	set progress total steps to -1
	set progress completed steps to 0
	set progress description to "🚧	" & (name of me) & " is Preparing this Mac…"
	set progress additional description to "
🚫	DO NOT TOUCH THIS MAC WHILE IT IS BEING SET UP"
	
	try
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as string) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as string) is equal to "NSButton" and ((thisProgressWindowSubView's title() as string) is equal to "Stop")) then
							(thisProgressWindowSubView's setEnabled:false)
							
							exit repeat
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
	
	set fgSetupLaunchAgentPlistName to "org.freegeek.Free-Geek-Setup.plist"
	set fgSetupUserLaunchAgentPlistPath to (userLaunchAgentsPath & fgSetupLaunchAgentPlistName)
	
	try
		((userLaunchAgentsPath as POSIX file) as alias)
	on error
		try
			tell application "Finder" to make new folder at (path to library folder from user domain) with properties {name:"LaunchAgents"}
		end try
	end try
	
	set fgSetupUserLaunchAgentPlistContents to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>Label</key>
	<string>org.freegeek.Free-Geek-Setup</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-n</string>
		<string>-a</string>
		<string>/Users/" & demoUsername & "/Applications/" & (name of me) & ".app</string>
	</array>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>"
	set needsToWriteFgSetupUserLaunchAgentPlistFile to false
	try
		((fgSetupUserLaunchAgentPlistPath as POSIX file) as alias)
		set currentFgSetupUserLaunchAgentPlistContents to (read (fgSetupUserLaunchAgentPlistPath as POSIX file))
		if (currentFgSetupUserLaunchAgentPlistContents is not equal to fgSetupUserLaunchAgentPlistContents) then
			set needsToWriteFgSetupUserLaunchAgentPlistFile to true
			try
				do shell script "launchctl unload " & (quoted form of fgSetupUserLaunchAgentPlistPath)
			end try
		end if
	on error
		set needsToWriteFgSetupUserLaunchAgentPlistFile to true
		try
			tell application "Finder" to make new file at (userLaunchAgentsPath as POSIX file) with properties {name:fgSetupLaunchAgentPlistName}
		end try
	end try
	if (needsToWriteFgSetupUserLaunchAgentPlistFile) then
		try
			set openedFgSetupUserLaunchAgentPlistFile to open for access (fgSetupUserLaunchAgentPlistPath as POSIX file) with write permission
			set eof of openedFgSetupUserLaunchAgentPlistFile to 0
			write fgSetupUserLaunchAgentPlistContents to openedFgSetupUserLaunchAgentPlistFile starting at eof
			close access openedFgSetupUserLaunchAgentPlistFile
		on error
			try
				close access (fgSetupUserLaunchAgentPlistPath as POSIX file)
			end try
		end try
		try
			do shell script "launchctl load " & (quoted form of fgSetupUserLaunchAgentPlistPath)
		end try
	end if
	
	
	try
		do shell script ("rm -f /Users/" & adminUsername & "/Library/Preferences/ByHost/*") user name adminUsername password adminPassword with administrator privileges
	end try
	try
		do shell script ("rm -f /Users/" & demoUsername & "/Library/Preferences/ByHost/*")
	end try
	
	
	set shouldRunDemoHelper to true -- Run Demo Helper once before any updates are done.
	try
		(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
		set shouldRunDemoHelper to false -- Don't re-run Demo Helper if only other apps were updated.
	end try
	
	if (shouldRunDemoHelper) then
		try
			-- Let Demo Helper know that it was launched by Setup so that it will always open QA Helper even if idle time is too short or time since boot is too long (which can happen on Big Sur because of Automation Guide).
			do shell script ("touch " & (quoted form of (buildInfoPath & ".fgSetupLaunchedDemoHelper"))) user name adminUsername password adminPassword with administrator privileges
		end try
		
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app'" -- Launch Demo Helper once first (even on source drive) before any other long processes start and any situations that may cause Setup to not finish. Demo Helper will be set to auto-launch after Setup is finished.
			
			set demoHelperDidLaunch to false
			repeat 10 times
				try
					if (application ("/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app") is running) then
						set demoHelperDidLaunch to true
						exit repeat
					end if
				end try
				delay 1
			end repeat
			
			if (demoHelperDidLaunch) then
				try
					repeat while (application ("/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app") is running) -- Wait for Demo Helper to finish so that Setup and Demo Helper don't interfere with eachother.
						delay 0.5
					end repeat
				end try
			end if
		end try
	end if
	
	-- GRANT FREE GEEK SNAPSHOT HELPER FULL DISK ACCESS (so that fg-snapshot-preserver does not need to manipulate the date, which could cause problems when the date get far out of sync)
	try
		((("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") as POSIX file) as alias)
		
		try
			(("/Users/Shared/.fg-snapshot-preserver" as POSIX file) as alias)
			
			set shouldGrantSnapshotHelperFullDiskAccess to true
			
			if (not isBigSurOrNewer) then
				-- DO NOT bother granting "Free Geek Snapshot Helper" Full Disk Access on Catalin since mounting the Snapshot does not help (see CAVEAT notes in fg-snapshot-preserver).
				set shouldGrantSnapshotHelperFullDiskAccess to false
			else
				try
					(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
					set shouldGrantSnapshotHelperFullDiskAccess to false -- Don't need to re-grant Snapshot Helper Full Disk Access after updating other apps.
					
					try
						(((buildInfoPath & ".fgUpdaterJustUpdated-org.freegeek.Free-Geek-Setup") as POSIX file) as alias)
						set shouldGrantSnapshotHelperFullDiskAccess to true -- Unless Setup (this app) was just updated and could possibly contain bug fixes in the granting Snapshot Helper Full Disk Access code.
					end try
				end try
			end if
			
			if (shouldGrantSnapshotHelperFullDiskAccess) then
				repeat 15 times
					-- Launch "Free Geek Snapshot Helper" to be sure macOS has added it to the Full Disk Access list and the automation only needs to check the box instead of adding it to the list.
					try
						-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
						do shell script "open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app'"
						
						set snapshotHelperDidLaunch to false
						repeat 10 times
							try
								if (application ("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") is running) then
									set snapshotHelperDidLaunch to true
									exit repeat
								end if
							end try
							delay 1
						end repeat
						
						if (snapshotHelperDidLaunch) then
							try
								repeat while (application ("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app") is running) -- Wait for Snapshot Helper to quit so that System Preferences will not prompt to quit it when granted Full Disk Access.
									delay 0.5
								end repeat
							end try
						end if
					end try
					
					try
						(("/Users/Shared/.fgResetSnapshotCreated" as POSIX file) as alias) -- Do not bother granting Full Disk Access if the Snapshot was lost, in which case Snapshot Helper will just be used to display an error.
						
						set snapshotHelperFullDiskAccessCheckboxValue to false
						
						try
							tell application "System Preferences"
								repeat 180 times -- Wait for Security pane to load
									try
										activate
									end try
									reveal ((anchor "Privacy_AllFiles") of (pane id "com.apple.preference.security"))
									delay 1
									if ((name of window 1) is "Security & Privacy") then exit repeat
								end repeat
							end tell
							tell application "System Events" to tell application process "System Preferences"
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
												-- As of beta 1, for some reason this sheet on Monterey will only show that it has 1 text field until the 2nd text field has been focused, so focus it by tabbing.
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
										repeat with thisFullDiskAccessRow in (every row of table 1 of scroll area 1 of group 1 of tab group 1 of window 1)
											if ((name of UI element 1 of thisFullDiskAccessRow) is equal to "Free Geek Snapshot Helper") then
												set snapshotHelperFullDiskAccessCheckbox to (checkbox 1 of UI element 1 of thisFullDiskAccessRow)
												if ((snapshotHelperFullDiskAccessCheckbox's value as boolean) is false) then
													set frontmost to true
													click snapshotHelperFullDiskAccessCheckbox
													
													-- Should not be running, but in case it is, dismiss the relaunch prompt
													repeat 5 times -- Wait for relaunch prompt
														delay 0.5
														if ((number of sheets of window (number of windows)) is 1) then exit repeat
														delay 0.5
													end repeat
													
													if ((number of sheets of window (number of windows)) is 1) then
														set frontmost to true
														
														repeat with thisSheetButton in (buttons of sheet 1 of window (number of windows))
															if ((name of thisSheetButton) is equal to "Later") then
																set frontmost to true
																click thisSheetButton
																exit repeat
															end if
														end repeat
														
														if ((number of sheets of window (number of windows)) is 1) then
															repeat 5 times -- Wait for relaunch prompt to be gone
																delay 0.5
																if ((number of sheets of window (number of windows)) is 0) then exit repeat
																delay 0.5
															end repeat
														end if
													end if
												end if
												
												set snapshotHelperFullDiskAccessCheckboxValue to (snapshotHelperFullDiskAccessCheckbox's value as boolean)
												exit repeat
											end if
										end repeat
										
										exit repeat
									end if
								end repeat
							end tell
						end try
						
						try
							with timeout of 1 second
								tell application "System Preferences" to quit
							end timeout
						end try
						
						try
							activate
						end try
						
						if (snapshotHelperFullDiskAccessCheckboxValue is true) then
							try
								-- Run fg-snapshot-preserver after Snapshot Helper has been granted Full Disk Access to the get the reset Snapshot mounted as soon as possible,
								-- so that the date can be set correctly before running Free Geek Updater or eficheck which can fail if the date is not correct.
								do shell script "/Users/Shared/.fg-snapshot-preserver/fg-snapshot-preserver.sh" user name adminUsername password adminPassword with administrator privileges
							end try
							exit repeat
						end if
					on error
						exit repeat
					end try
				end repeat
				
				try
					activate
				end try
			end if
		on error
			-- Delete "Free Geek Snapshot Helper" if ".fg-snapshot-preserver" doesn't exist, which means we're on High Sierra or Mojave.
			do shell script "rm -rf " & (quoted form of ("/Users/" & demoUsername & "/Applications/Free Geek Snapshot Helper.app")) user name adminUsername password adminPassword with administrator privileges
		end try
	end try
	
	
	set freeGeekUpdaterExists to false
	try
		((("/Users/" & demoUsername & "/Applications/Free Geek Updater.app") as POSIX file) as alias)
		set freeGeekUpdaterExists to true
	end try
	
	try
		if (freeGeekUpdaterExists) then
			(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- If just ran updater, then continue with setup. If not, we will launch updater.
			
			try
				do shell script ("rm -f " & (quoted form of (buildInfoPath & ".fgUpdater")) & "*") user name adminUsername password adminPassword with administrator privileges
			end try
		end if
		
		-- Wait for internet before checking EFI Firmware since AllowList may need to be update, and before installing Rosetta on Apple Silicon, as well as before launching QA Helper (if on source drive) to ensure that QA Helper can always update itself to the latest version.
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
			if (((do shell script "sysctl -in hw.optional.arm64") is equal to "1") and ((do shell script "file '/Users/" & demoUsername & "/Applications/QA Helper.app/Contents/MacOS/QA Helper'") does not contain ("[arm64:Mach-O 64-bit executable arm64]"))) then
				try -- Install Rosetta 2 if on Apple Silicon if QA Helper IS NOT Universal since it will need it to be able to run.
					-- Starting with Java 17 (which has seperate downloads for Intel and Apple Silicon and normally makes seperate native apps when jpackage is used on each platform), I figured out how to make QA Helper a Univeral Binary, but doesn't hurt to keep this check in place.
					do shell script "softwareupdate --install-rosetta --agree-to-license" user name adminUsername password adminPassword with administrator privileges
				end try
			end if
		end try
		
		-- Always run eficheck first even if on source drive to keep the AllowList up-to-date.
		set currentEFIfirmwareIsNotInAllowList to checkEFIfirmwareIsNotInAllowList()
		
		-- If we're on a real production drive, then check more stuff and set Demo Helper to launch every 30 minutes, etc.
		
		try
			-- DO NOT clear NVRAM if TRIM has been enabled on Catalina with "trimforce enable" because clearing NVRAM will undo it. (The TRIM flag is not stored in NVRAM before Catalina.)
			do shell script "nvram EnableTRIM" user name adminUsername password adminPassword with administrator privileges -- This will error if the flag does not exist.
		on error
			try -- Clear NVRAM if we're not on the source drive (just for house cleaning purposes, this doesn't clear SIP).
				if (isBigSurElevenDotThreeOrNewer or (do shell script "sysctl -in hw.optional.arm64" is not equal to "1")) then
					-- ALSO, do not clear NVRAM on Apple Silicon IF OLDER THAN 11.3 since it will cause an error saying that macOS needs to be reinstalled (but can boot properly after re-selecting the internal drive in Startup Disk),
					-- since it deletes important NVRAM keys (such as "boot-volume") which are now protected and cannot be deleted on 11.3 and newer.
					try
						do shell script "nvram -c" user name adminUsername password adminPassword with administrator privileges
					end try
				end if
			end try
		end try
		
		set serialNumber to ""
		try
			set serialNumber to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print 0:IOPlatformSerialNumber' /dev/stdin <<< \"$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)\"")))
		end try
		
		if (serialNumber is not equal to "") then
			try
				do shell script "ping -t 5 -c 1 www.apple.com" -- Only try to get DEP status if we have internet.
				
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
				
				if (remoteManagementOutput contains " - Request too soon.") then -- macOS 12.3 adds client side "profiles show" rate limiting of once every 23 hours: https://derflounder.wordpress.com/2022/03/22/profiles-command-includes-client-side-rate-limitation-for-certain-functions-on-macos-12-3/
					try
						set remoteManagementOutput to (do shell script ("cat " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))))
					end try
				else if (remoteManagementOutput is not equal to "") then -- So always cache the last "profiles show" output so we can show the last valid results in case it's checked again within 23 hours.
					try
						do shell script ("mkdir " & (quoted form of buildInfoPath))
					end try
					try
						do shell script ("echo " & (quoted form of remoteManagementOutput) & " > " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))) with administrator privileges -- DO NOT specify username and password in case it was prompted for. This will still work within a short time of the last valid admin permissions run though.
					end try
				end if
				
				if (remoteManagementOutput contains " - Request too soon.") then -- Don't allow setup if rate limited and there was no previous cached output to use.
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
					display alert ("Cannot Continue Setup

Unable to Check Remote Management Because of Once Every 23 Hours Rate Limiting

Next check will be allowed " & nextAllowedProfilesShowTime & ".") message "This should not have happened, please inform Free Geek I.T." buttons {"Shut Down"} as critical
					tell application "System Events" to shut down with state saving preference
					
					quit
					delay 10
				else if (remoteManagementOutput is not equal to "") then
					try
						set remoteManagementOutputParts to (paragraphs of remoteManagementOutput)
						
						if ((count of remoteManagementOutputParts) > 3) then
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
								set AppleScript's text item delimiters to (linefeed & tab & tab)
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
						end if
					end try
				end if
			end try
		end if
		
		try
			if ((do shell script "csrutil status") is not equal to "System Integrity Protection status: enabled.") then
				set shouldReboot to true
				try
					try
						activate
					end try
					try
						do shell script "afplay /System/Library/Sounds/Basso.aiff"
					end try
					set shutDownDialogButton to "              Shut Down              "
					set rebootDialogButton to "              Reboot              "
					-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
					if (isCatalinaOrNewer) then
						set shutDownDialogButton to "Shut Down                            "
						set rebootDialogButton to "Reboot                            "
					end if
					display dialog "⚠️	System Integrity Protection IS NOT Enabled


‼️	System Integrity Protection (SIP) MUST be re-enabled.

❌	This Mac CANNOT BE SOLD until SIP is enabled.

👉	The SIP setting is stored in NVRAM.

🔄	To re-enable it, all you need to do is
	reset the NVRAM by holding the
	“Option+Command+P+R” key combo
	while rebooting this Mac." buttons {shutDownDialogButton, rebootDialogButton} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				on error
					set shouldReboot to false
				end try
				
				try
					set rebootOrShutdownNote to "when you next start up this Mac"
					if (shouldReboot) then set rebootOrShutdownNote to "while this Mac reboots"
					
					set rebootOrShutdown to "shut down"
					if (shouldReboot) then set rebootOrShutdown to "reboot"
					
					set rebootOrShutdownButton to "Shut Down Now"
					if (shouldReboot) then set rebootOrShutdownButton to "Reboot Now"
					
					try
						activate
					end try
					display dialog "‼️	Remember to hold the
	“Option+Command+P+R” key combo
	" & rebootOrShutdownNote & "
	until you hear at least 2 startup sounds.


🔄	This Mac will " & rebootOrShutdown & " in 15 seconds…" buttons rebootOrShutdownButton default button 1 with title (name of me) with icon dialogIconName giving up after 15
					
					-- Quit all apps before rebooting or shutting down
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
					
					if (shouldReboot) then
						tell application "System Events" to restart with state saving preference
					else
						tell application "System Events" to shut down with state saving preference
					end if
					
					quit
					delay 10
				end try
			end if
		end try
		
		set modelIdentifier to "UNKNOWN"
		set currentEFIfirmwareVersion to "UNKNOWN-EFI-FIRMWARE-VERSION"
		set shippedWithNVMeDrive to false
		set needsTrimEnabled to false
		set internalDriveIsNVMe to false
		set isT2mac to false
		
		set hardwareAndDriveInfoPath to tmpPath & "hardwareAndDriveInfo.plist"
		repeat 30 times
			try
				do shell script "system_profiler -xml SPHardwareDataType SPiBridgeDataType SPSerialATADataType SPNVMeDataType > " & (quoted form of hardwareAndDriveInfoPath)
				tell application "System Events" to tell property list file hardwareAndDriveInfoPath
					repeat with i from 1 to (number of property list items)
						set thisDataTypeProperties to (item i of property list items)
						set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as string)
						if (thisDataType is equal to "SPHardwareDataType") then
							set hardwareItems to (first property list item of property list item "_items" of thisDataTypeProperties)
							set shortModelName to ((value of property list item "machine_name" of hardwareItems) as string)
							set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as string)
							set currentEFIfirmwareVersion to ((first word of ((value of property list item "boot_rom_version" of hardwareItems) as string)) as string) -- T2 Mac's have boot_rom_version's like "1037.100.362.0.0 (iBridge: 17.16.14281.0.0,0)" but we only care about the first part.
							set modelIdentifierNumber to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -dc '[:digit:],'")
							set AppleScript's text item delimiters to ","
							set modelNumberParts to (every text item of modelIdentifierNumber)
							set modelIdentifierMajorNumber to ((item 1 of modelNumberParts) as number)
							set modelIdentifierMinorNumber to ((last item of modelNumberParts) as number)
							
							if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 18)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 13)) or ((shortModelName is equal to "MacBook Air") and ((modelIdentifierMajorNumber ≥ 8) or ((modelIdentifierMajorNumber = 7) and (modelIdentifierMinorNumber = 1)))) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 7)) or (shortModelName is equal to "iMac Pro")) then set shippedWithNVMeDrive to true
						else if (thisDataType is equal to "SPiBridgeDataType") then
							try
								set iBridgeItems to (first property list item of property list item "_items" of thisDataTypeProperties) -- Will just error for empty _items array when not a T1 or T2 Mac.
								set iBridgeModelName to ((value of property list item "ibridge_model_name" of iBridgeItems) as string)
								if (iBridgeModelName contains " T2 ") then set isT2mac to true
							end try
						else if ((thisDataType is equal to "SPSerialATADataType") or (thisDataType is equal to "SPNVMeDataType")) then
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
												set internalDriveIsNVMe to true
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
				do shell script "rm -f " & (quoted form of hardwareAndDriveInfoPath) -- Delete incase User Canceled
				delay 1 -- Wait and try again because it seems to fail sometimes when run on login.
			end try
		end repeat
		do shell script "rm -f " & (quoted form of hardwareAndDriveInfoPath)
		
		set bootFilesystemType to "apfs"
		try
			set bootFilesystemType to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :FilesystemType' /dev/stdin <<< \"$(diskutil info -plist /)\"")))
		end try
		
		if (isT2mac and (bootFilesystemType is not equal to "apfs")) then
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			display alert "Since this Mac has a T2 Security Chip, macOS must be installed on an “APFS” formatted drive." message "Future macOS Updates will not be able to be installed on T2 Macs with macOS installed on a “Mac OS Extended (Journaled)” formatted drive." buttons {"Shut Down"} default button 1 as critical
			
			tell application "System Events" to shut down with state saving preference
			
			quit
			delay 10
		else if (internalDriveIsNVMe and (not shippedWithNVMeDrive)) then
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			display dialog "This Mac has an NVMe internal drive installed, but it did not originally ship with an NVMe drive.

Since this Mac did not originally ship with an NVMe drive, it is not fully compatible with using an NVMe drive as its primary internal drive.

You MUST replace the internal drive with a non-NVMe (AHCI) drive before this Mac can be sold.


The EFI Firmware will never be able to be properly updated when our customers run system updates with an NVMe drive installed as the primary internal drive." buttons {"Shut Down"} default button 1 with title (name of me) with icon dialogIconName
			
			tell application "System Events" to shut down with state saving preference
			
			quit
			delay 10
		end if
		
		repeat while (currentEFIfirmwareIsNotInAllowList)
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			
			set updateFirmwareMesssage to "You should not normally see this alert since the EFI Firmware should have been updated during the installation process.

Although, it is possible to see this alert on first boot if this Mac's EFI Firmware is already newer than what shipped with this version of macOS and the EFI AllowList has not yet been updated from the internet.

If the EFI Firmware version listed above starts with a NUMBER, this is likely an issue of the EFI AllowList needing to be updated. If so, you should make sure you are connected to the internet and then click the “Check Again” button below.

If the EFI Firmware version listed above starts with a LETTER, or you continue seeing this alert after multiple attempts, please inform and deliver this Mac to Free Geek I.T. for further research."
			
			set installationWasCloned to true
			try
				(((buildInfoPath & "Prepare OS Log.txt") as POSIX file) as alias)
				set installationWasCloned to false
			end try
			
			if (installationWasCloned) then
				set updateFirmwareMesssage to "YOU MUST reboot into the “Mac Test Boot” drive to update the EFI Firmware with “Firmware Checker”.

If you have already successfully updated the EFI Firmware with “Firmware Checker” and you are still seeing this alert, please inform and deliver this Mac to Free Geek I.T. for further research."
				
				if (modelIdentifier is equal to "MacPro5,1") then
					set updateFirmwareMesssage to "Unlike other Mac models, MacPro5,1 (Mid 2010 & Mid 2012) EFI Firmware cannot be updated by “Firmware Checker” in the “Mac Test Boot” drive.

YOU MUST manually update this Mac's EFI Firmware by using a full macOS 10.13 High Sierra installer, or by booting into Recovery Mode.

If you have already successfully updated the EFI Firmware and you are still seeing this alert, please inform and deliver this Mac to Free Geek I.T. for further research."
				end if
			end if
			
			try
				display dialog "macOS has reported that the current EFI Firmware (version " & currentEFIfirmwareVersion & ") IS NOT in the allowed list of EFI Firmware versions (the EFI AllowList).

The EFI Firmware or the EFI AllowList MUST be updated before this Mac can be sold.


" & updateFirmwareMesssage buttons {"Reboot", "Shut Down", "Check Again"} cancel button 2 default button 3 with title (name of me) with icon dialogIconName
				
				if ((button returned of result) is not equal to "Reboot") then
					set currentEFIfirmwareIsNotInAllowList to checkEFIfirmwareIsNotInAllowList()
					
					if (not currentEFIfirmwareIsNotInAllowList) then
						try
							do shell script "afplay /System/Library/Sounds/Glass.aiff"
						end try
					end if
				else
					tell application "System Events" to restart with state saving preference
					
					quit
					delay 10
				end if
			on error
				tell application "System Events" to shut down with state saving preference
				
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
				do shell script "echo 'y
y' | trimforce enable" user name adminUsername password adminPassword with administrator privileges
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
						tell application "Safari"
							try
								activate
							end try
							close every window without saving
						end tell
						
						tell application "System Events" to keystroke "n" using {shift down, command down} -- Open New Private Window
						
						repeat 10 times
							delay 1
							tell application "Safari"
								if ((count of windows) ≥ 1) then exit repeat -- Make sure New Private Window is Open
							end tell
						end repeat
						
						tell application "System Events" to keystroke tab -- Tab to take focus out of address field
						
						tell application "Safari"
							set ssdFanControlWebsite to "https://exirion.net/ssdfanctrl/"
							if (application "Safari" is not running) then
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
			
			try
				((userLaunchAgentsPath as POSIX file) as alias)
			on error
				try
					tell application "Finder" to make new folder at (path to library folder from user domain) with properties {name:"LaunchAgents"}
				end try
			end try
			
			set demoHelperLaunchAgentPlistName to "org.freegeek.Free-Geek-Demo-Helper.plist"
			set demoHelperUserLaunchAgentPlistPath to userLaunchAgentsPath & demoHelperLaunchAgentPlistName
			set demoHelperUserLaunchAgentPlistContents to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>Label</key>
	<string>org.freegeek.Free-Geek-Demo-Helper</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-n</string>
		<string>-a</string>
		<string>/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app</string>
	</array>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>1800</integer>
</dict>
</plist>"
			set needsToWriteDemoHelperPlistFile to false
			try
				((demoHelperUserLaunchAgentPlistPath as POSIX file) as alias)
				set currentDemoHelperUserLaunchAgentPlistContents to (read (demoHelperUserLaunchAgentPlistPath as POSIX file))
				if (currentDemoHelperUserLaunchAgentPlistContents is not equal to demoHelperUserLaunchAgentPlistContents) then
					set needsToWriteDemoHelperPlistFile to true
					try
						do shell script "launchctl unload " & (quoted form of demoHelperUserLaunchAgentPlistPath)
					end try
				end if
			on error
				set needsToWriteDemoHelperPlistFile to true
				try
					tell application "Finder" to make new file at (userLaunchAgentsPath as POSIX file) with properties {name:demoHelperLaunchAgentPlistName}
				end try
			end try
			
			try
				-- Let Demo Helper know that it was launched by Setup so that it will always open QA Helper even if idle time is too short or time since boot is too long (which can happen on Big Sur because of Automation Guide).
				do shell script ("touch " & (quoted form of (buildInfoPath & ".fgSetupLaunchedDemoHelper"))) user name adminUsername password adminPassword with administrator privileges
			end try
			
			if (needsToWriteDemoHelperPlistFile) then
				try
					set openedDemoHelperUserLaunchAgentPlistFile to open for access (demoHelperUserLaunchAgentPlistPath as POSIX file) with write permission
					set eof of openedDemoHelperUserLaunchAgentPlistFile to 0
					write demoHelperUserLaunchAgentPlistContents to openedDemoHelperUserLaunchAgentPlistFile starting at eof
					close access openedDemoHelperUserLaunchAgentPlistFile
				on error
					try
						close access (demoHelperUserLaunchAgentPlistPath as POSIX file)
					end try
				end try
				try
					do shell script "launchctl load " & (quoted form of demoHelperUserLaunchAgentPlistPath)
				end try
			else
				try
					-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
					do shell script "open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app'"
				end try
			end if
			
			set demoHelperDidLaunch to false
			repeat 10 times
				try
					if (application ("/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app") is running) then
						set demoHelperDidLaunch to true
						exit repeat
					end if
				end try
				delay 1
			end repeat
			
			if (demoHelperDidLaunch) then
				try
					repeat while (application ("/Users/" & demoUsername & "/Applications/Free Geek Demo Helper.app") is running) -- Wait for Demo Helper to finish so that Setup and Demo Helper don't interfere with eachother.
						delay 0.5
					end repeat
				end try
			end if
			
			do shell script ("launchctl unload " & (quoted form of fgSetupUserLaunchAgentPlistPath) & "; rm -f " & (quoted form of fgSetupUserLaunchAgentPlistPath))
			try
				set pathToMe to (POSIX path of (path to me))
				if ((offset of ".app" in pathToMe) > 0) then
					try
						do shell script "tccutil reset All org.freegeek.Free-Geek-Setup; rm -rf " & (quoted form of pathToMe) user name adminUsername password adminPassword with administrator privileges
					end try
				end if
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
				
				-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
				do shell script "open -n -a '/Users/" & demoUsername & "/Applications/Free Geek Updater.app'"
			end if
		end try
	end try
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
		set efiCheckPID to (do shell script "/usr/libexec/firmwarecheckers/eficheck/eficheck --integrity-check > " & (quoted form of efiCheckOutputPath) & " 2>&1 & echo $!" user name adminUsername password adminPassword with administrator privileges)
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

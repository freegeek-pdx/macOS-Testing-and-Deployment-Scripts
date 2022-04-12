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

-- App Icon is “Guide Dog” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

-- Build Flag: LSUIElement

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
	
	set intendedAppName to "Automation Guide" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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


set demoUsername to "fg-demo"
set demoPassword to "freegeek"


if (((short user name of (system info)) is equal to demoUsername) and ((POSIX path of (path to me)) is equal to ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app/"))) then
	set systemVersion to (system version of (system info))
	considering numeric strings
		set isMojaveOrNewer to (systemVersion ≥ "10.14")
		set isCatalinaOrNewer to (systemVersion ≥ "10.15")
		set isBigSurOrNewer to (systemVersion ≥ "11.0")
	end considering
	
	try
		if (application "/System/Library/CoreServices/KeyboardSetupAssistant.app" is running) then
			with timeout of 1 second
				tell application "KeyboardSetupAssistant" to quit
			end timeout
		end if
	end try
	
	-- SET TOUCH BAR SETTINGS TO *NOT* BE "App Controls" (because AppleScript alert buttons don't update properly)
	-- This is also done in "Free Geek Demo Helper" but do it here as well so it gets set on first boot.
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
				do shell script "defaults write com.apple.touchbar.agent PresentationModeGlobal fullControlStrip; defaults write com.apple.touchbar.agent PresentationModeFnModes -dict fullControlStrip functionKeys; killall ControlStrip"
			end try
		end if
	end try
	
	try
		-- Unmount any fgMIB, Install macOS, or MacLand Boot drives.
		if (not isBigSurOrNewer) then -- Unless if on Big Sur since don't want technician to need to approve access on removable drives.
			do shell script "for this_installer_volume in '/Volumes/fgMIB'* '/Volumes/Install '* '/Volumes/'*' Boot'*; do if [ -d \"${this_installer_volume}\" ]; then diskutil unmountDisk \"${this_installer_volume}\"; fi done"
		end if
	end try
	
	set freeGeekUpdaterExists to false
	try
		((("/Users/" & demoUsername & "/Applications/Free Geek Updater.app") as POSIX file) as alias)
		set freeGeekUpdaterExists to true
	end try
	
	
	set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
	
	
	set adminUsername to "fg-admin"
	set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"
	
	
	-- Verify admin can do admin things since there is a bug (which has been worked around) when customizing via LaunchDaemon and using "sysadminctl -addUser".
	-- For more information about this bug, see comments in create_user function within fg-prepare-os.
	
	set adminCanDoAdminThings to false
	try
		set adminCanDoAdminThings to ("CAN DO ADMIN THINGS" is equal to (do shell script "echo 'CAN DO ADMIN THINGS'" user name adminUsername password adminPassword with administrator privileges))
	end try
	
	if (not adminCanDoAdminThings) then
		try
			activate
		end try
		display alert "CRITICAL ERROR:
" & adminUsername & " Does Not Have Admin Privileges" message "Please inform and deliver this Mac to Free Geek I.T." buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
	
	-- demoUsername will be made an Admin and have it's Full Name changed temporarily later during Automation Guide and will be changed back in Automation Guide.
	-- But, make sure it starts a a regular user when Automation Guide is launched in case Automation Guide was quit or the Mac was shut down or rebooted during the process (when still set as admin).
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
	
	set shouldShowStartPrompt to true
	try
		if (freeGeekUpdaterExists) then
			(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias)
			set shouldShowStartPrompt to false
		end if
	end try
	
	set dialogIconName to "applet"
	try
		((((POSIX path of (path to me)) & "Contents/Resources/" & (name of me) & ".icns") as POSIX file) as alias)
		set dialogIconName to (name of me)
	end try
	
	if (shouldShowStartPrompt) then
		set osName to ("macOS " & systemVersion)
		considering numeric strings
			if ((systemVersion ≥ "10.13") and (systemVersion < "10.14")) then
				set osName to "macOS 10.13 High Sierra"
			else if ((systemVersion ≥ "10.14") and (systemVersion < "10.15")) then
				set osName to "macOS 10.14 Mojave"
			else if ((systemVersion ≥ "10.15") and (systemVersion < "10.16")) then
				set osName to "macOS 10.15 Catalina"
			else if ((systemVersion ≥ "11.0") and (systemVersion < "12.0")) then
				set osName to "macOS 11 Big Sur"
			else if ((systemVersion ≥ "12.0") and (systemVersion < "13.0")) then
				set osName to "macOS 12 Monterey"
			end if
		end considering
		
		set laterDialogButton to "         Later         "
		set startDialogButton to "         Start “" & (name of me) & "”         "
		-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
		if (isCatalinaOrNewer) then
			set laterDialogButton to "Later                  "
			set startDialogButton to "Start “" & (name of me) & "”                  "
		end if
		
		set grantAccessibilityFeaturesInfo to "“" & (name of me) & "” will do a bit of automated setup and present another prompt with info on how to grant some Free Geek apps permission to control this computer using Accessibility Features."
		
		set automationGuideInfo to "When you start, " & grantAccessibilityFeaturesInfo
		
		if (isMojaveOrNewer) then
			set automationGuideInfo to "First, you will approve a couple prompts for “" & (name of me) & "” to be able to control and perform actions in other macOS apps.

Then, " & grantAccessibilityFeaturesInfo & "

Finally, you will approve more prompts to allow Free Geek apps to control and perform actions in other macOS apps."
		end if
		
		try
			activate
		end try
		display dialog osName & " has been successfully installed!

Now, a bit of manual setup is required before being able to continue the refurbishment process.

“" & (name of me) & "” is here to help make that as easy as possible, but you will still need to do some manual clicking, typing, and drag-and-dropping.


" & automationGuideInfo buttons {laterDialogButton, startDialogButton} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
		
		delay 1 -- Delay for a second to allow this prompt to close before the automation approval prompt comes up.
	end if
	
	if (isMojaveOrNewer) then
		set needsAutomationAccess to false
		try
			tell application "Finder" to every window -- To prompt for Automation access on Mojave
		on error automationAccessErrorMessage number automationAccessErrorNumber
			if (automationAccessErrorNumber is equal to -1743) then set needsAutomationAccess to true
		end try
		try
			tell application "System Preferences" to every window -- To prompt for Automation access on Mojave
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

• Find “" & (name of me) & "” in the list on the right and turn on the “Finder” and “System Preferences” checkboxes underneath it.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
			end try
			quit
			delay 10
		end if
		
		try
			with timeout of 1 second
				tell application "System Preferences" to quit
			end timeout
		end try
	end if
	
	
	try
		if (freeGeekUpdaterExists) then
			(((buildInfoPath & ".fgUpdaterJustFinished") as POSIX file) as alias) -- If just ran updater, then continue with Automation Guide. If not, we will launch updater.
			try
				do shell script ("rm -f " & (quoted form of (buildInfoPath & ".fgUpdater")) & "*") user name adminUsername password adminPassword with administrator privileges
			end try
		end if
		
		set moreAutmationPromptsInfo to ""
		if (isMojaveOrNewer) then
			set moreAutmationPromptsInfo to " to approve the final prompts to allow Free Geek apps to control and perform actions in other macOS apps"
		end if
		
		set temporaryAdminUsername to "Free Geek TEMPORARY Administrator"
		
		set continueDialogButton to "               Continue to Select Apps & Reveal Accessibility Preferences               "
		set laterDialogButton to "               Later               "
		-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
		if (isCatalinaOrNewer) then
			set continueDialogButton to "Continue to Select Apps & Reveal Accessibility Preferences                              "
			set laterDialogButton to "Later                              "
		end if
		
		set showInstructions to true
		set userDidCompleteManualSteps to false
		
		try
			repeat
				if (showInstructions) then
					try
						activate
					end try
					display dialog "Now, you must grant Free Geek apps permission to control this computer using Accessibility Features.

When you click the “Continue to Select Apps & Reveal Accessibility Preferences” button below, the “System Preferences” app will be opened to the “Accessibility” section of the “Privacy” tab of the “Security & Privacy” preference pane and the “" & demoUsername & "” user “Applications” folder will be opened in “Finder” with the “Free Geek Setup”, “Free Geek Demo Helper”, and “Cleanup After QA Complete” apps selected.


Then, you must manually perform the following 2 steps to grant these 3 apps permission to control this computer using Accessibility Features:

• Click the Lock icon at the bottom left of the “System Preferences” window. Then “" & temporaryAdminUsername & "” will be in the “User Name” field (see NOTE below) and you will just need to enter “" & demoPassword & "” in the “Password” field and then click “Unlock”.

• Drag-and-drop the 3 selected Free Geek apps from “Finder” into the list on the right of the “System Preferences” window.


That's it! After those steps have been performed, you can click the “Continue” button in the next dialog" & moreAutmationPromptsInfo & ". Then, “Free Geek Setup” will run to do some automated setup and “QA Helper” will be opened when this computer is ready for you to take back over with the refurbishment process.

NOTE: The currently logged in “" & demoUsername & "” user will be made an Admin and its Full Name will be changed TEMPORARILY to make this process quick, clear, and easy for you. “" & demoUsername & "” will be removed from the Admin group and its Full Name will be changed back when you click the “Continue” button in the next dialog." buttons {laterDialogButton, continueDialogButton} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				end if
				
				set showInstructions to false
				
				try
					tell application "Finder"
						reveal (path to me)
						tell window 1
							select (every item where ((name is "Free Geek Setup.app") or (name is "Free Geek Demo Helper.app") or (name is "Cleanup After QA Complete.app")))
						end tell
					end tell
				end try
				
				set demoUsernameIsAdmin to false
				try
					set demoUsernameIsAdmin to ((do shell script ("dsmemberutil checkmembership -U " & (quoted form of demoUsername) & " -G 'admin'")) is equal to "user is a member of the group")
				end try
				if (not demoUsernameIsAdmin) then
					try
						do shell script "dseditgroup -o edit -a " & (quoted form of demoUsername) & " -t user admin" user name adminUsername password adminPassword with administrator privileges
					end try
				end if
				
				set demoUsernameIsChanged to false
				try
					set demoUsernameIsChanged to ((do shell script ("id -F " & (quoted form of demoUsername))) is equal to "Free Geek TEMPORARY Administrator")
				end try
				if (not demoUsernameIsChanged) then
					try
						do shell script "dscl . -create " & (quoted form of ("/Users/" & demoUsername)) & " RealName 'Free Geek TEMPORARY Administrator'" user name adminUsername password adminPassword with administrator privileges
					end try
				end if
				
				try
					tell application "System Preferences"
						repeat 180 times -- Wait for Security pane to load
							try
								activate
							end try
							reveal ((anchor "Privacy_Accessibility") of (pane id "com.apple.preference.security"))
							delay 1
							if ((name of window 1) is "Security & Privacy") then exit repeat
						end repeat
					end tell
				end try
				
				-- Use Dialog because I won't want any default button that can be hit accidentally with the Return key.
				try
					activate
				end try
				set continueDialogReply to display dialog "Now, you must grant Free Geek apps permission to control this computer using Accessibility Features as described in the previous dialog. If you need to see those instructions again, click the “Show Instructions Again” button below.

If “System Preferences” is not opened to the “Accessibility” section of the “Privacy” tab of the “Security & Privacy” preference pane or the specified apps are not selected in “Finder”, click the “Select Apps & Reveal Accessibility Preferences Again” button below.


After you've performed the manual steps described in the previous dialog, click the “Continue” button below" & moreAutmationPromptsInfo & ". Then, “Free Geek Setup” will run to do some automated setup and “QA Helper” will be opened when this computer is ready for you to take back over with the refurbishment process.

‼️ DON'T CLICK “Continue” UNTIL YOU'VE DROPPED THE APPS INTO SYSTEM PREFERENCES ‼️" buttons {"Show Instructions Again", "Select Apps & Reveal Accessibility Preferences Again", "Continue"} with title (name of me) with icon dialogIconName
				
				if ((button returned of continueDialogReply) is equal to "Continue") then
					set appsToVerifyAccessibilityPermissions to {"Free Geek Setup", "Free Geek Demo Helper", "Cleanup After QA Complete"}
					
					repeat
						-- Open all 3 apps while Automation Guide is running which while make them report their Accessibility status and then quit.
						repeat with thisAppName in appsToVerifyAccessibilityPermissions
							try
								do shell script ("open -n -a '/Users/" & demoUsername & "/Applications/" & thisAppName & ".app'")
							end try
						end repeat
						
						set AppleScript's text item delimiters to "-"
						
						-- Wait up to 30 seconds for the apps to report their Accessibility status and quit themselves before considering them to not have Accessibility permissions.
						repeat 30 times
							set appsReportedAccessibilityStatus to {}
							repeat with thisAppName in appsToVerifyAccessibilityPermissions
								try
									(((buildInfoPath & ".fgAutomationGuideAccessibilityStatus-org.freegeek." & ((words of thisAppName) as string)) as POSIX file) as alias) -- Will error if file does not exist.
									
									if (application ("/Users/" & demoUsername & "/Applications/" & thisAppName & ".app") is not running) then -- Make sure the app has quit itself before continuing (to no disrupt their next launch after Automation Guide is quit).
										set (end of appsReportedAccessibilityStatus) to thisAppName
									end if
								end try
							end repeat
							
							if ((count of appsReportedAccessibilityStatus) is equal to (count of appsToVerifyAccessibilityPermissions)) then
								exit repeat
							else
								delay 1
							end if
						end repeat
						
						set appsWithAccessibilityPermissions to {}
						repeat with thisAppName in appsToVerifyAccessibilityPermissions
							try
								if ((read ((buildInfoPath & ".fgAutomationGuideAccessibilityStatus-org.freegeek." & ((words of thisAppName) as string)) as POSIX file)) starts with "true") then -- Must check "starts with" since contents will have a empty line at the end.
									set (end of appsWithAccessibilityPermissions) to thisAppName
								end if
							end try
							
							try
								do shell script ("rm -f '" & buildInfoPath & ".fgAutomationGuideAccessibilityStatus-org.freegeek." & ((words of thisAppName) as string) & "'") user name adminUsername password adminPassword with administrator privileges
							end try
						end repeat
						
						if ((count of appsWithAccessibilityPermissions) is equal to (count of appsToVerifyAccessibilityPermissions)) then
							set userDidCompleteManualSteps to true
							exit repeat
						else
							try
								activate
							end try
							try
								display alert "You have not granted the Free Geek apps permission to control this computer using Accessibility Features as described in the previous dialog." buttons {"But I Did, Check Again!", "Show Instructions Again"} cancel button 1 default button 2 as critical
								set showInstructions to true
								exit repeat
							end try
						end if
					end repeat
					
					if (userDidCompleteManualSteps) then
						exit repeat
					end if
				else if ((button returned of continueDialogReply) is equal to "Show Instructions Again") then
					set showInstructions to true
				end if
			end repeat
		end try
		
		try
			with timeout of 1 second
				tell application "System Preferences" to quit
			end timeout
		end try
		
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
		
		if (userDidCompleteManualSteps) then
			do shell script "rm -rf " & (quoted form of ("/Users/" & demoUsername & "/Desktop/" & (name of me) & ".app"))
			
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
			
			tell application "Finder"
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
			
			try
				do shell script "mkdir " & (quoted form of buildInfoPath)
			end try
			try
				do shell script ("touch " & (quoted form of (buildInfoPath & ".fgAutomationGuideRunning"))) user name adminUsername password adminPassword with administrator privileges
			end try
			
			-- Launch Cleanup After QA Complete AFTER Automation Guide is quit so we know it has been deleted.
			do shell script ("
osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"/Users/" & demoUsername & "/Applications/Cleanup After QA Complete.app\\\"\"' > /dev/null 2>&1 &

launchctl unload " & (quoted form of ("/Users/" & demoUsername & "/Library/LaunchAgents/org.freegeek.Automation-Guide.plist")) & "
rm -rf " & (quoted form of ("/Users/" & demoUsername & "/Library/LaunchAgents/org.freegeek.Automation-Guide.plist")) & " " & (quoted form of ("/Users/" & demoUsername & "/Applications/" & (name of me) & ".app")))
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

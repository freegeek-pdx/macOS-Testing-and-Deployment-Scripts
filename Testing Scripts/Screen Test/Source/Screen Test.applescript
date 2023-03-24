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

-- Version: 2023.2.17-1

-- App Icon is “Mauritian Flag” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
	
	set intendedAppName to "Screen Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
		activate
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


try
	(("/Applications/PiXel Check.app" as POSIX file) as alias)
on error
	try
		activate
	end try
	display alert "“Screen Test” requires “PiXel Check”" message "“PiXel Check” must be installed in the “Applications” folder." buttons {"Quit", "Download “PiXel Check”"} cancel button 1 default button 2 as critical
	open location "http://macguitar.me/apps/pixelcheck/"
	quit
	delay 10
end try


set systemVersion to (system version of (system info))
considering numeric strings
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
end considering

if (isMojaveOrNewer) then
	try
		tell application id "com.apple.systemevents" to every window -- To prompt for Automation access on Mojave
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
	end try
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


set testCount to 0

try
	repeat
		set screenTestButtons to {"Quit", "Test Screen"}
		if (testCount ≥ 1) then set screenTestButtons to {"Test Screen Again", "Done"}
		
		set shouldTestScreen to false
		try
			activate
		end try
		try
			display dialog "	🇲🇺	Screen Test will cycle through solid color
		Red, Green, Blue, Black, and White screens.

	🔴	When you start Screen Test, the whole
		screen will first turn solid Red.

	👀	Examine the entire screen carefully, looking for
		any discolorations, dead pixels, or scratches.

	‼️	MAKE NOTE OF ANY ISSUES YOU FIND!

	👇	When you’re finished examining a screen color,
		CLICK ANY KEY to move to the next color and
		repeat your examination and note taking.

	🔎	Look very carefully over the entire screen for
		EACH COLOR as some kinds of screen issues
		will show on some colors and not on others.


	✅	SCREEN TEST PASSED IF:
		⁃ The screen has NO discolorations or hot spots.
		⁃ The screen has NO dead pixels.
		⁃ The screen has NO scratches or delamination.

	❌	SCREEN TEST FAILED IF:
		⁃ The screen has ANY discoloration or hot spots.
		⁃ The screen has ANY dead pixels.
		⁃ The screen has ANY scratches or delamination.


	👉 CONSULT INSTRUCTOR IF SCREEN TEST FAILS ‼️" buttons screenTestButtons cancel button 1 default button 2 with title "Screen Test"
			if ((last text item of screenTestButtons) is equal to "Test Screen") then set shouldTestScreen to true
		on error
			if ((first text item of screenTestButtons) is equal to "Test Screen Again") then set shouldTestScreen to true
		end try
		
		if (shouldTestScreen) then
			repeat
				if (application id ("me.macguitar." & "PiXel-Check") is running) then -- Break up App ID or else build will fail if not found during compilation when app is not installed.
					try
						with timeout of 1 second
							tell application id ("me.macguitar." & "PiXel-Check") to quit
						end timeout
					end try
					delay 1
				else
					exit repeat
				end if
			end repeat
			
			try
				do shell script "open -a '/Applications/PiXel Check.app'"
			end try
			
			tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "me.macguitar.PiXel-Check")
				repeat while ((count of windows) < 1)
					delay 1
				end repeat
				repeat with thisWindow in windows
					if ((name of thisWindow as text) is equal to "PiXel Check") then
						repeat with thisButton in (buttons of thisWindow)
							if ((name of thisButton as text) is equal to "Automatic") then
								click thisButton
								exit repeat
							end if
						end repeat
						exit repeat
					end if
				end repeat
			end tell
			
			try
				tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "me.macguitar.PiXel-Check")
					repeat while ((count of windows) ≥ 2)
						delay 1
					end repeat
				end tell
			end try
			
			try
				with timeout of 1 second
					if (application id ("me.macguitar." & "PiXel-Check") is running) then tell application id ("me.macguitar." & "PiXel-Check") to quit
				end timeout
			end try
			
			set testCount to (testCount + 1)
		else
			exit repeat
		end if
	end repeat
end try

if (testCount ≥ 1) then
	set shortModelName to "Unknown Model"
	try
		set shortModelName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:_items:0:machine_name' /dev/stdin <<< \"$(system_profiler -xml SPHardwareDataType)\"")))
	end try
	if ((words of shortModelName) contains "MacBook") then
		try
			(("/Applications/Trackpad Test.app" as POSIX file) as alias)
			if (application id ("org.freegeek." & "Trackpad-Test") is not running) then -- Break up App ID or else build will fail if not found during compilation when app is not installed.
				try
					activate
				end try
				display alert "
Would you like to launch “Trackpad Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
				do shell script "open -na '/Applications/Trackpad Test.app'"
			end if
		end try
	else
		try
			activate
		end try
		display alert "
The next test is manually testing
this Macs Ports and Disc Drive."
	end if
end if

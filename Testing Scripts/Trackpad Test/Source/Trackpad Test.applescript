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

-- Version: 2022.2.22-1

-- App Icon is “Victory Hand” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
	
	set intendedAppName to "Trackpad Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
		activate
		display alert checkReadOnlyErrorMessage buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try

try
	(("/Applications/FingerMgmt.app" as POSIX file) as alias)
on error
	try
		activate
	end try
	display alert "“Trackpad Test” requires “FingerMgmt”" message "“FingerMgmt” must be installed in the “Applications” folder." buttons {"Quit", "Download “FingerMgmt”"} cancel button 1 default button 2 as critical
	do shell script "open 'https://github.com/jnordberg/FingerMgmt/releases'"
	quit
	delay 10
end try


set dialogIconName to "applet"
try
	((((POSIX path of (path to me)) & "Contents/Resources/" & (name of me) & ".icns") as POSIX file) as alias)
	set dialogIconName to (name of me)
end try

set systemVersion to (system version of (system info))
considering numeric strings
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
end considering

if (isMojaveOrNewer) then
	try
		tell application "System Events" to every window -- To prompt for Automation access on Mojave
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
	end try
end if

try
	tell application "System Events" to tell application process "Finder" to (get windows)
on error (assistiveAccessTestErrorMessage)
	if ((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) then
		if (isMojaveOrNewer) then
			try
				tell application ("Finger" & "Mgmt") to every window -- To prompt for Automation access on Mojave
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
						display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “FingerMgmt” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “FingerMgmt” checkbox underneath it.

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
					tell application ("Finger" & "Mgmt") to quit
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

set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
try
	(((buildInfoPath & ".fgSetupSkipped") as POSIX file) as alias)
	
	try
		do shell script ("mkdir " & (quoted form of buildInfoPath))
	end try
	try
		set AppleScript's text item delimiters to "-"
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as string)))) user name adminUsername password adminPassword with administrator privileges
	end try
	
	try
		-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
		do shell script "open -n -a '/Applications/Test Boot Setup.app'"
	end try
	
	quit
	delay 10
end try


try
	activate
end try
display dialog "	👉	Trackpad Test will guide you through a
		series of 6 Click Tests and 6 Touch Tests.

	☝️	First, you will be presented with 6 Click Tests
		to make sure that the trackpad clicks properly
		in a variety of commonly used trackpad zones.

	⚠️	These click tests WILL NOT detect whether you
		actually clicked within the correct zone of the
		trackpad, it is just a guide for you to test with.

	🚫	If the trackpad doesn't click properly, doesn't
		respond instantly, or feels stiff, sticky, or funky
		in a certain zone, CONSULT AN INSTRUCTOR
		before continuing on with the next tests.


	✌️	After the 6 Click Tests are complete, you'll be
		guided through the 6 Touch Tests.


	‼️	DO NOT USE A MOUSE FOR THESE TESTS  ‼️" buttons {"Quit", "Continue to Click Tests"} cancel button 1 default button 2 with title "Trackpad Test"

repeat
	try
		activate
	end try
	display dialog "				Trackpad Click Test 1 of 6:

 ⬅️     Click Button with Finger in The Middle of Left Edge     ⬅️" buttons {"Click Me with Finger in MIDDLE OF LEFT EDGE of Trackpad"} with title "Trackpad Test"
	
	try
		activate
	end try
	display dialog "				Trackpad Click Test 2 of 6:

		⏺     Click Button with Finger in The Center     ⏺" buttons {"Click Me with Finger in THE CENTER of Trackpad"} with title "Trackpad Test"
	
	try
		activate
	end try
	display dialog "				Trackpad Click Test 3 of 6:

 ➡️     Click Button with Finger in The Middle of Right Edge     ➡️" buttons {"Click Me with Finger in MIDDLE OF RIGHT EDGE of Trackpad"} with title "Trackpad Test"
	
	try
		activate
	end try
	display dialog "				Trackpad Click Test 4 of 6:

 ↘️     Click Button with Finger in The Bottom Right Corner     ↘️" buttons {"Click Me with Finger in BOTTOM RIGHT CORNER of Trackpad"} with title "Trackpad Test"
	
	try
		activate
	end try
	display dialog "				Trackpad Click Test 5 of 6:

 ⬇️     Click Button with Finger in The Center of Bottom Edge     ⬇️" buttons {"Click Me with Finger in CENTER OF BOTTOM EDGE of Trackpad"} with title "Trackpad Test"
	
	try
		activate
	end try
	display dialog "				Trackpad Click Test 6 of 6:

 ↙️     Click Button with Finger in The Bottom Left Corner     ↙️" buttons {"Click Me with Finger in BOTTOM LEFT CORNER of Trackpad"} with title "Trackpad Test"
	
	try
		activate
	end try
	display dialog "				FINISHED Trackpad Click Tests

	✅	CLICK TESTS PASSED IF:
		⁃ The click action responded instantly in each zone.
 		⁃ The click action never felt stiff, sticky, or funky.

	❌	CLICK TESTS FAILED IF:
		⁃ The trackpad didn't click properly.
		⁃ The click action didn't respond instantly.
		⁃ The click action felt stiff, sticky, or funky in any zone.


  ‼️ CONSULT AN INSTRUCTOR IF THERE WERE ANY ISSUES ‼️


	👉	When you're ready, continue to Touch Tests to open
		an app called “FingerMgmt” which will allow you
		to see where the trackpad has detected fingers.

	✌️	Then, you will be guided through 6 Touch Tests to
		perform while watching what “FingerMgmt” detects.


		‼️	DO NOT USE A MOUSE FOR THESE TESTS  ‼️" buttons {"Redo Click Tests", "Quit", "Continue to Touch Tests"} cancel button 2 default button 3 with title "Trackpad Test"
	
	if (button returned of result) is "Continue to Touch Tests" then exit repeat
end repeat

repeat
	
	repeat
		if (application ("Finger" & "Mgmt") is running) then
			try
				with timeout of 1 second
					tell application ("Finger" & "Mgmt") to quit
				end timeout
			end try
			delay 1
		else
			exit repeat
		end if
	end repeat
	
	try
		tell application ("Finger" & "Mgmt") to activate
	end try
	
	tell application "System Events" to tell application process ("Finger" & "Mgmt")
		repeat
			if ((count of windows) = 1) then exit repeat
			delay 1
		end repeat
		
		tell (first window whose subrole is "AXStandardWindow")
			perform action "AXZoomWindow" of (first button whose subrole is "AXFullScreenButton")
			perform action "AXRaise"
		end tell
	end tell
	
	--repeat
	--	if (application ("Finger" & "Mgmt") is not running) then exit repeat
	--	tell application "System Events" to tell application process ("Finger" & "Mgmt")
	--		if (((count of windows) = 0)) then
	--			try
	--				with timeout of 1 second
	--					tell application ("Finger" & "Mgmt") to quit
	--				end timeout
	--			end try
	--			exit repeat
	--		end if
	--	end tell
	--	delay 1
	--end repeat
	
	tell application ("Finger" & "Mgmt")
		repeat
			try
				try
					activate
				end try
				display dialog "				Trackpad Touch Test 1 of 6:

     Move ONE FINGER along ALL FOUR EDGES of the trackpad.


	✅	Continue if where you touch the trackpad is
		exactly what you see in “FingerMgmt”.

	🚫 STOP AND CONSULT INSTRUCTOR IF ANY ISSUES" buttons {"Hide This Window for 5 Seconds", "Continue to Next Test"} cancel button 1 default button 2 with title "Trackpad Test"
				exit repeat
			on error
				delay 5
			end try
		end repeat
		
		repeat
			try
				try
					activate
				end try
				display dialog "				Trackpad Touch Test 2 of 6:

 Move ONE FINGER around the ENTIRE SURFACE of the trackpad.


	✅	Continue if where you touch the trackpad is
		exactly what you see in “FingerMgmt”.

	🚫 STOP AND CONSULT INSTRUCTOR IF ANY ISSUES" buttons {"Hide This Window for 5 Seconds", "Continue to Next Test"} cancel button 1 default button 2 with title "Trackpad Test"
				exit repeat
			on error
				delay 5
			end try
		end repeat
		
		repeat
			try
				try
					activate
				end try
				display dialog "				Trackpad Touch Test 3 of 6:

		   Place TWO FINGERS on the trackpad and
		   move them up and down and left and right.


	✅	Continue if where you touch the trackpad is
		exactly what you see in “FingerMgmt”.

	🚫 STOP AND CONSULT INSTRUCTOR IF ANY ISSUES" buttons {"Hide This Window for 5 Seconds", "Continue to Next Test"} cancel button 1 default button 2 with title "Trackpad Test"
				exit repeat
			on error
				delay 5
			end try
		end repeat
		
		repeat
			try
				try
					activate
				end try
				display dialog "				Trackpad Touch Test 4 of 6:

		   Place THREE FINGERS on the trackpad and
		   move them up and down and left and right.


	✅	Continue if where you touch the trackpad is
		exactly what you see in “FingerMgmt”.

	🚫 STOP AND CONSULT INSTRUCTOR IF ANY ISSUES" buttons {"Hide This Window for 5 Seconds", "Continue to Next Test"} cancel button 1 default button 2 with title "Trackpad Test"
				exit repeat
			on error
				delay 5
			end try
		end repeat
		
		repeat
			try
				try
					activate
				end try
				display dialog "				Trackpad Touch Test 5 of 6:

		   Place FOUR FINGERS on the trackpad and
		   move them up and down and left and right.


	✅	Continue if where you touch the trackpad is
		exactly what you see in “FingerMgmt”.

	🚫 STOP AND CONSULT INSTRUCTOR IF ANY ISSUES" buttons {"Hide This Window for 5 Seconds", "Continue to Next Test"} cancel button 1 default button 2 with title "Trackpad Test"
				exit repeat
			on error
				delay 5
			end try
		end repeat
		
		repeat
			try
				try
					activate
				end try
				display dialog "				Trackpad Touch Test 6 of 6:

		   Place FIVE FINGERS on the trackpad and
		   move them up and down and left and right.


	✅	Finish if where you touch the trackpad is
		exactly what you see in “FingerMgmt”.

	🚫 STOP AND CONSULT INSTRUCTOR IF ANY ISSUES" buttons {"Hide This Window for 5 Seconds", "Finish Touch Tests"} cancel button 1 default button 2 with title "Trackpad Test"
				exit repeat
			on error
				delay 5
			end try
		end repeat
		
		quit
	end tell
	
	try
		activate
	end try
	try
		display dialog "			FINISHED Trackpad Touch Tests

	✅	TOUCH TESTS PASSED IF:
		⁃ The trackpad always responded instantly.
		⁃ The trackpad had no dead or rough zones.
		⁃ Exactly where you touched the trackpad
		  was exactly what you saw in “FingerMgmt”.

	❌	TOUCH TESTS FAILED IF:
		⁃ The trackpad is physically damaged in any way.
 		⁃ The trackpad didn't respond instantly.
		⁃ The trackpad had any dead zones.
		⁃ Exactly where you touched the trackpad
		  WAS NOT exactly what you saw in “FingerMgmt”.


	👍	TRACKPAD TEST PASSED IF EVERY SINGLE
		CLICK TEST AND TOUCH TEST PASSED!

 ‼️ CONSULT INSTRUCTOR IF THERE WERE ANY ISSUES ‼️" buttons {"Redo Touch Tests", "Done"} cancel button 1 default button 2 with title "Trackpad Test"
		exit repeat
	end try
end repeat

try
	(("/Applications/Keyboard Test.app" as POSIX file) as alias)
	if (application ("Keyboard" & " Test") is not running) then
		try
			activate
		end try
		display alert "
Would you like to launch “Keyboard Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
		do shell script "open -n -a '/Applications/Keyboard Test.app'"
	end if
end try

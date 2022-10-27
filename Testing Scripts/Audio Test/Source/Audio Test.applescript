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

-- Version: 2022.10.24-1

-- App Icon is “Loudspeaker” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
	
	set intendedAppName to "Audio Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as string)))) user name adminUsername password adminPassword with administrator privileges
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
end considering

if (isMojaveOrNewer) then
	try
		tell application "System Events" to every window -- To prompt for Automation access on Mojave
	on error automationAccessErrorMessage number automationAccessErrorNumber
		if (automationAccessErrorNumber is equal to -1743) then
			try
				tell application "System Preferences" to activate
			end try
			try
				do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Automation'" -- The "Privacy_Automation" anchor is not exposed/accessible via AppleScript, but can be accessed via URL Scheme.
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

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		end try
		quit
		delay 10
	end if
end try


set testInternalSpeakersCount to 0
set testHeadphonesCount to 0

try
	repeat
		set audioTestButtons to {"Quit", "Test Audio Output"}
		if ((testInternalSpeakersCount > 0) and (testHeadphonesCount > 0)) then set audioTestButtons to {"Test Audio Output Again", "Done"}
		
		set internalSpeakerTestCountNote to ""
		set headphoneTestCountNote to ""
		
		if (testInternalSpeakersCount > 0) then set internalSpeakerTestCountNote to "

		Number of Internal Speaker Tests Run:	" & testInternalSpeakersCount
		
		if (testHeadphonesCount > 0) then set headphoneTestCountNote to "
		
		Number of Headphone Port Tests Run:	" & testHeadphonesCount
		
		set shouldTestAudio to false
		try
			activate
		end try
		try
			display dialog "			🔊	First, run this Audio Test
				through the built-in speakers.

			🎧	Then, run this Audio Test again
				with headphones plugged in to
				test the headphone port.


✅	AUDIO TEST PASSED IF:
You hear the phrases “Left speaker”, “Right speaker”, and “Both speakers” (or just “Single speaker”) crisply and clearly out of the correct speakers with both the built-in speakers as well as the headphones.

❌	AUDIO TEST FAILED IF:
You do not hear each phrase out of the correct speakers or they don't sound crisp and clear for either the built-in speakers or the headphones.


	👉 CONSULT INSTRUCTOR IF AUDIO TEST FAILS ‼️
" & internalSpeakerTestCountNote & headphoneTestCountNote buttons audioTestButtons cancel button 1 default button 2 with title "Audio Test"
			if ((last text item of audioTestButtons) is equal to "Test Audio Output") then set shouldTestAudio to true
		on error
			if ((first text item of audioTestButtons) is equal to "Test Audio Output Again") then set shouldTestAudio to true
		end try
		
		if (shouldTestAudio) then
			repeat with thisAudioTest in {{0, "Left speaker"}, {1, "Right speaker"}, {0.5, "Both speakers"}}
				repeat 60 times -- Wait for Sound pane to load
					tell application "System Preferences"
						try
							activate
						end try
						reveal ((anchor "output") of (pane id "com.apple.preference.sound"))
					end tell
					
					try
						tell application "System Events" to tell application process "System Preferences"
							if ((title of window 1) is equal to "Sound") then
								exit repeat
							else
								delay 0.5
							end if
						end tell
					on error
						delay 0.5
					end try
				end repeat
				
				set isTestingHeadphones to false
				try
					tell application "System Events" to tell application process "System Preferences"
						set allAudioOutputRows to (every row of table 1 of scroll area 1 of tab group 1 of window 1)
						set didSelectAudioOutputRow to false
						repeat with thisAudioOutputRow in allAudioOutputRows
							set thisAudioOutputType to ((value of text field 2 of thisAudioOutputRow) as string)
							if ((thisAudioOutputType is equal to "Built-In") or (thisAudioOutputType is equal to "Headphone port")) then
								select thisAudioOutputRow
								set didSelectAudioOutputRow to true
								if (thisAudioOutputType is equal to "Headphone port") then set isTestingHeadphones to true
								exit repeat
							end if
						end repeat
						if (not didSelectAudioOutputRow) then select (row 1 of table 1 of scroll area 1 of tab group 1 of window 1)
					end tell
					delay 0.25
				end try
				if (isTestingHeadphones) then
					try
						set volume output volume 25 without output muted
					end try
				else
					try
						set volume output volume 75 without output muted
					end try
				end if
				try
					set volume alert volume 100
				end try
				try
					tell application "System Events" to tell application process "System Preferences"
						set value of (slider 1 of group 1 of tab group 1 of window 1) to ((first item of thisAudioTest) as number)
					end tell
					delay 0.25
					say ((last item of thisAudioTest) as string)
					delay 0.25
				on error
					say "Single speaker"
					delay 0.25
					exit repeat
				end try
			end repeat
			try
				tell application "System Events" to tell application process "System Preferences"
					set allAudioOutputRows to (every row of table 1 of scroll area 1 of tab group 1 of window 1)
					repeat with thisAudioOutputRow in allAudioOutputRows
						if (selected of thisAudioOutputRow) then
							set thisAudioOutputType to ((value of text field 2 of thisAudioOutputRow) as string)
							if (thisAudioOutputType is equal to "Built-In") then
								set testInternalSpeakersCount to (testInternalSpeakersCount + 1)
							else if (thisAudioOutputType is equal to "Headphone port") then
								set testHeadphonesCount to (testHeadphonesCount + 1)
							end if
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
		else
			exit repeat
		end if
	end repeat
end try

if ((testInternalSpeakersCount > 0) and (testHeadphonesCount > 0)) then
	set shortModelName to "Unknown Model"
	try
		set shortModelName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:_items:0:machine_name' /dev/stdin <<< \"$(system_profiler -xml SPHardwareDataType)\"")))
	end try
	if ((shortModelName is not equal to "Mac Pro") and (shortModelName is not equal to "Mac mini") and (shortModelName is not equal to "Mac Studio")) then
		try
			(("/Applications/Microphone Test.app" as POSIX file) as alias)
			if (application ("Microphone" & " Test") is not running) then
				try
					activate
				end try
				display alert "
Would you like to launch
“Microphone Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
				do shell script "open -na '/Applications/Microphone Test.app'"
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

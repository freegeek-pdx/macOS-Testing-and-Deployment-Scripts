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

-- Version: 2023.9.12-3

-- App Icon is “Studio Microphone” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
	
	set intendedAppName to "Microphone Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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


set systemVersion to (system version of (system info))
considering numeric strings
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
end considering

if (isMojaveOrNewer) then
	try
		tell application id "com.apple.QuickTimePlayerX" to every window -- To prompt for Automation access on Mojave
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
				display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “QuickTime Player” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “QuickTime Player” checkbox underneath it.

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
			tell application id "com.apple.QuickTimePlayerX" to quit
		end timeout
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


if ((input volume of (get volume settings)) is equal to missing value) then
	try
		activate
	end try
	try
		do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
	end try
	display alert "No Microphone Detected" message "👉 IF THIS MAC IS SUPPOSED TO HAVE A MICROPHONE, THEN MICROPHONE TEST HAS FAILED ‼️" buttons {"Quit"} default button 1 as critical
	quit
	delay 10
end if


set microphoneTestDuration to 10
set testCount to 0
set tryAgainWithoutPrompting to false

try
	repeat
		set microphoneTestButtons to {"Quit", "Test Microphone"}
		if (testCount ≥ 1) then set microphoneTestButtons to {"Test Microphone Again", "Done"}
		
		set shouldTestMicrophone to false
		try
			activate
		end try
		
		if (tryAgainWithoutPrompting) then
			set shouldTestMicrophone to true
			set tryAgainWithoutPrompting to false
		else
			try
				display dialog "		🎙	Microphone Test will start an audio
			recording and record for " & microphoneTestDuration & " seconds.

		🗣	Speak a phrase during the recording so
			that we can make sure the microphone
			records crisply and clearly.

		⏱	After " & microphoneTestDuration & " seconds of audio is recorded,
			it will be played back to you.

		👂	Listen closely to the recording to make
			sure you can understand the phrase you
			spoke and that it sounds crisp and clear.

		⏱	After the " & microphoneTestDuration & " second recording has played
			the recording window will close and
			this window will open again.


	✅	MICROPHONE TEST PASSED IF:
		⁃ You hear your recording crisply and clearly.

	❌	MICROPHONE TEST FAILED IF:
		⁃ Nothing gets recorded.
		⁃ The recording doesn't sound crisp and clear.


👉 CONSULT INSTRUCTOR IF MICROPHONE TEST FAILS ‼️" buttons microphoneTestButtons cancel button 1 default button 2 with title "Microphone Test"
				if ((last text item of microphoneTestButtons) is equal to "Test Microphone") then set shouldTestMicrophone to true
			on error
				if ((first text item of microphoneTestButtons) is equal to "Test Microphone Again") then set shouldTestMicrophone to true
			end try
		end if
		
		if (shouldTestMicrophone) then
			try
				set volume input volume 100
			end try
			
			set failedToRecord to false
			
			tell application id "com.apple.QuickTimePlayerX"
				set startRecordingAttempts to 1
				repeat 30 times
					try
						activate
					end try
					delay 0.5
					try
						close every window without saving
					end try
					if (startRecordingAttempts > 1) then
						try
							quit
						end try
						delay 2
						try
							activate
						end try
					end if
					delay 0.5
					set newAudioRecording to new audio recording
					delay 1
					
					try
						activate
					end try
					
					if (startRecordingAttempts < 5) then
						delay startRecordingAttempts
					else
						delay 5
					end if
					
					try
						start newAudioRecording
						
						delay 1
						
						set recordingHasErrorSheet to false
						try
							-- On older/slower Macs (generally models that only support up to macOS 10.13 High Sierra),
							-- the first attempt at recording can immedaitely fail with a "Cannot Record" error sheet.
							-- But, the next attempt will work fine. So, detect this sheet to immediately start over and try again.
							tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.QuickTimePlayerX") to get sheet 1 of window 1
							set recordingHasErrorSheet to true
						end try
						if (recordingHasErrorSheet) then error "Recording Has Error Sheet"
						
						exit repeat
					on error
						try
							stop newAudioRecording
						end try
						set startRecordingAttempts to (startRecordingAttempts + 1)
						delay 0.5
					end try
				end repeat
				tell current application
					try
						activate
					end try
					display alert "Microphone Test is Recording
" & microphoneTestDuration & " Seconds of Audio" message "🗣 Speak your test phrase now…" buttons {"End Recording Early"} default button 1 giving up after microphoneTestDuration
				end tell
				try
					stop newAudioRecording
				on error -- If the recording failed for any other reason, immediately prompt to try again.
					set failedToRecord to true
				end try
				
				if (not failedToRecord) then
					delay 1
					try
						activate
					end try
					try
						play (document 1)
						
						tell current application
							try
								set volume output volume 75 without output muted
							end try
							try
								set volume alert volume 100
							end try
							
							try
								activate
							end try
							set endPlaybackDialogButton to "                          End Playback Early                          "
							-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
							if (isCatalinaOrNewer) then set endPlaybackDialogButton to "End Playback Early                                                    "
							display dialog "		Microphone Test is Playing Back
		" & microphoneTestDuration & " Seconds of Recorded Audio


👂 Listen closely to your recorded test phrase…


✅	MICROPHONE TEST PASSED IF:
	⁃ You hear your recording crisply and clearly.
		
❌	MICROPHONE TEST FAILED IF:
	⁃ Nothing got recorded.
	⁃ The recording doesn't sound crisp and clear.


👉 CONSULT INSTRUCTOR IF MIC TEST FAILED ‼️" buttons {endPlaybackDialogButton} default button 1 with title (name of me) with icon note giving up after (microphoneTestDuration + 2)
						end tell
					on error
						set failedToRecord to true
					end try
				end if
				try
					close every window without saving
				end try
				delay 1
				try
					quit
				end try
			end tell
			set testCount to (testCount + 1)
			
			if (failedToRecord) then
				try
					activate
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
				end try
				try
					display alert "Microphone Test Failed to Record

👉 Microphone Test can still pass if this only happens once and the next attempt records properly." message "
❌ IF THIS HAPPENS REPEATEDLY, THEN MICROPHONE TEST FAILED ‼️" buttons {"Quit", "Test Microphone Again"} cancel button 1 default button 2 as critical
					set tryAgainWithoutPrompting to true
				on error
					exit repeat
				end try
			end if
		else
			exit repeat
		end if
	end repeat
end try

if (testCount ≥ 1) then
	try
		(("/Applications/Camera Test.app" as POSIX file) as alias)
		if (application id ("org.freegeek." & "Camera-Test") is not running) then -- Break up App ID or else build will fail if not found during compilation when app is not installed.
			try
				activate
			end try
			display alert "
Would you like to launch “Camera Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
			do shell script "open -na '/Applications/Camera Test.app'"
		end if
	end try
end if

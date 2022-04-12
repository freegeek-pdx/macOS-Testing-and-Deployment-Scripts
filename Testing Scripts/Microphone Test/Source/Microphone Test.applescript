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

-- App Icon is “Studio Microphone” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
		tell application ("QuickTime" & " Player") to every window -- To prompt for Automation access on Mojave
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
				display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “QuickTime Player” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “QuickTime Player” checkbox underneath it.

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
			tell application ("QuickTime" & " Player") to quit
		end timeout
	end try
end if


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


set microphoneTestDuration to 10
set testCount to 0

try
	repeat
		set microphoneTestButtons to {"Quit", "Test Microphone"}
		if (testCount ≥ 1) then set microphoneTestButtons to {"Test Microphone Again", "Done"}
		
		set shouldTestMicrophone to false
		try
			activate
		end try
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
		
		if (shouldTestMicrophone) then
			try
				set volume input volume 100
			end try
			
			tell application "QuickTime Player"
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
					delay 0.5
					try
						activate
					end try
					delay startRecordingAttempts
					try
						start newAudioRecording
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
				end try
				delay 1
				try
					activate
				end try
				try
					play (document 1)
				end try
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


👉 CONSULT INSTRUCTOR IF MIC TEST FAILED ‼️" buttons {endPlaybackDialogButton} default button 1 with title (name of me) with icon dialogIconName giving up after (microphoneTestDuration + 2)
				end tell
				try
					close every window without saving
				end try
				delay 1
				try
					quit
				end try
			end tell
			set testCount to (testCount + 1)
		else
			exit repeat
		end if
	end repeat
end try

if (testCount ≥ 1) then
	try
		(("/Applications/Camera Test.app" as POSIX file) as alias)
		if (application ("Camera" & " Test") is not running) then
			try
				activate
			end try
			display alert "
Would you like to launch “Camera Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
			do shell script "open -n -a '/Applications/Camera Test.app'"
		end if
	end try
end if

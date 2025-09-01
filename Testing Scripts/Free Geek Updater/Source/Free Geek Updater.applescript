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

-- Version: 2024.11.11-1

-- App Icon is “Counterclockwise Arrows” from Twemoji (https://github.com/twitter/twemoji) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

-- Build Flag: LSUIElement

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

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Free Geek Updater" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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


set systemVersion to (system version of (system info))
considering numeric strings
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
end considering


global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate -- Needs to be accessible in doShellScriptAsAdmin function.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "Staff"

set currentUsername to (short user name of (system info))
if (currentUsername is equal to "fg-demo") then set adminUsername to "fg-admin"

set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"


set testingFlagExists to false
set baseUpdatesURL to "https://apps.freegeek.org/macland/download/"
try -- If "TESTING" flag folder exists on desktop, then use testing versions (from different URL)!
	((((POSIX path of (path to desktop folder from user domain)) & "TESTING") as POSIX file) as alias)
	set testingFlagExists to true
	set baseUpdatesURL to "http://tools.freegeek.org/macland/download/"
end try

set reinstallFlagExists to false
try -- If "REINSTALL" flag folder exists on desktop, then update everything!
	((((POSIX path of (path to desktop folder from user domain)) & "REINSTALL") as POSIX file) as alias)
	set reinstallFlagExists to true
end try

set appVersion to "UNKNOWN"
try
	set appVersion to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of ((POSIX path of (path to me)) & "Contents/Info.plist")))) as text)
end try

set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")

if (appVersion is not equal to "UNKNOWN") then
	set taskName to "Checking for Updates"
	if (reinstallFlagExists) then set taskName to "Preparing to Reinstall"
	if (testingFlagExists) then set taskName to (taskName & " (TESTING)")
	
	try
		activate
	end try
	set progress total steps to -1
	set progress completed steps to 0
	set progress description to "🔄	" & (name of me) & " is " & taskName & "…"
	set progress additional description to "
🚫	DO NOT TOUCH ANYTHING WHILE UPDATING"
	
	try
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as text) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Stop")) then
							(thisProgressWindowSubView's setTitle:"Skip")
							(thisProgressWindowSubView's setEnabled:false)
							
							exit repeat
						end if
					end repeat
				end if
			end if
		end repeat
	end try
	
	delay 0.5
	
	set AppleScript's text item delimiters to ""
	set tmpPathBase to (POSIX path of (((path to temporary items) as text) & "::"))
	set tmpPath to (tmpPathBase & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
	
	set latestVersion to "UNKNOWN"
	set latestVersions to ""
	
	repeat
		try
			set latestVersions to (do shell script "curl -m 5 -sfL " & (quoted form of (baseUpdatesURL & "latest-versions.txt")))
		end try
		
		if (latestVersions is equal to "") then
			try
				activate
			end try
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
			end try
			try
				display dialog (name of me) & " Failed to Check for Updates


You must be connected to the internet to be able to check for updates.

Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Continue Without Updating", "Try Again"} cancel button 1 default button 2 with title (name of me) with icon caution giving up after 30
				delay 0.5
			on error
				exit repeat
			end try
		else
			exit repeat
		end if
	end repeat
	
	try
		repeat with thisWindow in (current application's NSApp's |windows|())
			if (thisWindow's isVisible() is true) then
				if (((thisWindow's title()) as text) is equal to (name of me)) then
					repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
						if (((thisProgressWindowSubView's className()) as text) is equal to "NSProgressIndicator") then
							(thisWindow's setLevel:(current application's NSScreenSaverWindowLevel))
							
							exit repeat
						end if
					end repeat
				end if
			end if
		end repeat
	end try
	
	set latestVersionsLines to (paragraphs of latestVersions)
	
	repeat with thisLatestVersionLine in latestVersionsLines
		if (thisLatestVersionLine contains ": ") then
			set AppleScript's text item delimiters to ": "
			if (((first text item of thisLatestVersionLine) as text) is equal to (name of me)) then
				set latestVersion to ((text item 2 of thisLatestVersionLine) as text)
				exit repeat
			end if
		end if
	end repeat
	
	set shouldUpdateSelf to true -- Always have Free Geek Updater update itself before updating any other apps.
	try
		(((buildInfoPath & ".fgUpdaterJustUpdatedItself") as POSIX file) as alias)
		set shouldUpdateSelf to false
		doShellScriptAsAdmin("rm -f " & (quoted form of (buildInfoPath & ".fgUpdaterJustUpdatedItself")))
	end try
	
	set shouldUpdateOtherApps to true -- Will be set to false if self update is started.
	
	if (shouldUpdateSelf and (latestVersion is not equal to "UNKNOWN")) then
		set updaterNeedsUpdate to false
		considering numeric strings
			set updaterNeedsUpdate to (latestVersion > appVersion)
		end considering
		if (reinstallFlagExists) then set updaterNeedsUpdate to true
		
		if (updaterNeedsUpdate) then
			set taskName to "Updating Itself"
			if (reinstallFlagExists) then set taskName to "Reinstalling Itself"
			if (testingFlagExists) then set taskName to (taskName & " (TESTING)")
			set progress description to "🔄	" & (name of me) & " is " & taskName & "…"
			
			delay 0.5
			
			set launchDirectory to (POSIX path of (((path to me) as text) & "::"))
			
			set updaterAppFileName to ((name of me) & ".app")
			set AppleScript's text item delimiters to "-"
			set appUpdateZipFilename to (((words of (name of me)) as text) & ".zip")
			
			set appUpdateZipFilePath to (tmpPath & appUpdateZipFilename)
			set appUpdateTempFilePath to (tmpPathBase & "/" & updaterAppFileName)
			
			do shell script "rm -rf " & (quoted form of appUpdateZipFilePath) & " " & (quoted form of appUpdateTempFilePath)
			
			
			try
				set curlPID to (do shell script "curl --connect-timeout 5 -sfL " & (quoted form of (baseUpdatesURL & appUpdateZipFilename)) & " -o " & (quoted form of appUpdateZipFilePath) & " > /dev/null 2>&1 & echo $!")
				delay 0.5
				
				try
					repeat with thisWindow in (current application's NSApp's |windows|())
						if (thisWindow's isVisible() is true) then
							if (((thisWindow's title()) as text) is equal to (name of me)) then
								repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
									if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Skip")) then
										(thisProgressWindowSubView's setEnabled:true)
										
										exit repeat
									end if
								end repeat
							end if
						end if
					end repeat
				end try
				delay 0.5
				
				set curlIsRunning to ((do shell script ("ps -p " & curlPID & " > /dev/null 2>&1; echo $?")) as number)
				if (curlIsRunning is equal to 0) then
					try
						repeat
							set curlIsRunning to ((do shell script ("ps -p " & curlPID & " > /dev/null 2>&1; echo $?")) as number)
							delay 0.5
							if (curlIsRunning is not equal to 0) then exit repeat
						end repeat
					on error
						do shell script ("killall curl; rm -f " & (quoted form of appUpdateZipFilePath))
					end try
				end if
				
				try
					repeat with thisWindow in (current application's NSApp's |windows|())
						if (thisWindow's isVisible() is true) then
							if (((thisWindow's title()) as text) is equal to (name of me)) then
								repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
									if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Skip")) then
										(thisProgressWindowSubView's setEnabled:false)
										
										exit repeat
									end if
								end repeat
							end if
						end if
					end repeat
				end try
				delay 0.5
			on error
				do shell script ("killall curl; rm -f " & (quoted form of appUpdateZipFilePath))
			end try
			
			
			do shell script ("ditto -xk --noqtn " & (quoted form of appUpdateZipFilePath) & " " & (quoted form of tmpPathBase) & "; rm -f " & (quoted form of appUpdateZipFilePath))
			
			try
				((appUpdateTempFilePath as POSIX file) as alias)
				
				set updatedAppVersion to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of (appUpdateTempFilePath & "/Contents/Info.plist")))) as text)
				
				if (updatedAppVersion is equal to latestVersion) then
					do shell script ("
touch " & (quoted form of appUpdateTempFilePath) & "

echo '
use scripting additions

set updaterAppFilePath to \"" & (launchDirectory & updaterAppFileName) & "\"

delay 0.5
repeat while (application updaterAppFilePath is running)
	delay 0.5
end repeat

set appUpdateTempFilePath to \"" & appUpdateTempFilePath & "\"

try
	((appUpdateTempFilePath as POSIX file) as alias)
	
	try
		do shell script \"rm -rf \" & (quoted form of updaterAppFilePath) user name \"" & adminUsername & "\" password \"" & adminPassword & "\" with administrator privileges
	end try
	
	set appUpdateTempFileStructure to \"\"
	try
		set appUpdateTempFileStructure to (do shell script (\"cd \" & (quoted form of appUpdateTempFilePath) & \" && ls -Rsk\"))
	end try
	
	try
		do shell script \"mv -f \" & (quoted form of appUpdateTempFilePath) & \" \" & (quoted form of updaterAppFilePath)
	on error
		try
			do shell script \"mv -f \" & (quoted form of appUpdateTempFilePath) & \" \" & (quoted form of updaterAppFilePath) user name \"" & adminUsername & "\" password \"" & adminPassword & "\" with administrator privileges
		end try
	end try

	repeat 30 times
		try
			set updaterInstallAppFileStructure to \"\"
			try
				set updaterInstallAppFileStructure to (do shell script (\"cd \" & (quoted form of updaterAppFilePath) & \" && ls -Rsk\") user name \"" & adminUsername & "\" password \"" & adminPassword & "\" with administrator privileges)
			end try
			if (appUpdateTempFileStructure is equal to updaterInstallAppFileStructure) then exit repeat
		end try
		delay 0.5
	end repeat
end try

try
	do shell script \"open -na \" & (quoted form of updaterAppFilePath)
on error
	try
		do shell script \"open -na \\\"/Applications/Test Boot Setup.app\\\"\"
	on error
		try
			do shell script \"open -na \\\"/Users/fg-demo/Applications/Free Geek Setup.app\\\"\"
		on error
			try
				do shell script \"open -na \\\"/Applications/Mac Scope.app\\\"\"
			end try
		end try
	end try
end try

' | osascript > /dev/null 2>&1 &")
					
					set shouldUpdateOtherApps to false
					
					try
						do shell script "mkdir " & (quoted form of buildInfoPath)
					end try
					try
						doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgUpdaterJustUpdatedItself")))
					end try
				else
					do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 & rm -rf " & (quoted form of appUpdateTempFilePath)
				end if
			on error
				do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 & rm -rf " & (quoted form of appUpdateTempFilePath)
			end try
		end if
	end if
	
	if (shouldUpdateOtherApps) then
		repeat with thisLatestVersionLine in latestVersionsLines
			if (thisLatestVersionLine contains ": ") then
				set AppleScript's text item delimiters to ": "
				set thisAppName to ((first text item of thisLatestVersionLine) as text)
				if (thisAppName is not equal to (name of me)) then
					-- NOTE: The "fgreset" script is no longer installed since we are no longer installing older than macOS 10.15 Catalina.
					-- So, this code to update it is now commented out, but it is being left in place in case it is useful in the future.
					(*
					if ((currentUsername is equal to "fg-demo") and (thisAppName is equal to "fgreset")) then
						set thisScriptInstallPath to ("/Applications/" & thisAppName)
						
						set thisScriptLatestVersion to ((text item 2 of thisLatestVersionLine) as text)
						
						set thisScriptCurrentVersion to "0" -- Always update app if fails to get current version (possibly from previous bad update)
						try
							set thisScriptCurrentVersionLine to (do shell script "grep -m 1 '# Version: ' " & (quoted form of thisScriptInstallPath))
							
							if (thisScriptCurrentVersionLine contains "# Version: ") then
								set thisScriptCurrentVersion to ((text 12 thru -1 of thisScriptCurrentVersionLine) as text)
							end if
						end try
						
						set thisScriptNeedsUpdate to false
						considering numeric strings
							set thisScriptNeedsUpdate to (thisScriptLatestVersion > thisScriptCurrentVersion)
						end considering
						if (reinstallFlagExists) then set thisScriptNeedsUpdate to true
						
						if (thisScriptNeedsUpdate) then
							set taskName to "Updating"
							if (reinstallFlagExists) then set taskName to "Reinstalling"
							if (testingFlagExists) then set taskName to (taskName & " (TESTING)")
							set progress description to "🔄	" & (name of me) & " is " & taskName & " “" & thisAppName & "”…"
							
							delay 0.5
							
							set thisScriptUpdateZipFilename to (thisAppName & ".zip")
							
							set thisScriptUpdateZipFilePath to (tmpPath & thisScriptUpdateZipFilename)
							set thisScriptUpdateTempFilePath to (tmpPathBase & "/" & thisAppName & ".sh")
							
							do shell script "rm -f " & (quoted form of thisScriptUpdateZipFilePath) & " " & (quoted form of thisScriptUpdateTempFilePath)
							
							try
								set curlPID to (do shell script "curl --connect-timeout 5 -sfL " & (quoted form of (baseUpdatesURL & thisScriptUpdateZipFilename)) & " -o " & (quoted form of thisScriptUpdateZipFilePath) & " > /dev/null 2>&1 & echo $!")
								delay 0.5
								
								try
									repeat with thisWindow in (current application's NSApp's |windows|())
										if (thisWindow's isVisible() is true) then
											if (((thisWindow's title()) as text) is equal to (name of me)) then
												repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
													if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Skip")) then
														(thisProgressWindowSubView's setEnabled:true)
														
														exit repeat
													end if
												end repeat
											end if
										end if
									end repeat
								end try
								delay 0.5
								
								set curlIsRunning to ((do shell script ("ps -p " & curlPID & " > /dev/null 2>&1; echo $?")) as number)
								if (curlIsRunning is equal to 0) then
									try
										repeat
											set curlIsRunning to ((do shell script ("ps -p " & curlPID & " > /dev/null 2>&1; echo $?")) as number)
											delay 0.5
											if (curlIsRunning is not equal to 0) then exit repeat
										end repeat
									on error
										do shell script ("killall curl; rm -f " & (quoted form of thisScriptUpdateZipFilePath))
									end try
								end if
								
								try
									repeat with thisWindow in (current application's NSApp's |windows|())
										if (thisWindow's isVisible() is true) then
											if (((thisWindow's title()) as text) is equal to (name of me)) then
												repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
													if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Skip")) then
														(thisProgressWindowSubView's setEnabled:false)
														
														exit repeat
													end if
												end repeat
											end if
										end if
									end repeat
								end try
								delay 0.5
							on error
								do shell script ("killall curl; rm -f " & (quoted form of thisScriptUpdateZipFilePath))
							end try
							
							do shell script ("ditto -xk --noqtn " & (quoted form of thisScriptUpdateZipFilePath) & " " & (quoted form of tmpPathBase) & "; rm -f " & (quoted form of thisScriptUpdateZipFilePath))
							
							try
								((thisScriptUpdateTempFilePath as POSIX file) as alias)
								
								set thisUpdatedScriptVersion to "0"
								try
									set thisScriptUpdatedVersionLine to (do shell script "grep -m 1 '# Version: ' " & (quoted form of thisScriptUpdateTempFilePath))
									
									if (thisScriptUpdatedVersionLine contains "# Version: ") then
										set thisUpdatedScriptVersion to ((text 12 thru -1 of thisScriptUpdatedVersionLine) as text)
									end if
								end try
								
								if (thisUpdatedScriptVersion is equal to thisScriptLatestVersion) then
									try
										do shell script ("chmod +x " & (quoted form of thisScriptUpdateTempFilePath))
									end try
									
									try
										doShellScriptAsAdmin("rm -f " & (quoted form of thisScriptInstallPath))
									end try
									
									try
										do shell script "mv -f " & (quoted form of thisScriptUpdateTempFilePath) & " " & (quoted form of thisScriptInstallPath)
									on error
										try
											doShellScriptAsAdmin("mv -f " & (quoted form of thisScriptUpdateTempFilePath) & " " & (quoted form of thisScriptInstallPath))
										end try
									end try
									
									try
										do shell script "chflags hidden " & (quoted form of thisScriptInstallPath)
									end try
								end if
							end try
						end if
					else
					*)
					set thisAppInstallPath to ("/Applications/" & thisAppName & ".app")
					if (currentUsername is equal to "fg-demo") then set thisAppInstallPath to ("/Users/fg-demo/Applications/" & thisAppName & ".app")
					
					try
						((thisAppInstallPath as POSIX file) as alias)
						
						if (application thisAppInstallPath is not running) then
							try
								set thisAppCurrentVersion to "0" -- Always update app if fails to get current version (possibly from previous bad update)
								try
									set thisAppCurrentVersion to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of (thisAppInstallPath & "/Contents/Info.plist")))) as text)
								end try
								
								set thisAppLatestVersion to ((text item 2 of thisLatestVersionLine) as text)
								
								set thisAppNeedsUpdate to false
								considering numeric strings
									set thisAppNeedsUpdate to (thisAppLatestVersion > thisAppCurrentVersion)
								end considering
								if (reinstallFlagExists) then set thisAppNeedsUpdate to true
								
								if (thisAppNeedsUpdate) then
									set taskName to "Updating"
									if (reinstallFlagExists) then set taskName to "Reinstalling"
									if (testingFlagExists) then set taskName to (taskName & " (TESTING)")
									set progress description to "🔄	" & (name of me) & " is " & taskName & " “" & thisAppName & "”…"
									
									delay 0.5
									
									set AppleScript's text item delimiters to "-"
									set thisAppHyphenatedName to ((words of thisAppName) as text)
									
									set thisAppUpdateZipFilename to (thisAppHyphenatedName & ".zip")
									
									set thisAppUpdateZipFilePath to (tmpPath & thisAppUpdateZipFilename)
									set thisAppUpdateTempFilePath to (tmpPathBase & "/" & thisAppName & ".app")
									
									do shell script "rm -rf " & (quoted form of thisAppUpdateZipFilePath) & " " & (quoted form of thisAppUpdateTempFilePath)
									
									try
										set curlPID to (do shell script "curl --connect-timeout 5 -sfL " & (quoted form of (baseUpdatesURL & thisAppUpdateZipFilename)) & " -o " & (quoted form of thisAppUpdateZipFilePath) & " > /dev/null 2>&1 & echo $!")
										delay 0.5
										
										try
											repeat with thisWindow in (current application's NSApp's |windows|())
												if (thisWindow's isVisible() is true) then
													if (((thisWindow's title()) as text) is equal to (name of me)) then
														repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
															if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Skip")) then
																(thisProgressWindowSubView's setEnabled:true)
																
																exit repeat
															end if
														end repeat
													end if
												end if
											end repeat
										end try
										delay 0.5
										
										set curlIsRunning to ((do shell script ("ps -p " & curlPID & " > /dev/null 2>&1; echo $?")) as number)
										if (curlIsRunning is equal to 0) then
											try
												repeat
													set curlIsRunning to ((do shell script ("ps -p " & curlPID & " > /dev/null 2>&1; echo $?")) as number)
													delay 0.5
													if (curlIsRunning is not equal to 0) then exit repeat
												end repeat
											on error
												do shell script ("killall curl; rm -f " & (quoted form of thisAppUpdateZipFilePath))
											end try
										end if
										
										try
											repeat with thisWindow in (current application's NSApp's |windows|())
												if (thisWindow's isVisible() is true) then
													if (((thisWindow's title()) as text) is equal to (name of me)) then
														repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
															if (((thisProgressWindowSubView's className()) as text) is equal to "NSButton" and ((thisProgressWindowSubView's title() as text) is equal to "Skip")) then
																(thisProgressWindowSubView's setEnabled:false)
																
																exit repeat
															end if
														end repeat
													end if
												end if
											end repeat
										end try
										delay 0.5
									on error
										do shell script ("killall curl; rm -f " & (quoted form of thisAppUpdateZipFilePath))
									end try
									
									do shell script ("ditto -xk --noqtn " & (quoted form of thisAppUpdateZipFilePath) & " " & (quoted form of tmpPathBase) & "; rm -f " & (quoted form of thisAppUpdateZipFilePath))
									
									try
										((thisAppUpdateTempFilePath as POSIX file) as alias)
										
										set thisUpdatedAppVersion to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of (thisAppUpdateTempFilePath & "/Contents/Info.plist")))) as text)
										set thisUpdatedAppBundleID to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of (thisAppUpdateTempFilePath & "/Contents/Info.plist")))) as text)
										
										if (thisUpdatedAppVersion is equal to thisAppLatestVersion) then
											try
												do shell script ("touch " & (quoted form of thisAppUpdateTempFilePath))
											end try
											
											try
												doShellScriptAsAdmin("rm -rf " & (quoted form of thisAppInstallPath))
											end try
											
											set thisAppUpdateTempFileStructure to ""
											try
												set thisAppUpdateTempFileStructure to (do shell script ("cd " & (quoted form of thisAppUpdateTempFilePath) & " && ls -Rsk"))
											end try
											
											try
												do shell script "mv -f " & (quoted form of thisAppUpdateTempFilePath) & " " & (quoted form of thisAppInstallPath)
											on error
												try
													doShellScriptAsAdmin("mv -f " & (quoted form of thisAppUpdateTempFilePath) & " " & (quoted form of thisAppInstallPath))
												end try
											end try
											
											repeat 30 times
												try
													-- Catalina seems to fail to launch if done too quickly after a move (with an "executable not found" error).
													-- This error happens when trying to launch Test Boot Setup, because Test Boot Setup is the last to get updated on Catalina Restore Boot.
													-- Generating the install path file structure alone seems to delay enough to avoid the issue, but this loop makes it extra safe.
													set thisAppInstallFileStructure to ""
													try
														set thisAppInstallFileStructure to doShellScriptAsAdmin("cd " & (quoted form of thisAppInstallPath) & " && ls -Rsk")
													end try
													if (thisAppUpdateTempFileStructure is equal to thisAppInstallFileStructure) then
														try
															do shell script "mkdir " & (quoted form of buildInfoPath)
														end try
														try
															doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgUpdaterJustUpdated-" & thisUpdatedAppBundleID)))
														end try
														
														exit repeat
													end if
												end try
												delay 0.5
											end repeat
										end if
									end try
								end if
							end try
						end if
					end try
					--end if
				end if
			end if
		end repeat
		
		try
			do shell script "mkdir " & (quoted form of buildInfoPath)
		end try
		try
			doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgUpdaterJustFinished")))
		end try
		
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
			do shell script "open -na '/Applications/Test Boot Setup.app'"
		on error
			try
				do shell script "open -na '/Users/fg-demo/Applications/Free Geek Setup.app'"
			on error
				try
					do shell script "open -na '/Applications/Mac Scope.app'" -- Also check and launch Mac Scope if neither Setup exists for some other customized test boot environments used in Hardware Test.
				end try
			end try
		end try
	end if
end if

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

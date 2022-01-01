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

use AppleScript version "2.4"
use scripting additions

set bundleIdentifierPrefix to "org.freegeek."

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set AppleScript's text item delimiters to "-"
	set correctBundleIdentifier to bundleIdentifierPrefix & ((words of (name of me)) as string)
	try
		set currentBundleIdentifier to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath)) as string)
		if (currentBundleIdentifier is not equal to correctBundleIdentifier) then error "INCORRECT Bundle Identifier"
	on error
		do shell script "plutil -replace CFBundleIdentifier -string " & (quoted form of correctBundleIdentifier) & " " & (quoted form of infoPlistPath)
		
		try
			set currentCopyright to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :NSHumanReadableCopyright' " & (quoted form of infoPlistPath)) as string)
			if (currentCopyright does not contain "Twemoji") then error "INCORRECT Copyright"
		on error
			do shell script "plutil -replace NSHumanReadableCopyright -string " & (quoted form of ("Copyright © " & (year of (current date)) & " Free Geek
Designed and Developed by Pico Mitchell")) & " " & (quoted form of infoPlistPath)
		end try
		
		try
			set minSystemVersion to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' " & (quoted form of infoPlistPath)) as string)
			if (minSystemVersion is not equal to "10.13") then error "INCORRECT Minimum System Version"
		on error
			do shell script "plutil -replace LSMinimumSystemVersion -string '10.13' " & (quoted form of infoPlistPath)
			try
				do shell script "plutil -remove LSMinimumSystemVersionByArchitecture " & (quoted form of infoPlistPath)
			end try
		end try
		
		try
			set prohibitMultipleInstances to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :LSMultipleInstancesProhibited' " & (quoted form of infoPlistPath)) as number)
			if (prohibitMultipleInstances is equal to 0) then error "INCORRECT Multiple Instances Prohibited"
		on error
			do shell script "plutil -replace LSMultipleInstancesProhibited -bool true " & (quoted form of infoPlistPath)
		end try
		
		try
			set allowMixedLocalizations to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleAllowMixedLocalizations' " & (quoted form of infoPlistPath)) as number)
			if (allowMixedLocalizations is equal to 1) then error "INCORRECT Localization"
		on error
			do shell script "plutil -replace CFBundleAllowMixedLocalizations -bool false " & (quoted form of infoPlistPath)
			do shell script "plutil -replace CFBundleDevelopmentRegion -string 'en_US' " & (quoted form of infoPlistPath)
		end try
		
		try
			set currentAppleEventsUsageDescription to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :NSAppleEventsUsageDescription' " & (quoted form of infoPlistPath)) as string)
			if (currentAppleEventsUsageDescription does not contain (name of me)) then error "INCORRECT AppleEvents Usage Description"
		on error
			do shell script "plutil -replace NSAppleEventsUsageDescription -string " & (quoted form of ("You MUST click the “OK” button for “" & (name of me) & "” to be able to function.")) & " " & (quoted form of infoPlistPath)
		end try
		
		try
			set currentVersion to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of infoPlistPath)) as string)
			if (currentVersion is equal to "1.0") then error "INCORRECT Version"
		on error
			tell application "System Events" to set myCreationDate to (creation date of (path to me))
			set shortCreationDateString to (short date string of myCreationDate)
			set AppleScript's text item delimiters to "/"
			set correctVersion to ((text item 3 of shortCreationDateString) & "." & (text item 1 of shortCreationDateString) & "." & (text item 2 of shortCreationDateString))
			do shell script "plutil -replace CFBundleShortVersionString -string " & (quoted form of correctVersion) & " " & (quoted form of infoPlistPath)
			try
				do shell script "plutil -remove CFBundleVersion " & (quoted form of infoPlistPath)
			end try
		end try
		
		do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'try' -e 'do shell script \"chmod a-w \\\"" & ((POSIX path of (path to me)) & "Contents/Resources/Scripts/main.scpt") & "\\\"\"' -e 'do shell script \"codesign -s \\\"Developer ID Application\\\" --deep --force \\\"" & (POSIX path of (path to me)) & "\\\"\"' -e 'on error codeSignError' -e 'activate' -e 'display alert \"Code Sign Error\" message codeSignError' -e 'end try' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' &> /dev/null &"
		quit
		delay 10
	end try
end try

-- /Library/Caches/* ??
-- /System/Library/Caches/* ??
-- Delete user caches ??

set AppleScript's text item delimiters to ""
set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.

try -- CLEAN MAC TEST BOOT
	(("/Volumes/Mac Test Boot/" as POSIX file) as alias)
	
	do shell script "rm -rf '/Volumes/Mac Test Boot/Applications/memtest-test.sh' '/Volumes/Mac Test Boot/Applications/memtest' '/Volumes/Mac Test Boot/memtest' '/Volumes/Mac Test Boot/usr/local/bin/'"
	
	do shell script "rm -rf '/Volumes/Mac Test Boot/Users/Shared/Build Info/'"
	
	do shell script "rm -f '/Volumes/Mac Test Boot/private/var/db/softwareupdate/journal.plist'"
	
	-- Delete a few things from: https://bombich.com/kb/ccc5/some-files-and-folders-are-automatically-excluded-from-backup-task
	do shell script "rm -rf '/Volumes/Mac Test Boot/.fseventsd'"
	do shell script "rm -rf '/Volumes/Mac Test Boot/private/var/db/systemstats'"
	do shell script "rm -f '/Volumes/Mac Test Boot/private/var/db/dyld/dyld_'*"
	do shell script "rm -f '/Volumes/Mac Test Boot/.VolumeIcon.icns'"
	
	-- Delete vm and temporary files
	do shell script "rm -rf '/Volumes/Mac Test Boot/private/var/vm/'*"
	do shell script "rm -rf '/Volumes/Mac Test Boot/private/var/folders/'*"
	do shell script "rm -rf '/Volumes/Mac Test Boot/private/var/tmp/'*"
	do shell script "rm -rf '/Volumes/Mac Test Boot/private/tmp/'*"
	
	-- Get's created if drive was selected with Carbon Copy Cloner
	do shell script "rm -rf '/Volumes/Mac Test Boot/Library/Application Support/com.bombich.ccc'"
	
	set usersList to {"Staff", "Tester"}
	repeat with thisUser in usersList
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Desktop/QA Helper - Computer Specs.txt'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Desktop/TESTING'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Desktop/REINSTALL'"
		
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/ByHost/'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Application Support/com.apple.sharedfilelist/'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Application Support/App Store/updatejournal.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/.bash_history'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/.bash_sessions/'"
		
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/_geeks3d_gputest_log.txt'"
		
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Safari'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Caches/Apple - Safari - Safari Extensions Gallery'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Caches/Metadata/Safari'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Caches/com.apple.Safari'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Caches/com.apple.WebKit.PluginProcess'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Cookies/Cookies.binarycookies'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/Apple - Safari - Safari Extensions Gallery'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.Safari.LSSharedFileList.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.Safari.RSS.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.Safari.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.Safari.SafeBrowsing.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.Safari.SandboxBroker.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.SafariBookmarksSyncAgent.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.SafariCloudHistoryPushAgent.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.WebFoundation.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.WebKit.PluginHost.plist'"
		do shell script "rm -f '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Preferences/com.apple.WebKit.PluginProcess.plist'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/PubSub/Database'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Library/Saved Application State/com.apple.Safari.savedState'"
		
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Pictures/GPU Stress Test/'"
		do shell script "rm -rf '/Volumes/Mac Test Boot/Users/" & thisUser & "/Music/iTunes/'"
	end repeat
	
	tell application "Terminal"
		activate
		do script "find '/Volumes/Mac Test Boot' -name '.DS_Store' -type f -print -delete"
		activate
	end tell
	
	delay 2
end try

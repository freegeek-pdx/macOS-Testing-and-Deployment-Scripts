#!/bin/bash

#
# Created by Pico Mitchell on 4/19/21.
# For MacLand @ Free Geek
# Version: 2022.10.17-1
#
# MIT License
#
# Copyright (c) 2021 Free Geek
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# NOTICE: This script will only exist on boot to be able to run via LaunchDaemon when booting after not successfully completing fg-prepare-os.
# Actually, it will also exist when booting for fg-snapshot-reset, but will not run since there will be no error in the log.

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

launch_daemon_path='/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist'

launch_login_progress_app() {
	if [[ -f "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" && ! -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		ditto -x -k --noqtn "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" "${SCRIPT_DIR}/Tools" &> /dev/null
		touch "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app"
	fi

	if [[ -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		# Cannot open "Free Geek Login Progress" directly when at Login Window, but a LaunchAgent with LimitLoadToSessionType=LoginWindow and "launchctl load -S LoginWindow" can open it.
		# In my testing I haven't been able to figure out how to do this with any of the modern "launchctl bootstrap" options, but maybe there is some way that I haven't found.

		login_progress_launch_agent_path='/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'

		# NOTE: The following LaunchAgent is setup to run a signed script with launches the app and has "AssociatedBundleIdentifiers" specified to be properly displayed in the "Login Items" list in "System Settings" on macOS 13 Ventura and newer.
		# BUT, this is just done for consistency with other code since this particular script will never run when a user is logged in to even be able to see that list in macOS 13 Ventura.
		# On macOS 12 Monterey and older, the "AssociatedBundleIdentifiers" will just be ignored and the signed launcher script will behave just as if we ran "/usr/bin/open" directly via the LaunchAgent.
		PlistBuddy \
			-c 'Add :Label string org.freegeek.Free-Geek-Login-Progress' \
			-c 'Add :LimitLoadToSessionType string LoginWindow' \
			-c "Add :Program string '${SCRIPT_DIR}/Tools/Free Geek Login Progress.app/Contents/Resources/Launch Free Geek Login Progress'" \
			-c 'Add :AssociatedBundleIdentifiers string org.freegeek.Free-Geek-Login-Progress' \
			-c 'Add :RunAtLoad bool true' \
			-c 'Add :StandardOutPath string /dev/null' \
			-c 'Add :StandardErrorPath string /dev/null' \
			"${login_progress_launch_agent_path}" &> /dev/null

		launchctl load -S LoginWindow "${login_progress_launch_agent_path}"

		for (( wait_for_progress_app_seconds = 0; wait_for_progress_app_seconds < 15; wait_for_progress_app_seconds ++ )); do
			if pgrep -q 'Free Geek Login Progress'; then
				break
			else
				sleep 1
			fi
		done

		launchctl unload -S LoginWindow "${login_progress_launch_agent_path}"
		rm -f "${login_progress_launch_agent_path}"
	fi
}

if [[ "${SCRIPT_DIR}" == '/Users/Shared/fg-error-occurred' && -f "${launch_daemon_path}" && -f '/private/var/db/.AppleSetupDone' && "${EUID:-$(id -u)}" == '0' && \
	  ! -f '/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist' && -f '/Users/Shared/Build Info/Prepare OS Log.txt' ]] && grep -qF $'\tERROR:' '/Users/Shared/Build Info/Prepare OS Log.txt'; then
	# Do not run if fg-install-packages LaunchDaemon exists since that will do since it same error display on its own when rebooting after an error occurred.
	# The fg-install-packages LaunchDaemon needs to do its own identical error handling like this in case an error occurs before or after this was created or deleted by fg-prepare-os package.


	# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
	# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.
	
	for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		if afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff" &> /dev/null; then
			break
		else
			sleep 1
		fi
	done


	# WAIT FOR FULL BOOT
	# Since LaunchDaemons start so early on boot, always wait for full boot before continuing so that everything is run in a consistent state and all system services have been started.
	# Through investigation, I found that "coreauthd" is consistently the last, or nearly the last, root process to be started before the login window is displayed.

	until pgrep -q 'coreauthd'; do
		sleep 2
	done
	

	# DO NOT ALLOW SLEEP

	caffeinate -dimsu -w "$$" &


	# LAUNCH LOGIN PROGRESS APP

	launch_login_progress_app
	

	# ANNOUNCE DELIVER TO I.T. *AFTER* LOGIN WINDOW IS DISPLAYED

	osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
	afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"
fi

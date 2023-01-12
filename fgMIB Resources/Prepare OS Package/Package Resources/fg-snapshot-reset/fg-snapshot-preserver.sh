#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell on 3/19/21.
# For MacLand @ Free Geek
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

# APFS Snapshots are somewhat limited by macOS in that they only exist for 24 hours after being created and are purged by the "deleted" daemon automatically after that time.
# I found 2 ways around this issue, and this LaunchDaemon script exists to perform whichever of these solutions it's capable of doing when it's run.

# Solution 1: MANIPULATE DATE AND TIME
	# Manipulate the date and time so that macOS never thinks 24 hours have passed. Through investigation I also found that if a Snapshot is in the future, macOS will purge it.
	# So, this script will compare the current date with the reset Snapshot date and set the date back to the reset Snapshot date so that macOS does not think 24 hours have passed.
	# Since Network Time must be turned off to set the date back, worldtimeapi.org is used to keep the actual time in sync even though the date will be set back to the reset Snapshot date.
	# There is a possible edge case where the actual time could be earlier the reset Snapshots time, which would put the reset Snapshot in the future.
	# This is edge case is checked for and the time will be set to the reset Snapshot time if the actual time would put the reset Snapshot in the future.
	# To help avoid this issue, the time was set back to midnight when creating the reset Snapshot so that the reset Snapshot could really only be in the future for a few seconds near midnight.

# Solution 2: KEEP THE SNAPSHOT MOUNTED
	# This is a much better solution than manipulating the date and time (since internet things can get wonky when the date is wrong).
	# The issue with this solution is that a Snapshot can only be mounted by an app that has been granted Full Disk Access, and LaunchDaemon scripts cannot be granted Full Disk Access.
	# To workaround this limitation, I created the "Free Geek Snapshot Helper" AppleScript applet which can be granted Full Disk Access and then mount the reset Snapshot as soon as possible on each boot.
	# And, "Free Geek Snapshot Helper" will always be granted Full Disk Access right off the bat during a customized installation by "fg-install-os" (which you can read about in the comments in that script).
	# This script will always run "Free Geek Snapshot Helper" first, and check whether or not it was able to mount the reset Snapshot. If it was, Network Time will be left on (or turned on) and that will be all that is done.
	# If "Free Geek Snapshot Helper" could not mount the Snapshot (such as very early on boot or if something went wrong with "Free Geek Snapshot Helper" being granted Full Disk Access), this script will fallback to using the date and time manipulation solution.

# ANOTHER SNAPSHOT NOTE: macOS will also only keep 1 Snapshot per hour. If multiple Snapshots exist within the same hour, only the earliest one for that hour will be kept (unless a newer one has been mounted, then that one will also survive while mounted).

# CAVEAT FOR macOS 10.15 Catalina!
	# Even if the reset Snapshot is mounted to prevent it from being purged by the "deleted" daemon, "Restore from Time Machine Backup" in Recovery will not show the reset Snapshot if more than 24 hours has passed and the "deleted" daemon has run *which would* have purged it.
	# It seems that somehow the "deleted" daemon is maybe marking the reset Snapshot as unusable and preventing it from being able to show up in "Restore from Time Machine Backup" in Recovery. This seems to not be an issue on macOS 11 Big Sur though.
	# So, ALWAYS manipulate the system date (Solution 1) to keep set to the Snapshot date on macOS 10.15 Catalina and do not bother mounting the Snapshot (since knowing the Snapshot got purged is better user feedback than it just not showing in Recovery).

readonly SCRIPT_VERSION='2023.1.9-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

readonly DEMO_USERNAME='fg-demo'

# About running "launchctl", "osascript", and "open" commands as another user: https://scriptingosx.com/2020/08/running-a-command-as-another-user/
DEMO_USER_UID="$(id -u "${DEMO_USERNAME}" 2> /dev/null || echo '502')"
readonly DEMO_USER_UID

DARWIN_MAJOR_VERSION="$(uname -r | cut -d '.' -f 1)" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc.
readonly DARWIN_MAJOR_VERSION

write_to_log() {
	echo -e "$(date '+%D %T')\t$1" >> "${SCRIPT_DIR}/log.txt"
}

write_to_log "Running Snapshot Preserver (version ${SCRIPT_VERSION})"

if pgrep -qf "${BASH_SOURCE[0]}"; then
	# Need to check for an existing instance already running because of how this script could also be executed by a LaunchDaemon as well as
	# "Free Geek Setup" or "Free Geek Demo Helper" which could conflict with each other and cause multiple instances to be executed at the same time.
	# But, the LaunchDaemon schedule alone will never execute multiple instances if the previous LaunchDaemon instance is still running.

	write_to_log 'Exiting Snapshot Preserver - Another Instance Is Already Running'
	exit 2
fi

manually_sync_time() {
	if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then
		actual_date_time_info="$(curl -m 5 -sfL 'http://worldtimeapi.org/api/ip.txt' 2> /dev/null)" # Always use "http" since this is to set the correct time when we know the date will be in the past and if the date is too far in the past then "https" will fail anyways while "http" never will.
		actual_timezone="$(echo "${actual_date_time_info}" | awk -F ': ' '($1 == "timezone") { print $NF; exit }')"
		actual_date_time="$(echo "${actual_date_time_info}" | awk -F ': ' '($1 == "datetime") { print $NF; exit }')"
		
		actual_time=''
		actual_time_int="$(date '+%H%M%S')" # Will fallback to checking current system time if failed to get actual time (even though this check already happened before this function was called).
		if [[ -n "${actual_date_time}" ]]; then
			actual_time="${actual_date_time:11:8}"
			actual_time_int="${actual_time//:/}"
		fi

		if (( 10#$actual_time_int < 10#$1 )); then # "10#" removes any leading zeros to not force octal interpretation: https://github.com/koalaman/shellcheck/wiki/SC2004#rationale ($1 = reset_snapshot_time)
			# If the reset Snapshot time is in the future, macOS would purge it if the "deleted" daemon runs.
			# So, never allow the system time be less that the reset Snapshot time.

			systemsetup -settimezone "${actual_timezone}" &> /dev/null
			systemsetup -settime "${1:0:2}:${1:2:2}:${1:4:2}" &> /dev/null
			
			touch "${SCRIPT_DIR}/.timeNotSynced" # Create this flag so that the time can get synced to the correct time next time this script runs.

			write_to_log 'Blocked Manual Time Sync to Not Put Reset Snapshot in Future'
		elif [[ -n "${actual_time}" ]]; then
			systemsetup -settimezone "${actual_timezone}" &> /dev/null
			systemsetup -settime "${actual_time}" &> /dev/null
			rm -f "${SCRIPT_DIR}/.timeNotSynced"

			write_to_log 'Manually Synced Time'
		else
			touch "${SCRIPT_DIR}/.timeNotSynced"

			write_to_log 'Failed to Manually Sync Time'
		fi
	else
		write_to_log 'Did Not Attempt to Manual Time Sync Since Network Time Is On'
	fi
}

attempt_to_mount_reset_snapshot() {
	if (( DARWIN_MAJOR_VERSION >= 20 )); then # DO NOT mount reset Snapshot on macOS 10.15 Catalina (see CAVEAT notes above).
		if [[ -d "/Users/${DEMO_USERNAME}/Applications/Free Geek Snapshot Helper.app" && ! -d "${SCRIPT_DIR}/mount/Users/Shared/fg-snapshot-reset" ]]; then
			# This "Free Geek Snapshot Helper" app will attempt to mount the reset Snapshot, which prevents macOS from deleting it.
			# https://eclecticlight.co/2021/03/28/last-week-on-my-mac-macos-at-20-apfs-at-4/#comment-59001
			# This is done in an app instead of this script since Full Disk Access is required to be able to mount Snapshots. This script could mount the Snapshot if "bash" was granted Full Disk Access, but that is overzealous.
			# "Free Geek Snapshot Helper" will always be granted Full Disk Access right off the bat during a customized installation by "fg-install-os" (which you can read about in the comments in that script).

			if pgrep -qx 'Finder'; then
				# "Free Geek Snapshot Helper" will not be able to mount the reset Snapshot when this global LaunchDaemon is first run very early on boot, so will not try to launch unless logged in (by checking if Finder is running).
				# But, "Free Geek Demo Helper" will launch this script when it is run on login via user LaunchAgent which will get the reset Snapshot mounted as soon as possible.

				for (( launch_attempt = 1; launch_attempt <= 30; launch_attempt ++ )); do
					if launchctl asuser "${DEMO_USER_UID}" sudo -u "${DEMO_USERNAME}" open -na "/Users/${DEMO_USERNAME}/Applications/Free Geek Snapshot Helper.app"; then
						touch "${SCRIPT_DIR}/.launchedSnapshotHelper"
						write_to_log 'Launched Free Geek Snapshot Helper'

						for (( wait_for_mount = 0; wait_for_mount < 10; wait_for_mount ++ )); do
							sleep 1 # Give "Free Geek Snapshot Helper" up to 10 seconds to mount the reset Snapshot before checking for it and moving on if it's not mounted.

							if [[ ! -f "${SCRIPT_DIR}/.launchedSnapshotHelper" ]]; then
								break # "Free Geek Snapshot Helper" will delete this flag file after it's finished running (whether or not it was able to mount the reset Snapshot).
							fi
						done

						rm -rf "${SCRIPT_DIR}/.launchedSnapshotHelper"

						break
					else
						# This should not normally happened. If it does, it was probably JUST after login, so keep trying every 3 seconds for the next minute.
						write_to_log "Failed to Launch Free Geek Snapshot Helper (Attempt ${launch_attempt} of 30)"
						sleep 3
					fi
				done
			else
				write_to_log 'Not Attempting to Launch Free Geek Snapshot Helper Since Not Logged In'
			fi
		fi

		if [[ -d "${SCRIPT_DIR}/mount/Users/Shared/fg-snapshot-reset" ]]; then
			write_to_log 'Reset Snapshot is Mounted, Do Not Need to Manipulate Date'

			if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then
				if [[ -n "$1" ]]; then
					# Reset DATE to actual DATE (from before being set back to Snapshot date).
					# This is in case internet is not available to re-sync date right away when network time is turned on.
					systemsetup -setdate "$1" &> /dev/null
				fi

				systemsetup -setusingnetworktime on &> /dev/null
				rm -f "${SCRIPT_DIR}/.timeNotSynced"
				write_to_log 'Turned Network Time On'
			fi

			return 0
		fi
	fi

	return 1
}

set_date_to_reset_snapshot_date() {
	if [[ "$1" != "$(date '+%F')" ]]; then
		if [[ "$(sudo systemsetup -getusingnetworktime)" == *': On' ]]; then
			systemsetup -setusingnetworktime off &> /dev/null
			write_to_log 'Turned Network Time Off'
		else
			write_to_log 'Network Time Already Off'
		fi

		systemsetup -setdate "${1:5:2}:${1:8:2}:${1:2:2}" &> /dev/null # Reset DATE to Snapshot DATE.
		
		write_to_log 'Set Date Back to Reset Snapshot Date'

		return 0
	else
		write_to_log 'Current Date Is Equal to Reset Snapshot Date, Do Not Need to Manipulate Date'
	fi

	return 1
}

secure_token_holder_exists_that_cannot_be_removed="$([[ -n "$(ioreg -rc AppleSEPManager)" && "$(diskutil apfs listCryptoUsers /)" != 'No cryptographic users for disk'* ]] && echo 'true' || echo 'false')"
# If this Mac has a Secure Enclave (SEP) which is present on T2 and Apple Silicon Macs, Secure Tokens cannot be removed by fg-snapshot-reset.
# fg-install-os will only allow macOS 11 Big Sur to be installed on these Macs since Secure Tokens can be prevented (which cannot be done on older versions of macOS).
# But, just to be extra safe, double-check that no Secure Token holders exist on SEP Macs and delete the reset Snapshot if so.
# This way, the technician can be notified of the issue by Snapshot Helper before a Snapshot reset is attempted and fails.

if ! $secure_token_holder_exists_that_cannot_be_removed && [[ -f '/Users/Shared/.fgResetSnapshotCreated' && "$(tmutil listlocalsnapshots / | grep 'com.apple.TimeMachine' | head -1)" == "$(head -1 '/Users/Shared/.fgResetSnapshotCreated')" && "$(fdesetup isactive)" == 'false' ]]; then
	was_logged_in_at_launch="$(pgrep -qx 'Finder' && echo 'true' || echo 'false')"
	
	if ! attempt_to_mount_reset_snapshot; then
		# If "Free Geek Snapshot Helper" has not been granted Full Disk Access yet (or could not mount the Snapshot very early on boot),
		# fallback to using the date and time manipulation which will keep the system time within 24 hours of the reset Snapshot creation date,
		# which is the only other way I know of to prevent macOS from deleting the Snapshot automatically after 24 hours have passes.
		# The date and time manipulation code was written before deciding to also create and app to be granted Full Disk Access to be able
		# to mount the reset Snapshot, so it is pretty well tested and robust.

		write_to_log 'Reset Snapshot IS NOT Mounted, May Need to Manipulate Date'
		
		actual_date="$(date '+%m:%d:%y')"
		
		reset_snapshot_name="$(head -1 '/Users/Shared/.fgResetSnapshotCreated')"
		reset_snapshot_date="${reset_snapshot_name:22:10}"
		reset_snapshot_time="${reset_snapshot_name:33:6}"
		
		did_set_date_back_to_reset_snapshot_date=false
		time_needs_sync=false

		if set_date_to_reset_snapshot_date "${reset_snapshot_date}"; then
			did_set_date_back_to_reset_snapshot_date=true # This will be used to reboot after the DATE has been set back to make sure StartCalendarInterval continues properly.
			time_needs_sync=true # Make sure TIME stays correct after resetting the date.
		elif [[ -f "${SCRIPT_DIR}/.timeNotSynced" ]]; then
			if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then
				# Syncing time via curl could have fail on boot, or could have been blocked on the last run if it would have put the reset Snapshot in the future.
				# So, if this flag is set, we need to sync the time even if the date has not just been updated.
				write_to_log 'Previously Failed to Sync Time, Will Try Again'
				time_needs_sync=true
			else
				rm -f "${SCRIPT_DIR}/.timeNotSynced"
				write_to_log 'Previously Failed to Sync Time, BUT Now Network Time Is On'
			fi
		fi

		if (( 10#$(date '+%H%M%S') < 10#$reset_snapshot_time )); then # "10#" removes any leading zeros to not force octal interpretation: https://github.com/koalaman/shellcheck/wiki/SC2004#rationale
			# If the reset Snapshot time is in the future, macOS would purge it if the "deleted" daemon runs.
			# So, never allow the system time be less that the reset Snapshot time.
			
			if [[ "$(sudo systemsetup -getusingnetworktime)" == *': On' ]]; then
				systemsetup -setusingnetworktime off &> /dev/null
				write_to_log 'Turned Network Time Off'
			else
				write_to_log 'Network Time Already Off'
			fi

			systemsetup -settime "${reset_snapshot_time:0:2}:${reset_snapshot_time:2:2}:${reset_snapshot_time:4:2}" &> /dev/null

			write_to_log 'Adjusted Time to Not Put Reset Snapshot in Future'
			
			# We can still manually_sync_time (if needed) after doing this since manually_sync_time will do this same check
			# against the actual time and will not set an actual time that would put the reset Snapshot in the future.
		fi

		did_wait_for_login=false
		if ! $was_logged_in_at_launch && (( DARWIN_MAJOR_VERSION >= 20 )); then # DO NOT wait to try mounting reset Snapshot after login on macOS 10.15 Catalina (see CAVEAT notes above).
			# If was not logged in on first attempt to mount reset Snapshot, wait until login to attempt to mount reset Snapshot again before forcing a reboot if necessary.
			write_to_log 'Waiting for Login to Launch Free Geek Snapshot Helper'

			until pgrep -qx 'Finder'; do
				did_wait_for_login=true
				sleep 2

				# If network time is on, keep checking to make sure date hasn't been synced during boot since this script was launched.
				if [[ "$(sudo systemsetup -getusingnetworktime)" == *': On' ]] && set_date_to_reset_snapshot_date "${reset_snapshot_date}"; then
					did_set_date_back_to_reset_snapshot_date=true # This will be used to reboot after the DATE has been set back to make sure StartCalendarInterval continues properly.
					time_needs_sync=true # Make sure TIME stays correct after resetting the date.
				fi
			done

			attempt_to_mount_reset_snapshot "${actual_date}" # If the reset Snapshot is mounted, the date will be set back to actual_date and network time will be turned back on.
		fi

		if [[ ! -d "${SCRIPT_DIR}/mount/Users/Shared/fg-snapshot-reset" ]]; then
			
			# If waited for login and network time is on, make sure date hasn't been synced since waiting for login.
			if $did_wait_for_login && [[ "$(sudo systemsetup -getusingnetworktime)" == *': On' ]] && set_date_to_reset_snapshot_date "${reset_snapshot_date}"; then
				did_set_date_back_to_reset_snapshot_date=true # This will be used to reboot after the DATE has been set back to make sure StartCalendarInterval continues properly.
				time_needs_sync=true # Make sure TIME stays correct after resetting the date.
			fi

			if $time_needs_sync; then
				manually_sync_time "${reset_snapshot_time}"
			fi
			
			if $did_set_date_back_to_reset_snapshot_date; then

				# REBOOT AFTER DATE IS SET BACK IN TIME (if could not mount reset Snapshot after login or is macOS 10.15 Catalina)

				# This is EXTREMELY IMPORTANT because if the date is set back in time, such as at midnight, this LaunchDaemon's StartCalendarInterval
				# would stop being processed until the date and time caught back up to the next scheduled run before the date was set to the past
				# which would cause this script to stop being run properly after the first day (unless the computer is rebooted manually).

				# Since the StartCalendarInterval schedule does pick back up after the date and time catches back up to next scheduled run,
				# we do not really need to worry about small time adjustements being set back in time (which could happen when time is synced).
				# And we do not need to worry about any adjustments forward in time since this causes the LaunchDaemon to run immediately
				# since macOS detects that the next scheduled run has already passed, as if the computer just woke from sleep.

				# I tried using "launchctl kickstart -k 'system/org.freegeek.fg-snapshot-preserver'" to only
				# reload this specific LaunchDaemon but since (I believe) the date change messed up the system-wide
				# scheduling, the LaunchDaemon would only RunAtLoad and would not continue the StartCalendarInterval schedule.
				# I also tried "launchctl reboot userspace" which did restart the StartCalendarInterval schedule properly,
				# but it seemed to oddly cause issues with the AppleScript applets not being able to fully load properly.
				# The AppleScript applets would launch, but then never do their work or show any alerts or dialogs,
				# possibly because of hanging forever on "delay" commands because of going back in time since boot.
				# I saw similar kinds issues like this when time got set back after launching the "Free Geek Login Progress" app.

				# Therefore, a full computer reboot seems to be the most reliable option to be sure everything works properly after setting the date into the past.
				# This *should* only happen on boot, right after login, a day or more after installation on macOS 10.15 Catalina where the reset Snapshot will not be mounted.
				# The reboot happens right after login since we'll wait for login to be sure we can't mount the reset Snapshot instead of having to reboot.
				# Or this could happen at midnight if the computer is left on overnight on macOS 10.15 Catalina where the reset Snapshot will not be mounted.
				
				launchctl asuser "${DEMO_USER_UID}" sudo -u "${DEMO_USERNAME}" launchctl reboot apps # This is a fast way to kill all running DEMO_USERNAME apps (https://eclecticlight.co/2019/08/27/kickstarting-and-tearing-down-with-launchctl/)
				# so that the following prompt will be the only thing visible on screen before reboot.
				afplay '/System/Library/Sounds/Purr.aiff' & # Continue to display dialog before this is done playing.
				reset_date_dialog_icon_path="${SCRIPT_DIR}/Resources/DateAndTime.icns" # Had to extract images from Assets.car in DateAndTime.prefPane and re-create icns file to include and use here.
				if [[ ! -f "${reset_date_dialog_icon_path}" ]]; then reset_date_dialog_icon_path='/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Clock.icns'; fi # This icon doesn't have the calendar in the corner, but use it as a fallback.
				launchctl asuser "${DEMO_USER_UID}" sudo -u "${DEMO_USERNAME}" osascript -e "display dialog \"\nRebooting in 5 Seconds After Setting Date\nBack to Reset Snapshot Date (${reset_snapshot_date})…\" buttons {\"OK\"} with title \"Free Geek Snapshot Preserver\"$([[ -f "${reset_date_dialog_icon_path}" ]] && echo " with icon (\"${reset_date_dialog_icon_path}\" as POSIX file)")" &> /dev/null & disown
				sleep 5 # Give the technician some time to see this alert to know the computer didn't reboot because of a hardware issue.

				launchctl asuser "${DEMO_USER_UID}" sudo -u "${DEMO_USERNAME}" launchctl reboot apps # Kill all running DEMO_USERNAME apps AGAIN in case any were launched in the 5 seconds since the dialog was shown (so that the dialog will be visible just before reboot).
				
				nvram 'StartupMute=%01' # Disable chime for forced reboot.

				write_to_log 'Rebooting Mac After Setting Date Back to Reset Snapshot Date'
				shutdown -r now &> /dev/null

				exit 0
			fi
		fi
	fi
else
	if [[ ! -f '/Users/Shared/.fgResetSnapshotLost' ]]; then
		effective_loss_date_time="$(date '+%D %T')" # The possibly manipulated time before turning back on Network Time if it is off.

		if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then
			systemsetup -setusingnetworktime on &> /dev/null
			rm -f "${SCRIPT_DIR}/.timeNotSynced"
			write_to_log 'Turned Network Time On'
		fi

		actual_loss_date_time="$(date '+%D %T')" # The actual time which should have synced since turning back on Network Time if it was off.

		loss_date_time_display="${effective_loss_date_time} / ${actual_loss_date_time}"
		if [[ "${effective_loss_date_time}" == "${actual_loss_date_time}" ]]; then loss_date_time_display="${actual_loss_date_time}"; fi

		write_to_log "Lost Reset Snapshot at ${loss_date_time_display}"
		
		if [[ -f '/Users/Shared/.fgResetSnapshotCreated' ]]; then
			mv '/Users/Shared/.fgResetSnapshotCreated' '/Users/Shared/.fgResetSnapshotLost'

			if $secure_token_holder_exists_that_cannot_be_removed; then
				echo 'LOST REASON: Secure Token Holder Exists That Cannot Be Removed' >> '/Users/Shared/.fgResetSnapshotLost'
			elif [[ "$(fdesetup isactive)" == 'true' ]]; then
				echo 'LOST REASON: FileVault Enabled' >> '/Users/Shared/.fgResetSnapshotLost'
			elif [[ "$(tmutil listlocalsnapshots / | grep 'com.apple.TimeMachine' | head -1)" != "$(head -1 '/Users/Shared/.fgResetSnapshotLost')" ]]; then
				existing_snapshots="$(tmutil listlocalsnapshots / | grep 'com.apple.TimeMachine')"
				existing_snapshots="${existing_snapshots//$'\n'/, }"
				
				echo "LOST REASON: macOS Deleted Reset Snapshot at ${loss_date_time_display} (EXISTING SNAPSHOTS: ${existing_snapshots:-NONE})" >> '/Users/Shared/.fgResetSnapshotLost'
			else
				echo 'LOST REASON: Unknown' >> '/Users/Shared/.fgResetSnapshotLost'
			fi
		else
			echo 'LOST REASON: fgResetSnapshotCreated File Deleted' >> '/Users/Shared/.fgResetSnapshotLost'
		fi

		tmutil deletelocalsnapshots / &> /dev/null
	fi

	if pgrep -qx 'Finder'; then
		# Launch "Free Geek Snapshot Helper" (if logged in) since it also serves as a GUI to display an alert about the reset Snapshot being lost.
		launchctl asuser "${DEMO_USER_UID}" sudo -u "${DEMO_USERNAME}" open -na "/Users/${DEMO_USERNAME}/Applications/Free Geek Snapshot Helper.app"
	fi

	# DO NOT delete the "fg-snapshot-preserver" LaunchDaemon or this script since we want it to keep running every 5 minutes to keep
	# launching "Free Geek Snapshot Helper" to keep alerting that the reset Snapshot has been lost since it is a critical error.
fi

if nvram 'StartupMute' &> /dev/null; then
	nvram -d 'StartupMute' # Bring back chime if it was previously disabled for a forced reboot.
fi

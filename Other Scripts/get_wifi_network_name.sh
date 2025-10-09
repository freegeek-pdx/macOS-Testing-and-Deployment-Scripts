#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell on 9/11/25.
#
# MIT License
#
# Copyright (c) 2025 Free Geek
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

PATH='/usr/bin:/bin:/usr/sbin:/sbin:'

macos_version="$(sw_vers -productversion)"

is_macos_15_or_newer=false
if [[ "$(echo -e "${macos_version}\n15.0" | sort -V)" == *$'\n'"${macos_version}" ]]; then
	is_macos_15_or_newer=true
fi

is_macos_15_dot_6_or_newer=false
if $is_macos_15_or_newer && [[ "$(echo -e "${macos_version}\n15.6" | sort -V)" == *$'\n'"${macos_version}" ]]; then
	is_macos_15_dot_6_or_newer=true
fi

run_as_sudo_if_needed() { # Based On: https://github.com/freegeek-pdx/mkuser/blob/main/utilities/download-and-install-mkuser.sh#L41-L48
	if (( ${EUID:-$(id -u)} != 0 )); then # Only need to run with "sudo" if this script itself IS NOT already running as root.
		sudo -p 'Enter Password for "%p" to Get Wi-Fi Network Name: ' "$@"
	else
		"$@"
	fi
}

current_wifi_network_name=''

while read -ra this_network_hardware_ports_line_elements; do
	if [[ "${this_network_hardware_ports_line_elements[0]}" == 'Device:' ]] && getairportnetwork_output="$(networksetup -getairportnetwork "${this_network_hardware_ports_line_elements[1]}" 2> /dev/null)" && [[ "${getairportnetwork_output}" != *'disabled.' ]]; then
		if [[ "${getairportnetwork_output}" == 'Current Wi-Fi Network: '* ]]; then
			current_wifi_network_name="${getairportnetwork_output#*: }"
		elif $is_macos_15_or_newer; then
			# Starting on macOS 15, "networksetup -getairportnetwork" will always output "You are not associated with an AirPort network." even when connected to a Wi-Fi network.

			if [[ "${macos_version}" == '15.6'* ]] && (( ${EUID:-$(id -u)} != 0 )); then
				# If on macOS 15.6 (or macOS 15.6.1) and NOT running as root, can get Wi-Fi network name from "system_profiler SPAirPortDataType" without running a command as root, but that output is now also "<redacted>" on macOS 15.7 and macOS 26 and newer.
				# If this script is already running as root, fallback to using "ipconfig getsummary" instead as described below since it is much faster than "system_profiler SPAirPortDataType".

				current_wifi_network_name="$(/usr/libexec/PlistBuddy -c 'Print :0:_items:0:spairport_airport_interfaces:0:spairport_current_network_information:_name' /dev/stdin <<< "$(system_profiler -xml SPAirPortDataType)" 2> /dev/null)"
			else
				# If running on macOS 15-15.5 (or running as root on macOS 15.6-15.6.1) or macOS 15.7 or newer (including macOS 26 or newer), fallback to using "ipconfig getsummary" instead.
				# When running on macOS 15-15.5 (or running as root on macOS 15.6-15.6.1), "system_profiler SPAirPortDataType" could be used, but "ipconfig getsummary" is much faster (and is not redacted on macOS 15-15.5 so doesn't require running "ipconfig setverbose" as root).
				# When running on macOS 15.7 or newer (including macOS 26 or newer), running "ipconfig getsummary" after running "ipconfig setverbose 1" as root is currently the only known way to get the un-redacted Wi-Fi network name.

				if $is_macos_15_dot_6_or_newer; then
					# Starting with macOS 15.6, the Wi-Fi name on the "SSID" line of "ipconfig getsummary" will be "<redacted>" unless "ipconfig setverbose 1" is set, which must be run as root.
					# Apple support shared that "ipconfig setverbose 1" un-redacts the "ipconfig getsummary" output with a member of MacAdmins Slack who shared it there: https://macadmins.slack.com/archives/GA92U9YV9/p1757621890952369?thread_ts=1750227817.961659&cid=GA92U9YV9

					run_as_sudo_if_needed ipconfig setverbose 1 &> /dev/null # If not run as root/sudo, Wi-Fi name will be "<redacted>" on macOS 15.6 or newer.
				fi

				current_wifi_network_name="$(ipconfig getsummary "${this_network_hardware_ports_line_elements[1]}" | awk -F ' SSID : ' '/ SSID : / { print $2; exit }')"

				if $is_macos_15_dot_6_or_newer; then
					# Running "ipconfig setverbose 1" is a persistent system wide setting, so must manually disable by running "ipconfig setverbose 0" (which also requires running as root/sudo).

					run_as_sudo_if_needed ipconfig setverbose 0 &> /dev/null
				fi
			fi
		fi

		if [[ -n "${current_wifi_network_name}" ]]; then
			break
		fi
	fi
done < <(networksetup -listallhardwareports 2> /dev/null)

echo "${current_wifi_network_name:-N/A}"

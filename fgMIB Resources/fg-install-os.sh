#!/bin/bash

#
# Created by Pico Mitchell on 3/2/21.
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

readonly SCRIPT_VERSION='2022.5.19-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

readonly SCRIPT_DIR="${0%/*}" # Do not use dirname since it won't exist in recoveryOS and this script will always be launched by full path so this should always work.

IS_RECOVERY_OS="$([[ -d '/System/Installation' && ! -f '/usr/bin/pico' ]] && echo 'true' || echo 'false')" # The specified folder should exist in recoveryOS and the file should not.
readonly IS_RECOVERY_OS

BOOTED_DARWIN_MAJOR_VERSION="$(sw_vers -buildVersion | cut -c -2 | tr -dc '[:digit:]')" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc. ("uname -r" is not available in recoveryOS).
readonly BOOTED_DARWIN_MAJOR_VERSION

caffeinate_pid=''

if $IS_RECOVERY_OS; then
	# Disable sleep in recoveryOS.
	pmset -a sleep 0 displaysleep 0

	os_specific_extra_bins="${SCRIPT_DIR}/extra-bins/darwin-${BOOTED_DARWIN_MAJOR_VERSION}" # extra-bins must be OS specific because stuff like "networksetup" can fail on the wrong OS.
	
	if [[ ! -d "${os_specific_extra_bins}" ]]; then
		# If the exact OS specific extra-bins folder doesn't exist, use the oldest or newest one available depending on if the running OS is older or newer than those.
		os_specific_extra_bins=''
		all_os_specific_extra_bins="$(find "${SCRIPT_DIR}/extra-bins" -type d -maxdepth 1 -name 'darwin-*' 2> /dev/null | sort)"
		if [[ -n "${all_os_specific_extra_bins}" ]]; then
			os_specific_extra_bins="$(echo "${all_os_specific_extra_bins}" | tail -1)"
			oldest_os_specific_extra_bins="$(echo "${all_os_specific_extra_bins}" | head -1)"
			if (( BOOTED_DARWIN_MAJOR_VERSION < ${oldest_os_specific_extra_bins##*-} )); then
				os_specific_extra_bins="${oldest_os_specific_extra_bins}"
			fi
		fi
	fi

	if [[ -n "${os_specific_extra_bins}" && "${PATH}" != "${os_specific_extra_bins}:"* ]]; then
		PATH="${os_specific_extra_bins}:${PATH}" # Add os_specific_extra_bins to BEGINNING of PATH so that binaries missing from recoveryOS can be added and called and replacement versions can be used.
	fi
else
	# In full OS, use caffeinate to stay awake while script is running.
	caffeinate -dimsu -w "$$" &
	caffeinate_pid=$!
fi

readonly CLEAR_ANSI='\033[0m' # Clears all ANSI colors and styles.
# Start ANSI colors with "0;" so they clear all previous styles for convenience in ending bold and underline sections.
readonly ANSI_RED='\033[0;91m'
readonly ANSI_GREEN='\033[0;32m'
readonly ANSI_YELLOW='\033[0;33m'
readonly ANSI_PURPLE='\033[0;35m'
readonly ANSI_CYAN='\033[0;36m'
readonly ANSI_GREY='\033[0;90m'
# Do NOT start ANSI_BOLD and ANSI_UNDERLINE with "0;" so they can be combined with colors and eachother.
readonly ANSI_BOLD='\033[1m'
readonly ANSI_UNDERLINE='\033[4m'

FG_MIB_HEADER="
  ${ANSI_PURPLE}${ANSI_BOLD}fgMIB:${ANSI_PURPLE} Free Geek - Mac Install Buddy ${ANSI_GREY}(${SCRIPT_VERSION} / $($IS_RECOVERY_OS && echo 'recoveryOS' || echo 'macOS') $(sw_vers -productVersion))${CLEAR_ANSI}

"
readonly FG_MIB_HEADER

ansi_clear_screen() {
	# "clear" command is not available in recoveryOS, so instead of including it in extra-bins, use ANSI escape codes to clear the screen.
	# H = reset cursor to 0,0
	# 2J = clear screen (some documentation says this should also set to 0,0 but it does not in macOS)
	echo -ne '\033[H\033[2J'
}

trim_like_xargs() {
	# "xargs" command is not available in recoveryOS, so instead of including it in extra-bins, use "tr" and bash to get the job done.
	local delimiter
	delimiter="$2"
	if [[ -z "${delimiter}" ]]; then delimiter=' '; fi
	local trimmed
	trimmed="$(echo -ne "$1" | tr -s '[:space:]' "${delimiter}")"
	# Now there could only be a single leading or trailing space.
	trimmed="${trimmed#"${delimiter}"}"
	echo -ne "${trimmed%"${delimiter}"}"
}

strip_ansi_styles() {
	# The ANSI styles mess up grepping, comparing, and getting string length, so strip them when needed.
	# From: https://superuser.com/questions/380772/removing-ansi-color-codes-from-text-stream#comment2323889_380778
	echo -ne "$1" | sed -e $'s/\x1b\[[0-9;]*m//g'
}

# Use "sysctl" instead of "system_profiler" because "system_profiler" is not available in recoveryOS.
# Could show more detailed specs when in full OS, but we have other better tools for that.
MODEL_ID="$(trim_like_xargs "$(sysctl -n hw.model 2> /dev/null)")"
if [[ -z "${MODEL_ID}" ]]; then MODEL_ID='UNKNOWN Model Identifier'; fi
readonly MODEL_ID

SHORT_MODEL_NAME="${MODEL_ID//[0-9,]/}"
if [[ "${SHORT_MODEL_NAME}" == 'Mac' ]]; then
	SHORT_MODEL_NAME='Mac Studio' # The Mac Studio has a "MacXX,Y" Model Identifier without any "Studio" suffix (https://twitter.com/ClassicII_MrMac/status/1506146498198835206).
	# It's unclear if this is going to be a new style for all new Apple Silicon Macs from this point on or if the Mac Studio is actually internally considered a no suffix model,
	# like the MacBook (this person thinks all future Macs will be idenfied without a suffix, but I dunno: https://mobile.twitter.com/khronokernel/status/1501411685482958853)
	# TODO: Will need to keep an eye on this when future Apple Silicon Macs are released to see if all models will only get a "MacXX,Y" Model ID,
	# in which case we'll likely need to check the local Marketing Model Name here to extract the Short Model Name when "system_profiler" isn't available.
else
	declare -a short_model_name_end_components=( 'Pro' 'Air' 'mini' )
	for this_short_model_name_end_component in "${short_model_name_end_components[@]}"; do
		if [[ "${SHORT_MODEL_NAME}" == *"${this_short_model_name_end_component}" ]]; then
			SHORT_MODEL_NAME="${SHORT_MODEL_NAME/${this_short_model_name_end_component}/ ${this_short_model_name_end_component}}"
			break
		fi
	done
fi
readonly SHORT_MODEL_NAME

readonly MODEL_ID_NUMBER="${MODEL_ID//[^0-9,]/}"

model_name="${SHORT_MODEL_NAME} ${MODEL_ID_NUMBER}"

SERIAL="$(trim_like_xargs "$(PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null)")"
readonly SERIAL
readonly SPECS_SERIAL="${ANSI_BOLD}Serial:${CLEAR_ANSI} ${SERIAL}"

cpu_model="$(sysctl -n machdep.cpu.brand_string 2> /dev/null)"

declare -a cpu_model_removal_components=( 'Genuine' 'Intel' '(R)' '(TM)' 'CPU' 'processor' )
for this_cpu_model_removal_components in "${cpu_model_removal_components[@]}"; do
	cpu_model="${cpu_model//${this_cpu_model_removal_components}/ }"
done

if [[ "${cpu_model}" == *'0GHz'* ]]; then
	cpu_model="${cpu_model//0GHz/ GHz}"
else
	cpu_model="${cpu_model//GHz/ GHz}"
fi

cpu_model="$(trim_like_xargs "${cpu_model}")"

cpu_core_count="$(sysctl -n hw.physicalcpu_max 2> /dev/null)"
if [[ -n "${cpu_core_count}" ]]; then
	cpu_model+=" (${cpu_core_count} Core"
	if (( cpu_core_count > 1 )); then cpu_model+='s'; fi
	cpu_thread_count="$(sysctl -n hw.logicalcpu_max 2> /dev/null)"
	if [[ -n "${cpu_thread_count}" ]] && (( cpu_thread_count > cpu_core_count )); then cpu_model+=' + HT'; fi
	cpu_model+=')'
fi

readonly SPECS_CPU="${ANSI_BOLD}CPU:${CLEAR_ANSI} ${cpu_model}"
SPECS_CPU_NO_ANSI="$(strip_ansi_styles "${SPECS_CPU}")"
readonly SPECS_CPU_NO_ANSI

readonly SPECS_RAM="${ANSI_BOLD}RAM:${CLEAR_ANSI} $(( $(trim_like_xargs "$(sysctl -n hw.memsize 2> /dev/null)") / 1024 / 1024 / 1024 )) GB"

IS_APPLE_SILICON="$([[ "$1" == 'debugAS' || "$(sysctl -in hw.optional.arm64)" == '1' ]] && echo 'true' || echo 'false')"
readonly IS_APPLE_SILICON

specs_overview=''
did_load_marketing_model_name=false

load_specs_overview() {
	if ! $did_load_marketing_model_name; then
		local marketing_model_name

		if $IS_APPLE_SILICON; then
			# This local Marketing Model Name within "ioreg" only exists on Apple Silicon Macs.
			marketing_model_name="$(PlistBuddy -c 'Print :0:product-name' /dev/stdin <<< "$(ioreg -arc IOPlatformDevice -k product-name)" 2> /dev/null | tr -dc '[:print:]')" # Remove non-printable characters because this decoded value could end with a null char.
		elif (( ${#SERIAL} >= 11 )); then
			# The model part of the Serial Number is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials (which are very old and shouldn't actually be encountered: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/).
			# Starting with the 2021 MacBook Pro models, randomized 10 character Serial Numbers are now used which do not have any model specific characters, but those Macs will never get here or need to load the Marketing Model Name over the internet since they are Apple Silicon and the local Marketing Model Name will have been retrieved above.
			local model_characters_of_serial_number="${SERIAL:8}"
			local marketing_model_name_was_cached=false

			if ! $IS_RECOVERY_OS; then # If not in recoveryOS, try to get the marketing model name locally from the preferences location that "About This Mac" caches to after loading it over the internet.
				local possible_marketing_model_name

				if [[ "${EUID:-$(id -u)}" == '0' ]]; then # If running as root, check for the cached Marketing Model Name from the current user and if not found check for it from any and all other users.
					local current_user_id
					current_user_id="$(echo 'show State:/Users/ConsoleUser' | scutil | awk '($1 == "UID") { print $NF; exit }')"
					local current_user_name
					if [[ -n "${current_user_id}" ]] && (( current_user_id != 0 )); then
						current_user_name="$(dscl /Search -search /Users UniqueID "${current_user_id}" 2> /dev/null | awk '{ print $1; exit }')"
					fi

					if [[ -n "${current_user_name}" ]]; then # Always check cached preferences for current user first so that we know whether or not it needs to be cached for the current user if it is already cached for another user.
						# Since "defaults read" has no option to traverse into keys of dictionary values, use the whole "defaults export" output and parse it with "PlistBuddy" to get at the specific key of the "CPU Names" dictionary value that we want.
						# Using "defaults export" instead of accessing the plist file directly with "PlistBuddy" is important since preferences are not guaranteed to be written to disk if they were just set.
						possible_marketing_model_name="$(PlistBuddy -c "Print :'CPU Names':${model_characters_of_serial_number}-en-US_US" /dev/stdin <<< "$(launchctl asuser "${current_user_id}" sudo -u "${current_user_name}" defaults export com.apple.SystemProfiler -)" 2> /dev/null)"
						if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" == "${SHORT_MODEL_NAME}"* ]]; then
							marketing_model_name="${possible_marketing_model_name}"
							marketing_model_name_was_cached=true
						fi
					fi

					if [[ -z "${marketing_model_name}" ]]; then # If was not cached for current user, check any and all other users.
						local this_home_folder
						local user_name_for_home
						local user_id_for_home
						for this_home_folder in '/Users/'*; do
							if [[ -d "${this_home_folder}" && "${this_home_folder}" != '/Users/Shared' && "${this_home_folder}" != '/Users/Guest' ]]; then
								user_name_for_home="$(dscl /Search -search /Users NFSHomeDirectory "${this_home_folder}" | awk '{ print $1; exit }')"
								if [[ -n "${user_name_for_home}" ]]; then
									user_id_for_home="$(dscl -plist /Search -read "/Users/${user_name_for_home}" UniqueID 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null)"
									if [[ -n "${user_id_for_home}" && "${user_id_for_home}" != '0' && ( -z "${current_user_name}" || "${current_user_name}" != "${user_name_for_home}" ) ]]; then # No need to check current user in this loop since it was already checked.
										possible_marketing_model_name="$(PlistBuddy -c "Print :'CPU Names':${model_characters_of_serial_number}-en-US_US" /dev/stdin <<< "$(launchctl asuser "${user_id_for_home}" sudo -u "${user_name_for_home}" defaults export com.apple.SystemProfiler -)" 2> /dev/null)" # See notes above about using "PlistBuddy" with "defaults export".
										if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" == "${SHORT_MODEL_NAME}"* ]]; then
											marketing_model_name="${possible_marketing_model_name}"
											if [[ -z "${current_user_name}" ]]; then # DO NOT consider the Marketing Model Name cached if there is a current user that it was not cached for so that it can be cached to the current user.
												marketing_model_name_was_cached=true
											fi
											break
										fi
									fi
								fi
							fi
						done
					fi
				else # If running as a user, won't be able to check others home folders, so only check current user preferences.
					possible_marketing_model_name="$(PlistBuddy -c "Print :'CPU Names':${model_characters_of_serial_number}-en-US_US" /dev/stdin <<< "$(defaults export com.apple.SystemProfiler -)" 2> /dev/null)" # See notes above about using "PlistBuddy" with "defaults export".
					if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" == "${SHORT_MODEL_NAME}"* ]]; then
						marketing_model_name="${possible_marketing_model_name}"
						marketing_model_name_was_cached=true
					fi
				fi
			fi

			if [[ -z "${marketing_model_name}" ]]; then
				local marketing_model_name_xml
				marketing_model_name_xml="$(curl -m 5 -sL "https://support-sp.apple.com/sp/product?cc=${model_characters_of_serial_number}" 2> /dev/null)"

				if [[ -n "${marketing_model_name_xml}" ]]; then
					if [[ -f '/usr/bin/xmllint' ]]; then # xmllint doesn't exist in recoveryOS, but still use it when in full macOS.
						possible_marketing_model_name="$(xmllint --xpath '//configCode/text()' <(echo "${marketing_model_name_xml}") 2> /dev/null)"
					else
						possible_marketing_model_name="$(echo "${marketing_model_name_xml}" | awk -F '<configCode>|</configCode>' '/<configCode>/ { print $2; exit }')"
					fi

					if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" == "${SHORT_MODEL_NAME}"* ]]; then
						marketing_model_name="${possible_marketing_model_name}"
					fi
				fi
			fi

			if ! $IS_RECOVERY_OS && ! $marketing_model_name_was_cached && [[ -n "${marketing_model_name}" ]]; then
				# Cache the Marketing Model Name into the "About This Mac" preference key...
					# for the current user, if there is a current user (whether or not running as root), and the Marketing Model Name was downloaded or was loaded from another users cache,
					# OR for the first valid home folder detected if running as root and there is no current user and the Marketing Model Name was downloaded.

				local cpu_name_key_for_serial="${model_characters_of_serial_number}-en-US_US"
				local quoted_marketing_model_name_for_defaults
				quoted_marketing_model_name_for_defaults="$([[ "${marketing_model_name}" =~ [\(\)] ]] && echo "'${marketing_model_name}'" || echo "${marketing_model_name}")"
				# If the model contains parentheses, "defaults write" has trouble with it and the value needs to be specially quoted: https://apple.stackexchange.com/questions/300845/how-do-i-handle-e-g-correctly-escape-parens-in-a-defaults-write-key-val#answer-300853

				if [[ "${EUID:-$(id -u)}" == '0' ]]; then
					local user_id_for_cache
					local user_name_for_cache
					if [[ -n "${current_user_name}" ]]; then # Always cache for current user if there is one.
						user_id_for_cache="${current_user_id}"
						user_name_for_cache="${current_user_name}"
					else # Otherwise cache to first valid home folder detected.
						for this_home_folder in '/Users/'*; do
							if [[ -d "${this_home_folder}" && "${this_home_folder}" != '/Users/Shared' && "${this_home_folder}" != '/Users/Guest' ]]; then
								user_name_for_home="$(dscl /Search -search /Users NFSHomeDirectory "${this_home_folder}" | awk '{ print $1; exit }')"
								if [[ -n "${user_name_for_home}" ]]; then
									user_id_for_home="$(dscl -plist /Search -read "/Users/${user_name_for_home}" UniqueID 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null)"
									if [[ -n "${user_id_for_home}" && "${user_id_for_home}" != '0' ]]; then
										user_id_for_cache="${user_id_for_home}"
										user_name_for_cache="${user_name_for_home}"
										break
									fi
								fi
							fi
						done
					fi

					if [[ -n "${user_id_for_cache}" && "${user_name_for_cache}" != '0' && -n "${user_name_for_cache}" ]]; then
						launchctl asuser "${user_id_for_cache}" sudo -u "${user_name_for_cache}" defaults write com.apple.SystemProfiler 'CPU Names' -dict-add "${cpu_name_key_for_serial}" "${quoted_marketing_model_name_for_defaults}"
					fi
				else
					defaults write com.apple.SystemProfiler 'CPU Names' -dict-add "${cpu_name_key_for_serial}" "${quoted_marketing_model_name_for_defaults}"
				fi
			fi
		else
			model_name+=' (Invalid Serial Number for Marketing Model Name)';
			did_load_marketing_model_name=true # Do not keep trying for an invalid Serial Number.
		fi

		if [[ -n "${marketing_model_name}" ]]; then
			if [[ "${marketing_model_name}" == "${SHORT_MODEL_NAME}" ]]; then
				model_name+=' (No Marketing Model Name Specified)';
			else
				model_name="${marketing_model_name/${SHORT_MODEL_NAME}/${model_name}}"

				if [[ "${model_name}" != *" ${MODEL_ID_NUMBER}"* ]]; then
					model_name+=" ${MODEL_ID_NUMBER}"
				fi
			fi

			did_load_marketing_model_name=true
			specs_overview=''
		fi
	fi

	if [[ -z "${specs_overview}" ]]; then
		local specs_model="${ANSI_BOLD}Model:${CLEAR_ANSI} ${model_name}"
		local specs_model_no_ansi
		specs_model_no_ansi="$(strip_ansi_styles "${specs_model}")"

		local specs_model_vs_cpu_length_diff="$(( ( 5 + ${#specs_model_no_ansi} ) - ( 7 + ${#SPECS_CPU_NO_ANSI} ) ))"
		local specs_model_serial_spaces='  '
		local specs_cpu_ram_spaces='     '
		if [[ "${specs_model_vs_cpu_length_diff}" == '-'* ]]; then
		local space
		for (( space = 0; space > specs_model_vs_cpu_length_diff; space -- )); do
			specs_model_serial_spaces+=' '
		done
		else
		for (( space = 0; space < specs_model_vs_cpu_length_diff; space ++ )); do
			specs_cpu_ram_spaces+=' '
		done
		fi

		local specs_overview_line_one="    ${specs_model}${specs_model_serial_spaces}${SPECS_SERIAL}"
		local specs_overview_line_two="      ${SPECS_CPU}${specs_cpu_ram_spaces}${SPECS_RAM}"
		local specs_overview_line_one_no_ansi
		specs_overview_line_one_no_ansi="$(strip_ansi_styles "${specs_overview_line_one}")"
		local specs_overview_line_two_no_ansi
		specs_overview_line_two_no_ansi="$(strip_ansi_styles "${specs_overview_line_two}")"

		local terminal_width='80'
		if ! $IS_RECOVERY_OS; then terminal_width="$(tput cols || echo '80')"; fi # "tput" doesn't exist in Recovery. When in full macOS, if I redirect stderr for "tput cols" to "/dev/null" it always returns 80 instead of actual width, so don't redirect any possible error since this script must run in a Terminal anyway.

		if (( ${#specs_overview_line_one_no_ansi} > terminal_width )); then
			specs_overview_line_one="    ${specs_model}"
			specs_overview_line_two="      ${SPECS_CPU}  ${SPECS_RAM}  ${SPECS_SERIAL}"
			specs_overview_line_two_no_ansi="$(strip_ansi_styles "${specs_overview_line_two}")"
			if (( ${#specs_overview_line_two_no_ansi} > terminal_width )); then
				specs_overview_line_two="      ${SPECS_CPU}
      ${SPECS_RAM}  ${SPECS_SERIAL}"
			fi
		elif (( ${#specs_overview_line_two_no_ansi} > terminal_width )); then
			specs_overview_line_one="    ${specs_model}"
			specs_overview_line_two="      ${SPECS_CPU}
      ${SPECS_RAM}  ${SPECS_SERIAL}"
		fi

		# specs_overview IS NOT local since it is referenced outside of this function.
		specs_overview="
  ${ANSI_UNDERLINE}Specs Overview:${CLEAR_ANSI}

${specs_overview_line_one}
${specs_overview_line_two}
"
	fi
}

check_and_prompt_for_power_adapter_for_laptops() {
	# This will always pass if it's a Desktop. For Laptops, we do not want to risk power loss during drive erasure, OS installation, or OS customization.

	while ! pmset -g ps | grep -q "'AC Power'$"; do
		load_specs_overview
		ansi_clear_screen
		echo -e "${FG_MIB_HEADER}${specs_overview}

  ${ANSI_UNDERLINE}Power Adapter Required:${CLEAR_ANSI}

    ${ANSI_PURPLE}Plug in a ${ANSI_BOLD}Power Adapter${CLEAR_ANSI}${ANSI_PURPLE} and then press ${ANSI_BOLD}Return${CLEAR_ANSI}${ANSI_PURPLE} to continue.${CLEAR_ANSI}
"
		local power_adapter_testing_bypass
		read -r power_adapter_testing_bypass

		if [[ "${power_adapter_testing_bypass}" == 'TESTING' ]]; then
			break
		fi
	done
}

set_date_time_from_internet() {
	if $IS_RECOVERY_OS; then
		# Have to manually retrieve correct date/time and use the "date" command to set time in recoveryOS: https://www.alansiu.net/2020/08/05/setting-the-date-time-in-macos-10-14-recovery-mode/
		local actual_date_time
		actual_date_time="$(curl -m 5 -sL "http$( (( BOOTED_DARWIN_MAJOR_VERSION < 17 || BOOTED_DARWIN_MAJOR_VERSION > 18 )) && echo 's' )://worldtimeapi.org/api/ip.txt" 2> /dev/null | awk -F ': ' '($1 == "utc_datetime") { print $NF; exit }')" # Time gets set as UTC when using "date" command in recoveryOS.
		# Only use "https" on macOS 10.12 Sierra and older or macOS 10.15 Catalina and newer since "libcurl" in macOS 10.13 High Sierra and macOS 10.14 Mojave does not support "https" for some reason (it's odd that older versions do support it though).

		if [[ -n "${actual_date_time}" ]]; then
			date "${actual_date_time:5:2}${actual_date_time:8:2}${actual_date_time:11:2}${actual_date_time:14:2}${actual_date_time:2:2}.${actual_date_time:17:2}" &> /dev/null
		fi
	fi
}

set_date_time_and_prompt_for_internet_if_year_not_correct() {
	actual_current_year="${SCRIPT_VERSION%%.*}" # Get the actual current year from the script version so it's always up-to-date.

	if $IS_RECOVERY_OS && (( $(date '+%Y') < actual_current_year )); then # Do not try to set date/time in full OS since using "systemsetup" would require "sudo" (and it's pretty safe to assume date/time is correct when in full OS).
		set_date_time_from_internet

		while (( $(date '+%Y') < actual_current_year )); do
			load_specs_overview
			ansi_clear_screen
			echo -e "${FG_MIB_HEADER}${specs_overview}

  ${ANSI_UNDERLINE}Internet Required to Set Date:${CLEAR_ANSI}

    ${ANSI_YELLOW}${ANSI_BOLD}The system date is incorrectly set to $(trim_like_xargs "$(date)").${CLEAR_ANSI}

    Connect to a ${ANSI_BOLD}Wi-Fi${CLEAR_ANSI} network or plug in an ${ANSI_BOLD}Ethernet${CLEAR_ANSI} cable.
    If this Mac does not have Ethernet, use a Thunderbolt or USB adapter.

    ${ANSI_PURPLE}After connecting to ${ANSI_BOLD}Wi-Fi${CLEAR_ANSI}${ANSI_PURPLE} or ${ANSI_BOLD}Ethernet${CLEAR_ANSI}${ANSI_PURPLE}, press ${ANSI_BOLD}Return${CLEAR_ANSI}${ANSI_PURPLE} to correct the date.${CLEAR_ANSI}

    It may take a few moments for the internet connection to be established.
    If it takes more than a few minutes, please inform Free Geek I.T.${CLEAR_ANSI}
"
			local set_date_testing_bypass
			read -r set_date_testing_bypass

			set_date_time_from_internet

			if [[ "${set_date_testing_bypass}" == 'TESTING' ]]; then
				break
			fi
		done
	fi
}

CLEAN_INSTALL_REQUESTED="$([[ "$(echo "$1" | tr '[:upper:]' '[:lower:]')" == 'nopkg' || "$(echo "$1" | tr '[:upper:]' '[:lower:]')" == 'clean' ]] && echo 'true' || echo 'false')"
readonly CLEAN_INSTALL_REQUESTED

HAS_T2_CHIP="$([[ "$1" == 'debugT2' || -n "$(ioreg -rc AppleUSBDevice -n 'Apple T2 Controller' -d 1)" ]] && echo 'true' || echo 'false')"
readonly HAS_T2_CHIP

# Check for Secure Enclave (present on T2 or Apple Silicon Macs, and NOT on T1 Macs).
# To be able to prevent customization or customized installations older than macOS 11 Big Sur since Secure Tokens cannot be prevented and cannot be removed after the fact.
HAS_SEP="$([[ "$1" == 'debugSEP' || -n "$(ioreg -rc AppleSEPManager)" ]] && echo 'true' || echo 'false')"
if $HAS_SEP && [[ "$1" == 'debugNoSEP' ]]; then HAS_SEP=false; fi
readonly HAS_SEP

clear_nvram_and_reset_sip() {
	local should_clear_nvram=true
	if [[ "$1" == 'customizing' ]]; then
		# DO NOT clear NVRAM on an existing installation on Apple Silicon IF OLDER THAN macOS 11.3 Big Sur (build 20E232) since it will cause an error on reboot stating that macOS needs
		# to be reinstalled, but can be booted properly after re-selecting the internal drive in Startup Disk (which resets the necessary "boot-volume" key which was deleted in NVRAM).
		# This has been fixed in macOS 11.3 Big Sur by protecting the "boot-volume" key (among others) which can no longer be deleted by "nvram -c" or "nvram -d".
		should_clear_nvram="$(! $IS_APPLE_SILICON || [[ "$(sw_vers -buildVersion)" > '20E' ]] && echo 'true' || echo 'false')"
	fi
	
	# DO NOT reset SIP  on Apple Silicon since "csrutil clear" required an "admin user authorized for recovery" (assuming that means Secure Token/Volume Owner), which we won't ever have on a clean install.
	# And if "Erase Mac" has been run before starting a new installation, "csrutil clear" will not be able to do anything anyway and will just output "No macOS installations found".
	local should_reset_sip
	should_reset_sip="$($IS_RECOVERY_OS && ! $IS_APPLE_SILICON && echo 'true' || echo 'false')"
	
	if $should_clear_nvram || $should_reset_sip; then
		echo -e "\n  ${ANSI_CYAN}${ANSI_BOLD}$($should_clear_nvram && echo "Clearing ${ANSI_UNDERLINE}NVRAM")$($should_clear_nvram && $should_reset_sip && echo "${ANSI_CYAN}${ANSI_BOLD} & ")$($should_reset_sip && echo "Resetting ${ANSI_UNDERLINE}SIP")${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}\n"
		
		if $should_clear_nvram; then
			nvram -c && echo 'Successfully cleared NVRAM.' || echo 'FAILED to clear NVRAM.'
		fi

		if $should_reset_sip; then
			csrutil_output="$(csrutil clear 2>&1)"
			csrutil_output="${csrutil_output//. /.$'\n'}" # Put each sentence on it's own line, which is how macOS 11 Big Sur will display lines but previous versions put all sentences on one line which doesn't look as good.

			# Get rid of the "restart the machine" sentence since we will be rebooting after installation and don't want a technician to think they need to reboot manually which would interrupt the install.
			csrutil_output="${csrutil_output/$'\n'Please restart the machine for the changes to take effect./}" # This one is for macOS 10.15 Catalina and older.
			csrutil_output="${csrutil_output/$'\n'Restart the machine for the changes to take effect./}" # This one is for macOS 11 Big Sur and newer.

			echo "${csrutil_output}"
		fi
	fi
}

copy_customization_resources() {
	local install_volume_path="$1"
	if [[ -n "${install_volume_path}" && -d "${install_volume_path}" ]]; then
		local customization_resources_install_path="${install_volume_path}/Users/Shared/fg-install-packages"
		rm -rf "${customization_resources_install_path}"
		
		if ditto "${SCRIPT_DIR}/install-packages" "${customization_resources_install_path}"; then
			chmod +x "${customization_resources_install_path}/fg-install-packages.sh"

			PlistBuddy \
				-c 'Add :Label string org.freegeek.fg-install-packages' \
				-c 'Add :Program string /Users/Shared/fg-install-packages/fg-install-packages.sh' \
				-c 'Add :RunAtLoad bool true' \
				-c 'Add :StandardOutPath string /dev/null' \
				-c 'Add :StandardErrorPath string /dev/null' \
				"${install_volume_path}/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist" &> /dev/null

			if [[ -f "${install_volume_path}/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist" && -d "${customization_resources_install_path}" ]]; then
				touch "${install_volume_path}/private/var/db/.AppleSetupDone"
				chown 0:0 "${install_volume_path}/private/var/db/.AppleSetupDone" # Make sure this file is properly owned by root:wheel after installation.

				return 0
			fi
		fi
	fi

	return 1
}

readonly GLOBAL_INSTALL_NOTES_HEADER="  ${ANSI_UNDERLINE}Installation Notes:${CLEAR_ANSI}\n"
global_install_notes=''

can_only_install_on_boot_drive=false
if ! $IS_RECOVERY_OS; then
	can_only_install_on_boot_drive=true
	global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}
    - Can only install onto current boot drive from within macOS."

	if ! $IS_APPLE_SILICON; then
		global_install_notes+='\n      Reboot into recoveryOS to install onto a different internal drive.'
	fi
fi

load_specs_overview
ansi_clear_screen
echo -e "${FG_MIB_HEADER}${specs_overview}\n\n  ${ANSI_CYAN}${ANSI_BOLD}Detecting Drives...${CLEAR_ANSI}"

if $HAS_T2_CHIP || $IS_APPLE_SILICON; then
	if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
	if $HAS_T2_CHIP; then
		global_install_notes+="\n    - Internet is required on T2 Macs to download firmware and personalize."
	else
		global_install_notes+="\n    - Internet is required on Apple Silicon Macs to activate and personalize."
	fi
	# If internet is needed and is not available, the installation will error during the prepare phase.
fi

# Connect to Wi-Fi, but do not bother waiting for connection to finish.
# Internet is required with T2 Macs since bridgeOS firmware could need to be downloaded.
wifi_ssid='FG Reuse'
wifi_password='[COPY RESOURCES SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]'

network_interfaces="$(networksetup -listallhardwareports 2> /dev/null | awk -F ': ' '($1 == "Device") { print $NF }')"
IFS=$'\n'
for this_network_interface in ${network_interfaces}; do
	if getairportnetwork_output="$(networksetup -getairportnetwork "${this_network_interface}" 2> /dev/null)" && [[ "${getairportnetwork_output}" != *'disabled.' ]]; then
		if networksetup -getairportpower "${this_network_interface}" 2> /dev/null | grep -q '): Off$'; then
			networksetup -setairportpower "${this_network_interface}" on &> /dev/null
		fi
		networksetup -setairportnetwork "${this_network_interface}" "${wifi_ssid}" "${wifi_password}" &> /dev/null &
	fi
done
unset IFS

set_date_time_from_internet # Try to set correct date before doing anything else. If it fails, it will be re-attempted later and user will be prompted and required to connect to the internet if needed.


# DETECT INSTALL PACKAGES

declare -a install_packages=()
if $CLEAN_INSTALL_REQUESTED; then
	if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
	global_install_notes+="\n    - Clean installation will be peformed since \"$1\" argument has been used."
else
	for this_install_package_path in "${SCRIPT_DIR}/install-packages/"*'.pkg'; do
		if [[ -f "${this_install_package_path}" ]]; then
			install_packages+=( "${this_install_package_path}" )
		fi
	done	
fi
install_packages_count="${#install_packages[@]}"

if ! $CLEAN_INSTALL_REQUESTED && (( install_packages_count == 0 )) ; then
	if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
	global_install_notes+="\n    ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} No packages detected. Clean installation will be peformed.
    ${ANSI_RED}${ANSI_BOLD}!!! THIS SHOULD NOT HAVE HAPPENED !!!${ANSI_PURPLE} Please inform Free Geek I.T.${CLEAR_ANSI}"
fi


# DETECT INSTALLABLE DRIVES
# Will show any and all internal drives if in recoveryOS.
# Will only show boot drive if NOT in recoveryOS.

possible_disk_ids=''
boot_drive_is_fusion_drive=false

if $can_only_install_on_boot_drive; then
	# If can install on boot drive only because not in recoveryOS, then ONLY show the boot disk as an option as a way
	# for the technician to double confirm the action even though the drive won't actually be erased by this script.

	boot_drive_info_plist="$(diskutil info -plist /)"
	boot_drive_is_apfs="$([[ "$(PlistBuddy -c 'Print :FilesystemType' /dev/stdin <<< "${boot_drive_info_plist}" 2> /dev/null)" == 'apfs' ]] && echo 'true' || echo 'false')"

	possible_disk_ids="$(PlistBuddy -c 'Print :ParentWholeDisk' /dev/stdin <<< "${boot_drive_info_plist}" 2> /dev/null)"
	
	if $boot_drive_is_apfs; then
		boot_drive_apfs_info="$(diskutil apfs list -plist "${possible_disk_ids}" 2> /dev/null)" # macOS 10.13 and 10.14 do not include the Fusion key in volume info, but do include it in the APFS disk info.

		if [[ -n "${boot_drive_apfs_info}" ]]; then
			if [[ "$(PlistBuddy -c 'Print :Fusion' /dev/stdin <<< "${boot_drive_apfs_info}" 2> /dev/null)" == 'true' ]]; then
				boot_drive_is_fusion_drive=true
			else
				boot_drive_designated_physical_store="$(PlistBuddy -c 'Print :Containers:0:DesignatedPhysicalStore' /dev/stdin <<< "${boot_drive_apfs_info}" 2> /dev/null)"
				possible_disk_ids="$(PlistBuddy -c 'Print :ParentWholeDisk' /dev/stdin <<< "$(diskutil info -plist "${boot_drive_designated_physical_store}")" 2> /dev/null)" # This info will include the ParentWholeDisk for the actual physical disk.
			fi
		fi
	fi
elif (( BOOTED_DARWIN_MAJOR_VERSION >= 17 )); then # If is macOS 10.13 High Sierra or newer.
	# "diskutil list internal physical" was added in macOS 10.12 Sierra, but incorrectly includes "synthesized" disks for a macOS 10.13 High Sierra APFS installation even when "physical" is specified.
	# If this was used with the plist output, then the "WholeDisks" value would incorrectly include these "synthesized" disks and even checking "diskutil info" WOULD NOT properly catch that they are not actually a physical disk.
	# So, "diskutil list -plist internal physical" will only be used on macOS 10.13 High Sierra and newer where the "WholeDisks" value is reliable.
	# NOTE: Removable drives such as SD Cards will still show as "internal" so this output cannot be fully trusted and each disk ID must still be verified using "diskutil info" below.

	possible_disk_ids="$(PlistBuddy -c 'Print :WholeDisks' /dev/stdin <<< "$(diskutil list -plist internal physical)" 2> /dev/null | awk '/disk/ { print $1 }')"
elif (( BOOTED_DARWIN_MAJOR_VERSION >= 15 )); then # If is OS X 10.11 El Capitan or macOS 10.12 Sierra.
	# On macOS 10.12 Sierra, even though "diskutil list -plist internal physical" is not reliable (see comments above),
	# the the human readable text output of "diskutil list internal physical" does properly display "(internal" next to the disk IDs even though "synthesized" disks will also be in the output.
	# And OS X 10.11 El Captian DOES NOT include the options for "diskutil list internal physical" but DOES include "(internal" next to the disk IDs of the "diskutil list" human readable output.
	# So, to be compatible with both of these OS versions, just parse the human readable text output of "diskutil list" instead of using the plist output to be able to properly get only disk IDs of actual internal disks.

	possible_disk_ids="$(diskutil list | awk -F '/| ' '/^\/dev\/disk.*\(internal/ { print $3 }')"
else # If is OS X 10.10 Yosemite or older.
	# On OS X 10.10 Yosemite and older, "diskutil list internal physical" IS NOT available and also "(internal" IS NOT listed next to the disk IDs in the human readable output.
	# So for these older OS versions, just get all "WholeDisks" values from the "diskutil list -plist" output.
	# These disk IDs will be verified to be internal using using "diskutil info" below.
	
	possible_disk_ids="$(PlistBuddy -c 'Print :WholeDisks' /dev/stdin <<< "$(diskutil list -plist)" 2> /dev/null | awk '/disk/ { print $1 }')"
fi

declare -a install_drive_choices=()
install_drive_choices_display=''

declare -a install_drive_device_tree_paths=()

IFS=$'\n'
for this_disk_id in ${possible_disk_ids}; do
	this_disk_info_plist_path="$(mktemp -t 'fg_install_os-this_disk_info')"
	diskutil info -plist "${this_disk_id}" > "${this_disk_info_plist_path}"

	this_disk_is_valid_for_installation=true
	this_disk_is_not_internal=false

	if [[ "$(PlistBuddy -c 'Print :Internal' "${this_disk_info_plist_path}" 2> /dev/null)" == 'false' || \
		"$(PlistBuddy -c 'Print :RemovableMediaOrExternalDevice' "${this_disk_info_plist_path}" 2> /dev/null)" == 'true' ]]; then # SD Cards will show as Internal=true and RemovableMediaOrExternalDevice=true unlike actual internal drives.
		this_disk_is_valid_for_installation=false
		this_disk_is_not_internal=true # May still be allowed for installation if can_only_install_on_boot_drive and will want to know if not internal.
	fi

	if $this_disk_is_valid_for_installation && \
		[[ "$(PlistBuddy -c 'Print :ParentWholeDisk' "${this_disk_info_plist_path}" 2> /dev/null)" != "${this_disk_id}" || \
		"$(PlistBuddy -c 'Print :WholeDisk' "${this_disk_info_plist_path}" 2> /dev/null)" == 'false' || \
		"$(PlistBuddy -c 'Print :VirtualOrPhysical' "${this_disk_info_plist_path}" 2> /dev/null)" == 'Virtual' ]]; then # T2 lists "Unknown" for VirtualOrPhysical.
		this_disk_is_valid_for_installation=false
	fi

	this_disk_device_tree_path="$(PlistBuddy -c 'Print :DeviceTreePath' "${this_disk_info_plist_path}" 2> /dev/null)"
	if [[ -z "${this_disk_device_tree_path}" ]]; then
		this_disk_device_tree_path='UNKNOWN DeviceTreePath'
	elif $this_disk_is_valid_for_installation && [[ " ${install_drive_device_tree_paths[*]} " == *" ${this_disk_device_tree_path} "* ]]; then
		# On macOS 10.10 Yosemite and older, where the VirtualOrPhysical key is not present, virtual CoreStorage volumes could be detected as duplicate drives.
		# To catch this, check for duplicate DeviceTreePath's and exclude them. This assumes the actual physical disk was listed first, which it should've been.
		this_disk_is_valid_for_installation=false	
	fi

	if $this_disk_is_valid_for_installation || $can_only_install_on_boot_drive; then # Allow this disk no matter what if can_only_install_on_boot_drive.
		this_disk_bus="$(PlistBuddy -c 'Print :BusProtocol' "${this_disk_info_plist_path}" 2> /dev/null)"
		if [[ -z "${this_disk_bus}" ]]; then this_disk_bus='UNKNOWN Bus'; fi

		this_disk_model="$(PlistBuddy -c 'Print :MediaName' "${this_disk_info_plist_path}" 2> /dev/null)"
		if [[ -z "${this_disk_model}" ]]; then
			this_disk_model='UNKNOWN Model';
		else
			this_disk_model="$(trim_like_xargs "${this_disk_model//:/ }")" # Make sure Models never contain ':' since it is used as a splitting character.
		fi

		this_disk_smart_status="$(PlistBuddy -c 'Print :SMARTStatus' "${this_disk_info_plist_path}" 2> /dev/null)"
		if [[ -z "${this_disk_smart_status}" ]]; then this_disk_smart_status='UNKNOWN'; fi

		ssd_or_hhd="$([[ "$(PlistBuddy -c 'Print :SolidState' "${this_disk_info_plist_path}" 2> /dev/null)" == 'true' ]] && echo 'SSD' || echo 'HDD')"
		
		this_disk_size_bytes="$(PlistBuddy -c 'Print :TotalSize' "${this_disk_info_plist_path}" 2> /dev/null)"
		if [[ -z "${this_disk_size_bytes}" ]]; then
			this_disk_size='UNKNOWN Size'
		else
			this_disk_size="$(( this_disk_size_bytes / 1000 / 1000 / 1000 )) GB"
		fi
		
		install_drive_choices+=( "${this_disk_id}" )
		install_drive_device_tree_paths+=( "${this_disk_device_tree_path}" )
		
		this_drive_name="${this_disk_size} ${this_disk_bus} ${ssd_or_hhd} \"${this_disk_model}\""

		if $can_only_install_on_boot_drive && $boot_drive_is_fusion_drive; then
			this_drive_name="${this_disk_size} Fusion Drive"
		fi

		install_drive_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}${this_disk_id}:${ANSI_PURPLE} ${this_drive_name}${CLEAR_ANSI}"

		if $this_disk_is_not_internal; then
			install_drive_choices_display+="\n      ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} ${ANSI_UNDERLINE}NOT${ANSI_YELLOW} an Internal Drive${CLEAR_ANSI}"
		fi

		if [[ "${this_disk_smart_status}" != 'Verified' ]]; then
			install_drive_choices_display+="\n      ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} SMART Status = ${ANSI_UNDERLINE}${this_disk_smart_status}${CLEAR_ANSI}"
		fi
	fi

	rm -f "${this_disk_info_plist_path}"
done
unset IFS


if [[ -n "${install_drive_choices[*]}" && -n "${install_drive_choices_display}" ]]; then

	if ! $can_only_install_on_boot_drive; then

		if diskutil 2>&1 | grep -q '^     resetFusion' && (( ${#install_drive_choices[@]} == 2 )); then

			# CHECK IF CAN CREATE FUSION DRIVE AND ADD TO install_drive_choices_display IF SO (Doing this while "Detecting Drives" is still being displayed.)

			# diskutil supports the "resetFusion" argument on macOS 10.14 Mojave and newer.
			# Fusion Drives can be manually created on older versions of macOS, but it's too tedious to be worth since every Mac that shipped with a Fusion Drive supports macOS 10.14 Mojave and newer.
			# More Info: https://support.apple.com/HT207584

			internal_ssd_count="$(echo -e "${install_drive_choices_display}" | grep -c ' SSD "')"
			internal_hdd_count="$(echo -e "${install_drive_choices_display}" | grep -c ' HDD "')"

			if (( internal_ssd_count == 2 )) || (( internal_ssd_count == 1 && internal_hdd_count == 1 )); then
				install_drive_choices+=( 'diskF' )
				install_drive_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}diskF:${ANSI_PURPLE} Create Fusion Drive ${ANSI_YELLOW}(Will ${ANSI_BOLD}ERASE BOTH${ANSI_YELLOW} Internal Drives)${CLEAR_ANSI}"
			fi
		fi


		if ! $CLEAN_INSTALL_REQUESTED && (( install_packages_count > 0 )) && [[ -f "${SCRIPT_DIR}/install-packages/fg-install-packages.sh" ]]; then

			# DETECT CLEAN INSTALLATIONS AND OFFER TO CUSTOMIZE IF FOUND

			load_specs_overview
			ansi_clear_screen
			echo -e "${FG_MIB_HEADER}${specs_overview}\n\n  ${ANSI_CYAN}${ANSI_BOLD}Detecting Existing Clean Installations...${CLEAR_ANSI}"

			for this_disk_id in "${install_drive_choices[@]}"; do
				if [[ -n "${this_disk_id}" && "${this_disk_id}" != 'diskF' ]]; then
					# Make sure all internal drives are mounted before checking for clean installations.
					diskutil mountDisk "${this_disk_id}" &> /dev/null

					# Mounting parent disk IDs appears to not mount the child APFS Container disk IDs, so check for those and mount them too.
					apfs_container_disk_ids="$(diskutil list "${this_disk_id}" | awk '(($3 ~ /Container$/) && ($4 ~ /^disk/)) { gsub(/[^0-9]/, "", $4); print "disk" $4 }')"
					# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop, so just "awk" the human readable output of a single "diskutil list" command instead since it's right there.
					# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID, so they must be removed from the disk IDs for them to be usable.
					# When using gsub(/[^[:print:]]/, "", $4), I was seeing an extraneous "?" get outputted after the disk ID on one computer but not another (which is odd), but removing all non-digits and then adding "disk" back solved that for all computers.
					
					for this_apfs_container_disk_id in ${apfs_container_disk_ids}; do
						diskutil mountDisk "${this_apfs_container_disk_id}" &> /dev/null
					done
				fi
			done
			
			declare -a clean_install_choices=()
			clean_install_choices_display=''

			for this_volume in '/Volumes/'*; do
				if [[ -d "${this_volume}" ]]; then
					this_volume_system_version_plist_path="${this_volume}/System/Library/CoreServices/SystemVersion.plist"
					
					if [[ -d "${this_volume}" && "${this_volume}" != *' Base System' && "${this_volume}" != *' Test Boot'* && -f "${this_volume_system_version_plist_path}" && -d "${this_volume}/Users/Shared" && -d "${this_volume}/Library/LaunchDaemons" ]]; then
						this_volume_info_plist_path="$(mktemp -t 'fg_install_os-this_volume_info')"
						diskutil info -plist "${this_volume}" > "${this_volume_info_plist_path}"

						this_volume_is_apfs="$([[ "$(PlistBuddy -c 'Print :FilesystemType' "${this_volume_info_plist_path}" 2> /dev/null)" == 'apfs' ]] && echo 'true' || echo 'false')"
						
						if [[ -d "${this_volume}/Users/Shared/fg-install-packages" ]]; then
							echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Already Prepared Customizations${CLEAR_ANSI}"
						elif [[ -f "${this_volume}/private/var/db/.AppleSetupDone" ]]; then
							echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Setup Assistant Already Completed${CLEAR_ANSI}"
						elif $this_volume_is_apfs && [[ "$(diskutil apfs listCryptoUsers "${this_volume}")" != 'No cryptographic users for disk'* ]]; then
							echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Secure Token User Exists${CLEAR_ANSI}"
						else
							existing_user_names="$(trim_like_xargs "$(find "${this_volume}/private/var/db/dslocal/nodes/Default/users" \( -name '*.plist' -and ! -name '_*.plist' \) | awk -F '/|[.]plist' '{ print $(NF-1) }' | sort)")" # "-exec basename {} '.plist'" would be nicer than "awk", but "basename" doesn't exist in recoveryOS.

							if [[ "${existing_user_names}" == 'daemon nobody root' ]]; then
								this_volume_os_version="$(PlistBuddy -c 'Print :ProductUserVisibleVersion' "${this_volume_system_version_plist_path}" 2> /dev/null)"
								if [[ -z "${this_volume_os_version}" ]]; then
									this_volume_os_version="$(PlistBuddy -c 'Print :ProductVersion' "${this_volume_system_version_plist_path}" 2> /dev/null)"
								fi

								if [[ -n "${this_volume_os_version}" ]]; then
									this_volume_os_name=''

									if ! $HAS_SEP && [[ "${this_volume_os_version}" == '10.13'* ]]; then
										this_volume_os_name="macOS ${this_volume_os_version} High Sierra"
									elif ! $HAS_SEP && [[ "${this_volume_os_version}" == '10.14'* ]]; then
										this_volume_os_name="macOS ${this_volume_os_version} Mojave"
									elif ! $HAS_SEP && [[ "${this_volume_os_version}" == '10.15'* ]]; then
										this_volume_os_name="macOS ${this_volume_os_version} Catalina"
									elif [[ "${this_volume_os_version}" == '11'* ]]; then
										this_volume_os_name="macOS ${this_volume_os_version} Big Sur"
									elif [[ "${this_volume_os_version}" == '12'* ]]; then
										this_volume_os_name="macOS ${this_volume_os_version} Monterey"
									fi

									# fg-prepare-os script is only made to support macOS 10.13 High Sierra and newer, so do not allow installation on any macOS version that is not named above.
									# Also do not allow SEP Macs to customize macOS 10.15 Catalina and older since Secure Tokens cannot be prevented and cannot be removed after the fact
									# during Snapshot reset (on macOS 10.15 Catalina) and the last Secure Token admin can also not be removed by fgreset (on macOS 10.14 Mojave and older).

									if [[ -n "${this_volume_os_name}" ]]; then
										this_volume_disk_id="$(PlistBuddy -c 'Print :ParentWholeDisk' "${this_volume_info_plist_path}" 2> /dev/null)"

										this_volume_is_on_fusion_drive=false

										if $this_volume_is_apfs; then
											this_volume_apfs_info="$(diskutil apfs list -plist "${this_volume_disk_id}" 2> /dev/null)" # macOS 10.13 and 10.14 do not include the Fusion key in volume info, but do include it in the APFS disk info.

											if [[ -n "${this_volume_apfs_info}" ]]; then
												if [[ "$(PlistBuddy -c 'Print :Fusion' /dev/stdin <<< "${this_volume_apfs_info}" 2> /dev/null)" == 'true' ]]; then
													this_volume_is_on_fusion_drive=true
												else
													this_volume_designated_physical_store="$(PlistBuddy -c 'Print :Containers:0:DesignatedPhysicalStore' /dev/stdin <<< "${this_volume_apfs_info}" 2> /dev/null)"
													this_volume_disk_id="$(PlistBuddy -c 'Print :ParentWholeDisk' /dev/stdin <<< "$(diskutil info -plist "${this_volume_designated_physical_store}")" 2> /dev/null)" # This info will include the ParentWholeDisk for the actual physical disk.
												fi
											fi
										fi

										if $this_volume_is_on_fusion_drive || strip_ansi_styles "${install_drive_choices_display}" | grep -q "^    ${this_volume_disk_id}:"; then
											this_volume_drive_name='UNKNOWN Drive'
											if $this_volume_is_on_fusion_drive; then
												this_fusion_drive_size_bytes="$(PlistBuddy -c 'Print :TotalSize' "${this_volume_info_plist_path}" 2> /dev/null)"
												if [[ -n "${this_fusion_drive_size_bytes}" ]]; then
													this_fusion_drive_size="$(( this_fusion_drive_size_bytes / 1000 / 1000 / 1000 )) GB"
												else
													this_fusion_drive_size='UNKNOWN Size'
												fi
												this_volume_drive_name="${this_fusion_drive_size} Fusion Drive"
											else
												this_volume_drive_name="$(strip_ansi_styles "${install_drive_choices_display}" | grep "^    ${this_volume_disk_id}:")"
												this_volume_drive_name="${this_volume_drive_name#*: }"
											fi

											clean_install_choice_index="${#clean_install_choices[@]}"

											next_line_indent_spaces='      '
											this_index_character_count="${#clean_install_choice_index}"
											for (( space = 0; space < this_index_character_count; space ++ )); do
												next_line_indent_spaces+=' '
											done
											
											clean_install_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}${clean_install_choice_index}:${ANSI_PURPLE} ${this_volume_os_name} at \"${this_volume}\"\n${next_line_indent_spaces}on ${this_volume_drive_name}${CLEAR_ANSI}"
											clean_install_choices+=( "${this_volume}:${this_volume_os_name}:${this_volume_drive_name}" )
										else
											echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} ${this_volume_disk_id} Is Not an Internal Drive${CLEAR_ANSI}"
										fi
									elif $HAS_SEP; then
										echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Would Not Be Able to Peform Reset of This macOS Version on SEP Mac${CLEAR_ANSI}"
									else
										echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} macOS ${this_volume_os_version} Is Not Supported${CLEAR_ANSI}"
									fi
								else
									echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Unable to Extract macOS Version${CLEAR_ANSI}"
								fi
							else
								existing_user_names_display=''
								IFS=' '
								for this_existing_username in ${existing_user_names}; do
									if [[ "${this_existing_username}" != 'daemon' && "${this_existing_username}" != 'nobody' && "${this_existing_username}" != 'root' ]]; then
										if [[ -n "${existing_user_names_display}" ]]; then existing_user_names_display+=', '; fi
										existing_user_names_display+="${this_existing_username}"
									fi
								done
								unset IFS
								
								echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Users Already Exist (${existing_user_names_display})${CLEAR_ANSI}"
							fi
						fi

						rm -f "${this_volume_info_plist_path}"
					fi
				fi
			done
		fi
		
		if (( ${#clean_install_choices[@]} > 0 )); then
			clean_install_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}C:${ANSI_PURPLE} Continue Without Customizing Clean Installation${CLEAR_ANSI}"
			
			clean_install_to_customize_path=''
			clean_install_to_customize_info=''

			last_choose_clean_install_error=''
			while [[ -z "${clean_install_to_customize_path}" ]]; do
				load_specs_overview
				ansi_clear_screen
				echo -e "${FG_MIB_HEADER}${specs_overview}"
				echo -e "\n  ${ANSI_UNDERLINE}Choose Clean Installation to Customize:${CLEAR_ANSI}${last_choose_clean_install_error}${clean_install_choices_display}"

				echo -en "\n  Enter the ${ANSI_BOLD}Index of Clean Installation${CLEAR_ANSI} to Customize (or ${ANSI_BOLD}\"C\" to Continue${CLEAR_ANSI}): "
				read -r chosen_clean_install_index

				if [[ "${chosen_clean_install_index}" =~ ^[Cc] ]]; then # Do not confirm continuing, just continue.
					clean_install_to_customize_path=''
					clean_install_to_customize_info=''

					break
				else
					chosen_clean_install_index="${chosen_clean_install_index//[^0-9]/}" # Remove all non-digits
					if [[ "${chosen_clean_install_index}" == '0'* ]]; then
						chosen_clean_install_index="${chosen_clean_install_index#"${chosen_clean_install_index%%[^0]*}"}" # Remove any leading zeros
						if [[ -z "${chosen_clean_install_index}" ]]; then chosen_clean_install_index='0'; fi # Catch if the number was all zeros
					fi
				fi

				if [[ -n "${chosen_clean_install_index}" ]] && (( chosen_clean_install_index < ${#clean_install_choices[@]} )); then
					clean_install_to_customize_info="${clean_install_choices[$chosen_clean_install_index]}"
					
					possible_clean_install_to_customize_path="$(echo "${clean_install_to_customize_info}" | cut -d ':' -f 1)"
					possible_clean_install_os_name="$(echo "${clean_install_to_customize_info}" | cut -d ':' -f 2)"
					possible_clean_install_drive_name="$(echo "${clean_install_to_customize_info}" | cut -d ':' -f 3)"

					echo -en "\n  Enter ${ANSI_BOLD}${chosen_clean_install_index}${CLEAR_ANSI} Again to Confirm Customizing ${ANSI_BOLD}${possible_clean_install_os_name}${CLEAR_ANSI}\n  at ${ANSI_BOLD}\"${possible_clean_install_to_customize_path}\"${CLEAR_ANSI} on ${ANSI_BOLD}${possible_clean_install_drive_name}${CLEAR_ANSI}: "
					read -r confirmed_clean_install_index

					confirmed_clean_install_index="${confirmed_clean_install_index//[^0-9]/}" # Remove all non-digits
					if [[ "${confirmed_clean_install_index}" == '0'* ]]; then
						confirmed_clean_install_index="${confirmed_clean_install_index#"${confirmed_clean_install_index%%[^0]*}"}" # Remove any leading zeros
						if [[ -z "${confirmed_clean_install_index}" ]]; then confirmed_clean_install_index='0'; fi # Catch if the number was all zeros
					fi

					if [[ "${chosen_clean_install_index}" == "${confirmed_clean_install_index}" ]]; then
						clean_install_to_customize_path="${possible_clean_install_to_customize_path}"

						if [[ -z "${clean_install_to_customize_path}" || ! -d "${clean_install_to_customize_path}" ]]; then
							last_choose_clean_install_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Selected Clean Installation No Longer Exists ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${ANSI_RED}\n     ${ANSI_BOLD}PATH:${ANSI_RED} ${os_installer_path}${CLEAR_ANSI}"

							clean_install_to_customize_path=''
							clean_install_to_customize_info=''
						fi
					else
						clean_install_to_customize_info=''

						last_choose_clean_install_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Did Not Confirm Index ${ANSI_BOLD}${chosen_clean_install_index}${ANSI_PURPLE} ${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
					fi
				elif [[ -n "${chosen_clean_install_index}" ]]; then
					last_choose_clean_install_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Index ${ANSI_BOLD}${chosen_clean_install_index}${ANSI_RED} Is Not a Valid Choice ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
				else
					last_choose_clean_install_error=''
				fi
			done
		fi

		if [[ -n "${clean_install_to_customize_path}" ]]; then
			if [[ -d "${clean_install_to_customize_path}" && -n "${clean_install_to_customize_info}" ]]; then
				clean_install_os_name="$(echo "${clean_install_to_customize_info}" | cut -d ':' -f 2)"
				clean_install_drive_name="$(echo "${clean_install_to_customize_info}" | cut -d ':' -f 3)"
				

				# MAKE SURE POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT BEFORE ALLOWING OS CUSTOMIZATION TO BEGIN

				check_and_prompt_for_power_adapter_for_laptops
				set_date_time_and_prompt_for_internet_if_year_not_correct
				
				
				# CLEAR SCREEN BEFORE CLEARING NVRAM & RESETTING SIP AND/OR STARTING OS CUSTOMIZATION

				ansi_clear_screen


				# CLEAR NVRAM & RESET SIP
				# SIP will not be reset on Apple Silicon, see notes within clear_nvram_and_reset_sip for more information.
				# NVRAM will not be cleared on Apple Silicon older that macOS 11.3 Big Sur, see notes within clear_nvram_and_reset_sip for more information.
				clear_nvram_and_reset_sip 'customizing'


				# START OS CUSTOMIZATION

				echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Copying Customization Resources\n  Into ${ANSI_UNDERLINE}${clean_install_os_name}${ANSI_CYAN}${ANSI_BOLD} at ${ANSI_UNDERLINE}\"${clean_install_to_customize_path}\"${ANSI_CYAN}${ANSI_BOLD}\n  on ${ANSI_UNDERLINE}${clean_install_drive_name}${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}"

				if copy_customization_resources "${clean_install_to_customize_path}"; then

					# Delete any existing Preferences, Caches, and Temporary Files (in case any Setup Assistant screens had been clicked through).
					rm -rf "${clean_install_to_customize_path}/Library/Preferences/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/Library/Caches/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/System/Library/Caches/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/private/var/vm/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/private/var/folders/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/private/var/tmp/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/private/tmp/"{,.[^.],..?}* &> /dev/null
					rm -rf "${clean_install_to_customize_path}/.TemporaryItems/"{,.[^.],..?}* &> /dev/null

					echo -e "\n\n  ${ANSI_GREEN}${ANSI_BOLD}Successfully Copied Customization Resources and Prepared Customization\n\n  ${ANSI_GREY}${ANSI_BOLD}This Mac Will Reboot and Start Customizing in 10 Seconds...${CLEAR_ANSI}\n"
					
					sleep 10 # Sleep a bit so technician can see that customization resources were copied.
					
					shutdown -r now &> /dev/null

					echo -e '\n'
				else
					echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to Copy Customization Resources${CLEAR_ANSI}\n\n"
				fi
			else
				echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unknown Error During Clean Installation Selection${CLEAR_ANSI}\n\n"
			fi

			exit 0
		fi

		# NOTICE: Script will END and REBOOT Mac in THE PREVIOUS BLOCK if technician chose to customize an existing clean installation.
	fi


	# DETECT MACOS INSTALLERS

	load_specs_overview
	ansi_clear_screen
	echo -e "${FG_MIB_HEADER}${specs_overview}\n\n  ${ANSI_CYAN}${ANSI_BOLD}Detecting macOS Installers...${CLEAR_ANSI}"

	readonly MODEL_ID_MAJOR_NUMBER="${MODEL_ID_NUMBER%%,*}"
	SUPPORTS_HIGH_SIERRA="$([[ ( "${SHORT_MODEL_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '10' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Air' && "${MODEL_ID_MAJOR_NUMBER}" -ge '3' ) || ( "${SHORT_MODEL_NAME}" == 'Mac mini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '4' ) || ( "${SHORT_MODEL_NAME}" == 'Mac Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '5' ) || ( "${SHORT_MODEL_NAME}" == 'iMac Pro' ) ]] && echo 'true' || echo 'false')"
	readonly SUPPORTS_HIGH_SIERRA
	SUPPORTS_CATALINA="$([[ ( "${SHORT_MODEL_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '13' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '8' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '9' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Air' && "${MODEL_ID_MAJOR_NUMBER}" -ge '5' ) || ( "${SHORT_MODEL_NAME}" == 'Mac mini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'Mac Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'iMac Pro' ) ]] && echo 'true' || echo 'false')"
	readonly SUPPORTS_CATALINA # Catalina supports same as Mojave
	SUPPORTS_BIG_SUR="$([[ ( "${MODEL_ID}" == 'iMac14,4' ) || ( "${SHORT_MODEL_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '15' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '8' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '11' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Air' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'Mac mini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${SHORT_MODEL_NAME}" == 'Mac Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'iMac Pro' ) ]] && echo 'true' || echo 'false')"
	readonly SUPPORTS_BIG_SUR
	SUPPORTS_MONTEREY="$([[ ( "${SHORT_MODEL_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '16' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '9' ) || ( "${MODEL_ID}" == 'MacBookPro11,4' ) || ( "${MODEL_ID}" == 'MacBookPro11,5' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '12' ) || ( "${SHORT_MODEL_NAME}" == 'MacBook Air' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${SHORT_MODEL_NAME}" == 'Mac mini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${SHORT_MODEL_NAME}" == 'Mac Pro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${SHORT_MODEL_NAME}" == 'iMac Pro' ) || ( "${SHORT_MODEL_NAME}" == 'Mac Studio' ) ]] && echo 'true' || echo 'false')"
	readonly SUPPORTS_MONTEREY

	declare -a os_installer_search_group_prefixes=(
		'/Volumes/Image ' # Always want installers in "Image Volume" to come before any other installers (which is for the booted installer in recoveryOS).
		'/Volumes/Install ' # Check any other available "Install macOS..." volumes.
		'/' # A stub installer will always be in the root filesystem in recoveryOS.
		'/Applications/' # Check "/Applications" folder in case we are in full OS, this could contain full or stub installers. In our use case, these should not exist and does not need to be higher in the list.
	)

	declare -a os_installer_choices=()
	os_installer_choices_display=''

	declare -a stub_os_installers_info=()

	for this_os_installer_search_group_prefixes in "${os_installer_search_group_prefixes[@]}"; do
		declare -a this_os_installer_search_group_paths=()
		if [[ "${this_os_installer_search_group_prefixes}" != *'/' ]]; then
			this_os_installer_search_group_paths=( "${this_os_installer_search_group_prefixes}"*'/Install '*'.app/Contents/Resources/startosinstall' )
		else
			this_os_installer_search_group_paths=( "${this_os_installer_search_group_prefixes}Install "*'.app/Contents/Resources/startosinstall' )
		fi

		these_sorted_os_installer_paths=''
		for this_os_installer_path in "${this_os_installer_search_group_paths[@]}"; do
			if [[ -f "${this_os_installer_path}" ]]; then
				this_os_installer_app_path="${this_os_installer_path%.app/*}.app"
				this_os_installer_darwin_major_version="$(PlistBuddy -c 'Print :DTSDKBuild' "${this_os_installer_app_path}/Contents/Info.plist" 2> /dev/null | cut -c -2 | tr -dc '[:digit:]')"
				if (( this_os_installer_darwin_major_version >= 10 )); then
					if (( this_os_installer_darwin_major_version < BOOTED_DARWIN_MAJOR_VERSION )); then
						echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Older Than Running OS${CLEAR_ANSI}"
					elif $CLEAN_INSTALL_REQUESTED || ! $HAS_SEP || (( this_os_installer_darwin_major_version >= 20 )); then
						if [[ -n "${these_sorted_os_installer_paths}" ]]; then these_sorted_os_installer_paths+=$'\n'; fi
						these_sorted_os_installer_paths+="${this_os_installer_darwin_major_version}:${this_os_installer_path}"
					else
						# Do not allow SEP Macs to install macOS 10.15 Catalina and older (unless doing a clean install) since Secure Tokens cannot be prevented and cannot be removed
						# during Snapshot reset (on macOS 10.15 Catalina) and the last Secure Token admin can also not be removed by fgreset (on macOS 10.14 Mojave and older).
						echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Would Not Be Able to Peform Reset of This macOS Version on SEP Mac${CLEAR_ANSI}"
					fi
				else
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Invalid Darwin Version${CLEAR_ANSI}"
				fi
			fi
		done

		these_sorted_os_installer_paths="$(echo "${these_sorted_os_installer_paths}" | sort -rV)" # Sort by OS versions in reverse order (newest to oldest).
		
		is_first_os_installer_of_search_group=true

		IFS=$'\n'
		for this_os_installer_path in ${these_sorted_os_installer_paths}; do
			this_os_installer_darwin_major_version="$(echo "${this_os_installer_path}" | cut -d ':' -f 1)"
			this_os_installer_path="$(echo "${this_os_installer_path}" | cut -d ':' -f 2)"

			can_run_this_os_installer=false

			this_os_installer_usage_notes=''
			
			# NOTICE: For info about grepping the "startosinstall" binary contents to check for supported arguments
			# as well as OS support for each argument, refer to the "os_installer_options" code near the end of this script.

			if ! grep -qU -e '--installpackage, ' "${this_os_installer_path}"; then
				if [[ -n "${this_os_installer_usage_notes}" ]]; then this_os_installer_usage_notes+=' & '; fi
				this_os_installer_usage_notes+='Clean Install Only'
			fi

			# CANNOT use this "startosinstall" if in recoveryOS and "volume" argument is not supported or NOT in recoveryOS and "eraseinstall" argument is not supported.
			# Must check that we are in recoveryOS since the strings will ALWAYS exist when checked this way even if it wouldn't be outputted from running "startosinstall --usage"
			if $IS_RECOVERY_OS && grep -qU -e '--volume, ' "${this_os_installer_path}"; then
				can_run_this_os_installer=true
			elif ! $IS_RECOVERY_OS && grep -qU -e '--eraseinstall, ' "${this_os_installer_path}"; then
				# Do not add to this_os_installer_usage_notes about only being able to install on boot drive since the
				# note will be included on its own line on the OS and drive selection screens when running in full OS.
				# No need to also include it here redundantly next to every installer choice.
				can_run_this_os_installer=true
			fi

			this_os_installer_name="${this_os_installer_path%.app/*}"
			this_os_installer_app_path="${this_os_installer_name}.app"
			this_os_installer_name="${this_os_installer_name##*/Install }"

			if (( this_os_installer_darwin_major_version >= 10 )); then
				this_os_installer_version="10.$(( this_os_installer_darwin_major_version - 4 ))"
				if (( this_os_installer_darwin_major_version >= 20 )); then # Darwin 20 and newer are macOS 11 and newer.
					this_os_installer_version="$(( this_os_installer_darwin_major_version - 9 ))"
				fi

				if [[ "${this_os_installer_name}" == *'macOS'* ]]; then
					this_os_installer_name="${this_os_installer_name/macOS/macOS ${this_os_installer_version}}"
				elif [[ "${this_os_installer_name}" == *'OS X'* ]]; then
					this_os_installer_name="${this_os_installer_name/OS X/OS X ${this_os_installer_version}}"
				fi
			fi

			if $can_run_this_os_installer; then
				if [[ -f "${this_os_installer_app_path}/Contents/SharedSupport/SharedSupport.dmg" || -f "${this_os_installer_app_path}/Contents/SharedSupport/InstallESD.dmg" ]]; then
					# Full installer apps will contain "SharedSupport.dmg" (on macOS 11 Big Sur and newer) or "InstallESD.dmg" (on Catalina or older).

					if { ! $SUPPORTS_HIGH_SIERRA && [[ "${this_os_installer_name}" == *' High Sierra'* ]]; } || \
						{ ! $SUPPORTS_CATALINA && [[ "${this_os_installer_name}" == *' Mojave'* || "${this_os_installer_name}" == *' Catalina'* ]]; } || \
						{ ! $SUPPORTS_BIG_SUR && [[ "${this_os_installer_name}" == *' Big Sur'* ]]; } || \
						{ ! $SUPPORTS_MONTEREY && [[ "${this_os_installer_name}" == *' Monterey'* ]]; }; then # Catalina supports same as Mojave
						echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Model Does Not Support ${this_os_installer_name}${CLEAR_ANSI}"
					elif [[ "$(strip_ansi_styles "${os_installer_choices_display}")" == *": ${this_os_installer_name}"* ]]; then
						echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Duplicate Installer Already Added${CLEAR_ANSI}"
					else
						if [[ -n "${this_os_installer_usage_notes}" ]]; then this_os_installer_usage_notes=" (${this_os_installer_usage_notes})"; fi
						
						if $is_first_os_installer_of_search_group; then
							os_installer_choices_display+=$'\n';
							is_first_os_installer_of_search_group=false
						fi

						os_installer_choices_display+="\n    ${ANSI_PURPLE}${ANSI_BOLD}${#os_installer_choices[@]}:${ANSI_PURPLE} ${this_os_installer_name}${CLEAR_ANSI}${this_os_installer_usage_notes}"
						os_installer_choices+=( "${this_os_installer_path}" )
					fi
				else
					# Stub installers (which will download the full installer from the internet) will not have "SharedSupport.dmg" or "InstallESD.dmg" but WILL HAVE "startosinstall".

					if [[ -n "${this_os_installer_usage_notes}" ]]; then this_os_installer_usage_notes+=' & '; fi
					this_os_installer_usage_notes+='Internet Required'
					
					stub_os_installers_info+=( "${this_os_installer_path}:${this_os_installer_name}:${this_os_installer_usage_notes}" )
				fi
			else
				echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Does Not Support Required Argument${CLEAR_ANSI}"
			fi
		done
		unset IFS
	done

	# Include any stub installers (one will always be in recoveryOS root filesystem) as choices if a full installer for the same version has not already been found.
	is_first_stub_os_installer=true
	for this_stub_installer_info in "${stub_os_installers_info[@]}"; do
		this_os_installer_path="$(echo "${this_stub_installer_info}" | cut -d ':' -f 1)"
		this_os_installer_name="$(echo "${this_stub_installer_info}" | cut -d ':' -f 2)"
		this_os_installer_usage_notes="$(echo "${this_stub_installer_info}" | cut -d ':' -f 3)" # This will always at least contain "Internet Required".

		# Do not need to check if model supports stub installer version since stubs should only be for an already booted version.
		if [[ -n "${this_os_installer_path}" && -n "${this_os_installer_name}" && -n "${this_os_installer_usage_notes}" ]]; then
			if [[ "$(strip_ansi_styles "${os_installer_choices_display}")" != *": ${this_os_installer_name}"* ]]; then
				if $is_first_stub_os_installer; then
					os_installer_choices_display+=$'\n';
					is_first_stub_os_installer=false
				fi
				
				os_installer_choices_display+="\n    ${ANSI_PURPLE}${ANSI_BOLD}${#os_installer_choices[@]}:${ANSI_PURPLE} ${this_os_installer_name}${CLEAR_ANSI} (${this_os_installer_usage_notes})"
				os_installer_choices+=( "${this_os_installer_path}" )
			else
				echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_path%.app/*}.app\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Duplicate Installer Already Added${CLEAR_ANSI}"
			fi
		fi
	done


	# PROMPT TO CHOOSE INSTALLER (only if more than one installer is available)

	os_installer_choices_count="${#os_installer_choices[@]}"
	os_installer_path=''
	os_installer_name=''
	os_installer_usage_notes=''

	if (( os_installer_choices_count > 0 )); then
		if (( os_installer_choices_count == 1 )); then
			os_installer_path="${os_installer_choices[0]}"
			os_installer_line="$(strip_ansi_styles "${os_installer_choices_display}" | grep '^    0:')"
			os_installer_name="$(echo "${os_installer_line}" | awk -F ': | [(]' '{ print $2; exit }')"
			if [[ "${os_installer_line}" == *')' ]]; then os_installer_usage_notes="$(echo "${os_installer_line}" | awk -F '[(]|[)]' '{ print $2; exit }')"; fi
		fi

		last_choose_os_error=''
		while [[ -z "${os_installer_path}" ]]; do
			load_specs_overview
			ansi_clear_screen
			echo -e "${FG_MIB_HEADER}${specs_overview}"
			if [[ -n "${global_install_notes}" ]]; then echo -e "\n${global_install_notes}\n"; fi
			echo -e "\n  ${ANSI_UNDERLINE}Choose macOS Version to Install:${CLEAR_ANSI}${last_choose_os_error}${os_installer_choices_display}"

			echo -en "\n  Enter the ${ANSI_BOLD}Index of macOS Version${CLEAR_ANSI} to Install: "
			read -r chosen_os_installer_index
			
			chosen_os_installer_index="${chosen_os_installer_index//[^0-9]/}" # Remove all non-digits
			if [[ "${chosen_os_installer_index}" == '0'* ]]; then
				chosen_os_installer_index="${chosen_os_installer_index#"${chosen_os_installer_index%%[^0]*}"}" # Remove any leading zeros
				if [[ -z "${chosen_os_installer_index}" ]]; then chosen_os_installer_index='0'; fi # Catch if the number was all zeros
			fi

			if [[ -n "${chosen_os_installer_index}" ]] && (( chosen_os_installer_index < os_installer_choices_count )); then
				possible_os_installer_path="${os_installer_choices[$chosen_os_installer_index]}"
				os_installer_line="$(strip_ansi_styles "${os_installer_choices_display}" | grep "^    ${chosen_os_installer_index}:")"
				os_installer_name="$(echo "${os_installer_line}" | awk -F ': | [(]' '{ print $2; exit }')"
				if [[ "${os_installer_line}" == *')' ]]; then os_installer_usage_notes="$(echo "${os_installer_line}" | awk -F '[(]|[)]' '{ print $2; exit }')"; fi

				echo -en "\n  Enter ${ANSI_BOLD}${chosen_os_installer_index}${CLEAR_ANSI} Again to Confirm Installing ${ANSI_BOLD}${os_installer_name}${CLEAR_ANSI}: "
				read -r confirmed_os_installer_index

				confirmed_os_installer_index="${confirmed_os_installer_index//[^0-9]/}" # Remove all non-digits
				if [[ "${confirmed_os_installer_index}" == '0'* ]]; then
					confirmed_os_installer_index="${confirmed_os_installer_index#"${confirmed_os_installer_index%%[^0]*}"}" # Remove any leading zeros
					if [[ -z "${confirmed_os_installer_index}" ]]; then confirmed_os_installer_index='0'; fi # Catch if the number was all zeros
				fi

				if [[ "${chosen_os_installer_index}" == "${confirmed_os_installer_index}" ]]; then
					os_installer_path="${possible_os_installer_path}"

					if [[ -z "${os_installer_path}" || ! -f "${os_installer_path}" ]]; then
						last_choose_os_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Selected macOS Installer No Longer Exists ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${ANSI_RED}\n     ${ANSI_BOLD}PATH:${ANSI_RED} ${os_installer_path%.app/*}.app${CLEAR_ANSI}"

						os_installer_path=''
						os_installer_name=''
						os_installer_usage_notes=''
					fi
				else
					os_installer_name=''
					os_installer_usage_notes=''

					last_choose_os_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Did Not Confirm Index ${ANSI_BOLD}${chosen_os_installer_index}${ANSI_PURPLE} ${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
				fi
			elif [[ -n "${chosen_os_installer_index}" ]]; then
				last_choose_os_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Index ${ANSI_BOLD}${chosen_os_installer_index}${ANSI_RED} Is Not a Valid Choice ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
			else
				last_choose_os_error=''
			fi
		done

		if [[ -n "${os_installer_usage_notes}" ]]; then
			if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
			IFS='&'
			for this_os_installer_usage_note in ${os_installer_usage_notes}; do
				this_os_installer_usage_note="$(trim_like_xargs "${this_os_installer_usage_note}")"
				if [[ "${this_os_installer_usage_note}" == 'Internet Required' ]]; then
					this_os_installer_usage_note="Selected installer ${ANSI_BOLD}is a stub${CLEAR_ANSI}, full installer will be downloaded."
				elif [[ "${this_os_installer_usage_note}" == 'Clean Install Only' ]]; then
					this_os_installer_usage_note="Selected installer ${ANSI_BOLD}does not support${CLEAR_ANSI} including customization packages."
				fi
				global_install_notes+="\n    - ${this_os_installer_usage_note}"
			done
			unset IFS
		fi
	fi


	check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs() {
		# Internet is required during the installation when using a stub installer and on T2 or Apple Silicon Macs. If internet is not connected, the installation will fail.

		local installer_is_a_stub
		installer_is_a_stub="$([[ "${global_install_notes}" == *'is a stub'* ]] && echo 'true' || echo 'false')"

		if $installer_is_a_stub || $IS_APPLE_SILICON || $HAS_T2_CHIP; then
			local this_mac_type
			this_mac_type="$($IS_APPLE_SILICON && echo 'Apple Silicon' || echo 'T2') Macs"
			
			while ! ping -t 5 -c 1 'www.apple.com' &> /dev/null; do
				load_specs_overview
				ansi_clear_screen
				echo -e "${FG_MIB_HEADER}${specs_overview}

  ${ANSI_UNDERLINE}Internet Required $($installer_is_a_stub && echo 'for Stub Installer' || echo "on ${this_mac_type}"):${CLEAR_ANSI}

    ${ANSI_YELLOW}${ANSI_BOLD}The macOS installation will fail without internet$(! $installer_is_a_stub && echo " on ${this_mac_type}").${CLEAR_ANSI}

    Connect to a ${ANSI_BOLD}Wi-Fi${CLEAR_ANSI} network or plug in an ${ANSI_BOLD}Ethernet${CLEAR_ANSI} cable.
    If this Mac does not have Ethernet, use a Thunderbolt or USB adapter.

    ${ANSI_PURPLE}After connecting to ${ANSI_BOLD}Wi-Fi${CLEAR_ANSI}${ANSI_PURPLE} or ${ANSI_BOLD}Ethernet${CLEAR_ANSI}${ANSI_PURPLE}, press ${ANSI_BOLD}Return${CLEAR_ANSI}${ANSI_PURPLE} to continue.${CLEAR_ANSI}

    It may take a few moments for the internet connection to be established.
    If it takes more than a few minutes, please inform Free Geek I.T.${CLEAR_ANSI}
"
				read -r
			done
		fi
	}


	if [[ -n "${os_installer_path}" && -f "${os_installer_path}" && -n "${os_installer_name}" ]]; then
		
		install_volume_name='Macintosh HD'
		install_volume_path="/Volumes/${install_volume_name}"
		
		if $IS_APPLE_SILICON && $IS_RECOVERY_OS; then

			# ABOUT PERFORMING MANUALLY ASSISTED CUSTOMIZED CLEAN INSTALL ON APPLE SILICON

			# As of macOS 11.3 Big Sur, "startosinstall" does not work in recoveryOS on Apple Silicon.
			# When "startosinstall" is run in recoveryOS on Apple Silicon, it simply outputs "startosinstall is not currently supported in the recoveryOS on Apple Silicon".

			# BUT, I've discovered a simple way to customize a clean install by tricking the installer into thinking it's an upgrade/re-install.
			# This process cannot be completely scripted and requires some user interaction, but it is the
			# best option on Apple Silicon from within recoveryOS until Apple makes "startosinstall" work.

			# The first important thing is to make sure the Apple Silicon Mac has been properly erased for a clean install.
			# This cannot be scripted (as far as I know) and requires manually running "Erase Mac" through GUI means.
			# If "Erase Mac" is not used and the internal drive is erased incorrectly, Secure Token/Volume Owner users may not be able to be created.

			# "Erase Mac" can be run from the Recovery Assistant menu (on first boot into recoveryOS if FileVault is enabled or by running "resetpassword" in Terminal to re-open Recovery Assistant).
			# "Erase Mac" can also be done by following the prompts in Disk Utility when erasing the internal volume group (I think these prompted were added to Disk Utility in macOS 11.2 Big Sur).
			# Since we are in Terminal at this point, the easiest option is to launch "resetpassword" to re-open Recovery Assistant and then display instructions on how to manually run "Erase Mac".

			# After "Erase Mac" has been run, the internal drive will be named "Untitled" on macOS 11 Big Sur or "Macintosh HD" on macOS 12 Monterey and it will be empty except for the ".fseventsd" folder.
			# So, this is what we will check for to determine if "Erase Mac" has already been run and proceed with preparing the drive to trick the installer
			# into performing a upgrade/re-install as well as copying the customization resources (the same as when customizing an existing clean install).

			# Now, FOR THE TRICK! Through random trial-and-error, I found that simply the existance of the "/System/Library/CoreServices/SystemVersion.plist" file will make the installer perform
			# an upgrade/re-install process instead of a clean install. This means that any files or folders added into the filesystem are preserved instead of deleted during the installation process.
			# I first started with a valid "SystemVersion.plist" file, but through more testing I found that the contents of this file do not matter, and creating an empty one is enough.
			# BUT, whatever "/System/Library/CoreServices/SystemVersion.plist" we create will be moved to "/private/var/db/PreviousSystemVersion.plist" during the installation process.
			# Since I am not sure when/if/how this "PreviousSystemVersion.plist" may be used by macOS, it seems best to be safe and create a valid "SystemVersion.plist" in the first place.
			# The easist way to create a valid "SystemVersion.plist" is to COPY the one from the currently running recoveryOS, so that it what we will do.

			# The one big important thing about this is that if you ONLY create the "SystemVersion.plist", the installation will fail and reboot into recoveryOS with an error stating
			# that "An error occurred migrating user data during an install." So, more trial-and-error testing was necessary. My first though was to extract the entire "/private/var/db/dslocal"
			# folder from a clean installation and copy it into place before starting the installation process, and this worked! But, I was concerned about having to check and maintain any changes over time
			# between different versions of macOS, as well as if there was any computer specific information stored in the "localhost.plist" file or others that should be freshly created during an installation.
			# In an effort to find the absolute least amount of actions necessary to make this trick work, I tried only creating certain "dslocal" folders and files to see what worked and what didn't.
			# To my delight, I found that ALL that needs to be created is an EMPTY "/private/var/db/dslocal/nodes/Default" folder!
			# If only the "/private/var/db/dslocal/nodes" folder or any less is created, the installation process will fail with the same error as stated above, but anymore is unnecessary.
			# The installer will properly create the default "dslocal" contents when only an EMPTY "/private/var/db/dslocal/nodes/Default" folder exists!

			# The other concern about this process was permission issues between what the permissions are when folders are created in recoveryOS vs what they are supposed to be after a normal installation.
			# But, this appears to MOSTLY be a non-issue in my testing. The installation process appears to reset and correct MOST permissions for MOST files or folders created in recoveryOS.
			# EXCEPT for the "/Library" and "/Library/LaunchDaemons" folder, which does not get its group correctly changed from "admin" to "wheel", so that must be done manually as well.

			# Once these files and folder are created to trick the installer into peforming the upgrade/re-install and our customization resources are also setup and copied in,
			# Install Assistant is launched to be manually clicked through since that is the only way to start an installation process within recoveryOS on Apple Silicon.
			# At this point we will just display instructions how how to manually start the installation.

			# So, that is the summary of all the checking and actions that are done below to be able to perform a customized clean install on Apple Silicon!
			# Of course, Apple Silicon Macs can also be put into DFU mode and restored via Apple Configurator 2 on another Mac and then that existing clean install can be customized by this script.
			# But, this option was fairly simple to add and is nice to have if a re-install is needed on an Apple Silicon Mac without needing to have another Mac on hand to do a DFU restore.


			# DETECT APPLE SILICON STATE AND PROMPT TO MANUALLY ERASE OR MANUALLY START CUSTOMIZED CLEAN INSTALLATION

			load_specs_overview
			ansi_clear_screen
			echo -e "${FG_MIB_HEADER}${specs_overview}\n\n  ${ANSI_CYAN}${ANSI_BOLD}Detecting State of This Apple Silicon Mac...${CLEAR_ANSI}"

			os_install_assistant_springboard_path="${os_installer_path/\/Resources\/startosinstall//MacOS/InstallAssistant_springboard}"

			# See notes above about why "startosinstall" cannot be used and why "Install Assistant" must be launched instead for the installation to be manually started.
			# There are 3 binaries within an installers "MacOS" folder: InstallAssistant, InstallAssistant_plain, and InstallAssistant_springboard
			# I am not sure the differences between these binaries, but the instructions at the bottom of https://web.archive.org/web/20211021212342/https://support.apple.com/en-us/HT211983
			# show launching "InstallAssistant_springboard" to manually start the installer, so that's what we'll do.
			
			if [[ -f "${os_install_assistant_springboard_path}" ]]; then

				internal_drive_name='Apple Silicon Internal Drive'
				internal_drive_has_mounted_volume=false
				erase_mac_has_been_run=false

				 # To be able to determine if "Erase Mac" has been run yet, we will check some NVRAM keys as well as check that the internal drive was erased and renamed to "Untitled" or "Macintosh HD".
				 # This is not all that happens during the "Erase Mac" process, but these are the best indicators I've found to determine that "Erase Mac" has been run successfully.
				 # First check that NVRAM "recovery-boot-mode" key gets set to "obliteration". This key and value is set during the "Erase Mac" process, but is oddly not deleted on
				 # reboot after "Erase Mac" has finished. That means this key could be leftover from a previous "Erase Mac" even if a new installation has been performed.
				 # So, we will also check the NVRAM "boot-volume" key DOES NOT exist. Prior to macOS 11.3 Big Sur, the "boot-volume" key could possibly be deleted manually using
				 # "nvram -c" or "nvram -d" but as of macOS 11.3 Big Sur, this key and other "*-volume" keys are now protected in NVRAM and cannot be manually deleted outside of running "Erase Mac".
				 # Therefore, checking that both "recovery-boot-mode" is equal to "obliteration" AND that "boot-volume" does not exist should be a very strong indicator that "Erase Mac" has been run.

				recovery_boot_mode_is_obliteration="$([[ "$(nvram recovery-boot-mode 2> /dev/null)" == *'obliteration' || -z "$(nvram boot-volume 2> /dev/null)" ]] && echo 'true' || echo 'false')"

				 # To be doubly sure that "Erase Mac" has been run successfully and that this Apple Silicon Mac is ready
				 # for a new installation, we will also check that the internal drive has a mounted volume named "Untitled" or "Macintosh HD".
				 # See comments below about a possible error when running "Erase Mac" twice in a row that can cause the internal drive to not have a mounted volume.

				for this_disk_id in "${install_drive_choices[@]}"; do
					# There should only be a single internal drive on Apple Silicon, so this should always be correct.
					# THIS MAY CHANGE IN THE FUTURE (MAYBE WITH MAC PRO) AND MORE THINGS WILL NEED TO BE CHECKED TO GET THE CORRECT INTERNAL DRIVE ON APPLE SILICON.
					internal_drive_name="$(strip_ansi_styles "${install_drive_choices_display}" | grep "^    ${this_disk_id}:")"
					internal_drive_name="${internal_drive_name#*: }"

					# Make sure all internal drives are mounted to be able to check if "Erase Mac" has been run successfully. This should not be necessary on Apple Silicon, but does not hurt.
					diskutil mountDisk "${this_disk_id}" &> /dev/null
					
					# Mounting parent disk IDs appears to not mount the child APFS Container disk IDs, so mount them too to be able to check if "Erase Mac" has been run successfully.
					apfs_container_disk_ids="$(diskutil list "${this_disk_id}" | awk '(($3 ~ /Container$/) && ($4 ~ /^disk/)) { gsub(/[^0-9]/, "", $4); print "disk" $4 }')"
					# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop, so just "awk" the human readable output of a single "diskutil list" command instead since it's right there.
					# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID, so they must be removed from the disk IDs for them to be usable.
					# When using gsub(/[^[:print:]]/, "", $4), I was seeing an extraneous "?" get outputted after the disk ID on one computer but not another (which is odd), but removing all non-digits and then adding "disk" back solved that for all computers.
					
					for this_apfs_container_disk_id in ${apfs_container_disk_ids}; do
						diskutil mountDisk "${this_apfs_container_disk_id}" &> /dev/null

						this_apfs_container_info_plist="$(diskutil list -plist "${this_apfs_container_disk_id}")"
						if echo "${this_apfs_container_info_plist}" | grep -q '>/Volumes/'; then # Using PlistBuddy would not make these checks any easier.
							# Make sure any volume is mounted on the internal drive to check for a possible error after "Erase Mac" has been run. See comments below for more information.
							internal_drive_has_mounted_volume=true

							if $recovery_boot_mode_is_obliteration; then # Only bother checking for "Untitled" or "Macintosh HD" volume after "Erase Mac" if recovery_boot_mode_is_obliteration. See comments above for more information.
								erased_volume_name="$( (( this_os_installer_darwin_major_version >= 21 )) && echo 'Macintosh HD' || echo 'Untitled' )" # Internal drive will be named "Untitled" after "Erase Mac" on macOS 11 Big Sur or named "Macintosh HD" on macOS 12 Monterey.
								if echo "${this_apfs_container_info_plist}" | grep -q ">/Volumes/${erased_volume_name}<" && [[ -d "/Volumes/${erased_volume_name}" ]]; then
									erased_volume_contents="$(find "/Volumes/${erased_volume_name}" -mindepth 1 -maxdepth 1 2> /dev/null)"

									if [[ -z "${erased_volume_contents}" || "${erased_volume_contents}" == "/Volumes/${erased_volume_name}/.fseventsd" ]]; then
										# If recovery_boot_mode_is_obliteration and an internal drive has an empty "/Volumes/Untitled" or "/Volumes/Macintosh HD" volume, we can assume "Erase Mac" has been run successfully.
										erase_mac_has_been_run=true
									fi
								fi
							fi
						fi
					done
				done

				if ! $internal_drive_has_mounted_volume; then
					# As of macOS 11.3 Big Sur, when "Erase Mac" is run twice in a row on Apple Silicon the volume will not mount when rebooted into
					# recoveryOS after the 2nd "Erase Mac" and Disk Utility will display an error when attempting to manually mount the volume.
					# No graphical error will be displayed, but errors will be visible in the Log during the "Erase Mac" process.
					# This should be able to fixed by manually erasing the Container in Disk Utility, but I have not automated this since it is not something that should normally happen.
					# If for some reason there is an error when erasing the Container in Disk Utility, a DFU restore through Apple Configurator 2 would be the only way to get the Mac working properly again.

					echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} No Volume Mounted on ${internal_drive_name}\n\n    ${ANSI_YELLOW}This may indicate that an error occurred after running \"Erase Mac\".\n\n    ${ANSI_PURPLE}${ANSI_BOLD}Please inform and deliver this Mac to Free Geek I.T.${CLEAR_ANSI}\n\n"
					
					'/System/Applications/Utilities/Disk Utility.app/Contents/MacOS/Disk Utility' &> /dev/null & disown # Launch Disk Utility to be able to see what's going on with the drive to be able to easily erase the Container.

					exit 0
				fi
				
				confirm_continue_response=''
				while [[ "${confirm_continue_response}" != 'Y' ]]; do
					load_specs_overview
					ansi_clear_screen
					echo -e "${FG_MIB_HEADER}${specs_overview}"
					if [[ -n "${global_install_notes}" ]]; then echo -e "\n${global_install_notes}\n"; fi

					if $erase_mac_has_been_run; then
						echo -e "\n  ${ANSI_UNDERLINE}${os_installer_name} Is Ready to Be ${ANSI_BOLD}MANUALLY INSTALLED${CLEAR_ANSI}${ANSI_UNDERLINE} On This Apple Silicon Mac:${CLEAR_ANSI}"
						echo -en "\n    ${ANSI_PURPLE}Enter ${ANSI_BOLD}Y${CLEAR_ANSI}${ANSI_PURPLE} to ${ANSI_UNDERLINE}PREPARE $($CLEAN_INSTALL_REQUESTED && echo 'INSTALLATION' || echo 'CUSTOMIZATIONS') AND VIEW INSTRUCTIONS${CLEAR_ANSI}${ANSI_PURPLE}\n    or Enter ${ANSI_BOLD}N${CLEAR_ANSI}${ANSI_PURPLE} to ${ANSI_UNDERLINE}EXIT${CLEAR_ANSI}${ANSI_PURPLE}:${CLEAR_ANSI} "
					else
						echo -e "\n  ${ANSI_UNDERLINE}Apple Silicon Macs Must Be ${ANSI_BOLD}MANUALLY ERASED${CLEAR_ANSI}${ANSI_UNDERLINE} Before ${ANSI_BOLD}INSTALLING${CLEAR_ANSI}${ANSI_UNDERLINE} ${os_installer_name}:${CLEAR_ANSI}"
						echo -en "\n    ${ANSI_PURPLE}Enter ${ANSI_BOLD}Y${CLEAR_ANSI}${ANSI_PURPLE} to ${ANSI_UNDERLINE}VIEW INSTRUCTIONS${CLEAR_ANSI}${ANSI_PURPLE} or Enter ${ANSI_BOLD}N${CLEAR_ANSI}${ANSI_PURPLE} to ${ANSI_UNDERLINE}EXIT${CLEAR_ANSI}${ANSI_PURPLE}:${CLEAR_ANSI} "
					fi

					read -r confirm_continue_response

					confirm_continue_response="$(echo "${confirm_continue_response}" | tr '[:lower:]' '[:upper:]')"
					if [[ "${confirm_continue_response}" == 'N' ]]; then
						echo -e '\n'
						exit 0
					fi
				done

				if $erase_mac_has_been_run; then

					# MAKE SURE POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT AND INTERNET IS CONNECTED

					check_and_prompt_for_power_adapter_for_laptops
					set_date_time_and_prompt_for_internet_if_year_not_correct
					check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs
					

					# CLEAR SCREEN BEFORE CLEARING NVRAM PREPARING OS CUSTOMIZATION AND/OR INSTALLATION

					ansi_clear_screen

					
					# CLEAR NVRAM
					# SIP will not be reset on Apple Silicon, see notes within clear_nvram_and_reset_sip for more information.
					# This is not completely necessary, but doesn't hurt and will remove the "recovery-boot-mode=obliteration" key from NVRAM, which is no longer need.
					# Not sure why that key is not deleted automatically after "Erase Mac" has been run (as of macOS 11.3 Big Sur). I think it's a bug.

					clear_nvram_and_reset_sip


					if (( this_os_installer_darwin_major_version < 21 )); then

						# RENAME "Untitled" TO install_volume_name WHEN ON macOS 11 Big Sur
						# This is no longer necessary on macOS 12 Monterey.

						echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Renaming ${ANSI_UNDERLINE}${internal_drive_name}${ANSI_CYAN}${ANSI_BOLD} to ${ANSI_UNDERLINE}\"${install_volume_name}\"${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}\n"
						
						
						if [[ -d "${install_volume_path}" ]]; then
							# Unmount any other drive already named the same as install_volume_name to not conflict with our intended install drive mount point.
							diskutil unmount "${install_volume_path}" || diskutil unmount force "${install_volume_path}"
						fi
						
						diskutil rename 'Untitled' "${install_volume_name}"
					fi


					if [[ -d "${install_volume_path}" ]]; then

						install_volume_contents="$(find "${install_volume_path}" -mindepth 1 -maxdepth 1 2> /dev/null)"
						
						if [[ -z "${install_volume_contents}" || "${install_volume_contents}" == "${install_volume_path}/.fseventsd" ]]; then

							if ! $CLEAN_INSTALL_REQUESTED && (( install_packages_count > 0 )) && [[ -f "${SCRIPT_DIR}/install-packages/fg-install-packages.sh" ]]; then
							
								# PREPARE CUSTOMIZATION RESOURCES

								echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Copying Customization Resources Into ${ANSI_UNDERLINE}\"${install_volume_path}\"${ANSI_CYAN}${ANSI_BOLD}\n  on ${ANSI_UNDERLINE}${internal_drive_name}${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}\n"

								# See notes above about why the next two commands are CRITICAL.
								# See notes above about why we are copying a valid "SystemVersion.plist" from recoveryOS rather than create a blank one (it's because even though a blank one will work, it will be moved to "/private/var/db/PreviousSystemVersion.plist" by the installer).
								ditto '/System/Library/CoreServices/SystemVersion.plist' "${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" # "ditto" will create missing parent folders.
								mkdir -p "${install_volume_path}/private/var/db/dslocal/nodes/Default"

								# These folders need to be created for our customization LaunchDaemon and resources.
								mkdir -p "${install_volume_path}/Users/Shared"
								mkdir -p "${install_volume_path}/Library/LaunchDaemons"
								chown -R 0:0 "${install_volume_path}/Library" # Make sure this folder (and LaunchDaemons) gets properly owned by root:wheel after installation, see notes above for more information.

								if [[ -f "${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" && -d "${install_volume_path}/private/var/db/dslocal/nodes/Default" && \
									-d "${install_volume_path}/Users/Shared" && -d "${install_volume_path}/Library/LaunchDaemons" ]]; then

									if copy_customization_resources "${install_volume_path}"; then

										echo -e "  ${ANSI_GREEN}${ANSI_BOLD}Successfully Copied Customization Resources and Prepared Customization${CLEAR_ANSI}\n"

										sleep 3 # Sleep a bit so technician can see that customization resources were copied.
									else
										echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to Copy Customization Resources${CLEAR_ANSI}\n\n"
									fi
								else
									echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed Setup Files/Folders for Customized Clean Install${CLEAR_ANSI}\n\n"
								fi
							fi
							

							while true; do # Looping forever to keep re-displaying instructions if user presses enter.

								# MAKE SURE POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT AND INTERNET IS CONNECTED

								check_and_prompt_for_power_adapter_for_laptops
								set_date_time_and_prompt_for_internet_if_year_not_correct
								check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs
								

								# PROMPT TO MANUALLY START INSTALLATION
								# Do not show specs since this text will fill the entire default window size.

								ansi_clear_screen
								echo -e "
  ${ANSI_UNDERLINE}Manual Action Required on Apple Silicon Macs:${CLEAR_ANSI}

    ${ANSI_PURPLE}${ANSI_BOLD}Now, the ${os_installer_name} installation must be started manually.${CLEAR_ANSI}

    The ${ANSI_BOLD}Install Assistant${CLEAR_ANSI} app has been opened in the background.
    $($CLEAN_INSTALL_REQUESTED && \
		echo "Clean installation will be peformed since \"$1\" argument has been used." || \
		echo "Even though it will look like you're starting a clean install process,
    it will be a customized install because of the preparation that's been done.")

    First, click the \"Continue\" button in the installation window.

    Next, click the \"Agree\" button and then click \"Agree\" again in the prompt.

    Finally, select \"${install_volume_name}\" in the disk selection window
    and then click \"Continue\" to start the installation process.


  ${ANSI_UNDERLINE}Internet Required During Installation:${CLEAR_ANSI}

    You should have already connected this Mac to the internet during
    activation, but make sure it's still connected since the install
    process will fail if this Mac is not connected to the internet.
"

								# Suppress ShellCheck suggestion to use pgrep since it's not available in recoveryOS.
								# shellcheck disable=SC2009
								if ! ps | grep -v grep | grep -q 'InstallAssistant'; then # Do not want to launch a new instance if it's already running.
									"${os_install_assistant_springboard_path}" &> /dev/null & disown
								fi

								read -r # Keep this process running to not show the command prompt for a clean window and just keep re-displaying instructions if user presses enter.
							done
						else
							echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Internal Drive Not Empty${CLEAR_ANSI}\n\n"
						fi
					else
						echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed Rename Internal Drive${CLEAR_ANSI}\n\n"
					fi
				else
					while true; do # Looping forever to keep re-displaying instructions if user presses enter.
						
						# MAKE SURE POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT

						check_and_prompt_for_power_adapter_for_laptops
						set_date_time_and_prompt_for_internet_if_year_not_correct
						

						# PROMPT TO MANUALLY ERASE MAC
						# Do not show specs since this text will fill the entire default window size.

						ansi_clear_screen
						echo -e "
  ${ANSI_UNDERLINE}Manual Action Required on Apple Silicon Macs:${CLEAR_ANSI}

    ${ANSI_PURPLE}${ANSI_BOLD}Apple Silicon Macs must be erased manually using \"Erase Mac\".${CLEAR_ANSI}

    The ${ANSI_BOLD}Recovery Assistant${CLEAR_ANSI} app has been opened in the background.
    Click on the ${ANSI_BOLD}Recovery Assistant${CLEAR_ANSI} window titled \"Reset Password\" to bring
    it to the front, but we are not going to use it for any password resets.

    When ${ANSI_BOLD}Recovery Assistant${CLEAR_ANSI} is frontmost, open the \"Recovery Assistant\" menu
    in the menubar, and select the \"Erase Mac...\" menu item.
    If \"Erase Mac...\" is disabled, wait until \"Examining volumes...\" is done.

    Now, click the blue \"Erase Mac...\" button in the \"Erase Mac\" window.
    Finally, confirm the action by clicking \"Erase Mac\" in the prompt.

    When \"Erase Mac\" has finished, this Mac will reboot back into recoveryOS.
    Then, you will need to activate this Mac over the internet to continue.

    After activation, you will need to manually re-open Terminal, and then
    re-launch this script to proceed with the customized installation.
    This script will detect \"Erase Mac\" has finished and display the next steps.
"

						# Suppress ShellCheck suggestion to use pgrep since it's not available in recoveryOS.
						# shellcheck disable=SC2009
						if ! ps | grep -v grep | grep -q 'KeyRecoveryAssistant'; then # Do not want to launch a new instance if it's already running.
							resetpassword &> /dev/null
						fi

						read -r # Keep this process running to not show the command prompt for a clean window and just keep re-displaying instructions if user presses enter.
					done
				fi
			else
				echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required \"InstallAssistant_springboard\" Not Found in Standard Location${CLEAR_ANSI}\n\n"
			fi
		else
			
			# PROMPT TO CHOOSE INSTALL DRIVE (even if only one is available so that erasing can be confirmed)

			install_disk_id=''
			install_drive_name=''
			
			last_choose_drive_error=''
			while [[ -z "${install_disk_id}" ]]; do
				load_specs_overview
				ansi_clear_screen
				echo -e "${FG_MIB_HEADER}${specs_overview}"
				if [[ -n "${global_install_notes}" ]]; then echo -e "\n${global_install_notes}\n"; fi
				echo -e "\n  ${ANSI_UNDERLINE}Choose Drive to ${ANSI_BOLD}COMPLETELY ERASE${CLEAR_ANSI}${ANSI_UNDERLINE} and ${ANSI_BOLD}INSTALL${CLEAR_ANSI}${ANSI_UNDERLINE} ${os_installer_name} Onto:${CLEAR_ANSI}${last_choose_drive_error}${install_drive_choices_display}"

				echo -en "\n  Enter the ${ANSI_BOLD}ID of Drive${CLEAR_ANSI} to ${ANSI_UNDERLINE}COMPLETELY ERASE${CLEAR_ANSI}\n  and ${ANSI_UNDERLINE}INSTALL${CLEAR_ANSI} ${ANSI_BOLD}${os_installer_name}${CLEAR_ANSI} Onto: disk"
				read -r chosen_disk_id_number

				chosen_disk_id_number="$(echo "${chosen_disk_id_number}" | tr '[:lower:]' '[:upper:]')"
				if [[ "${chosen_disk_id_number}" != 'F' ]]; then
					chosen_disk_id_number="${chosen_disk_id_number//[^0-9]/}" # Remove all non-digits
					if [[ "${chosen_disk_id_number}" == '0'* ]]; then
						chosen_disk_id_number="${chosen_disk_id_number#"${chosen_disk_id_number%%[^0]*}"}" # Remove any leading zeros
						if [[ -z "${chosen_disk_id_number}" ]]; then chosen_disk_id_number='0'; fi # Catch if the number was all zeros
					fi
				fi
				
				if [[ " ${install_drive_choices[*]} " == *" disk${chosen_disk_id_number} "* ]]; then
					install_drive_name="$(strip_ansi_styles "${install_drive_choices_display}" | grep "^    disk${chosen_disk_id_number}:")"
					install_drive_name="${install_drive_name#*: }"
					if [[ "${install_drive_name}" == 'Create Fusion Drive'* ]]; then install_drive_name='Fusion Drive'; fi

					echo -en "\n  Enter ${ANSI_BOLD}disk${chosen_disk_id_number}${CLEAR_ANSI} Again to Confirm ${ANSI_UNDERLINE}COMPLETELY ERASING${CLEAR_ANSI} and ${ANSI_UNDERLINE}INSTALLING${CLEAR_ANSI}\n  ${ANSI_BOLD}${os_installer_name}${CLEAR_ANSI} Onto ${ANSI_BOLD}${install_drive_name}${CLEAR_ANSI}: disk"
					read -r confirmed_disk_id_number

					confirmed_disk_id_number="$(echo "${confirmed_disk_id_number}" | tr '[:lower:]' '[:upper:]')"
					if [[ "${confirmed_disk_id_number}" != 'F' ]]; then
						confirmed_disk_id_number="${confirmed_disk_id_number//[^0-9]/}" # Remove all non-digits
						if [[ "${confirmed_disk_id_number}" == '0'* ]]; then
							confirmed_disk_id_number="${confirmed_disk_id_number#"${confirmed_disk_id_number%%[^0]*}"}" # Remove any leading zeros
							if [[ -z "${confirmed_disk_id_number}" ]]; then confirmed_disk_id_number='0'; fi # Catch if the number was all zeros
						fi
					fi

					if [[ "${chosen_disk_id_number}" == "${confirmed_disk_id_number}" ]]; then

						# MAKE SURE POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT (AND INTERNET IS CONNECTED FOR STUB INSTALLER OR T2 MACS) BEFORE ALLOWING DRIVE TO BE ERASED OR OS INSTALLATION TO BEGIN

						check_and_prompt_for_power_adapter_for_laptops
						set_date_time_and_prompt_for_internet_if_year_not_correct
						check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs

			
						install_disk_id="disk${confirmed_disk_id_number}"
			
						# DO NOT actually erase the drive in this script if can_only_install_on_boot_drive and installation will be done with "eraseinstall" argument.
						if ! $can_only_install_on_boot_drive && grep -qU -e '--volume, ' "${os_installer_path}"; then
							if xartutil --list &> /dev/null; then
								# Clear encryption keys BEFORE formatting drive because new keys will be created on T2 Macs for the newly formatted drive that we don't want to clear.
								xartutil_output='CLEAR ONCE NO MATTER WHAT'
								while [[ -n "${xartutil_output}" && "${xartutil_output}" != 'Total Session count: 0' ]]; do # Cleared output is empty on T1s and "Total Session count: 0" on T2s
									ansi_clear_screen
									echo -e "\n  ${ANSI_CYAN}${ANSI_BOLD}Clearing All Encryption Keys...${CLEAR_ANSI}\n"
									
									xartutil_output="$(xartutil --list)"

									if [[ -n "${xartutil_output}" ]]; then
										echo -e "${xartutil_output}\n" # Show current keys to technician.
									fi

									echo 'yes' | xartutil --erase-all

									echo '' # Add line break after prompt was automatically confirmed with "yes".

									xartutil_output="$(xartutil --list)"

									if [[ -n "${xartutil_output}" ]]; then
										echo -e "\n${xartutil_output}" # Show new keys output to technician.
									fi
									
									if [[ -z "${xartutil_output}" || "${xartutil_output}" == 'Total Session count: 0' ]]; then
										echo -e "\n  ${ANSI_GREEN}${ANSI_BOLD}Successfully Cleared All Encryption Keys${CLEAR_ANSI}\n"
									fi
								done
								
								sleep 3 # Sleep a bit so technician can see that keys were cleared (or see error if not).
							fi

							ansi_clear_screen
							echo -e "\n  ${ANSI_CYAN}${ANSI_BOLD}Formatting ${ANSI_UNDERLINE}${install_drive_name}${ANSI_CYAN}${ANSI_BOLD}\n  to Install ${ANSI_UNDERLINE}${os_installer_name}${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}"
							
							for erase_disk_attempt in {1..3}; do
								erase_did_succeed=false

								if [[ "${install_disk_id}" == 'diskF' ]]; then
									echo -e "\n    ${ANSI_BOLD}Unmounting All Internal Drives...${CLEAR_ANSI}\n"

									for this_disk_id in "${install_drive_choices[@]}"; do
										if [[ -n "${this_disk_id}" && "${this_disk_id}" != 'diskF' ]]; then
											diskutil unmountDisk "${this_disk_id}" || diskutil unmountDisk force "${this_disk_id}"
										fi
									done

									if [[ -d "${install_volume_path}" ]]; then
										# Unmount any other drive already named the same as install_volume_name to not conflict with our intended formatted drive mount point.
										diskutil unmount "${install_volume_path}" || diskutil unmount force "${install_volume_path}"
									fi

									echo -e "\n    ${ANSI_CYAN}${ANSI_BOLD}Creating Fusion Drive...${CLEAR_ANSI}"

									if echo 'Yes' | diskutil resetFusion; then
										erase_did_succeed=true
									else
										# I have seen that a messed up APFS Container can cause "diskutil eraseDisk" to fail (assuming it would affect "diskutil resetFusion" as well),
										# so try to delete any and all existing APFS Containers and then try "diskutil resetFusion" again.
										# I ran into this issue after restoring some Snapshots failed during other testing and caused the APFS Container to be messed up.

										did_delete_apfs_container=false
										
										for this_disk_id in "${install_drive_choices[@]}"; do
											if [[ -n "${this_disk_id}" && "${this_disk_id}" != 'diskF' ]]; then
												apfs_container_disk_ids="$(diskutil list "${this_disk_id}" | awk '(($3 ~ /Container$/) && ($4 ~ /^disk/)) { gsub(/[^0-9]/, "", $4); print "disk" $4 }')"
												# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop, so just "awk" the human readable output of a single "diskutil list" command instead since it's right there.
												# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID, so they must be removed from the disk IDs for them to be usable.
												# When using gsub(/[^[:print:]]/, "", $4), I was seeing an extraneous "?" get outputted after the disk ID on one computer but not another (which is odd), but removing all non-digits and then adding "disk" back solved that for all computers.
												
												for this_apfs_container_disk_id in ${apfs_container_disk_ids}; do
													if diskutil apfs deleteContainer "${this_apfs_container_disk_id}"; then
														did_delete_apfs_container=true
													fi
												done
											fi
										done

										if $did_delete_apfs_container && echo 'Yes' | diskutil resetFusion; then
											erase_did_succeed=true
										fi
									fi
								else
									echo -e "\n    ${ANSI_BOLD}Unmounting ${install_drive_name}...${CLEAR_ANSI}\n"

									diskutil unmountDisk "${install_disk_id}" || diskutil unmountDisk force "${install_disk_id}"

									if [[ -d "${install_volume_path}" ]]; then
										# Unmount any other drive already named the same as install_volume_name to not conflict with our intended formatted drive mount point.
										diskutil unmount "${install_volume_path}" || diskutil unmount force "${install_volume_path}"
									fi

									echo -e "\n    ${ANSI_BOLD}Erasing ${install_drive_name}...${CLEAR_ANSI}\n"

									format_for_drive="$($HAS_T2_CHIP && echo 'APFS' || echo 'JHFS+')"
									# Only format straight to APFS for T2 Macs, which required APFS to be able to function properly.
									# If we format to JHFS+ on a T2 Mac, then startosinstall will exit with an error stating the volume is not compatible.
									# Otherwise let the installer do the conversion from JHFS+ to APFS when it is supported, and after any necessary EFI Firmware updates.
									# If we format straight to APFS on a Mac whose EFI Firmware is too old to boot to APFS, startosinstall will exit with an error stating that JHFS+ is required.
									# The installer will take care of updating EFI Firmware and then convert to APFS after that has been completed, if supported by the OS version and drive type.

									if diskutil eraseDisk "${format_for_drive}" "${install_volume_name}" "${install_disk_id}"; then
										erase_did_succeed=true
									else
										# I have seen that a messed up APFS Container can cause "diskutil eraseDisk" to fail,
										# so try to delete any and all existing APFS Containers and then try "diskutil eraseDisk" again.
										# I ran into this issue after restoring some Snapshots failed during other testing and caused the APFS Container to be messed up.
										
										did_delete_apfs_container=false

										apfs_container_disk_ids="$(diskutil list "${install_disk_id}" | awk '(($3 ~ /Container$/) && ($4 ~ /^disk/)) { gsub(/[^0-9]/, "", $4); print "disk" $4 }')"
										# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop, so just "awk" the human readable output of a single "diskutil list" command instead since it's right there.
										# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID, so they must be removed from the disk IDs for them to be usable.
										# When using gsub(/[^[:print:]]/, "", $4), I was seeing an extraneous "?" get outputted after the disk ID on one computer but not another (which is odd), but removing all non-digits and then adding "disk" back solved that for all computers.
										
										for this_apfs_container_disk_id in ${apfs_container_disk_ids}; do
											if diskutil apfs deleteContainer "${this_apfs_container_disk_id}"; then
												did_delete_apfs_container=true
											fi
										done

										if $did_delete_apfs_container && diskutil eraseDisk "${format_for_drive}" "${install_volume_name}" "${install_disk_id}"; then
											erase_did_succeed=true
										fi
									fi
								fi

								if $erase_did_succeed; then
									echo -e "\n    ${ANSI_BOLD}Waiting for ${install_drive_name}\n    to Mount After Being Erased...${CLEAR_ANSI}"
									for (( wait_for_mount_seconds = 0; wait_for_mount_seconds < 10; wait_for_mount_seconds ++ )); do
										if [[ -d "${install_volume_path}" ]]; then
											break
										else
											sleep 1
										fi
									done
								fi

								if [[ -d "${install_volume_path}" ]]; then
									if [[ "${install_drive_name}" == 'Fusion Drive' ]]; then
										install_fusion_drive_size_bytes="$(PlistBuddy -c 'Print :TotalSize' /dev/stdin <<< "$(diskutil info -plist "${install_volume_path}")" 2> /dev/null)"
										if [[ -n "${install_fusion_drive_size_bytes}" ]]; then
											install_fusion_drive_size="$(( install_fusion_drive_size_bytes / 1000 / 1000 / 1000 )) GB"
										else
											install_fusion_drive_size='UNKNOWN Size'
										fi
										install_drive_name="${install_fusion_drive_size} Fusion Drive"
									fi
									
									break
								else
									echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to $([[ "${install_disk_id}" == 'diskF' ]] && echo 'Create Fusion Drive' || echo "Erase ${install_disk_id}") ${ANSI_YELLOW}${ANSI_BOLD}(Attempt ${erase_disk_attempt} of 3)${CLEAR_ANSI}"
									sleep 3 # Sleep a bit so technician can see the error.
								fi
							done

							if [[ ! -d "${install_volume_path}" ]]; then
								install_disk_id=''
								install_drive_name='ERROR-FORMATTING-DRIVE'
								break
							fi
						fi
					else
						install_drive_name=''
						last_choose_drive_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Did Not Confirm Drive ID ${ANSI_BOLD}disk${chosen_disk_id_number} ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
					fi
				elif [[ -n "${chosen_disk_id_number}" ]]; then
					last_choose_drive_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Drive ID ${ANSI_BOLD}disk${chosen_disk_id_number}${ANSI_RED} Is Not a Valid Choice ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
				else
					last_choose_drive_error=''
				fi
			done

			if [[ -n "${install_disk_id}" && -n "${install_drive_name}" ]]; then
				if $can_only_install_on_boot_drive || [[ -d "${install_volume_path}" ]]; then
					
					# DOUBLE CHECK POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT (AND INTERNET IS CONNECTED FOR STUB INSTALLER OR T2 MACS) BEFORE STARTING OS INSTALLATION
					# We already did this check before allowing drive selection, but doesn't hurt to double check before the longer installation process starts.

					check_and_prompt_for_power_adapter_for_laptops
					set_date_time_and_prompt_for_internet_if_year_not_correct
					check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs


					# CLEAR SCREEN BEFORE CLEARING NVRAM & RESETTING SIP AND STARTING OS INSTALLATION

					ansi_clear_screen


					# CLEAR NVRAM & RESET SIP
					# SIP will not be reset on Apple Silicon, see notes within clear_nvram_and_reset_sip for more information.
					
					clear_nvram_and_reset_sip


					# START OS INSTALLATION

					echo -e "\n\n  ${ANSI_GREEN}${ANSI_BOLD}Installing ${ANSI_UNDERLINE}${os_installer_name}${ANSI_GREEN}${ANSI_BOLD}\n  Onto ${ANSI_UNDERLINE}${install_drive_name}${ANSI_GREEN}${ANSI_BOLD}...${CLEAR_ANSI}\n"
					if [[ -n "${global_install_notes}" ]]; then echo -e "${global_install_notes}\n"; fi
					
					declare -a os_installer_options=( '--nointeraction' ) # The "nointeraction" argument is undocumented, but is supported on ALL versions of "startosinstall" (which is OS X 10.11 El Capitan and newer).

					# NOTE: Instead of using version checks to determine supported "startosinstall" arguments, I wanted to use the output of "startosinstall --usage" instead.
					# But, I found that "startosinstall --usage" can take a VERY long time. Grepping the binary contents to check for supported arguments is unconventional but effective and MUCH faster!
					# The part of the binary contents that have the actual usage strings all end with a ", " so it is included in the greps to not match other error messages, etc.
					# To retrieve/verify all the strings referencing arguments within a "startosinstall" binary, run: strings "${path_to_installer_app}/Contents/Resources/startosinstall" | grep -e '--'

					if grep -qU -e '--agreetolicense, ' "${os_installer_path}"; then
						# The "agreetolicense" argument is supported on macOS 10.12 Sierra and newer.
						# Although, installations of OS X 10.11 El Capitan should still be silent because of the "nointeraction" argument.
						os_installer_options+=( '--agreetolicense' )
					fi

					if grep -qU -e '--applicationpath, ' "${os_installer_path}"; then
						# The "applicationpath" argument is only supported on macOS 10.13 High Sierra and older.
						# I believe "applicationpath" is actually only required for macOS 10.12 Sierra and older, but macOS 10.13 High Sierra still supports it.
						os_installer_options+=( '--applicationpath' "${os_installer_path%.app/*}.app" )
					fi

					if grep -qU -e '--installpackage, ' "${os_installer_path}"; then
						# The "installpackage" argument is supported on macOS 10.13 High Sierra and newer.
						if ! $CLEAN_INSTALL_REQUESTED && (( install_packages_count > 0 )); then
							for this_install_package_path in "${install_packages[@]}"; do
								os_installer_options+=( '--installpackage' "${this_install_package_path}" )
							done
						fi
					fi

					if grep -qU -e '--forcequitapps, ' "${os_installer_path}"; then
						# The "forcequitapps" argument is supported on macOS 10.15 Catalina and newer.
						# This should not be necessary IN RECOVERY OS, but doesn't hurt and is useful IN FULL OS.
						os_installer_options+=( '--forcequitapps' )
					fi

					if [[ -n "${caffeinate_pid}" ]] && grep -qU -e '--pidtosignal, ' "${os_installer_path}"; then
						# The "pidtosignal" argument (to terminate the specified PID when the prepare phase is complete) is supported on macOS 10.12 Sierra and newer.
						os_installer_options+=( '--pidtosignal' "${caffeinate_pid}" )
					fi

					can_run_os_installer=false # Double check OS and "volume" or "eraseinstall" args even though it should be redundant if we got this far.

					if $IS_RECOVERY_OS && grep -qU -e '--volume, ' "${os_installer_path}"; then
						# The "volume" argument is supported IN RECOVERY OS on ALL versions of "startosinstall" (which is OS X 10.11 El Capitan and newer).
						# The "volume" argument can also be used IN FULL OS when SIP is disabled, but that is not useful or necessary for our usage.
						os_installer_options+=( '--volume' "${install_volume_path}" )
						can_run_os_installer=true
					elif ! $IS_RECOVERY_OS && grep -qU -e '--eraseinstall, ' "${os_installer_path}"; then
						# The "eraseinstall" AND "newvolumename" arguments are supported IN FULL OS on macOS 10.13 High Sierra and newer. Also, "eraseinstall" is only supported when booted into an APFS volume.
						# If attemped to run on a non-APFS volume, macOS 10.14 Mojave and newer return "Error: Erase installs are supported only on APFS disks." and macOS 10.13 High Sierra returns "Error: 801".
						os_installer_options+=( '--eraseinstall' )

						if grep -qU -e '--newvolumename, ' "${os_installer_path}"; then
							os_installer_options+=( '--newvolumename' "${install_volume_name}" )
						fi

						if grep -qU 'add --allowremoval.' "${os_installer_path}"; then
							# The undocumented "allowremoval" argument is only supported for macOS 10.15 Catalina and there is a note in the macOS 11 Big Sur installer that it is ignored and should be removed.
							# NOTICE: Since this argument is undocumented, it is grepped for at the end of a sentence rather than from the usage like all other greps.
							# This specified string will not exist in the macOS 11 Big Sur installer, so it properly won't get added on macOS 11 Big Sur.
							# More Info: https://grahamrpugh.com/2020/06/09/startosinstall-undocumented-options.html#allowremoval
							os_installer_options+=( '--allowremoval' )
						fi

						if grep -qU -e '--passprompt, ' "${os_installer_path}"; then
							# The "passprompt" argument (to specify the form of authentication) is required on macOS 11 Big Sur when using the "agreetolicense" argument. Previous versions would just do a GUI prompt when needed.
							# This argument will do a command line prompt on macOS 11 Big Sur. The other authentication option is "stdinpass" which is not useful or necessary for our usage.
							# If "agreetolicense" is used without "passprompt" or "stdinpass" then "Error: A method of password entry is required." will be returned.
							os_installer_options+=( '--passprompt' )

							if grep -qU -e '--user, ' "${os_installer_path}"; then
								# The "user" argument must also be included along with "passprompt" (if not running as admin, or always on Apple Silicon).
								# If not running as admin and no "user" argument is specified, then will always fail with "Error: could not get authorization..." since the current user cannot authorize.
								# Including the username even if running as admin doesn't hurt and needs to be specified if not fully logged in and running via "su" (but without "sudo").
								# TODO: If runnning on Apple Silicon, Volume Owner credentials are required no matter what, but they DO NOT need to also be admin credentials if "startosinstall" is being run as root. This situation is not currently detected in this code and admin credentials are always used no matter what.
								admin_username="$(id -un)" # We will use the current username as authorizing admin user if it is and admin and has a Secure Token (and is also a Volume Owner on Apple Silicon).
								diskutil_apfs_users_output="$($IS_APPLE_SILICON && diskutil apfs listUsers /)" # Only need this output to check for Volume Owners on Apple Silicon.
								all_admin_usernames="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:GroupMembership' /dev/stdin <<< "$(dscl -plist /Search -read '/Groups/admin' GroupMembership 2> /dev/null)" 2> /dev/null | awk '(($NF != "{") && ($NF != "root") && ($NF != "}")) { print $NF }')"
								if [[ $'\n'"${all_admin_usernames}"$'\n' != *$'\n'"${admin_username}"$'\n'* || "$(sysadminctl -secureTokenStatus "${admin_username}" 2>&1)" != *'is ENABLED for'* ]] || { $IS_APPLE_SILICON && ! echo "${diskutil_apfs_users_output}" | grep -A 2 "$(dscl -plist /Search -read "/Users/${admin_username}" GeneratedUID 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null)$" | grep -q 'Volume Owner: Yes$'; }; then
									IFS=$'\n'
									for this_admin_username in ${all_admin_usernames}; do
										if [[ "${this_admin_username}" != '_'* ]]; then
											if [[ "$(sysadminctl -secureTokenStatus "${this_admin_username}" 2>&1)" == *'is ENABLED for'* ]] && { ! $IS_APPLE_SILICON || echo "${diskutil_apfs_users_output}" | grep -A 2 "$(dscl -plist /Search -read "/Users/${this_admin_username}" GeneratedUID 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null)$" | grep -q 'Volume Owner: Yes$'; }; then
												# If current user was not admin or did not have a Secure Token,
												# check all admin users for Secure Tokens and use the first admin with a Secure Token.
												admin_username="${this_admin_username}"
												break
											elif [[ " ${all_admin_usernames} " != *" ${admin_username} "* ]]; then
												# If no admin has a Secure Token we still want to get the correct admin username, so fallback to using the first admin or the current user if they are admin.
												# This could happen because running on macOS 11 Big Sur where Secure Tokens can be prevented from being granted: https://support.apple.com/guide/deployment-reference-macos/using-secure-and-bootstrap-tokens-apdff2cf769b/web
												# Or because running on APFS macOS 10.13 High Sierra or macOS 10.14 Mojave when the admin was NOT the first user to log in: https://travellingtechguy.blog/macos-mojave-secure-tokens/
												
												# The previous two situations are fine and the installation can continue with a non-Secure Token admin. The other situation this could happen would be if NOT booted to APFS volume,
												# in which case the "eraseinstall" will exit with an error because it can only be done on APFS volumes, but doesn't hurt to still display the correct admin username.
												
												admin_username="${this_admin_username}"
											fi
										fi
									done
									unset IFS
								fi

								os_installer_options+=( '--user' "${admin_username}" )

								# Let the technician know which admin password is required since the installer prompt does not specify it.
								echo -e "    ${ANSI_PURPLE}${ANSI_BOLD}NOTICE:${ANSI_PURPLE} You will be prompted for ${ANSI_BOLD}${admin_username}${ANSI_PURPLE}'s $($IS_APPLE_SILICON && echo "${diskutil_apfs_users_output}" | grep -A 2 "$(dscl -plist /Search -read "/Users/${admin_username}" GeneratedUID 2> /dev/null | xmllint --xpath '//string[1]/text()' - 2> /dev/null)$" | grep -q 'Volume Owner: Yes$' && echo '(Volume Owner) ')admin password.${CLEAR_ANSI}\n"
							fi
						fi

						can_run_os_installer=true
					fi

					if $can_run_os_installer; then
						"${os_installer_path}" "${os_installer_options[@]}"
					else
						# Should never get here, but handle it with an error and show usage just in case.

						missing_required_os_installer_argument='volume'
						if ! $IS_RECOVERY_OS && grep -qU -e '--eraseinstall, ' "${os_installer_path}"; then missing_required_os_installer_argument='eraseinstall'; fi
						
						echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} This \"startosinstall\" Does Not Support the Required \"${missing_required_os_installer_argument}\" Argument${CLEAR_ANSI}\n"
						"${os_installer_path}" --usage
					fi
					
					echo -e '\n'
				else
					echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} \"${install_volume_path}\" Did Not Mount After Erasing ${install_drive_name}${CLEAR_ANSI}\n\n"
				fi
			elif [[ "${install_drive_name}" == 'ERROR-FORMATTING-DRIVE' ]]; then
				echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to Format Drive After 3 Attempts${CLEAR_ANSI}\n\n"

				'/System/Applications/Utilities/Disk Utility.app/Contents/MacOS/Disk Utility' &> /dev/null & disown # Launch Disk Utility to be able to see what's going on with the drive.
			else
				echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unknown Error During Install Drive Selection${CLEAR_ANSI}\n\n"
			fi
		fi
	else
		echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required \"startosinstall\" Not Found in Any Standard Location${CLEAR_ANSI}\n\n"
	fi
else
	echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} No Installable Drives Detected${CLEAR_ANSI}\n\n"
fi

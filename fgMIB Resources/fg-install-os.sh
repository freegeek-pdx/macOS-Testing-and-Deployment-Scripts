#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

readonly SCRIPT_VERSION='2023.2.16-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

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

if [[ ! -d '/System/Installation' || -f '/usr/bin/pico' ]]; then # The specified folder should exist in recoveryOS and the file should not.
	>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} \"fg-install-os\" can ONLY be run within recoveryOS.${CLEAR_ANSI}\n\n"
	exit 1
fi

current_process_list="$(ps -ax)" # Must use "ps -ax" output to check for running processes since "pgrep" is not available in recoveryOS.

if (( $(echo "${current_process_list}" | grep -ci '[f]g-install-os') > 1 )); then # https://mywiki.wooledge.org/ProcessManagement#But_I.27m_on_some_old_legacy_Unix_system_that_doesn.27t_have_pgrep.21__What_do_I_do.3F
	>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Another \"fg-install-os\" process is already running.${CLEAR_ANSI}\n\n"
	exit 1
fi

if echo "${current_process_list}" | grep -qi '[s]tartosinstall\|[I]nstallAssistant'; then
	>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Another macOS installation process is already running.${CLEAR_ANSI}\n\n"
	exit 1
fi


install_log_path='/private/tmp/Install OS Log.txt'

write_to_log() {
	echo -e "$(date -v '-7H' '+%D %T')\t$1" >> "${install_log_path}" # Must manually adjust from UTC to PDT timezone (by subtracting 7 hours) since the "date" command in recoveryOS always outputs UTC and setting the TZ='PDT' environment variable doesn't work in recoveryOS.
}

write_to_log "Starting Install OS (version ${SCRIPT_VERSION} / recoveryOS $(sw_vers -productVersion))"

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

BOOTED_BUILD_VERSION="$(sw_vers -buildVersion)"
readonly BOOTED_BUILD_VERSION
BOOTED_DARWIN_MAJOR_VERSION="$(echo "${BOOTED_BUILD_VERSION}" | cut -c -2 | tr -dc '[:digit:]')" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc. ("uname -r" is not available in recoveryOS).
readonly BOOTED_DARWIN_MAJOR_VERSION

pmset -a sleep 0 displaysleep 0 # Disable sleep in recoveryOS.

os_specific_extra_bins="${SCRIPT_DIR}/extra-bins/darwin-${BOOTED_DARWIN_MAJOR_VERSION}" # extra-bins must be OS specific because stuff like "networksetup" can fail on the wrong OS.

if [[ ! -d "${os_specific_extra_bins}" ]]; then
	# If the exact OS specific extra-bins folder doesn't exist, use the oldest or newest one available depending on if the running OS is older or newer than those.
	os_specific_extra_bins=''
	all_os_specific_extra_bins="$(find "${SCRIPT_DIR}/extra-bins" -maxdepth 1 -type d -name 'darwin-*' 2> /dev/null | sort)"
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

FG_MIB_HEADER="
  ${ANSI_PURPLE}${ANSI_BOLD}fgMIB:${ANSI_PURPLE} Free Geek - Mac Install Buddy ${ANSI_GREY}(${SCRIPT_VERSION} / recoveryOS $(sw_vers -productVersion))${CLEAR_ANSI}

"
readonly FG_MIB_HEADER

ansi_clear_screen() {
	# "clear" command is not available in recoveryOS, so instead of including it in extra-bins, use ANSI escape codes to clear the screen.
	# H = reset cursor to 0,0
	# 2J = clear screen (some documentation says this should also set to 0,0 but it does not in macOS)
	printf '%b' '\033[H\033[2J'
}

trim_and_squeeze_whitespace() {
	{ [[ "$#" -eq 0 && ! -t 0 ]] && cat - || printf '%s ' "$@"; } | tr -s '[:space:]' ' ' | sed -E 's/^ | $//g'
	# NOTE 1: Must only read stdin when NO arguments are passed because if this function is called with arguments but is within a block that
	# has another stdin piped or redirected to it, (such as a "while read" loop) the function will detect the stdin from the block and read
	# it instead of the arguments being passed which results in the function reading the wrong input as well as ending the loop prematurely.
	# NOTE 2: When multiple arguments are passed, DO NOT use "$*" since that would join on current "IFS" which may not be default which means
	# space may not be the first character and could instead be some non-whitespace character that would not be properly trimmed and squeezed.
	# Instead, use "printf" to manually join all arguments with a space (which will leave a trailing space, but that will get trimmed anyways).
	# NOTE 3: After "tr -s" there could still be a single leading and/or trailing space, so use "sed" to remove them.
}

strip_ansi_styles() {
	# The ANSI styles mess up grepping, comparing, and getting string length, so strip them when needed.
	# From: https://superuser.com/questions/380772/removing-ansi-color-codes-from-text-stream#comment2323889_380778
	printf '%b' "$1" | sed $'s/\x1b\[[0-9;]*m//g'
}

# Use "sysctl" instead of "system_profiler" because "system_profiler" is not available in recoveryOS.
MODEL_ID="$(sysctl -n hw.model 2> /dev/null)"
if [[ -z "${MODEL_ID}" ]]; then MODEL_ID='UNKNOWN Model Identifier'; fi
readonly MODEL_ID

readonly MODEL_ID_NAME="${MODEL_ID//[0-9,]/}" # Need use this whenever comparing along with Model ID numbers since there could be false matches for the newer "MacXX,Y" style Model IDs if I used SHORT_MODEL_NAME in those conditions instead (which I used to do).
readonly MODEL_ID_NUMBER="${MODEL_ID//[^0-9,]/}"

HAS_T2_CHIP="$([[ "$1" == 'debugT2' || -n "$(ioreg -rc AppleUSBDevice -n 'Apple T2 Controller' -d 1)" ]] && echo 'true' || echo 'false')"
if $HAS_T2_CHIP && [[ "$1" == 'debugNoT2' ]]; then HAS_T2_CHIP=false; fi
readonly HAS_T2_CHIP

IS_APPLE_SILICON="$([[ "$1" == 'debugAS' || "$(sysctl -in hw.optional.arm64)" == '1' ]] && echo 'true' || echo 'false')"
if $IS_APPLE_SILICON && [[ "$1" == 'debugNoAS' ]]; then IS_APPLE_SILICON=false; fi
readonly IS_APPLE_SILICON

MODEL_PART_NUMBER=''
if $HAS_T2_CHIP || $IS_APPLE_SILICON; then # This "M####LL/A" style Model Part Number is only be accessible in software on T2 and Apple Silicon Macs.
	MODEL_PART_NUMBER="$(/usr/libexec/remotectl dumpstate | awk '($1 == "RegionInfo") { if ($NF == "=>") { region_info = "LL/A" } else { region_info = $NF } } ($1 == "ModelNumber") { print $NF region_info; exit }')" # I have seen a T2 Mac without any "RegionInfo" specified, so just assume "LL/A" (USA) in that case.
fi
readonly MODEL_PART_NUMBER

APPLE_SILICON_MARKETING_MODEL_NAME=''
if $IS_APPLE_SILICON; then # This local Marketing Model Name within "ioreg" only exists on Apple Silicon Macs.
	APPLE_SILICON_MARKETING_MODEL_NAME="$(PlistBuddy -c 'Print :0:product-name' /dev/stdin <<< "$(ioreg -arc IOPlatformDevice -k product-name)" 2> /dev/null | tr -d '[:cntrl:]')" # Remove control characters because this decoded value could end with a NUL char.
fi
readonly APPLE_SILICON_MARKETING_MODEL_NAME

SHORT_MODEL_NAME="${MODEL_ID_NAME}" # Must turn Model Identifier Name (or Marketing Model Name) into the Short Model Name since "system_profiler" is not available to retrieve it directly in recoveryOS.
if [[ "${MODEL_ID_NAME}" == 'Mac' && -n "${APPLE_SILICON_MARKETING_MODEL_NAME}" ]]; then
	# Starting with the Mac Studio, all new models now only have a "MacXX,Y" style Model Identifier (with only "Mac" and without the specific model as part of the Model Identifier such as "MacBookProXX,Y").
	# References: https://twitter.com/khronokernel/status/1501315940260016133 & https://mobile.twitter.com/khronokernel/status/1501411685482958853 & https://twitter.com/ClassicII_MrMac/status/1506146498198835206 & https://twitter.com/ClassicII_MrMac/status/1534296010020855808
	# So, to get the short model name, we must extract it from the full Marketing Model Name (retreived from "ioreg" since this only affects Apple Silicon Macs) by extracting the first part up to " (".
	SHORT_MODEL_NAME="$(echo "${APPLE_SILICON_MARKETING_MODEL_NAME}" | awk -F ' [(]' '{ print $1; exit }')"
else # When the specific model is part of the Model Identifier (on Intel and early Apple Silicon Macs), we can create it by just separating one of these suffixes in the textual part of the Model Identifier with a space.
	for this_short_model_name_end_component in 'Pro' 'Air' 'mini'; do # These are the only suffixes that will ever exist in this condition since the Mac Studio and and possible future models will be Apple Silicon Macs with "MacXX,Y" Model IDs that will be caught in the condition above.
		if [[ "${SHORT_MODEL_NAME}" == *"${this_short_model_name_end_component}" ]]; then
			SHORT_MODEL_NAME="${SHORT_MODEL_NAME/${this_short_model_name_end_component}/ ${this_short_model_name_end_component}}"
			break
		fi
	done
fi
readonly SHORT_MODEL_NAME

model_name="${SHORT_MODEL_NAME} ${MODEL_ID_NUMBER}"

SERIAL="$(PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null | trim_and_squeeze_whitespace)"
readonly SERIAL
readonly SPECS_SERIAL="${ANSI_BOLD}Serial:${CLEAR_ANSI} ${SERIAL}"

cpu_model="$(sysctl -n machdep.cpu.brand_string 2> /dev/null)"

for this_cpu_model_removal_components in 'Genuine' 'Intel' '(R)' '(TM)' 'CPU' 'processor'; do
	cpu_model="${cpu_model//${this_cpu_model_removal_components}/ }"
done

if [[ "${cpu_model}" == *'0GHz'* ]]; then
	cpu_model="${cpu_model//0GHz/ GHz}"
else
	cpu_model="${cpu_model//GHz/ GHz}"
fi

cpu_model="$(trim_and_squeeze_whitespace "${cpu_model}")"

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

readonly SPECS_RAM="${ANSI_BOLD}RAM:${CLEAR_ANSI} $(( $(sysctl -n hw.memsize 2> /dev/null) / 1024 / 1024 / 1024 )) GB"

specs_overview=''
did_load_marketing_model_name=false

load_specs_overview() {
	if ! $did_load_marketing_model_name; then
		local marketing_model_name

		if $IS_APPLE_SILICON; then
			marketing_model_name="${APPLE_SILICON_MARKETING_MODEL_NAME}"
		elif (( ${#SERIAL} >= 11 )); then
			# The model part of the Serial Number is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials
			# (which are very old and shouldn't actually be encountered: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/).
			# Starting with the 2021 MacBook Pro models, randomized 10 character Serial Numbers are now used which do not have any model specific characters, but those Macs will
			# never get here or need to load the Marketing Model Name over the internet since they are Apple Silicon and the local Marketing Model Name will have been retrieved above.
			local model_characters_of_serial_number="${SERIAL:8}"

			if [[ -z "${marketing_model_name}" ]]; then
				local marketing_model_name_xml
				marketing_model_name_xml="$(curl -m 5 -sfL "https://support-sp.apple.com/sp/product?cc=${model_characters_of_serial_number}" 2> /dev/null)"

				if [[ -n "${marketing_model_name_xml}" ]]; then
					possible_marketing_model_name="$(echo "${marketing_model_name_xml}" | awk -F '<configCode>|</configCode>' '/<configCode>/ { print $2; exit }')" # "xmllint" doesn't exist in recoveryOS, so just use "awk" instead.

					if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" == "${SHORT_MODEL_NAME}"* ]]; then
						marketing_model_name="${possible_marketing_model_name}"
					fi
				fi
			fi
		else
			model_name+=' (Invalid Serial Number for Marketing Model Name)'
			did_load_marketing_model_name=true # Do not keep trying for an invalid Serial Number.
		fi

		if [[ -n "${marketing_model_name}" ]]; then
			if [[ "${marketing_model_name}" == "${SHORT_MODEL_NAME}" ]]; then
				model_name+=' (No Marketing Model Name Specified)'
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
		if [[ -n "${MODEL_PART_NUMBER}" ]]; then
			specs_model+=" / ${MODEL_PART_NUMBER}"
		fi

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

		local window_width="${COLUMNS:-80}" # "COLUMNS" seems to be set in the Terminal, but is NOT set when retrieved in this script.
		# Seems like maybe "shopt -s checkwinsize" needs to set for the script to be able to read "COLUMNS", but I couldn't get that to work.
		# Also, "tput" doesn't exist in recoveryOS, so can't use that instead. So, the default of "80" will just always be used as the window width.

		if (( ${#specs_overview_line_one_no_ansi} > window_width )); then
			specs_overview_line_one="    ${specs_model}"
			specs_overview_line_two="      ${SPECS_CPU}  ${SPECS_RAM}  ${SPECS_SERIAL}"
			specs_overview_line_two_no_ansi="$(strip_ansi_styles "${specs_overview_line_two}")"
			if (( ${#specs_overview_line_two_no_ansi} > window_width )); then
				specs_overview_line_two="      ${SPECS_CPU}
      ${SPECS_RAM}  ${SPECS_SERIAL}"
			fi
		elif (( ${#specs_overview_line_two_no_ansi} > window_width )); then
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

	until pmset -g ps | grep -q "'AC Power'$"; do
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
	# Have to manually retrieve correct date/time and use the "date" command to set time in recoveryOS: https://www.alansiu.net/2020/08/05/setting-the-date-time-in-macos-10-14-recovery-mode/
	local actual_date_time
	actual_date_time="$(curl -m 5 -sfL 'http://worldtimeapi.org/api/ip.txt' 2> /dev/null | awk -F ': ' '($1 == "utc_datetime") { print $NF; exit }')" # Time gets set as UTC when using "date" command in recoveryOS.
	# Always use "http" even though "https" could be used on macOS 10.12 Sierra and older or macOS 10.15 Catalina and newer since "libcurl" supports "https" on those versions,
	# while "libcurl" doesn't support "https" macOS 10.13 High Sierra and macOS 10.14 Mojave for some reason (it's odd that older versions do support it though).
	# Regardless, "http" is always used since this is to set the correct date and time and if the date is too far in the past "https" will fail anyways while "http" never will.

	if [[ -n "${actual_date_time}" ]]; then
		date "${actual_date_time:5:2}${actual_date_time:8:2}${actual_date_time:11:2}${actual_date_time:14:2}${actual_date_time:2:2}.${actual_date_time:17:2}" &> /dev/null
		write_to_log 'Set Date From Internet'
	fi
}

set_date_time_and_prompt_for_internet_if_year_not_correct() {
	actual_current_year="${SCRIPT_VERSION%%.*}" # Get the actual current year from the script version so it's always up-to-date.

	if (( $(date '+%Y') < actual_current_year )); then
		set_date_time_from_internet

		while (( $(date '+%Y') < actual_current_year )); do
			load_specs_overview
			ansi_clear_screen
			echo -e "${FG_MIB_HEADER}${specs_overview}

  ${ANSI_UNDERLINE}Internet Required to Set Date:${CLEAR_ANSI}

    ${ANSI_YELLOW}${ANSI_BOLD}The system date is incorrectly set to $(date | trim_and_squeeze_whitespace).${CLEAR_ANSI}

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
		should_clear_nvram="$(! $IS_APPLE_SILICON || [[ "${BOOTED_BUILD_VERSION}" > '20E' ]] && echo 'true' || echo 'false')"
	fi

	# DO NOT reset SIP on Apple Silicon since "csrutil clear" required an "admin user authorized for recovery" (assuming that means Secure Token/Volume Owner), which we won't ever have on a clean install.
	# And if "Erase Mac" has been run before starting a new installation, "csrutil clear" will not be able to do anything anyway and will just output "No macOS installations found".
	local should_reset_sip
	should_reset_sip="$(! $IS_APPLE_SILICON && echo 'true' || echo 'false')"

	if $should_clear_nvram || $should_reset_sip; then
		echo -e "\n  ${ANSI_CYAN}${ANSI_BOLD}$($should_clear_nvram && echo "Clearing ${ANSI_UNDERLINE}NVRAM")$($should_clear_nvram && $should_reset_sip && echo "${ANSI_CYAN}${ANSI_BOLD} & ")$($should_reset_sip && echo "Resetting ${ANSI_UNDERLINE}SIP")${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}\n"

		if $should_clear_nvram; then
			nvram_output="$(nvram -c && echo 'Successfully cleared NVRAM.' || echo "Failed to clear all of NVRAM, but that's not an issue.")"

			echo "${nvram_output}"
			write_to_log "Clear NVRAM: ${nvram_output}"
		fi

		if $should_reset_sip; then
			csrutil_output="$(csrutil clear 2>&1)"
			csrutil_output="${csrutil_output//. /.$'\n'}" # Put each sentence on it's own line, which is how macOS 11 Big Sur will display lines but previous versions put all sentences on one line which doesn't look as good.

			# Get rid of the "restart the machine" sentence since we will be rebooting after installation and don't want a technician to think they need to reboot manually which would interrupt the install.
			csrutil_output="${csrutil_output/$'\n'Please restart the machine for the changes to take effect./}" # This one is for macOS 10.15 Catalina and older.
			csrutil_output="${csrutil_output/$'\n'Restart the machine for the changes to take effect./}" # This one is for macOS 11 Big Sur and newer.

			echo "${csrutil_output}"
			write_to_log "Reset SIP: ${csrutil_output//$'\n'/ }"
		fi
	fi
}

copy_customization_resources() {
	local install_volume_path="$1"
	if [[ -d "${install_volume_path}" ]]; then
		local customization_resources_install_path="${install_volume_path}/Users/Shared/fg-customization-resources"
		rm -rf "${customization_resources_install_path}"

		if ditto "${SCRIPT_DIR}/customization-resources" "${customization_resources_install_path}"; then
			chmod +x "${customization_resources_install_path}/fg-install-packages.sh"

			PlistBuddy \
				-c 'Add :Label string org.freegeek.fg-install-packages' \
				-c 'Add :Program string /Users/Shared/fg-customization-resources/fg-install-packages.sh' \
				-c 'Add :RunAtLoad bool true' \
				-c 'Add :StandardOutPath string /dev/null' \
				-c 'Add :StandardErrorPath string /dev/null' \
				"${install_volume_path}/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist" &> /dev/null

			if [[ -f "${install_volume_path}/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist" && -d "${customization_resources_install_path}" ]]; then
				touch "${install_volume_path}/private/var/db/.AppleSetupDone"
				chown 0:0 "${install_volume_path}/private/var/db/.AppleSetupDone" "${install_volume_path}/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist" # Make sure these files are properly owned by root:wheel after installation.

				write_to_log 'Copied Customization Resources'

				return 0
			fi
		fi
	fi

	return 1
}

create_custom_global_tcc_database() {
	local global_tcc_folder_path="$1"
	local installed_os_darwin_major_version="$2"
	if [[ -d "${global_tcc_folder_path}" && -n "${installed_os_darwin_major_version}" ]]; then
		local global_tcc_database_path="${global_tcc_folder_path}/TCC.db"
		rm -rf "${global_tcc_database_path}" # If we are customizing a clean install, just delete any existing TCC.db to be sure there are no possible conflicts with the new one we are creating.

		# CREATE GLOBAL TCC DATABASE WITH FREE GEEK APP PRE-APPROVED FOR FULL DISK ACCESS AND AUTOMATION PERMISSIONS
		# The following TCC.db structures were created by running "sqlite3 '/Library/Application Support/com.apple.TCC/TCC.db' '.dump'" in Terminal will Full Disk Access (which is required to read this SIP protected file).
		# There is a lot more detail about this database format and each field (especially the "csreq" field) at: https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive
		# This setup must be done from within recoveryOS since this location will be protected by SIP when the macOS installation is finished and running.
		# Even if an app has Full Disk Access, it cannot modify SIP protected locations (but FDA does allow apps to *read* SIP protected locations).
		# The *global* TCC database stores Full Disk Access (kTCCServiceSystemPolicyAllFiles) and Accessibility (kTCCServiceAccessibility) permissions (and other permissions but those are the only ones that we are using).
		# The other TCC permissions that the Free Geek apps need, such as Automation/AppleEvents (kTCCServiceAppleEvents) and Microphone (kTCCServiceMicrophone), are stored in the *user* TCC database and are per-user settings.
		# The *user* TCC database is protected be TCC itself, not SIP, which means that an app with Full Disk Access can directly edit the *user* TCC database.
		# Therefore, when we pre-approve an app with Full Disk Access here, that app can then add the required *user* TCC permissions when it runs for that user upon login.
		# NOTE: When we are erasing the disk and doing a clean install (rather than just customizing an existing clean install), we are using the "UPGRADE/RE-INSTALL TRICK" to make this custom TCC.db file be preserved during the installation process and adopted by the installed OS.

		local create_global_tcc_db_commands='PRAGMA foreign_keys=OFF;'
		create_global_tcc_db_commands+='BEGIN TRANSACTION;'
		create_global_tcc_db_commands+='CREATE TABLE admin (key TEXT PRIMARY KEY NOT NULL, value INTEGER NOT NULL);'
		create_global_tcc_db_commands+='CREATE TABLE policies (id INTEGER NOT NULL PRIMARY KEY, bundle_id TEXT NOT NULL, uuid TEXT NOT NULL, display TEXT NOT NULL, UNIQUE (bundle_id, uuid));'
		create_global_tcc_db_commands+='CREATE TABLE active_policy (client TEXT NOT NULL, client_type INTEGER NOT NULL, policy_id INTEGER NOT NULL, PRIMARY KEY (client, client_type), FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);'
		create_global_tcc_db_commands+='CREATE TABLE access_overrides (service TEXT NOT NULL PRIMARY KEY);'
		create_global_tcc_db_commands+='CREATE INDEX active_policy_id ON active_policy(policy_id);'

		if (( installed_os_darwin_major_version <= 17 )); then # This "access_times" table was removed after in macOS 10.13 High Sierra.
			create_global_tcc_db_commands+='CREATE TABLE access_times (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, last_used_time INTEGER NOT NULL, policy_id INTEGER, PRIMARY KEY (service, client, client_type), FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);' # This table was totally removed after macOS 10.13 High Sierra.
		else # This "expired" table was added in macOS 10.14 Mojave.
			create_global_tcc_db_commands+="CREATE TABLE expired (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, csreq BLOB, last_modified INTEGER NOT NULL, expired_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)), PRIMARY KEY (service, client, client_type));"
		fi

		# It's safe to always use INSERT instead of REPLACE for the following rows since the TCC.db file will always be getting created (either it never existed since there is no OS yet, or it was deleted from the existing OS at the beginning of the function).

		local allowed_or_authorized_fields='1'
		local footer_fields='NULL'

		if (( installed_os_darwin_major_version <= 17 )); then # This is version and table structure in macOS 10.13 High Sierra (didn't bother checking older versions since we don't install any older, but TCC was introduced in macOS 10.9 Mavericks so there probably are prior versions).
			create_global_tcc_db_commands+="INSERT INTO admin VALUES('version',9);"
			create_global_tcc_db_commands+='CREATE TABLE access (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, allowed INTEGER NOT NULL, prompt_count INTEGER NOT NULL, csreq BLOB, policy_id INTEGER, PRIMARY KEY (service, client, client_type), FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);'
		elif (( installed_os_darwin_major_version <= 19 )); then # The following is the version and table structure for macOS 10.14 Mojave and macOS 10.15 Catalina.
			create_global_tcc_db_commands+="INSERT INTO admin VALUES('version',15);"
			create_global_tcc_db_commands+="CREATE TABLE access (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, allowed INTEGER NOT NULL, prompt_count INTEGER NOT NULL, csreq BLOB, policy_id INTEGER, indirect_object_identifier_type INTEGER, indirect_object_identifier TEXT, indirect_object_code_identity BLOB, flags INTEGER, last_modified INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)), PRIMARY KEY (service, client, client_type, indirect_object_identifier), FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);"

			footer_fields="NULL,NULL,'UNUSED',NULL,0,$(date '+%s')"
		else # The following is the versions and table structure for macOS 11 Big Sur and newer.
			if (( installed_os_darwin_major_version >= 22 )); then # The TCC.db version was changed in macOS 13 Ventura, but the table structure is the same as before.
				create_global_tcc_db_commands+="INSERT INTO admin VALUES('version',22);"
			else
				create_global_tcc_db_commands+="INSERT INTO admin VALUES('version',20);"
			fi
			create_global_tcc_db_commands+="CREATE TABLE access (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, auth_value INTEGER NOT NULL, auth_reason INTEGER NOT NULL, auth_version INTEGER NOT NULL, csreq BLOB, policy_id INTEGER, indirect_object_identifier_type INTEGER, indirect_object_identifier TEXT NOT NULL DEFAULT 'UNUSED', indirect_object_code_identity BLOB, flags INTEGER, last_modified INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)), PRIMARY KEY (service, client, client_type, indirect_object_identifier), FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);"

			allowed_or_authorized_fields='2,4'
			footer_fields="NULL,0,'UNUSED',NULL,0,$(date '+%s')"
		fi

		# The following csreq (Code Signing Requirement) hex strings were generated by the "generate_csreq_hex_for_tcc_db.jxa" script in the "Other Scripts" folder.
		# See comments in the "generate_csreq_hex_for_tcc_db.jxa" script for some important detailed information about these csreq hex strings (and https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
		# Including the csreq for the client seems to NOT actually be required when initially setting the TCC permissions and macOS will fill them out when the app launches for the first time.
		# But, that would reduce security by allowing any app that's first to launch with the specified Bundle Identifier to be granted the specified TCC permissions (even though fraudulent apps spoofing our Bundle IDs isn't a risk in our environment).
		local csreq_for_free_geek_setup_app='fade0c00000000a80000000100000006000000020000001c6f72672e667265656765656b2e467265652d4765656b2d5365747570000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000'
		local csreq_for_free_geek_demo_helper_app='fade0c00000000b0000000010000000600000002000000226f72672e667265656765656b2e467265652d4765656b2d44656d6f2d48656c7065720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000'
		local csreq_for_cleanup_after_qa_complete_app='fade0c00000000b4000000010000000600000002000000266f72672e667265656765656b2e436c65616e75702d41667465722d51412d436f6d706c6574650000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000'
		local csreq_for_free_geek_snapshot_helper_app='fade0c00000000b4000000010000000600000002000000266f72672e667265656765656b2e467265652d4765656b2d536e617073686f742d48656c7065720000000000060000000f000000060000000e000000010000000a2a864886f76364060206000000000000000000060000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a595257364e55474136330000'
		local csreq_for_keyboard_clean_tool_app='fade0c00000000cc0000000100000006000000060000000f000000020000001f636f6d2e686567656e626572672e4b6579626f617264436c65616e546f6f6c00000000070000000e000000000000000a2a864886f7636406010900000000000000000006000000060000000e000000010000000a2a864886f763640602060000000000000000000e000000000000000a2a864886f7636406010d0000000000000000000b000000000000000a7375626a6563742e4f550000000000010000000a4441465653585a3832500000'

		create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceAccessibility','org.freegeek.Free-Geek-Setup',0,${allowed_or_authorized_fields},1,X'${csreq_for_free_geek_setup_app}',${footer_fields});"
		create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceAccessibility','org.freegeek.Free-Geek-Demo-Helper',0,${allowed_or_authorized_fields},1,X'${csreq_for_free_geek_demo_helper_app}',${footer_fields});"
		create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceAccessibility','org.freegeek.Cleanup-After-QA-Complete',0,${allowed_or_authorized_fields},1,X'${csreq_for_cleanup_after_qa_complete_app}',${footer_fields});"
		create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceAccessibility','com.hegenberg.KeyboardCleanTool',0,${allowed_or_authorized_fields},1,X'${csreq_for_keyboard_clean_tool_app}',${footer_fields});"

		if (( installed_os_darwin_major_version >= 18 )); then # Full Disk Access was introduced in macOS 10.14 Mojave
			create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceSystemPolicyAllFiles','org.freegeek.Free-Geek-Setup',0,${allowed_or_authorized_fields},1,X'${csreq_for_free_geek_setup_app}',${footer_fields});" # Free Geek Setup needs FDA since it confirms all of these Global TCC permissions got set correctly AND grants all apps their required User TCC permissions at first login.
			create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceSystemPolicyAllFiles','org.freegeek.Free-Geek-Demo-Helper',0,${allowed_or_authorized_fields},1,X'${csreq_for_free_geek_demo_helper_app}',${footer_fields});" # Free Geek Demo Helper just has FDA so that it can explicitly confirm all it's own TCC permissions are correct instead of needing to do implicit checks/prompts.
			create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceSystemPolicyAllFiles','org.freegeek.Cleanup-After-QA-Complete',0,${allowed_or_authorized_fields},1,X'${csreq_for_cleanup_after_qa_complete_app}',${footer_fields});" # Cleanup After QA Complete just has FDA so that it can explicitly confirm all it's own TCC permissions are correct instead of needing to do implicit checks/prompts.

			if (( installed_os_darwin_major_version >= 20 )); then
				# "Free Geek Snapshot Helper" is only used to mount the reset Snapshot (which requires Full Disk Access) on macOS 11 Big Sur and newer, since mounting the Snapshot on macOS 10.15 Catalina does not help (see CAVEAT notes in "fg-snapshot-preserver" script).
				# But, it is still installed on macOS 10.15 Catalina to be used as an alert GUI if the reset Snapshot is lost, and no reset Snapshot is created on macOS 10.14 Mojave and older (where the "fgreset" script is used instead) so it is not installed at all on those versions.
				create_global_tcc_db_commands+="INSERT INTO access VALUES('kTCCServiceSystemPolicyAllFiles','org.freegeek.Free-Geek-Snapshot-Helper',0,${allowed_or_authorized_fields},1,X'${csreq_for_free_geek_snapshot_helper_app}',${footer_fields});"
			fi
		fi

		create_global_tcc_db_commands+='COMMIT;'

		if echo "${create_global_tcc_db_commands}" | sqlite3 "${global_tcc_database_path}"; then
			chown 0:0 "${global_tcc_database_path}" # Make sure this file gets properly owned by root:wheel after installation.

			write_to_log 'Created Custom Global TCC Database'

			return 0
		fi
	fi

	return 1
}

readonly GLOBAL_INSTALL_NOTES_HEADER="  ${ANSI_UNDERLINE}Installation Notes:${CLEAR_ANSI}\n"
global_install_notes=''

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

while read -ra this_network_hardware_ports_line_elements; do
	if [[ "${this_network_hardware_ports_line_elements[0]}" == 'Device:' ]] && getairportnetwork_output="$(networksetup -getairportnetwork "${this_network_hardware_ports_line_elements[1]}" 2> /dev/null)" && [[ "${getairportnetwork_output}" != *'disabled.' ]]; then
		if networksetup -getairportpower "${this_network_hardware_ports_line_elements[1]}" 2> /dev/null | grep -q '): Off$'; then
			networksetup -setairportpower "${this_network_hardware_ports_line_elements[1]}" on &> /dev/null
		fi
		networksetup -setairportnetwork "${this_network_hardware_ports_line_elements[1]}" "${wifi_ssid}" "${wifi_password}" &> /dev/null &
	fi
done < <(networksetup -listallhardwareports 2> /dev/null)

set_date_time_from_internet # Try to set correct date before doing anything else. If it fails, it will be re-attempted later and user will be prompted and required to connect to the internet if needed.


# DETECT CUSTOMIZATION PACKAGES

declare -a customization_packages=()
if $CLEAN_INSTALL_REQUESTED; then
	if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
	global_install_notes+="\n    - Clean installation will be peformed since \"$1\" argument has been used."
	write_to_log 'Chose to Perform Clean Installation'
else
	for this_customization_package_path in "${SCRIPT_DIR}/customization-resources/"*'.pkg'; do
		if [[ -f "${this_customization_package_path}" ]]; then
			customization_packages+=( "${this_customization_package_path}" )
			write_to_log "Detected Customization Package: ${this_customization_package_path##*/}"
		fi
	done
fi
customization_packages_count="${#customization_packages[@]}"

if ! $CLEAN_INSTALL_REQUESTED && (( customization_packages_count == 0 )) ; then
	if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
	global_install_notes+="\n    ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} No customization packages detected. Clean installation will be peformed.
    ${ANSI_RED}${ANSI_BOLD}!!! THIS SHOULD NOT HAVE HAPPENED !!!${ANSI_PURPLE} Please inform Free Geek I.T.${CLEAR_ANSI}"
	write_to_log 'WARNING: Clean Installation Will Be Peformed Because No Packages Detected - THIS SHOULD NOT HAVE HAPPENED'
fi


# DETECT INSTALLABLE DRIVES
# Will show any and all internal drives if in recoveryOS.
# Will only show boot drive if NOT in recoveryOS.

possible_disk_ids=''

if (( BOOTED_DARWIN_MAJOR_VERSION >= 17 )); then # If is macOS 10.13 High Sierra or newer.
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
declare -a fusion_drive_choices=()
install_drive_choices_display=''

declare -a install_drive_device_tree_paths=()

while IFS='' read -r this_disk_id; do
	this_disk_info_plist_path="$(mktemp -t 'fg_install_os-this_disk_info')"
	diskutil info -plist "${this_disk_id}" > "${this_disk_info_plist_path}"

	this_disk_is_valid_for_installation=true

	if [[ "$(PlistBuddy -c 'Print :Internal' "${this_disk_info_plist_path}" 2> /dev/null)" == 'false' ||
		"$(PlistBuddy -c 'Print :RemovableMediaOrExternalDevice' "${this_disk_info_plist_path}" 2> /dev/null)" == 'true' ]]; then # SD Cards will show as Internal=true and RemovableMediaOrExternalDevice=true unlike actual internal drives.
		this_disk_is_valid_for_installation=false
	fi

	if $this_disk_is_valid_for_installation &&
		[[ "$(PlistBuddy -c 'Print :ParentWholeDisk' "${this_disk_info_plist_path}" 2> /dev/null)" != "${this_disk_id}" ||
		"$(PlistBuddy -c 'Print :WholeDisk' "${this_disk_info_plist_path}" 2> /dev/null)" == 'false' ||
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

	if $this_disk_is_valid_for_installation; then
		this_disk_size_bytes="$(PlistBuddy -c 'Print :TotalSize' "${this_disk_info_plist_path}" 2> /dev/null)"
		this_disk_bus="$(PlistBuddy -c 'Print :BusProtocol' "${this_disk_info_plist_path}" 2> /dev/null)"

		this_disk_model="$(PlistBuddy -c 'Print :MediaName' "${this_disk_info_plist_path}" 2> /dev/null)"
		this_disk_model="$(trim_and_squeeze_whitespace "${this_disk_model//:/ }")" # Make sure Models never contain ':' since it's used as a delimiter and the model is only for display.

		this_drive_name="$([[ -z "${this_disk_size_bytes}" ]] && echo 'UNKNOWN Size' || echo "$(( this_disk_size_bytes / 1000 / 1000 / 1000 )) GB") ${this_disk_bus:-UNKNOWN Bus} $([[ "$(PlistBuddy -c 'Print :SolidState' "${this_disk_info_plist_path}" 2> /dev/null)" == 'true' ]] && echo 'SSD' || echo 'HDD') \"${this_disk_model:-UNKNOWN Model}\""

		install_drive_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}${this_disk_id}:${ANSI_PURPLE} ${this_drive_name}${CLEAR_ANSI}"

		install_drive_device_tree_paths+=( "${this_disk_device_tree_path}" )
		fusion_drive_choices+=( "${this_disk_id}" )

		if (( this_disk_size_bytes >= 59000000000 )); then
			# Only allow installation on at least at 60 GB drive (but actually check for at least 59 GB since byte sizes are not always precise).
			# This limit is set because anything below about 60 GB will quickly be big hassle for the customer to have enough free space to even be able to install updates.
			# But, smaller than 60 GB drives may be present (such as 32 GB or 24 GB) since they are intended to be used as part of a Fusion Drive.
			install_drive_choices+=( "${this_disk_id}" )
		else
			# If the drive is less that 60 GB (actually less than 59 GB), still display it so the technician knows it's present
			# in the system and so that it can be used in a Fusion Drive (hence it still being included in "fusion_drive_choices").
			# BUT, DO NOT include it in "install_drive_choices" to NOT allow it to be chosen for installation on its own for the reasons stated above.
			install_drive_choices_display+="\n      ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} Smaller Than 60 GB Minimum (But Can Be Used in Fusion Drive)${CLEAR_ANSI}"
		fi

		this_disk_smart_status="$(PlistBuddy -c 'Print :SMARTStatus' "${this_disk_info_plist_path}" 2> /dev/null)"
		if [[ "${this_disk_smart_status}" != 'Verified' ]]; then
			install_drive_choices_display+="\n      ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} SMART Status = ${ANSI_UNDERLINE}${this_disk_smart_status:-UNKNOWN}${CLEAR_ANSI}"
		fi
	fi

	rm -f "${this_disk_info_plist_path}"
done <<< "${possible_disk_ids}"


if (( ${#install_drive_choices[@]} == 0 )) || [[ -z "${install_drive_choices_display}" ]]; then
	>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} No Installable Drives Detected${CLEAR_ANSI}\n\n"
	write_to_log 'ERROR: No Installable Drives Detected'
	exit 1
fi

if diskutil 2>&1 | grep -q '^     resetFusion' && (( ${#fusion_drive_choices[@]} == 2 )); then

	# CHECK IF CAN CREATE FUSION DRIVE AND ADD TO "install_drive_choices_display" IF SO (Doing this while "Detecting Drives" is still being displayed.)

	# "diskutil" supports the "resetFusion" argument on macOS 10.14 Mojave and newer.
	# Fusion Drives can be manually created on older versions of macOS, but it's too tedious to be worth since every Mac that shipped with a Fusion Drive supports macOS 10.14 Mojave and newer.
	# More Info: https://support.apple.com/HT207584

	internal_ssd_count="$(echo -e "${install_drive_choices_display}" | grep -c ' SSD "')"
	internal_hdd_count="$(echo -e "${install_drive_choices_display}" | grep -c ' HDD "')"

	if (( internal_ssd_count == 2 )) || (( internal_ssd_count == 1 && internal_hdd_count == 1 )); then
		install_drive_choices+=( 'diskF' )
		install_drive_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}diskF:${ANSI_PURPLE} Create Fusion Drive ${ANSI_YELLOW}(Will ${ANSI_BOLD}ERASE BOTH${ANSI_YELLOW} Internal Drives)${CLEAR_ANSI}"
	fi
fi


if ! $CLEAN_INSTALL_REQUESTED && (( customization_packages_count > 0 )) && [[ -f "${SCRIPT_DIR}/customization-resources/fg-install-packages.sh" ]]; then

	# DETECT CLEAN INSTALLATIONS AND OFFER TO CUSTOMIZE IF FOUND

	load_specs_overview
	ansi_clear_screen
	echo -e "${FG_MIB_HEADER}${specs_overview}\n\n  ${ANSI_CYAN}${ANSI_BOLD}Detecting Existing Clean Installations...${CLEAR_ANSI}"

	for this_disk_id in "${fusion_drive_choices[@]}"; do # Use "fusion_drive_choices" instead of "install_drive_choices" for this loop to mount all internal drives regardless of size, and to not need to ignore the fake "diskF" when a Fusion Drive could be created.
		if [[ -n "${this_disk_id}" ]]; then
			# Make sure all internal drives are mounted before checking for clean installations.
			diskutil mountDisk "${this_disk_id}" &> /dev/null

			# Mounting parent disk IDs appears to not mount the child APFS Container disk IDs, so check for those and mount them too.
			while read -ra this_disk_info_line_elements; do
				if [[ "${this_disk_info_line_elements[2]#[^[:alpha:]]}" == 'Container' && "${this_disk_info_line_elements[3]}" == 'disk'* ]]; then
					diskutil mountDisk "${this_disk_info_line_elements[3]%[^[:digit:]]}" &> /dev/null
					# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop,
					# so just parse the human readable output of a single "diskutil list" command instead since it's right there even though it's not necessarily future-proof to parse the human readable output.
					# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID as of macOS 11 Big Sur and newer, so they must be removed.
				fi
			done < <(diskutil list "${this_disk_id}")
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

				if [[ -d "${this_volume}/Users/Shared/fg-customization-resources" || -f "${this_volume}/private/var/db/dslocal_orig.cpgz" ]]; then
					# ALSO check for "dslocal_orig.cpgz" which indicates that a *customized installation* has been started via "startosinstall" but hasn't been finished yet since "dslocal_orig.cpgz" would be deleted when "fg-prepare-os.pkg" is installed at the end of the installation process.
					# "dslocal_orig.cpgz" existing at this point would only happen if someone (presumably accidentally) booted back into recoveryOS before a *customized installation* process had been finished.
					# Without this check, they could then choose to customize a "clean install" which is actually an unfinished *customized installation*.
					# If we do not catch this scenario, it would be possible for the LauchDaemon customizations to be prepared and run on an installation that will ALSO run the "startosinstall --installpackage" customizations which leaves the system in an
					# unexpected state where the first customizations to run work, but the second customizations fail and the system still boots to the Desktop and would only present the blocking error message on the NEXT reboot (which actually happened once).
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Already Prepared Customizations${CLEAR_ANSI}"
				elif [[ -f "${this_volume}/private/var/db/.AppleSetupDone" ]]; then
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Setup Assistant Already Completed${CLEAR_ANSI}"
				elif $this_volume_is_apfs && [[ "$(diskutil apfs listCryptoUsers "${this_volume}")" != 'No cryptographic users for disk'* ]]; then
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Secure Token User Exists${CLEAR_ANSI}"
				else
					existing_user_names="$(find "${this_volume}/private/var/db/dslocal/nodes/Default/users" \( -name '*.plist' -and ! -name 'daemon.plist' -and ! -name 'nobody.plist' -and ! -name 'root.plist' -and ! -name '_*.plist' \) | awk -F '/|[.]plist' '{ print $(NF-1) }' | sort)" # "-exec basename {} '.plist'" would be nicer than "awk", but "basename" doesn't exist in recoveryOS.

					if [[ -z "${existing_user_names}" ]]; then
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
							elif [[ "${this_volume_os_version}" == '13'* ]]; then
								this_volume_os_name="macOS ${this_volume_os_version} Ventura"
							fi

							# "fg-prepare-os" script is only made to support macOS 10.13 High Sierra and newer, so do not allow installation on any macOS version that is not named above.
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
									clean_install_choices+=( "${this_volume_os_name}:${this_volume_drive_name}:${this_volume}" )
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
						echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_volume}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Users Already Exist (${existing_user_names//$'\n'/, })${CLEAR_ANSI}"
					fi
				fi

				rm -f "${this_volume_info_plist_path}"
			fi
		fi
	done
fi

clean_install_to_customize_volume=''
clean_install_to_customize_os_name=''
clean_install_to_customize_drive_name=''

if (( ${#clean_install_choices[@]} > 0 )); then
	clean_install_choices_display+="\n\n    ${ANSI_PURPLE}${ANSI_BOLD}C:${ANSI_PURPLE} Continue Without Customizing Clean Installation${CLEAR_ANSI}"

	last_choose_clean_install_error=''
	until [[ -n "${clean_install_to_customize_volume}" ]]; do
		load_specs_overview
		ansi_clear_screen
		echo -e "${FG_MIB_HEADER}${specs_overview}"
		echo -e "\n  ${ANSI_UNDERLINE}Choose Clean Installation to Customize:${CLEAR_ANSI}${last_choose_clean_install_error}${clean_install_choices_display}"

		echo -en "\n  Enter the ${ANSI_BOLD}Index of Clean Installation${CLEAR_ANSI} to Customize (or ${ANSI_BOLD}\"C\" to Continue${CLEAR_ANSI}): "
		read -r chosen_clean_install_index

		if [[ "${chosen_clean_install_index}" =~ ^[Cc] ]]; then # Do not confirm continuing, just continue.
			break
		else
			chosen_clean_install_index="${chosen_clean_install_index//[^0-9]/}" # Remove all non-digits.
			if [[ "${chosen_clean_install_index}" == '0'* ]]; then
				chosen_clean_install_index="$(( 10#${chosen_clean_install_index} ))" # Remove any leading zeros (https://mywiki.wooledge.org/ArithmeticExpression#Pitfall:_Base_prefix_with_signed_numbers & https://github.com/koalaman/shellcheck/wiki/SC2004#rationale).
			fi
		fi

		if [[ -n "${chosen_clean_install_index}" ]] && (( chosen_clean_install_index < ${#clean_install_choices[@]} )); then
			IFS=':' read -rd '' possible_clean_install_os_name possible_clean_install_drive_name possible_clean_install_to_customize_volume < <(echo -n "${clean_install_choices[chosen_clean_install_index]}") # MUST to use "echo -n" and process substitution since a here-string would add a trailing line break that would be included in the last value (this allows line breaks to exist within the values, even though that is unlikely).

			echo -en "\n  Enter ${ANSI_BOLD}${chosen_clean_install_index}${CLEAR_ANSI} Again to Confirm Customizing ${ANSI_BOLD}${possible_clean_install_os_name}${CLEAR_ANSI}\n  at ${ANSI_BOLD}\"${possible_clean_install_to_customize_volume}\"${CLEAR_ANSI} on ${ANSI_BOLD}${possible_clean_install_drive_name}${CLEAR_ANSI}: "
			read -r confirmed_clean_install_index

			confirmed_clean_install_index="${confirmed_clean_install_index//[^0-9]/}" # Remove all non-digits.
			if [[ "${confirmed_clean_install_index}" == '0'* ]]; then
				confirmed_clean_install_index="$(( 10#${confirmed_clean_install_index} ))" # Remove any leading zeros (https://mywiki.wooledge.org/ArithmeticExpression#Pitfall:_Base_prefix_with_signed_numbers & https://github.com/koalaman/shellcheck/wiki/SC2004#rationale).
			fi

			if [[ "${chosen_clean_install_index}" == "${confirmed_clean_install_index}" ]]; then
				if [[ -d "${possible_clean_install_to_customize_volume}" ]]; then
					clean_install_to_customize_volume="${possible_clean_install_to_customize_volume}"
					clean_install_to_customize_os_name="${possible_clean_install_os_name}"
					clean_install_to_customize_drive_name="${possible_clean_install_drive_name}"
				else
					last_choose_clean_install_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Selected Clean Installation No Longer Exists ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${ANSI_RED}\n     ${ANSI_BOLD}PATH:${ANSI_RED} ${possible_clean_install_to_customize_volume}${CLEAR_ANSI}"
					write_to_log "ERROR: Selected Clean Installation (${possible_clean_install_to_customize_volume}) No Longer Exists"
				fi
			else
				last_choose_clean_install_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Did Not Confirm Index ${ANSI_BOLD}${chosen_clean_install_index}${ANSI_PURPLE} ${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
			fi
		elif [[ -n "${chosen_clean_install_index}" ]]; then
			last_choose_clean_install_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Index ${ANSI_BOLD}${chosen_clean_install_index}${ANSI_RED} Is Not a Valid Choice ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${CLEAR_ANSI}"
		else
			last_choose_clean_install_error=''
		fi
	done
fi

if [[ -n "${clean_install_to_customize_volume}" ]]; then
	if [[ ! -d "${clean_install_to_customize_volume}" || -z "${clean_install_to_customize_os_name}" || -z "${clean_install_to_customize_drive_name}" ]]; then
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unknown Error During Clean Installation Selection${CLEAR_ANSI}\n\n"
		write_to_log 'ERROR: Unknown Error During Clean Installation Selection'
		exit 1
	fi

	write_to_log "Chose to Customize Clean Installation of ${clean_install_to_customize_os_name} on ${clean_install_to_customize_drive_name}"


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

	echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Copying Customization Resources\n  Into ${ANSI_UNDERLINE}${clean_install_to_customize_os_name}${ANSI_CYAN}${ANSI_BOLD} at ${ANSI_UNDERLINE}\"${clean_install_to_customize_volume}\"${ANSI_CYAN}${ANSI_BOLD}\n  on ${ANSI_UNDERLINE}${clean_install_to_customize_drive_name}${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}"

	if copy_customization_resources "${clean_install_to_customize_volume}" && create_custom_global_tcc_database "${clean_install_to_customize_volume}/Library/Application Support/com.apple.TCC" "$(PlistBuddy -c 'Print :ProductBuildVersion' "${clean_install_to_customize_volume}/System/Library/CoreServices/SystemVersion.plist" 2> /dev/null | cut -c -2 | tr -dc '[:digit:]')"; then

		# Delete any existing Preferences, Caches, and Temporary Files (in case any Setup Assistant screens had been clicked through).
		rm -rf "${clean_install_to_customize_volume}/Library/Preferences/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/Library/Caches/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/System/Library/Caches/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/private/var/vm/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/private/var/folders/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/private/var/tmp/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/private/tmp/"{,.[^.],..?}* \
			"${clean_install_to_customize_volume}/.TemporaryItems/"{,.[^.],..?}* &> /dev/null

		write_to_log 'Successfully Copied Customization Resources and Prepared Customization'

		# Copy installation log onto install drive to save the record of the customization choices.
		if [[ -e "${clean_install_to_customize_volume}/Users/Shared/Build Info" ]]; then # If a previous "Build Info" folder exists from being preserved after running "fgreset" (but would not be preserved from Snapshot Reset), save it with a new name so that a new logs can be created.
			mv "${clean_install_to_customize_volume}/Users/Shared/Build Info" "${clean_install_to_customize_volume}/Users/Shared/Build Info - BEFORE $(date '+%s')"
		fi
		mkdir -p "${clean_install_to_customize_volume}/Users/Shared/Build Info"
		chown -R 502:20 "${clean_install_to_customize_volume}/Users/Shared/Build Info" # Want fg-demo to own the "Build Info" folder, but keep log owned by root.
		ditto "${install_log_path}" "${clean_install_to_customize_volume}/Users/Shared/Build Info/"

		echo -e "\n\n  ${ANSI_GREEN}${ANSI_BOLD}Successfully Copied Customization Resources and Prepared Customization\n\n  ${ANSI_GREY}${ANSI_BOLD}This Mac Will Reboot and Start Customizing in 10 Seconds...${CLEAR_ANSI}\n"

		sleep 10 # Sleep a bit so technician can see that customization resources were copied.

		shutdown -r now &> /dev/null

		echo -e '\n'
	else
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to Copy Customization Resources${CLEAR_ANSI}\n\n"
		write_to_log 'ERROR: Failed to Copy Customization Resources'
		exit 1
	fi

	exit 0
fi

# NOTICE: Script will END and REBOOT Mac in THE PREVIOUS BLOCK if technician chose to customize an existing clean installation.


# DETECT MACOS INSTALLERS

load_specs_overview
ansi_clear_screen
echo -e "${FG_MIB_HEADER}${specs_overview}\n\n  ${ANSI_CYAN}${ANSI_BOLD}Detecting macOS Installers...${CLEAR_ANSI}"

readonly MODEL_ID_MAJOR_NUMBER="${MODEL_ID_NUMBER%%,*}"
SUPPORTS_HIGH_SIERRA="$([[ ( "${MODEL_ID_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '10' ) || ( "${MODEL_ID_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'MacBookPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'MacBookAir' && "${MODEL_ID_MAJOR_NUMBER}" -ge '3' ) || ( "${MODEL_ID_NAME}" == 'Macmini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '4' ) || ( "${MODEL_ID_NAME}" == 'MacPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '5' ) || ( "${MODEL_ID_NAME}" == 'iMacPro' ) ]] && echo 'true' || echo 'false')"
readonly SUPPORTS_HIGH_SIERRA
SUPPORTS_CATALINA="$([[ ( "${MODEL_ID_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '13' ) || ( "${MODEL_ID_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '8' ) || ( "${MODEL_ID_NAME}" == 'MacBookPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '9' ) || ( "${MODEL_ID_NAME}" == 'MacBookAir' && "${MODEL_ID_MAJOR_NUMBER}" -ge '5' ) || ( "${MODEL_ID_NAME}" == 'Macmini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'MacPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'iMacPro' ) ]] && echo 'true' || echo 'false')"
readonly SUPPORTS_CATALINA # macOS 10.15 Catalina supports the same models as macOS 10.14 Mojave (except for the MacPro5,1 with a Metal-capable GPU which maxes out at Mojave and is not included in the "SUPPORTS_CATALINA" conditions and is only included in the "SUPPORTS_HIGH_SIERRA" conditions since MacPro5,1 and Mojave installations are handled specially when they are done).
SUPPORTS_BIG_SUR="$([[ ( "${MODEL_ID}" == 'iMac14,4' ) || ( "${MODEL_ID_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '15' ) || ( "${MODEL_ID_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '8' ) || ( "${MODEL_ID_NAME}" == 'MacBookPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '11' ) || ( "${MODEL_ID_NAME}" == 'MacBookAir' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'Macmini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${MODEL_ID_NAME}" == 'MacPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'iMacPro' ) ]] && echo 'true' || echo 'false')"
readonly SUPPORTS_BIG_SUR
SUPPORTS_MONTEREY="$([[ ( "${MODEL_ID_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '16' ) || ( "${MODEL_ID_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '9' ) || ( "${MODEL_ID}" == 'MacBookPro11,4' ) || ( "${MODEL_ID}" == 'MacBookPro11,5' ) || ( "${MODEL_ID_NAME}" == 'MacBookPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '12' ) || ( "${MODEL_ID_NAME}" == 'MacBookAir' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${MODEL_ID_NAME}" == 'Macmini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${MODEL_ID_NAME}" == 'MacPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '6' ) || ( "${MODEL_ID_NAME}" == 'iMacPro' ) || ( "${MODEL_ID_NAME}" == 'Mac' ) ]] && echo 'true' || echo 'false')"
readonly SUPPORTS_MONTEREY
SUPPORTS_VENTURA="$([[ ( "${MODEL_ID_NAME}" == 'iMac' && "${MODEL_ID_MAJOR_NUMBER}" -ge '18' ) || ( "${MODEL_ID_NAME}" == 'MacBook' && "${MODEL_ID_MAJOR_NUMBER}" -ge '10' ) || ( "${MODEL_ID_NAME}" == 'MacBookPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '14' ) || ( "${MODEL_ID_NAME}" == 'MacBookAir' && "${MODEL_ID_MAJOR_NUMBER}" -ge '8' ) || ( "${MODEL_ID_NAME}" == 'Macmini' && "${MODEL_ID_MAJOR_NUMBER}" -ge '8' ) || ( "${MODEL_ID_NAME}" == 'MacPro' && "${MODEL_ID_MAJOR_NUMBER}" -ge '7' ) || ( "${MODEL_ID_NAME}" == 'iMacPro' ) || ( "${MODEL_ID_NAME}" == 'Mac' ) ]] && echo 'true' || echo 'false')"
readonly SUPPORTS_VENTURA

declare -a os_installer_choices=()
os_installer_choices_display=''

declare -a stub_os_installers_info=()

for this_os_installer_search_group_prefixes in '/Volumes/Image ' '/Volumes/Install ' '/'; do # Always want installers in "Image Volume" to come before any other installers (which is for the booted installer in recoveryOS). Check any other available "Install macOS..." volumes. A stub installer will always be in the root filesystem in recoveryOS.
	declare -a this_os_installer_search_group_paths=()
	if [[ "${this_os_installer_search_group_prefixes}" != *'/' ]]; then
		this_os_installer_search_group_paths=( "${this_os_installer_search_group_prefixes}"*'/Install '*'.app/Contents/Resources/startosinstall' )
	else
		this_os_installer_search_group_paths=( "${this_os_installer_search_group_prefixes}Install "*'.app/Contents/Resources/startosinstall' )
	fi

	declare -a these_os_versions_and_installer_paths=()
	for this_os_installer_path in "${this_os_installer_search_group_paths[@]}"; do
		if [[ -f "${this_os_installer_path}" ]]; then
			this_os_installer_app_path="${this_os_installer_path%.app/*}.app"
			this_os_installer_darwin_major_version="$(PlistBuddy -c 'Print :DTSDKBuild' "${this_os_installer_app_path}/Contents/Info.plist" 2> /dev/null | cut -c -2 | tr -dc '[:digit:]')"
			if [[ -n "${this_os_installer_darwin_major_version}" ]] && (( this_os_installer_darwin_major_version >= 10 )); then
				if $IS_APPLE_SILICON && (( this_os_installer_darwin_major_version < 20 )); then
					# Do not allow Apple Silicon Mac to install macOS 10.15 Catalina and older since Apple Silicon support was introduced with macOS 11 Big Sur.
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} This macOS Version Is Not Supported on Apple Silicon Macs${CLEAR_ANSI}"
				elif $HAS_T2_CHIP && ! $CLEAN_INSTALL_REQUESTED && (( this_os_installer_darwin_major_version < 20 )); then
					# Do not allow T2 Macs to install macOS 10.15 Catalina and older (unless doing a clean install) since Secure Tokens cannot be prevented and cannot be removed
					# during Snapshot reset (on macOS 10.15 Catalina) and the last Secure Token admin can also not be removed by fgreset (on macOS 10.14 Mojave and older).
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Would Not Be Able to Peform Reset of This macOS Version on T2 Macs${CLEAR_ANSI}"
				elif ! $IS_APPLE_SILICON && (( this_os_installer_darwin_major_version < BOOTED_DARWIN_MAJOR_VERSION )); then # Do NOT disallow installing older versions of macOS when on Apple Silicon, since as of macOS 13 Ventura the latest Local recoveryOS still allows installing macOS 11 Big Sur and it is not possible to actually boot to older recoveryOS versions via USB.
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Older Than Running OS${CLEAR_ANSI}"
				else
					these_os_versions_and_installer_paths+=( "${this_os_installer_darwin_major_version}:${this_os_installer_path}" )
				fi
			else
				echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Invalid Darwin Version${CLEAR_ANSI}"
			fi
		fi
	done

	if (( ${#these_os_versions_and_installer_paths[@]} > 0 )); then
		is_first_os_installer_of_search_group=true

		while IFS=':' read -rd '' this_os_installer_darwin_major_version this_os_installer_path; do
			this_os_installer_usage_notes=''

			# NOTICE: For info about grepping the "startosinstall" binary contents to check for supported arguments
			# as well as OS support for each argument, refer to the "os_installer_options" code near the end of this script.

			if ! grep -qU -e '--installpackage, ' "${this_os_installer_path}"; then
				this_os_installer_usage_notes='Clean Install Only'
			fi

			this_os_installer_name="${this_os_installer_path%.app/*}"
			this_os_installer_app_path="${this_os_installer_name}.app"
			this_os_installer_name="${this_os_installer_name##*/Install }"
			this_os_installer_name="$(trim_and_squeeze_whitespace "${this_os_installer_name//:/ }")" # Make sure installer name never contain ':' since it's used as a delimiter and the installer name is only for display (this should never happen, but better safe than sorry).

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

			if [[ -f "${this_os_installer_app_path}/Contents/SharedSupport/SharedSupport.dmg" || -f "${this_os_installer_app_path}/Contents/SharedSupport/InstallESD.dmg" ]]; then
				# Full installer apps will contain "SharedSupport.dmg" (on macOS 11 Big Sur and newer) or "InstallESD.dmg" (on macOS 10.15 Catalina or older).

				if { ! $SUPPORTS_HIGH_SIERRA && [[ "${this_os_installer_name}" == *' High Sierra'* ]]; } ||
					{ ! $SUPPORTS_CATALINA && [[ "${this_os_installer_name}" == *' Mojave'* || "${this_os_installer_name}" == *' Catalina'* ]]; } || # See comments when "SUPPORTS_CATALINA" is set for Catalina/Mojave support information.
					{ ! $SUPPORTS_BIG_SUR && [[ "${this_os_installer_name}" == *' Big Sur'* ]]; } ||
					{ ! $SUPPORTS_MONTEREY && [[ "${this_os_installer_name}" == *' Monterey'* ]]; } ||
					{ ! $SUPPORTS_VENTURA && [[ "${this_os_installer_name}" == *' Ventura'* ]]; }; then
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Model Does Not Support ${this_os_installer_name}${CLEAR_ANSI}"
				elif [[ "$(strip_ansi_styles "${os_installer_choices_display}")" == *": ${this_os_installer_name}"* ]]; then
					echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}EXCLUDED:${ANSI_YELLOW} ${this_os_installer_app_path}\n      ${ANSI_BOLD}REASON:${ANSI_YELLOW} Duplicate Installer Already Added${CLEAR_ANSI}"
				else
					if $is_first_os_installer_of_search_group; then
						os_installer_choices_display+=$'\n'
						is_first_os_installer_of_search_group=false
					fi

					os_installer_choices_display+="\n    ${ANSI_PURPLE}${ANSI_BOLD}${#os_installer_choices[@]}:${ANSI_PURPLE} ${this_os_installer_name}${CLEAR_ANSI}"

					if [[ -n "${this_os_installer_usage_notes}" ]]; then
						os_installer_choices_display+=" (${this_os_installer_usage_notes})"
					fi

					os_installer_choices+=( "${this_os_installer_path}" )
				fi
			else
				# Stub installers (which will download the full installer from the internet) will not have "SharedSupport.dmg" or "InstallESD.dmg" but WILL HAVE "startosinstall".

				if [[ -n "${this_os_installer_usage_notes}" ]]; then this_os_installer_usage_notes+=' & '; fi
				this_os_installer_usage_notes+='Internet Required'
				this_os_installer_usage_notes="$(trim_and_squeeze_whitespace "${this_os_installer_usage_notes//:/ }")" # Make sure usage notes never contain ':' since it's used as a delimiter and the usage notes are only for display (this should never happen, but better safe than sorry).

				stub_os_installers_info+=( "${this_os_installer_name}:${this_os_installer_usage_notes}:${this_os_installer_path}" )
			fi
		done < <(printf '%s\0' "${these_os_versions_and_installer_paths[@]}" | sort -zr"$( (( BOOTED_DARWIN_MAJOR_VERSION >= 17 )) && echo 'V' || echo 'n' )") # Sort by OS versions in reverse order (newest to oldest), which must be done by converting the array to a string since arrays cannot be easily sorted natively.
		# NOTE: The "-V" ("--version-sort") option is only available in "sort" on macOS 10.13 High Sierra and newer, but since we could be booted into an older version of Internet Recovery, fallback on using "-n" ("--numeric-sort") instead when on macOS 10.12 Sierra or older.
		# ALSO NOTE: The "these_os_versions_and_installer_paths" array is being joined with NUL characters using "printf" and "sort -z" is being used to use NUL as record separator instead of newline, all of which allows line breaks to exist and be preserved within the array values, even though that is unlikely.
	fi
done

# Include any stub installers (one will always be in recoveryOS root filesystem) as choices if a full installer for the same version has not already been found.
is_first_stub_os_installer=true
for this_stub_installer_info in "${stub_os_installers_info[@]}"; do
	IFS=':' read -rd '' this_os_installer_name this_os_installer_usage_notes this_os_installer_path < <(echo -n "${this_stub_installer_info}") # MUST to use "echo -n" and process substitution since a here-string would add a trailing line break that would be included in the last value (this allows line breaks to exist within the values, even though that is unlikely).

	# Do not need to check if model supports stub installer version since stubs should only be for an already booted version.
	if [[ -n "${this_os_installer_name}" && -n "${this_os_installer_usage_notes}" && -n "${this_os_installer_path}" ]]; then # "this_os_installer_usage_notes" will always at least contain "Internet Required".
		if [[ "$(strip_ansi_styles "${os_installer_choices_display}")" != *": ${this_os_installer_name}"* ]]; then
			if $is_first_stub_os_installer; then
				os_installer_choices_display+=$'\n'
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
		if [[ "${os_installer_line}" == *')' ]]; then os_installer_usage_notes="$(echo "${os_installer_line}" | awk -F '[()]' '{ print $2; exit }')"; fi
		write_to_log "Defaulted to Installing ${os_installer_name}"
	fi

	last_choose_os_error=''
	until [[ -n "${os_installer_path}" ]]; do
		load_specs_overview
		ansi_clear_screen
		echo -e "${FG_MIB_HEADER}${specs_overview}"
		if [[ -n "${global_install_notes}" ]]; then echo -e "\n${global_install_notes}\n"; fi
		echo -e "\n  ${ANSI_UNDERLINE}Choose macOS Version to Install:${CLEAR_ANSI}${last_choose_os_error}${os_installer_choices_display}"

		echo -en "\n  Enter the ${ANSI_BOLD}Index of macOS Version${CLEAR_ANSI} to Install: "
		read -r chosen_os_installer_index

		chosen_os_installer_index="${chosen_os_installer_index//[^0-9]/}" # Remove all non-digits.
		if [[ "${chosen_os_installer_index}" == '0'* ]]; then
			chosen_os_installer_index="$(( 10#${chosen_os_installer_index} ))" # Remove any leading zeros (https://mywiki.wooledge.org/ArithmeticExpression#Pitfall:_Base_prefix_with_signed_numbers & https://github.com/koalaman/shellcheck/wiki/SC2004#rationale).
		fi

		if [[ -n "${chosen_os_installer_index}" ]] && (( chosen_os_installer_index < os_installer_choices_count )); then
			possible_os_installer_path="${os_installer_choices[chosen_os_installer_index]}"
			os_installer_line="$(strip_ansi_styles "${os_installer_choices_display}" | grep "^    ${chosen_os_installer_index}:")"
			os_installer_name="$(echo "${os_installer_line}" | awk -F ': | [(]' '{ print $2; exit }')"
			if [[ "${os_installer_line}" == *')' ]]; then os_installer_usage_notes="$(echo "${os_installer_line}" | awk -F '[()]' '{ print $2; exit }')"; fi

			echo -en "\n  Enter ${ANSI_BOLD}${chosen_os_installer_index}${CLEAR_ANSI} Again to Confirm Installing ${ANSI_BOLD}${os_installer_name}${CLEAR_ANSI}: "
			read -r confirmed_os_installer_index

			confirmed_os_installer_index="${confirmed_os_installer_index//[^0-9]/}" # Remove all non-digits.
			if [[ "${confirmed_os_installer_index}" == '0'* ]]; then
				confirmed_os_installer_index="$(( 10#${confirmed_os_installer_index} ))" # Remove any leading zeros (https://mywiki.wooledge.org/ArithmeticExpression#Pitfall:_Base_prefix_with_signed_numbers & https://github.com/koalaman/shellcheck/wiki/SC2004#rationale).
			fi

			if [[ "${chosen_os_installer_index}" == "${confirmed_os_installer_index}" ]]; then
				os_installer_path="${possible_os_installer_path}"

				if [[ -z "${os_installer_path}" || ! -f "${os_installer_path}" ]]; then
					last_choose_os_error="\n\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Selected macOS Installer No Longer Exists ${ANSI_PURPLE}${ANSI_BOLD}(CHOOSE AGAIN)${ANSI_RED}\n     ${ANSI_BOLD}PATH:${ANSI_RED} ${os_installer_path%.app/*}.app${CLEAR_ANSI}"
					write_to_log "ERROR: Selected macOS Installer (${os_installer_path%.app/*}.app) No Longer Exists"

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

	if (( os_installer_choices_count > 1 )); then
		write_to_log "Chose to Install ${os_installer_name}"
	fi

	if [[ -n "${os_installer_usage_notes}" ]]; then
		if [[ -z "${global_install_notes}" ]]; then global_install_notes="${GLOBAL_INSTALL_NOTES_HEADER}"; fi
		while read -rd '&' this_os_installer_usage_note; do # NOTE: NOT setting "IFS=''" so that leading and trailing whitespace (which will exist) DOES get trimmed automatically like we would want to be manually anyways.
			if [[ "${this_os_installer_usage_note}" == 'Internet Required' ]]; then
				this_os_installer_usage_note="Selected installer ${ANSI_BOLD}is a stub${CLEAR_ANSI}, full installer will be downloaded."
			elif [[ "${this_os_installer_usage_note}" == 'Clean Install Only' ]]; then
				this_os_installer_usage_note="Selected installer ${ANSI_BOLD}does not support${CLEAR_ANSI} including customization packages."
			fi
			global_install_notes+="\n    - ${this_os_installer_usage_note}"
		done <<< "${os_installer_usage_notes}&" # NOTE: MUST include a trailing/terminating "&" so that the last last value doesn't get lost by the "while read" loop.
	fi
fi


check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs() {
	# Internet is required during the installation when using a stub installer and on T2 or Apple Silicon Macs. If internet is not connected, the installation will fail.

	local installer_is_a_stub
	installer_is_a_stub="$([[ "${global_install_notes}" == *'is a stub'* ]] && echo 'true' || echo 'false')"

	if $installer_is_a_stub || $IS_APPLE_SILICON || $HAS_T2_CHIP; then
		local this_mac_type
		this_mac_type="$($IS_APPLE_SILICON && echo 'Apple Silicon' || echo 'T2') Macs"

		until ping -t 5 -c 1 'www.apple.com' &> /dev/null; do
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


if [[ ! -f "${os_installer_path}" || -z "${os_installer_name}" ]]; then
	>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required \"startosinstall\" Not Found in Any Standard Location${CLEAR_ANSI}\n\n"
	write_to_log 'ERROR: Required "startosinstall" Not Found in Any Standard Location'
	exit 1
fi

os_installer_darwin_major_version="$(PlistBuddy -c 'Print :DTSDKBuild' "${os_installer_path/\/Resources\/startosinstall/}/Info.plist" 2> /dev/null | cut -c -2 | tr -dc '[:digit:]')"

install_volume_name='Macintosh HD'
install_volume_path="/Volumes/${install_volume_name}"

if $IS_APPLE_SILICON; then

	# ABOUT PERFORMING MANUALLY ASSISTED CUSTOMIZED CLEAN INSTALL ON APPLE SILICON

	# In recoveryOS on Apple Silicon, "startosinstall" does not work (which has not changed from macOS 11 Big Sur through macOS 13 Ventura, which is the current latest version at the time of writing this).
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

	# After "Erase Mac" has been run, the internal drive will be named "Untitled" on macOS 11 Big Sur or "Macintosh HD" on macOS 12 Monterey and newer and it will be empty except for the ".fseventsd" folder.
	# So, this is what we will check for to determine if "Erase Mac" has already been run and proceed with preparing the drive to trick the installer
	# into performing a upgrade/re-install as well as copying the customization resources (the same as when customizing an existing clean install).

	# Now, FOR THE UPGRADE/RE-INSTALL TRICK! Through trial-and-error, I found that simply the existence of the "/System/Library/CoreServices/SystemVersion.plist" file will make the installer perform
	# an upgrade/re-install process instead of a clean install. This means that any files or folders added into the filesystem are preserved instead of deleted during the installation process.
	# I first started with a valid "SystemVersion.plist" file, but through more testing I found that the contents of this file do not matter for the trick itself to work, and creating an empty one is enough.
	# BUT, whatever "/System/Library/CoreServices/SystemVersion.plist" we create will be moved to "/private/var/db/PreviousSystemVersion.plist" during the installation process.
	# Since I am not sure when/if/how this "PreviousSystemVersion.plist" may be used by macOS, it seems best to be safe and create a valid "SystemVersion.plist" in the first place.
	# Originally, I just copied the "SystemVersion.plist" from the current recoveryOS, but later realized that prevented installing older versions of macOS than the current version of recoveryOS.
	# When testing, it could be possible to be booted to the latest local recoveryOS but want to be able to install an older version of macOS. If I copy the "SystemVersion.plist" from the latest recoveryOS
	# the installer will think that version of macOS has been fully installed and will not allow a "downgrade". So, instead I decided to manually create the "SystemVersion.plist" for the oldest possible
	# version of macOS that could be manually installed on an Apple Silicon Mac, which is macOS 11.0.1 Big Sur (build 20B29) since 11.0 (build 20A2411) only came pre-installed on the first Apple Silicon Macs.
	# Installing older versions of macOS than the currently running recoveryOS is not allowed on non-Apple Silicon Macs since it can cause installation failures and it's always possible to boot to an older version of recoveryOS,
	# but on Apple Silicon Macs you cannot boot to an older version of recoveryOS since Internet Recovery no longer exists and "booting" to a USB installer actually still boots to the local recoveryOS.
	# And, with macOS 11 Big Sur and newer on Apple Silicon doing installations of older versions of macOS from the latest versions of recoveryOS appears to not be an issue as of at least macOS 13 Ventura.
	# Also, this was tested and confirmed to not cause any issue on 2021 14-inch MacBook Pro 18,3 which originally shipped with macOS 12 Monterey.

	# The one big important thing about this is that if you ONLY create the "SystemVersion.plist", the installation will fail and reboot into recoveryOS with an error stating
	# that "An error occurred migrating user data during an install." So, more trial-and-error testing was necessary. My first though was to extract the entire "/private/var/db/dslocal"
	# folder from a clean installation and copy it into place before starting the installation process, and this worked! But, I was concerned about having to check and maintain any changes over time
	# between different versions of macOS, as well as if there was any computer specific information stored in the "localhost.plist" file or others that should be freshly created during an installation.
	# In an effort to find the absolute least amount of actions necessary to make this trick work, I tried only creating certain "dslocal" folders and files to see what worked and what didn't.
	# To my delight, I found that ALL that needs to be created is an EMPTY "/private/var/db/dslocal/nodes/Default" folder!
	# If only the "/private/var/db/dslocal/nodes" folder or any less is created, the installation process will fail with the same error as stated above, but anymore is unnecessary.
	# The installer will properly create the default "dslocal" contents when only an EMPTY "/private/var/db/dslocal/nodes/Default" folder exists!
	# Also, this "/private/var/db/dslocal" folder containing the empty "Default" folder will be archived to "/private/var/db/dslocal_orig.cpgz" during the installation process.

	# NOTE: Both the leftover "/private/var/db/PreviousSystemVersion.plist" and "/private/var/db/dslocal_orig.cpgz" files will be
	# DELETED by "fg-prepare-os.sh" on first boot to make everything appear as a regular "clean install" like we really wanted.

	# The other concern about this process was permission issues between what the permissions are when folders are created in recoveryOS vs what they are supposed to be after a normal installation.
	# But, this appears to MOSTLY be a non-issue in my testing. The installation process appears to reset and correct MOST permissions for MOST files or folders created in recoveryOS.
	# EXCEPT for the "/Library" and "/Library/LaunchDaemons" folder, which does not get its group correctly changed from "admin" to "wheel", so that must be done manually as well.

	# Once these files and folder are created to trick the installer into performing the upgrade/re-install and our customization resources are also setup and copied in,
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

	if [[ ! -f "${os_install_assistant_springboard_path}" ]]; then
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required \"InstallAssistant_springboard\" Not Found in Standard Location${CLEAR_ANSI}\n\n"
		write_to_log 'ERROR: Required "InstallAssistant_springboard" Not Found in Standard Location'
		exit 1
	fi

	internal_drive_name='Apple Silicon Internal Drive'
	internal_drive_has_mounted_volume=false
	erase_mac_has_been_run=false

	# To be able to determine if "Erase Mac" has been run yet, we will check some NVRAM keys as well as check that the internal drive was erased and renamed to "Untitled" or "Macintosh HD".
	# This is not all that happens during the "Erase Mac" process, but these are the best indicators I've found to determine that "Erase Mac" has been run successfully.

	# First, we will always check that the NVRAM "boot-volume" key DOES NOT exist, but prior to macOS 11.3 Big Sur the "boot-volume" key could possibly be deleted manually using "nvram -c" or "nvram -d",
	# while as of macOS 11.3 Big Sur and newer that key and other "*-volume" keys are protected in NVRAM and cannot be manually deleted outside of running "Erase Mac". So when on macOS 11.3 Big Sur and newer,
	# it would be safe to ONLY check that "boot-volume" has been cleared to detemine if "Erase Mac" has been run since it cannot be cleared manually. But, there is also a "recovery-boot-mode" key that gets
	# set to "obliteration" after "Erase Mac" has been run. Although, "recovery-boot-mode" is oddly NOT deleted upon next reboot after "Erase Mac" was run which means that key could be leftover from a previous
	# "Erase Mac" process even if a new installation has been performed. And, as of macOS 12.3 Monterey (build 21E230) that "recovery-boot-mode" is no longer set at all after "Erase Mac" has been run.
	# So, we must NOT check for it when running on macOS 12.3 Monterey and newer since it would not be set and would give a false negative result. Therefore, to be as thorough as possible on all versions of macOS,
	# we will check for BOTH "boot-volume" being cleared AND "recovery-boot-mode" being set to "obliteration" on macOS 12.2.1 Monterey and older both of which together are guaranteed indicators on macOS 11.3 Big Sur
	# through macOS 12.2.1 Monterey, and together should still be a very strong indicator that "Erase Mac" has been run on macOS 11.2.3 Big Sur and older. And, on macOS 12.3 Monterey and newer we'll
	# ONLY check for "boot-volume" being cleared since "recovery-boot-mode" is no longer set, which is still a strong indicator since "boot-volume" cannot be cleared manually as of macOS 11.3 Big Sur and newer.
	nvram_indicates_erase_mac_has_been_run="$([[ -z "$(nvram boot-volume 2> /dev/null)" && ( "${BOOTED_BUILD_VERSION}" > '21E' || "$(nvram recovery-boot-mode 2> /dev/null)" == *'obliteration' ) ]] && echo 'true' || echo 'false')"

	# Next, we'll check that the internal drive has a mounted volume named "Untitled" on macOS 11 Big Sur or "Macintosh HD" on macOS 12 Monterey and newer
	# to sure that "Erase Mac" has been run successfully and that this Apple Silicon Mac is ready for a new installation.
	# See comments below about a possible error when running "Erase Mac" twice in a row that can cause the internal drive to not have a mounted volume.

	for this_disk_id in "${install_drive_choices[@]}"; do
		# There should only be a single internal drive on Apple Silicon, so this should always be correct.
		# THIS MAY CHANGE IN THE FUTURE (MAYBE WITH MAC PRO) AND MORE THINGS WILL NEED TO BE CHECKED TO GET THE CORRECT INTERNAL DRIVE ON APPLE SILICON.
		internal_drive_name="$(strip_ansi_styles "${install_drive_choices_display}" | grep "^    ${this_disk_id}:")"
		internal_drive_name="${internal_drive_name#*: }"

		# Make sure all internal drives are mounted to be able to check if "Erase Mac" has been run successfully. This should not be necessary on Apple Silicon, but does not hurt.
		diskutil mountDisk "${this_disk_id}" &> /dev/null

		# Mounting parent disk IDs appears to not mount the child APFS Container disk IDs, so mount them too to be able to check if "Erase Mac" has been run successfully.
		while read -ra this_disk_info_line_elements; do
			if [[ "${this_disk_info_line_elements[2]#[^[:alpha:]]}" == 'Container' && "${this_disk_info_line_elements[3]}" == 'disk'* ]]; then
				this_apfs_container_disk_id="${this_disk_info_line_elements[3]%[^[:digit:]]}"
				# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop,
				# so just parse the human readable output of a single "diskutil list" command instead since it's right there even though it's not necessarily future-proof to parse the human readable output.
				# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID as of macOS 11 Big Sur and newer, so they must be removed.

				diskutil mountDisk "${this_apfs_container_disk_id}" &> /dev/null

				this_apfs_container_info_plist="$(diskutil list -plist "${this_apfs_container_disk_id}")"
				if echo "${this_apfs_container_info_plist}" | grep -q '>/Volumes/'; then # Using PlistBuddy would not make these checks any easier.
					# Make sure any volume is mounted on the internal drive to check for a possible error after "Erase Mac" has been run. See comments below for more information.
					internal_drive_has_mounted_volume=true

					if $nvram_indicates_erase_mac_has_been_run; then # Only bother checking for "Untitled" or "Macintosh HD" volume after "Erase Mac" if nvram_indicates_erase_mac_has_been_run. See comments above for more information.
						erased_volume_name="$( (( BOOTED_DARWIN_MAJOR_VERSION >= 21 )) && echo 'Macintosh HD' || echo 'Untitled' )" # Internal drive will be named "Untitled" after "Erase Mac" on macOS 11 Big Sur or named "Macintosh HD" on macOS 12 Monterey and newer.
						if echo "${this_apfs_container_info_plist}" | grep -q ">/Volumes/${erased_volume_name}<" && [[ -d "/Volumes/${erased_volume_name}" ]]; then
							erased_volume_contents="$(find "/Volumes/${erased_volume_name}" -mindepth 1 -maxdepth 1 2> /dev/null)"

							if [[ -z "${erased_volume_contents}" || "${erased_volume_contents}" == "/Volumes/${erased_volume_name}/.fseventsd" ]]; then
								# If nvram_indicates_erase_mac_has_been_run and an internal drive has an empty "/Volumes/Untitled" or "/Volumes/Macintosh HD" volume, we can safely assume "Erase Mac" has been run successfully.
								erase_mac_has_been_run=true
							fi
						fi
					fi
				fi
			fi
		done < <(diskutil list "${this_disk_id}")
	done

	if ! $internal_drive_has_mounted_volume; then
		# As of macOS 11.3 Big Sur, when "Erase Mac" is run twice in a row on Apple Silicon the volume will not mount when rebooted into
		# recoveryOS after the 2nd "Erase Mac" and Disk Utility will display an error when attempting to manually mount the volume.
		# No graphical error will be displayed, but errors will be visible in the Log during the "Erase Mac" process.
		# This should be able to fixed by manually erasing the Container in Disk Utility, but I have not automated this since it is not something that should normally happen.
		# If for some reason there is an error when erasing the Container in Disk Utility, a DFU restore through Apple Configurator 2 would be the only way to get the Mac working properly again.

		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} No Volume Mounted on ${internal_drive_name}\n\n    ${ANSI_YELLOW}This may indicate that an error occurred after running \"Erase Mac\".\n\n    ${ANSI_PURPLE}${ANSI_BOLD}Please inform and deliver this Mac to Free Geek I.T.${CLEAR_ANSI}\n\n"
		write_to_log "ERROR: No Volume Mounted on ${internal_drive_name}"

		'/System/Applications/Utilities/Disk Utility.app/Contents/MacOS/Disk Utility' &> /dev/null & disown # Launch Disk Utility to be able to see what's going on with the drive to be able to easily erase the Container.

		exit 1
	fi

	confirm_continue_response=''
	until [[ "${confirm_continue_response}" == 'Y' ]]; do
		load_specs_overview
		ansi_clear_screen
		echo -e "${FG_MIB_HEADER}${specs_overview}"
		if [[ -n "${global_install_notes}" ]]; then echo -e "\n${global_install_notes}\n"; fi

		if $erase_mac_has_been_run; then
			write_to_log 'Detected "Erase Mac" Has Been Run on Apple Silicon'
			echo -e "\n  ${ANSI_UNDERLINE}${os_installer_name} Is Ready to Be ${ANSI_BOLD}MANUALLY INSTALLED${CLEAR_ANSI}\n  ${ANSI_UNDERLINE}On This Apple Silicon Mac:${CLEAR_ANSI}"
			echo -en "\n    ${ANSI_PURPLE}Enter ${ANSI_BOLD}Y${CLEAR_ANSI}${ANSI_PURPLE} to ${ANSI_UNDERLINE}PREPARE $($CLEAN_INSTALL_REQUESTED && echo 'INSTALLATION' || echo 'CUSTOMIZATIONS') AND VIEW INSTRUCTIONS${CLEAR_ANSI}${ANSI_PURPLE}\n    or Enter ${ANSI_BOLD}N${CLEAR_ANSI}${ANSI_PURPLE} to ${ANSI_UNDERLINE}EXIT${CLEAR_ANSI}${ANSI_PURPLE}:${CLEAR_ANSI} "
		else
			write_to_log 'Detected "Erase Mac" Must Be Run Manually on Apple Silicon'
			echo -e "\n  ${ANSI_UNDERLINE}Apple Silicon Macs Must Be ${ANSI_BOLD}MANUALLY ERASED${CLEAR_ANSI}\n  ${ANSI_UNDERLINE}Before ${ANSI_BOLD}INSTALLING${CLEAR_ANSI}${ANSI_UNDERLINE} ${os_installer_name}:${CLEAR_ANSI}"
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

		write_to_log 'Chose to Start Manual Installation on Apple Silicon'

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


		if (( BOOTED_DARWIN_MAJOR_VERSION < 21 )); then

			# RENAME "Untitled" TO install_volume_name WHEN ON macOS 11 Big Sur
			# This is no longer necessary on macOS 12 Monterey.

			echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Renaming ${ANSI_UNDERLINE}${internal_drive_name}${ANSI_CYAN}${ANSI_BOLD} to ${ANSI_UNDERLINE}\"${install_volume_name}\"${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}\n"


			if [[ -d "${install_volume_path}" ]]; then
				# Unmount any other drive already named the same as install_volume_name to not conflict with our intended install drive mount point.
				diskutil unmount "${install_volume_path}" || diskutil unmount force "${install_volume_path}"
			fi

			diskutil rename 'Untitled' "${install_volume_name}"
		fi


		if [[ ! -d "${install_volume_path}" ]]; then
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed Rename Internal Drive${CLEAR_ANSI}\n\n"
			write_to_log 'ERROR: Failed Rename Internal Drive'
			exit 1
		fi

		install_volume_contents="$(find "${install_volume_path}" -mindepth 1 -maxdepth 1 2> /dev/null)"

		if [[ -n "${install_volume_contents}" && "${install_volume_contents}" != "${install_volume_path}/.fseventsd" ]]; then
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Internal Drive Not Empty${CLEAR_ANSI}\n\n"
			write_to_log 'ERROR: Internal Drive Not Empty'
			exit 1
		fi

		if ! $CLEAN_INSTALL_REQUESTED && (( customization_packages_count > 0 )) && [[ -f "${SCRIPT_DIR}/customization-resources/fg-install-packages.sh" ]]; then

			# PREPARE CUSTOMIZATION RESOURCES

			echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Copying Customization Resources Into ${ANSI_UNDERLINE}\"${install_volume_path}\"${ANSI_CYAN}${ANSI_BOLD}\n  on ${ANSI_UNDERLINE}${internal_drive_name}${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}\n"

			# See the "ABOUT PERFORMING MANUALLY ASSISTED CUSTOMIZED CLEAN INSTALL ON APPLE SILICON" notes above about
			# why the next file and folder creation commands are CRITICAL to be able to place a custom LaunchDaemon to be run
			# on first boot in a way that it will be preserved during the installation process and adopted by the installed OS.

			# The following version 11.0.1 (build 20B29) info is for the first released full installer of macOS 11 Big Sur (which was the first vesion to support Apple Silicon).
			# Version 11.0 (build 20A2411) only came pre-installed on the first Apple Silicon Macs, so it's only ever possible to be manually installing version 11.0.1 and newer.
			mkdir -p "${install_volume_path}/System/Library/CoreServices"
			PlistBuddy \
				-c 'Add :ProductBuildVersion string 20B29' \
				-c 'Add :ProductCopyright string "1983-2020 Apple Inc."' \
				-c 'Add :ProductName string macOS' \
				-c 'Add :ProductUserVisibleVersion string 11.0.1' \
				-c 'Add :ProductVersion string 11.0.1' \
				-c 'Add :iOSSupportVersion string 14.2' \
				"${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" &> /dev/null

			mkdir -p "${install_volume_path}/private/var/db/dslocal/nodes/Default"

			# These folders need to be created for our customization LaunchDaemon and resources.
			mkdir -p "${install_volume_path}/Users/Shared"
			mkdir -p "${install_volume_path}/Library/LaunchDaemons"
			mkdir -p "${install_volume_path}/Library/Application Support/com.apple.TCC"
			chown -R 0:0 "${install_volume_path}/Library" # Make sure this folder (and LaunchDaemons) gets properly owned by root:wheel after installation, see notes above for more information.

			if [[ ! -f "${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" || ! -d "${install_volume_path}/private/var/db/dslocal/nodes/Default" ||
				! -d "${install_volume_path}/Users/Shared" || ! -d "${install_volume_path}/Library/LaunchDaemons" || ! -d "${install_volume_path}/Library/Application Support/com.apple.TCC" ]]; then
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed Setup Files/Folders for Customized Clean Install${CLEAR_ANSI}\n\n"
				write_to_log 'ERROR: Failed Setup Files/Folders for Customized Clean Install'
				exit 1
			fi

			if copy_customization_resources "${install_volume_path}" && create_custom_global_tcc_database "${install_volume_path}/Library/Application Support/com.apple.TCC" "${os_installer_darwin_major_version}"; then

				write_to_log 'Successfully Copied Customization Resources and Prepared Customization'

				# Copy installation log onto install drive to save the record of the installation choices, as well as being able to see the installation duration from the time stamps.
				mkdir -p "${install_volume_path}/Users/Shared/Build Info"
				chown -R 502:20 "${install_volume_path}/Users/Shared/Build Info" # Want fg-demo to own the "Build Info" folder, but keep log owned by root.
				ditto "${install_log_path}" "${install_volume_path}/Users/Shared/Build Info/"

				echo -e "  ${ANSI_GREEN}${ANSI_BOLD}Successfully Copied Customization Resources and Prepared Customization${CLEAR_ANSI}\n"

				sleep 3 # Sleep a bit so technician can see that customization resources were copied.
			else
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to Copy Customization Resources${CLEAR_ANSI}\n\n"
				write_to_log 'ERROR: Failed to Copy Customization Resources'
				exit 1
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
    $($CLEAN_INSTALL_REQUESTED &&
		echo "Clean installation will be peformed since \"$1\" argument has been used." ||
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

			# Suppress ShellCheck suggestion to use "pgrep" since it's not available in recoveryOS.
			# shellcheck disable=SC2009
			if ! ps -ax | grep -q '[I]nstallAssistant'; then # Do not want to launch a new instance if it's already running.
				"${os_install_assistant_springboard_path}" &> /dev/null & disown
				write_to_log 'Displayed Instructions and Launched "InstallAssistant_springboard" for Manual Installation'
			fi

			read -r # Keep this process running to not show the command prompt for a clean window and just keep re-displaying instructions if user presses enter.
		done
	else
		write_to_log 'Chose to Manual Run "Erase Mac" on Apple Silicon'

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

			# Suppress ShellCheck suggestion to use "pgrep" since it's not available in recoveryOS.
			# shellcheck disable=SC2009
			if ! ps -ax | grep -q '[K]eyRecoveryAssistant'; then # Do not want to launch a new instance if it's already running.
				resetpassword &> /dev/null
				write_to_log 'Displayed Instructions and Launched "KeyRecoveryAssistant" for Manual "Erase Mac"'
			fi

			read -r # Keep this process running to not show the command prompt for a clean window and just keep re-displaying instructions if user presses enter.
		done
	fi
else

	# PROMPT TO CHOOSE INSTALL DRIVE (even if only one is available so that erasing can be confirmed)

	install_disk_id=''
	install_drive_name=''

	last_choose_drive_error=''
	until [[ -n "${install_disk_id}" ]]; do
		load_specs_overview
		ansi_clear_screen
		echo -e "${FG_MIB_HEADER}${specs_overview}"
		if [[ -n "${global_install_notes}" ]]; then echo -e "\n${global_install_notes}\n"; fi
		echo -e "\n  ${ANSI_UNDERLINE}Choose Drive to ${ANSI_BOLD}COMPLETELY ERASE${CLEAR_ANSI}${ANSI_UNDERLINE} and ${ANSI_BOLD}INSTALL${CLEAR_ANSI}${ANSI_UNDERLINE} ${os_installer_name} Onto:${CLEAR_ANSI}${last_choose_drive_error}${install_drive_choices_display}"

		echo -en "\n  Enter the ${ANSI_BOLD}ID of Drive${CLEAR_ANSI} to ${ANSI_UNDERLINE}COMPLETELY ERASE${CLEAR_ANSI}\n  and ${ANSI_UNDERLINE}INSTALL${CLEAR_ANSI} ${ANSI_BOLD}${os_installer_name}${CLEAR_ANSI} Onto: disk"
		read -r chosen_disk_id_number

		chosen_disk_id_number="$(echo "${chosen_disk_id_number}" | tr '[:lower:]' '[:upper:]')"
		if [[ "${chosen_disk_id_number}" != 'F' ]]; then
			chosen_disk_id_number="${chosen_disk_id_number//[^0-9]/}" # Remove all non-digits.
			if [[ "${chosen_disk_id_number}" == '0'* ]]; then
				chosen_disk_id_number="$(( 10#${chosen_disk_id_number} ))" # Remove any leading zeros (https://mywiki.wooledge.org/ArithmeticExpression#Pitfall:_Base_prefix_with_signed_numbers & https://github.com/koalaman/shellcheck/wiki/SC2004#rationale).
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
				confirmed_disk_id_number="${confirmed_disk_id_number//[^0-9]/}" # Remove all non-digits.
				if [[ "${confirmed_disk_id_number}" == '0'* ]]; then
					confirmed_disk_id_number="$(( 10#${confirmed_disk_id_number} ))" # Remove any leading zeros (https://mywiki.wooledge.org/ArithmeticExpression#Pitfall:_Base_prefix_with_signed_numbers & https://github.com/koalaman/shellcheck/wiki/SC2004#rationale).
				fi
			fi

			if [[ "${chosen_disk_id_number}" == "${confirmed_disk_id_number}" ]]; then
				install_disk_id="disk${confirmed_disk_id_number}"

				write_to_log "Chose Installation Drive ${install_drive_name} (${install_disk_id})"
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


	# MAKE SURE POWER ADAPTER IS PLUGGED IN AND DATE IS CORRECT (AND INTERNET IS CONNECTED FOR STUB INSTALLER OR T2 MACS) BEFORE ALLOWING DRIVE TO BE ERASED OR OS INSTALLATION TO BEGIN

	check_and_prompt_for_power_adapter_for_laptops
	set_date_time_and_prompt_for_internet_if_year_not_correct
	check_and_prompt_for_internet_for_stubs_and_t2_or_as_macs


	if [[ -z "$(ioreg -rc AppleSEPManager)" ]] && xartutil --list &> /dev/null; then # Use actual SEP (Secure Enclave Processor) check which would only have output on T2 or Apple Silicon Macs instead of the "HAS_T2_CHIP" or "HAS_SEP" variables since we DO NOT want this to be done even if the debug args are passed. An Apple Silicon Mac will never get to this code, but they should also NOT have their xART entries messed with.
		# Only run "xartutil --erase-all" on T1 (*NOT* T2) Macs to clear any possible Touch ID data (since "bioutil" is not available in recoveryOS).
		# This used to also work fine on T2 Macs (and would do more than just clear Touch ID data) when I originally wrote this script when macOS 11 Big Sur was the latest version of macOS.
		# But, at some point between then and macOS 12.4 Monterey, something changed (likely in the bridgeOS T2 Firmware) that causes a MAJOR issue during the macOS installation.
		# If "xartutil --erase-all" is run at this point in recoveryOS on a T2 Mac, the installation will start fine and reboot to the Apple logo with progress bar phase.
		# Then, at some point during that phase (I think at the next reboot), the Mac will jut shut down and won't turn back on *AT ALL*, even manually, basically seeming to be a brick.
		# But, luckily, the T2 Mac can be put back into DFU Mode to restore the bridgeOS T2 Firmware to bring the T2 Mac back to life to be able to do another macOS installation attempt.
		# I'm not sure exactly when this change in the bridgeOS T2 Firmware happened since we don't get that many T2 Macs and I hadn't been testing each new version regulary.
		# Regardless, since every T2 Mac that comes in gets the bridgeOS T2 Firmware DFU restored (which securely cryptographically erases the T2 Mac by clearing encryption keys)
		# before this script is run anyways, running "xartutil --erase-all" as a secure erasure measure has never really been necessary for our process on T2 Macs anyways.
		# Now, since running "xartutil --erase-all" would cause a serious disruption to the refurbishment process for T2 Macs, it will just not be run anymore.
		# Also, even if we're not starting from a DFU restored state on a T2 Mac, simply erasing a volume (or disk) will automatically delete the associated xART sessions for any volumes being deleted/erased.
		# That can be seen by running "xartutil --list" repeatedly while a disk is being reformatted on a T2 Mac and observing the "session seed" count for the entry with a UID of all zeros go down by one when the old volume is deleted and then back up when a new volume is created.
		# Starting from a DFU restored state, there are 4 session seeds for the entry with a UID of all zeros and then another session seed is added one for each volume that is created on the internal drive.
		# But, when "xartutil --erase-all" is one there are only the number of session seeds for the entry with a UID of all zeros for each volume present on the internal drive, those original 4 are lost.
		# I don't know exactly what those original 4 session seeds for the entry with a UID of all zeros are that are present on a T2 Mac after a DFU restore, but I'm assuming they are critical and erasing them is what causes the issue described above.
		# Also, for T2 Macs, I've confirmed that any existing Touch ID entries are automatically removed when the associated volume is deleted, which will always happen since if any Touch ID entries exist, it will not be considered a clean install and the volume will always be deleted.

		xartutil_output='CLEAR ONCE NO MATTER WHAT'
		until [[ -z "${xartutil_output}" ]]; do # Cleared output is empty on T1s (and would be "Total Session count: 0" on T2s, but that's never done anymore for the reasons described above).
			ansi_clear_screen
			echo -e "\n  ${ANSI_CYAN}${ANSI_BOLD}Clearing All Touch ID Data...${CLEAR_ANSI}\n"

			xartutil_output="$(xartutil --list)"

			if [[ -n "${xartutil_output}" ]]; then
				echo -e "${xartutil_output}\n" # Show current entries output to technician.
			fi

			echo 'yes' | xartutil --erase-all

			echo '' # Add line break after prompt was automatically confirmed with "yes".

			xartutil_output="$(xartutil --list)"

			if [[ -n "${xartutil_output}" ]]; then
				echo -e "\n${xartutil_output}" # Show new entries output to technician.
			fi

			if [[ -z "${xartutil_output}" ]]; then
				echo -e "\n  ${ANSI_GREEN}${ANSI_BOLD}Successfully Cleared All Touch ID Data${CLEAR_ANSI}\n"
				write_to_log 'Successfully Cleared All Touch ID Data'
			fi
		done

		sleep 3 # Sleep a bit so technician can see that entries were cleared (or see error if not).
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
				write_to_log 'Successfully Created Fusion Drive'
			else
				# I have seen that a messed up APFS Container can cause "diskutil eraseDisk" to fail (assuming it would affect "diskutil resetFusion" as well),
				# so try to delete any and all existing APFS Containers and then try "diskutil resetFusion" again.
				# I ran into this issue after restoring some Snapshots failed during other testing and caused the APFS Container to be messed up.

				did_delete_apfs_container=false

				for this_disk_id in "${install_drive_choices[@]}"; do
					if [[ -n "${this_disk_id}" && "${this_disk_id}" != 'diskF' ]]; then
						while read -ra this_disk_info_line_elements; do
							if [[ "${this_disk_info_line_elements[2]#[^[:alpha:]]}" == 'Container' && "${this_disk_info_line_elements[3]}" == 'disk'* ]] &&
								diskutil apfs deleteContainer "${this_disk_info_line_elements[3]%[^[:digit:]]}"; then
								# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop,
								# so just parse the human readable output of a single "diskutil list" command instead since it's right there even though it's not necessarily future-proof to parse the human readable output.
								# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID as of macOS 11 Big Sur and newer, so they must be removed.

								did_delete_apfs_container=true
							fi
						done < <(diskutil list "${this_disk_id}")
					fi
				done

				if $did_delete_apfs_container && echo 'Yes' | diskutil resetFusion; then
					erase_did_succeed=true
					write_to_log 'Successfully Created Fusion Drive AFTER Deleting Existing Containers'
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
			# If we format to JHFS+ on a T2 Mac, then "startosinstall" will exit with an error stating that "this Mac can only install macOS on APFS-formatted drives" on macOS 10.15 Catalina and older (with exit code "108") or that the "volume is not compatible with this update" on macOS 11 Big Sur and newer (with exit code "5").
			# Otherwise let the installer do the conversion from JHFS+ to APFS when it is supported (and after any necessary EFI Firmware updates are performed by the installation process).
			# If we format straight to APFS on a Mac whose EFI Firmware is too old to boot to APFS, "startosinstall" will exit with an error stating that a firmware update or JHFS+ is required (exit code "253" on macOS 10.15 Catalina and older and exit code "5" on macOS 11 Big Sur and newer).
			# The installer will take care of updating EFI Firmware and then convert to APFS after that has been completed, if supported by the OS version and drive type.

			if diskutil eraseDisk "${format_for_drive}" "${install_volume_name}" "${install_disk_id}"; then
				erase_did_succeed=true
				write_to_log "Successfully Formatted ${install_disk_id} to ${format_for_drive}"
			else
				# I have seen that a messed up APFS Container can cause "diskutil eraseDisk" to fail,
				# so try to delete any and all existing APFS Containers and then try "diskutil eraseDisk" again.
				# I ran into this issue after restoring some Snapshots failed during other testing and caused the APFS Container to be messed up.

				did_delete_apfs_container=false

				while read -ra this_disk_info_line_elements; do
					if [[ "${this_disk_info_line_elements[2]#[^[:alpha:]]}" == 'Container' && "${this_disk_info_line_elements[3]}" == 'disk'* ]] &&
						diskutil apfs deleteContainer "${this_disk_info_line_elements[3]%[^[:digit:]]}"; then
						# Trying to get APFS Containers of a disk from "diskutil" plist output would require a "diskutil list -plist" command and then multiple "diskutil info -plist" commands in a loop,
						# so just parse the human readable output of a single "diskutil list" command instead since it's right there even though it's not necessarily future-proof to parse the human readable output.
						# BUT, there are invisible characters in the "diskutil list" output before "Container" and after the disk ID as of macOS 11 Big Sur and newer, so they must be removed.

						did_delete_apfs_container=true
					fi
				done < <(diskutil list "${install_disk_id}")

				if $did_delete_apfs_container && diskutil eraseDisk "${format_for_drive}" "${install_volume_name}" "${install_disk_id}"; then
					erase_did_succeed=true
					write_to_log "Successfully Formatted ${install_disk_id} to ${format_for_drive} AFTER Deleting Existing Containers"
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
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to $([[ "${install_disk_id}" == 'diskF' ]] && echo 'Create Fusion Drive' || echo "Erase ${install_disk_id}") ${ANSI_YELLOW}${ANSI_BOLD}(Attempt ${erase_disk_attempt} of 3)${CLEAR_ANSI}"
			write_to_log "ERROR: Failed to $([[ "${install_disk_id}" == 'diskF' ]] && echo 'Create Fusion Drive' || echo "Erase ${install_disk_id}") (Attempt ${erase_disk_attempt} of 3)"
			sleep 3 # Sleep a bit so technician can see the error.
		fi
	done

	if [[ ! -d "${install_volume_path}" ]]; then
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to Format Drive After 3 Attempts${CLEAR_ANSI}\n\n"
		write_to_log 'ERROR: Failed to Format Drive After 3 Attempts'

		'/System/Applications/Utilities/Disk Utility.app/Contents/MacOS/Disk Utility' &> /dev/null & disown # Launch Disk Utility to be able to see what's going on with the drive.

		exit 1
	elif [[ -z "${install_disk_id}" || -z "${install_drive_name}" ]]; then
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unknown Error During Install Drive Selection${CLEAR_ANSI}\n\n"
		write_to_log 'ERROR: Unknown Error During Install Drive Selection'
		exit 1
	fi

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

	declare -a os_installer_options=( '--volume' "${install_volume_path}" '--nointeraction' )
	# The "volume" argument is supported in recoveryOS on ALL versions of "startosinstall" (which is OS X 10.11 El Capitan and newer). (The "volume" argument can also be used in full macOS when SIP is disabled, but that is not useful or necessary for our usage.)
	# The "nointeraction" argument is undocumented, but is supported on ALL versions of "startosinstall" (which is OS X 10.11 El Capitan and newer).

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
		if ! $CLEAN_INSTALL_REQUESTED && (( customization_packages_count > 0 )); then
			for this_customization_package_path in "${customization_packages[@]}"; do
				os_installer_options+=( '--installpackage' "${this_customization_package_path}" )
			done
		fi
	fi

	if grep -qU -e '--forcequitapps, ' "${os_installer_path}"; then
		# The "forcequitapps" argument is supported on macOS 10.15 Catalina and newer.
		# This should not be necessary in recoveryOS, but doesn't hurt.
		os_installer_options+=( '--forcequitapps' )
	fi

	if ! $CLEAN_INSTALL_REQUESTED; then
		# See the "Now, FOR THE UPGRADE/RE-INSTALL TRICK!" section in the "ABOUT PERFORMING MANUALLY ASSISTED CUSTOMIZED CLEAN INSTALL ON APPLE SILICON" notes above about
		# why the next file and folder creation commands are CRITICAL to be able to place a customized global TCC.db (which is SIP protected location when booted into the installed OS)
		# in a way that it will be preserved during the installation process (via "startosinstall") and adopted by the installed OS (see comments in "create_custom_global_tcc_database" function for more info).
		# NOTE: This "UPGRADE/RE-INSTALL TRICK" was originally discovered for use on Apple Silicon to do a customized clean install from recoveryOS (where "startosinstall" is not available).

		if (( os_installer_darwin_major_version > 17 )); then
			# Like when doing customized clean installs for Apple Silicon (as described above), we also DO NOT want to always copy the "SystemVersion.plist" from the current version of recoveryOS onto the installation drive,
			# but for different reasons than allowing older versions of macOS than the current recoveryOS (which is not allowed on non-Apple Silicon Macs since it can cause installation failures and it's always possible to boot to an older version of recoveryOS).
			# It's because I found that having an existing "SystemVersion.plist" can change the drive format checks performed by "startosinstall" (which are never an issue for Apple Silicon since they are always APFS).
			# Specifically, "startosinstall" will check the macOS version in the existing "SystemVersion.plist" and if it indicates that macOS 10.14 Mojave or newer was already installed on the drive,
			# it makes the assumption that the drive must already be formatted as APFS (since macOS 10.14 Mojave was the first to convert all drives to APFS including HDDs and Fusion drives while macOS 10.13 High Sierra only converted SSDs to APFS).
			# But, since we are only tricking "startosinstall" into thinking there is an existing installation on the drive, this can be an issue when the Mac has never actually had macOS 10.14 Mojave or newer installed onto it and the EFI Firmware
			# does not support booting to APFS. When this happens, a sort of Catch-22 scenario can happen where "startosinstall" first checks the version in the "SystemVersion.plist" and sees that macOS 10.14 Mojave or newer is already installed
			# and then errors stating that "volume is not formatted as APFS" with exit code "223" on macOS 10.14 Mojave and macOS 10.15 Catalina and with exit code "5" on macOS 11 Big Sur and newer.
			# BUT, if we then try again with the drive formatted to APFS then "startosintall" will do the normal EFI Firmware version checks and if the EFI Firmware is too old to support booting to APFS,
			# then "startosinstall" will error again but this time stating that a firmware update or JHFS+ is required (exit code "253" on macOS 10.15 Catalina and older and exit code "5" on macOS 11 Big Sur and newer).
			# If the EFI Firmware is NOT too old to support booting to APFS, then installing macOS 10.14 Mojave with the drive formatted to APFS will work fine, but that is not a solution that could work for any and all Macs regardless of the EFI Firmware version.
			# So, when the EFI Firmware is too old to boot to APFS, we end up in a situation where "startosinstall" WILL NOT install macOS 10.14 Mojave and newer on either JHFS+ or APFS.

			# TO AVOID THIS POSSIBLE CATCH-22 WHEN THE EFI FIRMWARE IS TOO OLD TO SUPPORT BOOTING TO APFS, we can simply trick "startosinstall" into thinking an OLDER version of macOS is currently installed on the system which may still require the drive be converted to AFPS.
			# This way, we can always safely format the install drive to JHFS+ as we have always done (when NOT a T2 Mac) regardless of the EFI Firmware version and then just let the installer do the conversion from JHFS+ to APFS when it is supported (and after any necessary EFI Firmware updates are performed by the installation process).
			# In my testing I found that creating an EMPTY "SystemVersion.plist" file (just using the "touch" command) WORKS fine and "startosinstall" will seemingly still assume some version of macOS is already installed, but not assume that it's new enough to already be formatted as APFS.
			# But, I prefer to create an actual "SystemVersion.plist" file with valid contents, so I've chosen to always create it with the keys and values from a macOS 10.13.6 High Sierra installation.
			# Since macOS 10.13 High Sierra only converted SSDs to APFS (which could also have been opted-out of) and not HDDs or Fusion drives, it's old enough so that "startosinstall" knows that a conversion to APFS may be required and takes care of that for us without erroring that "volume is not formatted as APFS".
			# Also, this does not cause any issue on T2 Mac (even on a 15-inch 2019 MacBook Pro 15,1 which originally shipped with macOS 10.14.5 Mojave).
			# This ALSO avoids another possible issue when booting to Internet Recovery (such as on a T2 Mac) which happens to be newer minor version than the current macOS version we are trying to install via USB.
			# If we copied the newer "SystemVersion.plist" from Internet Recovery and then attempted to install the older minor version of macOS from the USB, we would get a "cannot downgrade macOS" error, which always creating this older "SystemVersion.plist" avoids.

			mkdir -p "${install_volume_path}/System/Library/CoreServices"
			PlistBuddy \
				-c 'Add :ProductBuildVersion string 17G66' \
				-c 'Add :ProductCopyright string "1983-2018 Apple Inc."' \
				-c 'Add :ProductName string "Mac OS X"' \
				-c 'Add :ProductUserVisibleVersion string 10.13.6' \
				-c 'Add :ProductVersion string 10.13.6' \
				"${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" &> /dev/null
		else
			# But, when performing a macOS 10.13 High Sierra (or older) installation, it's always fine to just copy the "SystemVersion.plist" from the current version of recoveryOS onto
			# the installation drive since "startosinstall" for macOS 10.13 High Sierra (or older) would never be assuming that the drive would always already be formatted as APFS
			# and this installation script prevents installing versions of macOS that are older than the currently running version of recoveryOS (since that can cause installation errors).

			ditto '/System/Library/CoreServices/SystemVersion.plist' "${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" # "ditto" will create missing parent folders.
		fi

		mkdir -p "${install_volume_path}/private/var/db/dslocal/nodes/Default"

		mkdir -p "${install_volume_path}/Library/Application Support/com.apple.TCC" # This folder need to be created for our custom global "TCC.db" file.

		if [[ ! -f "${install_volume_path}/System/Library/CoreServices/SystemVersion.plist" || ! -d "${install_volume_path}/private/var/db/dslocal/nodes/Default" ||
			! -d "${install_volume_path}/Library/Application Support/com.apple.TCC" ]]; then
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed Setup Files/Folders for Customized Installation${CLEAR_ANSI}\n\n"
			write_to_log 'ERROR: Failed Setup Files/Folders for Customized Installation'
			exit 1
		fi

		if ! create_custom_global_tcc_database "${install_volume_path}/Library/Application Support/com.apple.TCC" "${os_installer_darwin_major_version}"; then
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed Create TCC Database for Customized Installation${CLEAR_ANSI}\n\n"
			write_to_log 'ERROR: Failed Create TCC Database for Customized Installation'
			exit 1
		fi

		write_to_log "Starting ${os_installer_name} Installation on ${install_drive_name}"

		# Copy installation log onto install drive to save the record of the installation choices, as well as being able to see the installation duration from the time stamps.
		mkdir -p "${install_volume_path}/Users/Shared/Build Info"
		chown -R 502:20 "${install_volume_path}/Users/Shared/Build Info" # Want fg-demo to own the "Build Info" folder, but keep log owned by root.
		ditto "${install_log_path}" "${install_volume_path}/Users/Shared/Build Info/"
	fi

	"${os_installer_path}" "${os_installer_options[@]}"
	startosinstall_exit_code="$?"

	if (( startosinstall_exit_code != 0 )); then
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} \"startosinstall\" Failed With Exit Code ${startosinstall_exit_code}${CLEAR_ANSI}"
		write_to_log "ERROR: \"startosinstall\" Failed With Exit Code ${startosinstall_exit_code}"

		if [[ "${install_disk_id}" == 'diskF' ]] && (( ( installed_os_darwin_major_version <= 19 && startosinstall_exit_code == 253 ) || ( installed_os_darwin_major_version >= 20 && startosinstall_exit_code == 5 ) )); then
			# If technician chose to create a Fusion Drive (which will always be APFS), but got error indicating that an EFI Firmware update is required to install on APFS, give a detailed error explaining the situation.

			>&2 echo -e "
     ${ANSI_YELLOW}${ANSI_BOLD}NOTE:${ANSI_YELLOW} This Mac requires an EFI Firmware update to be able to install macOS
           onto an ${ANSI_UNDERLINE}APFS Fusion Drive${ANSI_YELLOW}. To update the EFI Firmware of this Mac,
           you must first install macOS onto just one of the internal drives
           without creating an APFS Fusion Drive. The EFI Firmware will be
           updated when macOS is installed onto one of the internal drives.
           After that installation is done, you can boot back to here and
           perform another installation onto the APFS Fusion Drive.${CLEAR_ANSI}" # This note is indended 1 extra space so that it nicely lines up with the "ERROR:" message before it.
		fi
	fi

	echo -e '\n'

	exit "${startosinstall_exit_code}" # Exit with whatever the "startosinstall" exit code was.
fi

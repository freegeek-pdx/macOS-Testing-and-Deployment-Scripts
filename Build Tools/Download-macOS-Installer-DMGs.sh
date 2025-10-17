#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

readonly MIST_PATH='/usr/local/bin/mist'

PROJECT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/.."
readonly PROJECT_DIR

installer_dmgs_path="$(realpath "${PROJECT_DIR}/../../MacLand Images/macOS Installers")"

declare -a installer_names_to_download=(
#	'High Sierra' 'Mojave' 'Catalina' 'Big Sur' 'Monterey' 'Ventura' # NOT including these versions anymore since the latest installers are already downloaded and they will never get any new updates.
	'Sonoma' 'Sequoia' 'Tahoe'
)

catalog_url='' # Fill with custom Software Update Catalog URL if needed.

run_as_sudo_if_needed() { # Based On: https://github.com/freegeek-pdx/mkuser/blob/main/utilities/download-and-install-mkuser.sh#L41-L48
	if (( ${EUID:-$(id -u)} != 0 )); then # Only need to run with "sudo" if this script itself IS NOT already running as root.
		sudo -p 'Enter Password for "%p" to Download macOS Installer: ' "$@"
	else
		"$@"
	fi
}

for this_installer_name_to_download in "${installer_names_to_download[@]}"; do
	mist_list_options=( 'list' 'installer' "${this_installer_name_to_download}" )

	if [[ "${this_installer_name_to_download}" == *' '[Bb][Ee][Tt][Aa] ]]; then
		mist_list_options+=( '-b' )
	fi

	if [[ -n "${catalog_url}" ]]; then
		mist_list_options+=( '-c' "${catalog_url}" )
	fi

	mist_list_options+=( '-lqo' 'json' )

	this_installer_info_json="$("${MIST_PATH}" "${mist_list_options[@]}")"

	IFS=$'\n' read -rd '' -a this_installer_info < <(osascript -l 'JavaScript' -e '
function run(argv) {
	const latestInstallerDict = JSON.parse(argv[0])[0]
	return [latestInstallerDict.name, latestInstallerDict.version, latestInstallerDict.build].join("\n")
}
' -- "${this_installer_info_json}" 2> /dev/null)
	# NOTE: Because of JavaScript behavior, any "undefined" (or "null") values in an array would be turned into empty strings when using "join", making them empty lines.
	# And, because of bash behaviors with whitespace IFS treating consecutive whitespace as a single delimiter (explained in https://mywiki.wooledge.org/IFS),
	# any empty lines will NOT be included in the bash array being created with this technique to set all lines to an array.
	# So, that means if any of these values are not found, the bash array WILL NOT have a count of exactly 3 which we can check to verify all required values were properly loaded.

	if (( ${#this_installer_info[@]} == 3 )); then
		this_installer_dmg_name="Install ${this_installer_info[0]} ${this_installer_info[1]}-${this_installer_info[2]}.dmg"

		if [[ -f "${installer_dmgs_path}/${this_installer_dmg_name}" ]]; then
			echo "\"${this_installer_dmg_name}\" is up-to-date!"
		else
			echo "\"${this_installer_dmg_name}\" needs to be downloaded..."
			rm -f "${installer_dmgs_path}/Install ${this_installer_info[0]} "*'.dmg' # Delete any outdated installer dmgs.

			mist_download_options=( 'download' 'installer' "${this_installer_info[2]}" 'image' )

			if [[ "${this_installer_name_to_download}" == *' '[Bb][Ee][Tt][Aa] ]]; then
				mist_download_options+=( '-b' )
			fi

			if [[ -n "${catalog_url}" ]]; then
				mist_download_options+=( '-c' "${catalog_url}" )
			fi

			mist_download_options+=( '-o' "${installer_dmgs_path}" )

			run_as_sudo_if_needed "${MIST_PATH}" "${mist_download_options[@]}"
		fi
	else
		echo "\"${this_installer_name_to_download}\" WAS NOT FOUND: $(declare -p this_installer_info | cut -d '=' -f 2-)"
	fi
done

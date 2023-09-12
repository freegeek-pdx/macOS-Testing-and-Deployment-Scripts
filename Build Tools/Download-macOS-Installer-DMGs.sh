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

installer_dmgs_path="${HOME}/Documents/Programming/Free Geek/MacLand Images/macOS Installers"

declare -a installer_names_to_download=( 'Big Sur' 'Monterey' 'Ventura' 'Sonoma beta' ) # NOT including 'High Sierra' 'Mojave' 'Catalina' anymore since the latest installers are already downloaded and they will never get any new updates.

for this_installer_name_to_download in "${installer_names_to_download[@]}"; do
	catalog_url='https://swscan.apple.com/content/catalogs/others/index-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog'

	mist_list_options=( 'list' 'installer' "${this_installer_name_to_download}" )
	if [[ "${this_installer_name_to_download}" == *' beta' ]]; then
		catalog_url='https://swscan.apple.com/content/catalogs/others/index-14seed-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz'
		mist_list_options+=( '-b' )
	fi
	mist_list_options+=( '-c' "${catalog_url}" '-lqo' 'json' )

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
			if [[ "${this_installer_name_to_download}" == *' beta' ]]; then
				mist_download_options+=( '-b' )
			fi
			mist_download_options+=( '-c' "${catalog_url}" '-o' "${installer_dmgs_path}" )

			sudo "${MIST_PATH}" "${mist_download_options[@]}"
		fi
	else
		echo "\"${this_installer_name_to_download}\" WAS NOT FOUND: $(declare -p this_installer_info | cut -d '=' -f 2-)"
	fi
done

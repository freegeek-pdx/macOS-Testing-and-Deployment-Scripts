#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 8/9/22.
#
# MIT License
#
# Copyright (c) 2022 Free Geek
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

serial_number="$1" # Use a specified serial number from the first argument.

if [[ -z "$1" ]]; then # Get the current Mac serial number if no argument specified.
	serial_number="$(/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null)"
fi

# The following URLs were discovered from examining how "https://support.apple.com/specs/${serial_number}" loads the specs URL via JavaScript (as of August 9th, 2022 in case this breaks in the future).

serial_search_results_json="$(curl -m 5 -sfL "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=${serial_number}" 2> /dev/null)"

if [[ -z "${serial_search_results_json}" ]]; then
	>&2 echo 'INTERNET REQUIRED - SERIAL SEARCH FAILED'
	exit 1
fi

IFS=$'\n' read -rd '' -a serial_search_results_values < <(osascript -l 'JavaScript' -e '
function run(argv) {
	const serialSearchResultsDict = JSON.parse(argv[0])
	return [serialSearchResultsDict.name, serialSearchResultsDict.id, serialSearchResultsDict.parent, serialSearchResultsDict.grandparent, serialSearchResultsDict.greatgrandparent].join("\n")
}
' -- "${serial_search_results_json}" 2> /dev/null)
# NOTE: Because of JavaScript behavior, any "undefined" (or "null") values in an array would be turned into empty strings when using "join", making them empty lines.
# And, because of bash behaviors with whitespace IFS treating consecutive whitespace as a single delimiter (explained in https://mywiki.wooledge.org/IFS),
# any empty lines will NOT be included in the bash array being created with this technique to set all lines to an array.
# So, that means if any of these values are not found, the bash array WILL NOT have a count of exactly 5 which we can check to verify all required values were properly loaded.

if (( ${#serial_search_results_values[@]} != 5 )); then
	>&2 echo "UNEXPECTED ERROR - SERIAL SEARCH DOES NOT CONTAIN EXPECTED/REQUIRED VALUES: $(declare -p serial_search_results_values | cut -d '=' -f 2-)"
	exit 2
fi

specs_search_results_json="$(curl -m 5 -sfL "https://km.support.apple.com/kb/index?page=specs_browse&category=${serial_search_results_values[1]}&parent=${serial_search_results_values[2]}&grandparent=${serial_search_results_values[3]}&greatgrandparent=${serial_search_results_values[4]}" 2> /dev/null)"

if [[ -z "${specs_search_results_json}" ]]; then
	>&2 echo 'INTERNET REQUIRED - SPECS SEARCH FAILED'
	exit 3
fi

specs_url_kb_part="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).specs[0].url' -- "${specs_search_results_json}" 2> /dev/null)"

if [[ -z "${specs_url_kb_part}" ]]; then
	>&2 echo 'UNEXPECTED ERROR - SPECS SEARCH DOES NOT CONTAIN KB SPECS URL'
	exit 4
fi

specs_url="https://support.apple.com${specs_url_kb_part}"

echo "Specs URL for \"${serial_search_results_values[0]}\": ${specs_url}"

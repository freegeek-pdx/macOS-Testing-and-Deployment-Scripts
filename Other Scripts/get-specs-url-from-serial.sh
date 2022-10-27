#!/bin/bash

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

get_json_value() {
	# $1: JSON string OR file path to parse (tested to work with up to 1GB string and 2GB file).
	# $2: JSON key path to look up (using dot or bracket notation).
    # This code is originally based on: https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts
	printf '%s' "$1" | /usr/bin/osascript -l 'JavaScript' \
		-e "let json = $.NSString.alloc.initWithDataEncoding($.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile$(/usr/bin/uname -r | /usr/bin/awk -F '.' '($1 > 18) { print "AndReturnError(ObjC.wrap())" }'), $.NSUTF8StringEncoding)" \
		-e 'if ($.NSFileManager.defaultManager.fileExistsAtPath(json)) json = $.NSString.stringWithContentsOfFileEncodingError(json, $.NSUTF8StringEncoding, ObjC.wrap())' \
		-e "const value = JSON.parse(json.js)$([ -n "${2%%[.[]*}" ] && echo '.')$2" \
		-e 'if (typeof value === "object") { JSON.stringify(value, null, 4) } else { value }'
}

serial_number="$1" # Use a specified serial number from the first argument.

if [[ -z "$1" ]]; then # Get the current Mac serial number if no argument specified.
    serial_number="$(/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null)"
fi

# The following URLs were discovered from examining how "https://support.apple.com/specs/${serial_number}" loads the specs URL via JavaScript (as of August 9th, 2022 in case this breaks in the future).

serial_search_results="$(curl -m 5 -sL "https://km.support.apple.com/kb/index?page=categorydata&serialnumber=${serial_number}" 2> /dev/null)"

if [[ -z "${serial_search_results}" ]]; then
    >&2 echo 'INTERNET REQUIRED - SERIAL SEARCH FAILED'
    exit 1
fi

marketing_model_name="$(get_json_value "${serial_search_results}" 'name')"
category_id="$(get_json_value "${serial_search_results}" 'id')"
parent_id="$(get_json_value "${serial_search_results}" 'parent')"
grand_parent_id="$(get_json_value "${serial_search_results}" 'grandparent')"
great_grand_parent_id="$(get_json_value "${serial_search_results}" 'greatgrandparent')"

if [[ -z "${marketing_model_name}" || -z "${category_id}" || -z "${parent_id}" || -z "${grand_parent_id}" || -z "${great_grand_parent_id}" ]]; then
    >&2 echo 'UNEXPECTED ERROR - SERIAL SEARCH DOES NOT CONTAIN EXPECTED/REQUIRED VALUES'
    exit 2
fi

specs_search_results="$(curl -m 5 -sL "https://km.support.apple.com/kb/index?page=specs_browse&category=${category_id}&parent=${parent_id}&grandparent=${grand_parent_id}&greatgrandparent=${great_grand_parent_id}" 2> /dev/null)"

if [[ -z "${specs_search_results}" ]]; then
    >&2 echo 'INTERNET REQUIRED - SPECS SEARCH FAILED'
    exit 3
fi

specs_url_kb_part="$(get_json_value "${specs_search_results}" 'specs[0].url')"

if [[ -z "${specs_url_kb_part}" ]]; then
    >&2 echo 'UNEXPECTED ERROR - SPECS SEARCH DOES NOT CONTAIN KB SPECS URL'
    exit 4
fi

specs_url="https://support.apple.com${specs_url_kb_part}"

echo "Specs URL for \"${marketing_model_name}\": ${specs_url}"

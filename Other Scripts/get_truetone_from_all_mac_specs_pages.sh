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

declare -a all_mac_identification_pages=() # All Mac identification pages are listed on https://support.apple.com/102604 as well as in the "Product or packaging" section of https://support.apple.com/102767
all_mac_identification_pages+=( '108052' ) # MacBook Pro
all_mac_identification_pages+=( '102869' ) # MacBook Air
all_mac_identification_pages+=( '103257' ) # MacBook
all_mac_identification_pages+=( '108054' ) # iMac
#all_mac_identification_pages+=( '102852' ) # Mac mini
#all_mac_identification_pages+=( '102231' ) # Mac Studio
#all_mac_identification_pages+=( '102887' ) # Mac Pro

every_truetone_model=''

for this_mac_idenification_page in "${all_mac_identification_pages[@]}"; do
	this_mac_idenification_page_source="$(curl -m 5 -sfL "https://support.apple.com/${this_mac_idenification_page}")"

	this_model_identifier=''
	while IFS='' read -r this_model_id_or_specs_url; do
		if [[ "${this_model_id_or_specs_url}" == 'https://'* ]]; then
			echo " (${this_model_id_or_specs_url}):"
			truetone_element_from_page="$(curl -m 5 -sfL "${this_model_id_or_specs_url}" | xmllint --html --xpath 'string(//*[contains(text(),"True") and contains(text(),"Tone")])' - 2> /dev/null)" # NOTE: Check for each word separately to handle with or without a non-breaking space between the words.
			if [[ -n "${truetone_element_from_page}" ]]; then
				echo "Supports True Tone"
				every_truetone_model+="${this_model_identifier}+"
			else
				echo "DOES NOT SUPPORT True Tone"
			fi
		elif [[ "${this_model_id_or_specs_url}" == *','* ]]; then
			this_model_identifier="${this_model_id_or_specs_url}"
			echo -en "\n\n${this_model_identifier}"
		fi
	done < <(echo "${this_mac_idenification_page_source}" | sed s'/<\/p><p/<\/p>\n<p/g' | awk -F ':|"' '/Model Identifier:/ { gsub("&nbsp;", " ", $NF); gsub(", ", "+", $NF); gsub("; ", "+", $NF); gsub(" ", "", $NF); gsub("</b>", "", $NF); gsub("</p>", "", $NF); print ""; print $NF } /Tech Specs/ { for (f = 1; f <= NF; f ++) { if (($f ~ /support.apple.com/) && !($f ~ /\/specs$/)) { print "https:" $f; break } else if (($f ~ /^\//) && !($f ~ /\./)) { print "https://support.apple.com" $f; break } } }')
	# echo "${this_mac_idenification_page_source}" | xmllint --html --xpath '//a[contains(@href,"/kb/SP")]/@href' - 2> /dev/null | tr '"' '\n' | grep '/kb/SP' | sort -ur
done

echo -e "\n\nSupports True Tone"
every_truetone_model="$(echo "${every_truetone_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_truetone_model//$'\n'/", "}\""

echo ''

# Example output from 5/15/25:

# Supports True Tone
# "Mac14,2", "Mac14,5", "Mac14,6", "Mac14,7", "Mac14,9", "Mac14,10", "Mac14,15", "Mac15,3", "Mac15,4", "Mac15,5", "Mac15,6", "Mac15,7", "Mac15,8", "Mac15,9", "Mac15,10", "Mac15,11", "Mac15,12", "Mac15,13", "Mac16,1", "Mac16,2", "Mac16,3", "Mac16,5", "Mac16,6", "Mac16,7", "Mac16,8", "Mac16,12", "Mac16,13", "MacBookAir8,2", "MacBookAir9,1", "MacBookAir10,1", "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4", "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro16,4", "MacBookPro17,1", "MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4", "iMac20,1", "iMac20,2", "iMac21,1", "iMac21,2"
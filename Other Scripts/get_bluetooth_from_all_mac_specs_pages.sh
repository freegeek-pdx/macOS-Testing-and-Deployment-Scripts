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
all_mac_identification_pages+=( '102852' ) # Mac mini
all_mac_identification_pages+=( '102231' ) # Mac Studio
all_mac_identification_pages+=( '102887' ) # Mac Pro

every_bluetooth_version=''

every_bluetooth_5dot3_model=''
every_bluetooth_5_model=''
every_bluetooth_4dot2_model=''
every_bluetooth_4_model='Macmini5,3+' # Mid 2011 Mac mini Server (Macmini5,3) is not listed in the Specs pages.
every_bluetooth_2dot1plusEDR_model='MacBookPro4,1+MacBookPro5,1+'
every_bluetooth_other_version_model=''
every_error_model=''

for this_mac_idenification_page in "${all_mac_identification_pages[@]}"; do
	this_mac_idenification_page_source="$(curl -m 5 -sfL "https://support.apple.com/${this_mac_idenification_page}")"

	this_model_identifier=''
	while IFS='' read -r this_model_id_or_specs_url; do
		if [[ "${this_model_id_or_specs_url}" == 'https://'* ]]; then
			echo " (${this_model_id_or_specs_url}):"
			specs_page_source="$(curl -m 5 -sfL "${this_model_id_or_specs_url}")"
			bluetooth_element_from_page="$(echo "${specs_page_source}" | xmllint --html --xpath '(//li[contains(text(),"Bluetooth") and contains(text(),".")]/text())[last()]' - 2> /dev/null)"

			if [[ -z "${bluetooth_element_from_page}" ]]; then
				bluetooth_element_from_page="$(echo "${specs_page_source}" | xmllint --html --xpath '(//p[contains(text(),"Bluetooth") and contains(text(),".")]/text())[last()]' - 2> /dev/null)"
			fi

			if [[ -z "${bluetooth_element_from_page}" ]]; then
				echo 'ERROR DETECTING BLUETOOTH FOR MODEL'
				every_error_model+="${this_model_identifier}+"
			else
				bluetooth_version="$(echo "${bluetooth_element_from_page}" | tr -dc '[:digit:].')"

				if [[ "${bluetooth_version}" == '.'* ]]; then
					bluetooth_version="${bluetooth_version#.}"
				fi

				if [[ "${bluetooth_element_from_page}" == *'EDR'* ]]; then
					bluetooth_version+=' + EDR'
				fi

				case "${bluetooth_version}" in
					'5.3')
						every_bluetooth_5dot3_model+="${this_model_identifier}+"
						;;
					'5.0')
						every_bluetooth_5_model+="${this_model_identifier}+"
						;;
					'4.2')
						every_bluetooth_4dot2_model+="${this_model_identifier}+"
						;;
					'4.0')
						every_bluetooth_4_model+="${this_model_identifier}+"
						;;
					'2.1 + EDR')
						every_bluetooth_2dot1plusEDR_model+="${this_model_identifier}+"
						;;
					*)
						every_bluetooth_other_version_model+="${this_model_identifier}+"
						;;
				esac

				every_bluetooth_version+=$'\n'"${bluetooth_version}"

				echo "Bluetooth ${bluetooth_version}"
			fi
		elif [[ "${this_model_id_or_specs_url}" == *','* ]]; then
			this_model_identifier="${this_model_id_or_specs_url}"
			echo -en "\n\n${this_model_identifier}"
		fi
	done < <(echo "${this_mac_idenification_page_source}" | sed s'/<\/p><p/<\/p>\n<p/g' | awk -F ':|"' '/Model Identifier:/ { gsub("&nbsp;", " ", $NF); gsub(", ", "+", $NF); gsub("; ", "+", $NF); gsub(" ", "", $NF); gsub("</b>", "", $NF); gsub("</p>", "", $NF); print ""; print $NF } /Tech Specs/ { for (f = 1; f <= NF; f ++) { if (($f ~ /support.apple.com/) && !($f ~ /\/specs$/)) { print "https:" $f; break } else if (($f ~ /^\//) && !($f ~ /\./)) { print "https://support.apple.com" $f; break } } }')
	# echo "${this_mac_idenification_page_source}" | xmllint --html --xpath '//a[contains(@href,"/kb/SP")]/@href' - 2> /dev/null | tr '"' '\n' | grep '/kb/SP' | sort -ur
done

echo -e '\n\nEvery Bluetooth Verison'
echo "${every_bluetooth_version}" | sort -urV

echo 'Bluetooth 5.3'
every_bluetooth_5dot3_model="$(echo "${every_bluetooth_5dot3_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_bluetooth_5dot3_model//$'\n'/", "}\""

echo -e '\nBluetooth 5.0'
every_bluetooth_5_model="$(echo "${every_bluetooth_5_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_bluetooth_5_model//$'\n'/", "}\""

echo -e '\nBluetooth 4.2'
every_bluetooth_4dot2_model="$(echo "${every_bluetooth_4dot2_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_bluetooth_4dot2_model//$'\n'/", "}\""

echo -e '\nBluetooth 4.0'
every_bluetooth_4_model="$(echo "${every_bluetooth_4_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_bluetooth_4_model//$'\n'/", "}\""

echo -e '\nBluetooth 2.1 + EDR'
every_bluetooth_2dot1plusEDR_model="$(echo "${every_bluetooth_2dot1plusEDR_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_bluetooth_2dot1plusEDR_model//$'\n'/", "}\""

echo -e '\nBluetooth OTHER VERSION'
every_bluetooth_other_version_model="$(echo "${every_bluetooth_other_version_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_bluetooth_other_version_model//$'\n'/", "}\""

echo -e '\nERROR DETECTING BLUETOOTH'
every_error_model="$(echo "${every_error_model%+}" | tr '+' '\n' | sort -uV)"
echo "\"${every_error_model//$'\n'/", "}\""

echo ''

# Example output from 5/15/25:

# Every Bluetooth Verison
# 5.3
# 5.0
# 4.2
# 4.0
# 2.1 + EDR

# Bluetooth 5.3
# "Mac14,2", "Mac14,3", "Mac14,5", "Mac14,6", "Mac14,8", "Mac14,9", "Mac14,10", "Mac14,12", "Mac14,13", "Mac14,14", "Mac14,15", "Mac15,3", "Mac15,4", "Mac15,5", "Mac15,6", "Mac15,7", "Mac15,8", "Mac15,9", "Mac15,10", "Mac15,11", "Mac15,12", "Mac15,13", "Mac15,14", "Mac16,1", "Mac16,2", "Mac16,3", "Mac16,5", "Mac16,6", "Mac16,7", "Mac16,8", "Mac16,9", "Mac16,10", "Mac16,11", "Mac16,12", "Mac16,13"

# Bluetooth 5.0
# "Mac13,1", "Mac13,2", "Mac14,7", "MacBookAir9,1", "MacBookAir10,1", "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4", "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro16,4", "MacBookPro17,1", "MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4", "MacPro7,1", "Macmini8,1", "Macmini9,1", "iMac20,1", "iMac20,2", "iMac21,1", "iMac21,2", "iMacPro1,1"

# Bluetooth 4.2
# "MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookPro11,4", "MacBookPro11,5", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3", "iMac18,1", "iMac18,2", "iMac18,3", "iMac19,1", "iMac19,2"

# Bluetooth 4.0
# "MacBook8,1", "MacBook9,1", "MacBookAir4,1", "MacBookAir4,2", "MacBookAir5,1", "MacBookAir5,2", "MacBookAir6,1", "MacBookAir6,2", "MacBookAir7,1", "MacBookAir7,2", "MacBookPro9,1", "MacBookPro9,2", "MacBookPro10,1", "MacBookPro10,2", "MacBookPro11,1", "MacBookPro11,2", "MacBookPro11,3", "MacBookPro12,1", "MacPro6,1", "Macmini5,1", "Macmini5,2", "Macmini5,3", "Macmini6,1", "Macmini6,2", "Macmini7,1", "iMac13,1", "iMac13,2", "iMac14,1", "iMac14,2", "iMac14,4", "iMac15,1", "iMac16,1", "iMac16,2", "iMac17,1"

# Bluetooth 2.1 + EDR
# "MacBook5,2", "MacBook6,1", "MacBook7,1", "MacBookAir2,1", "MacBookAir3,1", "MacBookAir3,2", "MacBookPro4,1", "MacBookPro5,1", "MacBookPro5,2", "MacBookPro5,3", "MacBookPro5,5", "MacBookPro6,1", "MacBookPro6,2", "MacBookPro7,1", "MacBookPro8,1", "MacBookPro8,2", "MacBookPro8,3", "MacPro4,1", "MacPro5,1", "Macmini3,1", "Macmini4,1", "iMac9,1", "iMac10,1", "iMac11,2", "iMac11,3", "iMac12,1", "iMac12,2"

# Bluetooth OTHER VERSION
# ""

# ERROR DETECTING BLUETOOTH
# ""

#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

get_marketing_model_name() {
	##
	## Created by Pico Mitchell (of Free Geek)
	##
	## Version: 2023.11.8-1
	##
	## MIT License
	##
	## Copyright (c) 2021 Free Geek
	##
	## Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
	## to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
	## and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
	##
	## The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
	##
	## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	## WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	##

	local PATH='/usr/bin:/bin:/usr/sbin:/sbin'

	# THE NEXT 3 VARIABLES CAN OPTIONALLY BE SET TO "true" MANUALLY OR BY PASSING THE SPECIFIED ARGUMENTS TO THIS FUNCTION TO ALTER THE OUTPUT:
	local VERBOSE_LOGGING=false # Set to "true" or pass "v" argument for logging to stderr to see how the Marketing Model Name is being loaded and if and where it is being cached as well as other debug info.
	local ALWAYS_INCLUDE_MODEL_ID=false # Set to "true" or pass "i" argument if you want to always include the Model ID in the output after the Marketing Model Name (it will be included in the output from this script but it won't be cached to not alter the "About This Mac" model name).
	local INCLUDE_MODEL_PART_NUMBER=false # Set to "true" or pass "p" argument if you want to include the "M####LL/A" style Model Part Number in the output after the Marketing Model Name for T2 and Apple Silicon Macs (it will be included in the output from this script but it won't be cached to not alter the "About This Mac" model name).

	local this_option
	local OPTIND=1
	while getopts 'vip' this_option; do
		case "${this_option}" in
			'v') VERBOSE_LOGGING=true ;;
			'i') ALWAYS_INCLUDE_MODEL_ID=true ;;
			'p') INCLUDE_MODEL_PART_NUMBER=true ;;
			*) return 1 ;; # This matches any invalid options and "getopts" will output an error, so we don't need to.
		esac
	done
	readonly VERBOSE_LOGGING
	readonly ALWAYS_INCLUDE_MODEL_ID
	readonly INCLUDE_MODEL_PART_NUMBER

	local MODEL_IDENTIFIER
	MODEL_IDENTIFIER="$(sysctl -n hw.model 2> /dev/null)"
	if [[ -z "${MODEL_IDENTIFIER}" ]]; then MODEL_IDENTIFIER='UNKNOWN Model Identifier'; fi # This should never happen, but will result in some useful feedback if somehow "sysctl" fails to return a Model Identifier.
	readonly MODEL_IDENTIFIER
	if $VERBOSE_LOGGING; then >&2 echo "DEBUG - MODEL ID: ${MODEL_IDENTIFIER}"; fi

	local IS_APPLE_SILICON
	IS_APPLE_SILICON="$([[ "$(sysctl -in hw.optional.arm64)" == '1' ]] && echo 'true' || echo 'false')"
	readonly IS_APPLE_SILICON

	local IS_VIRTUAL_MACHINE
	# "machdep.cpu.features" is always EMPTY on Apple Silicon (whether or not it's a VM) so it cannot be used to check for the "VMM" feature flag when the system is a VM,
	# but I examined the full "sysctl -a" output when running a VM on Apple Silicon and found that "kern.hv_vmm_present" is set to "1" when running a VM and "0" when not.
	# Though testing, I found the "kern.hv_vmm_present" key is also the present on Intel Macs starting with macOS version macOS 11 Big Sur and gets properly set to "1"
	# on Intel VMs, but still check for either since "kern.hv_vmm_present" is not available on every version of macOS that this script may be run on.
	IS_VIRTUAL_MACHINE="$([[ " $(sysctl -in machdep.cpu.features) " == *' VMM '* || "$(sysctl -in kern.hv_vmm_present)" == '1' ]] && echo 'true' || echo 'false')"
	readonly IS_VIRTUAL_MACHINE
	if $VERBOSE_LOGGING; then >&2 echo "DEBUG - IS VM: ${IS_VIRTUAL_MACHINE}"; fi

	local possible_marketing_model_name
	local marketing_model_name

	if $IS_APPLE_SILICON; then
		# This local Marketing Model Name within "ioreg" only exists on Apple Silicon Macs.
		if $VERBOSE_LOGGING; then >&2 echo 'DEBUG - LOADING FROM IOREG ON APPLE SILICON'; fi
		possible_marketing_model_name="$(/usr/libexec/PlistBuddy -c 'Print :0:product-name' /dev/stdin <<< "$(ioreg -arc IOPlatformDevice -k product-name)" 2> /dev/null | tr -d '[:cntrl:]')" # Remove control characters because this decoded value could end with a NUL char.

		if $IS_VIRTUAL_MACHINE; then
			# It appears that Apple Silicon Virtual Machines will always output "Apple Virtual Machine 1" as their local Marketing Model Name from the previous "ioreg" command.
			# I'm not sure if that trailing "1" could ever be another number and whether it indicates some version or what.
			# But, if the retrieved local Marketing Model Name contains "Virtual Machine", we will only output "Apple Silicon Virtual Machine" instead to be more specific instead.
			# If this ever changes in the future and the local Marketing Model Name DOES NOT contain "Virtual Machine", then the retrieved local Marketing Model Name will
			# ALSO be displayed like "Apple Silicon Virtual Machine: [LOCAL MARKETING MODEL NAME]" to give the most possible info, like is done for Intel Virtual Machines.

			marketing_model_name='Apple Silicon Virtual Machine'

			if [[ -n "${possible_marketing_model_name}" && "${possible_marketing_model_name}" != *'Virtual Machine'* ]]; then
				marketing_model_name+=": ${possible_marketing_model_name}"
			fi
		else
			marketing_model_name="${possible_marketing_model_name}"
		fi
	else
		local SERIAL_NUMBER
		SERIAL_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :0:IOPlatformSerialNumber' /dev/stdin <<< "$(ioreg -arc IOPlatformExpertDevice -k IOPlatformSerialNumber -d 1)" 2> /dev/null)"
		readonly SERIAL_NUMBER
		if $VERBOSE_LOGGING; then >&2 echo "DEBUG - SERIAL: ${SERIAL_NUMBER}"; fi

		local SERIAL_CONFIG_CODE=''
		if [[ -n "${SERIAL_NUMBER}" ]]; then
			local serial_number_length="${#SERIAL_NUMBER}"
			if (( serial_number_length == 11 || serial_number_length == 12 )); then
				# The Configuration Code part of the Serial Number which indicates the model is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials (which are very old and shouldn't actually be encountered: https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/).
				# Starting with the 2021 MacBook Pro models, randomized 10 character Serial Numbers are now used which do not have any model specific characters, but those Macs will never get here or need to load the Marketing Model Name over the internet since they are Apple Silicon and the local Marketing Model Name will have been retrieved above.
				SERIAL_CONFIG_CODE="${SERIAL_NUMBER:8}"
				if $VERBOSE_LOGGING; then >&2 echo "DEBUG - SERIAL CONFIG CODE: ${SERIAL_CONFIG_CODE}"; fi
			fi
		fi
		readonly SERIAL_CONFIG_CODE

		# The following list of Marketing Model Names with grouped Model IDs and Serial Config Codes is generated from: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/group_every_intel_mac_marketing_model_name_with_model_ids_and_serial_config_codes.sh
		every_intel_mac_marketing_model_name_with_grouped_model_ids_and_serial_config_codes='iMac (17-inch, Early 2006):iMac4,1:U2N:U2R:V4M:V4N:V4U:V66:VGB:VGZ:VH1:VHP:VV4:VV6:
iMac (17-inch, Late 2006 CD):iMac5,2:
iMac (17-inch, Late 2006):iMac5,1:AC1:VUX:VUY:WAR:WRR:WRW:WV8:WVR:X1A:X1W:X2W:X6Q:X9F:X9Y:XLF:Y3V:Y3W:Y3X:Y6K:Y94:Y97:YAG:YLJ:
iMac (17-inch, Mid 2006):iMac4,2:
iMac (20-inch, Early 2006):iMac4,1:U2P:U2S:V4P:V4Q:V4R:V67:VGC:VGM:VH0:VH2:VW4:VX0:WXN:X0U:
iMac (20-inch, Early 2008):iMac8,1:28B:2PN:2PR:3FF:3FG:3SZ:5A8:5J0:6F9:8R2:8R3:ZE2:ZE3:ZE5:ZE6:
iMac (20-inch, Early 2009):iMac9,1:0TF:0TH:6X0:8M5:8TS:8TT:9EX:9LN:
iMac (20-inch, Late 2006):iMac5,1:VUV:VUW:WRS:WRX:WSD:X0E:X29:X6S:X9E:X9G:XA4:XCR:XCY:Y3R:Y3U:Y9B:YAE:YDW:
iMac (20-inch, Mid 2007):iMac7,1:02X:09Q:0PQ:0PR:0PT:0U1:1NU:1NV:3PB:X85:X86:X87:X88:Z58:Z9G:ZEG:ZFD:
iMac (20-inch, Mid 2009):iMac9,1:6MH:6MJ:9TH:BAH:DMV:DWY:E86:FUN:FXN:GM9:H1S:HS6:HS7:HT6:HUE:
iMac (21.5-inch, 2017):iMac18,1:
iMac (21.5-inch, Early 2013):iMac13,3:
iMac (21.5-inch, Late 2009):iMac10,1:5PC:5PK:B9S:B9U:CY8:DMW:DMX:DWR:DWU:E8D:E8E:E8F:F0G:F0H:FQH:FU1:H9K:HDF:
iMac (21.5-inch, Late 2011):iMac12,1:DKL9:DKLH:DPNK:DPNW:
iMac (21.5-inch, Late 2012):iMac13,1:
iMac (21.5-inch, Late 2013):iMac14,1:iMac14,3:
iMac (21.5-inch, Late 2015):iMac16,1:iMac16,2:GF1J:GF1K:GF1L:GF1M:GG77:GG79:GG7D:GG7G:H0N6:H0P6:H1DX:H1DY:H1F1:H1F2:H1WR:H25M:H2KW:H8KX:HHMG:HQ9T:HQ9V:HQ9W:HYGQ:J0DG:J0DH:J0DJ:
iMac (21.5-inch, Mid 2010):iMac11,2:
iMac (21.5-inch, Mid 2011):iMac12,1:DHJF:DHJN:DHJR:DHJT:DL8M:DL8N:DMP0:DNWY:DPM0:DPNT:DWTP:DWTQ:F611:
iMac (21.5-inch, Mid 2014):iMac14,4:
iMac (24-inch, Early 2008):iMac8,1:0KM:0N4:1LW:28A:2E4:2NX:2PT:39S:3F9:3FH:3GS:3NX:5J1:5U6:6J3:6J6:6ZC:ZE4:ZE7:
iMac (24-inch, Early 2009):iMac9,1:0TG:0TJ:0TL:0TM:250:259:6X1:6X2:6X3:8M6:8XH:9ET:9F3:9LP:9LQ:9LR:9LS:E1B:
iMac (24-inch, Late 2006):iMac6,1:
iMac (24-inch, Mid 2007):iMac7,1:0PL:0PM:0PN:0PP:0PU:1NW:1SC:2CB:3PA:X89:X8A:Z59:Z9F:ZCR:ZCT:ZCV:ZCW:ZEF:ZGH:ZGP:
iMac (27-inch, Late 2009):iMac10,1:iMac11,1:5PE:5PJ:5PM:5RU:CYB:CYC:D4V:DMY:DMZ:DWZ:E1J:F0J:F0K:GRP:H9L:H9N:H9P:H9R:
iMac (27-inch, Late 2012):iMac13,2:
iMac (27-inch, Late 2013):iMac14,2:
iMac (27-inch, Mid 2010):iMac11,3:
iMac (27-inch, Mid 2011):iMac12,2:
iMac (Retina 4K, 21.5-inch, 2017):iMac18,2:
iMac (Retina 4K, 21.5-inch, 2019):iMac19,2:
iMac (Retina 4K, 21.5-inch, Late 2015):iMac16,2:GG78:GG7C:GG7F:GG7H:H0KF:H0P7:H15R:H1F3:H1F5:H1F7:H1F8:H1F9:H25N:H28H:H3RJ:H8KY:H8L0:H8L1:H8L2:H8L3:HLWV:
iMac (Retina 5K, 27-inch, 2017):iMac18,3:
iMac (Retina 5K, 27-inch, 2019):iMac19,1:
iMac (Retina 5K, 27-inch, 2020):iMac20,1:iMac20,2:
iMac (Retina 5K, 27-inch, Late 2014):iMac15,1:FY11:FY14:FY68:FY6F:GCTM:GDQY:GDR3:GDR4:GDR5:GDR6:GDR7:GDR8:GDR9:GDRC:GFFQ:GJDM:GJDN:GJDP:GJDQ:GPJN:GV7V:H5DN:H682:
iMac (Retina 5K, 27-inch, Late 2015):iMac17,1:
iMac (Retina 5K, 27-inch, Mid 2015):iMac15,1:FY10:FY13:FY67:FY6D:GL1Q:GL1R:GL1T:GL1V:GL1W:
iMac Pro (2017):iMacPro1,1:
Mac mini (2018):Macmini8,1:
Mac mini (Early 2006):Macmini1,1:U35:U36:U38:U39:VJN:VLK:VS5:VS7:VU2:VU4:WBZ:WCU:WEN:
Mac mini (Early 2009):Macmini3,1:19X:19Y:1BU:1BV:8NC:92G:9RR:9RS:AFR:BAV:
Mac mini (Late 2006):Macmini1,1:W0A:W0B:W0C:W0D:WKN:X1X:X1Y:X1Z:X20:XAS:Y9E:
Mac mini (Late 2009):Macmini3,1:306:307:9G5:9G6:9G7:9G8:AFK:B9X:CS6:DMG:DMH:F6J:
Mac mini (Late 2012):Macmini6,1:Macmini6,2:DWYL:DWYM:DY3G:DY3H:F9RK:F9RL:F9RM:F9VV:F9VW:F9W0:F9W1:F9W2:FD9G:FD9H:FD9J:FD9K:FDWK:FGML:FRFP:FW56:FW57:G430:
Mac mini (Late 2014):Macmini7,1:
Mac mini (Mid 2007):Macmini2,1:
Mac mini (Mid 2010):Macmini4,1:DD6H:DD6L:DDQ9:DDVN:DFDK:
Mac mini (Mid 2011):Macmini5,1:Macmini5,2:
Mac mini Server (Late 2012):Macmini6,2:DWYN:DY3J:F9VY:F9W3:FC08:FCCW:FP14:FP39:
Mac mini Server (Mid 2010):Macmini4,1:DD6K:DD6N:DDJF:
Mac mini Server (Mid 2011):Macmini5,3:
Mac Pro (2019):MacPro7,1:K7GD:K7GF:NYGV:P7QJ:P7QK:P7QL:P7QM:P7QN:P7QP:PLXV:PLXW:PLXX:PLXY:
Mac Pro (Early 2008):MacPro3,1:
Mac Pro (Early 2009):MacPro4,1:20G:20H:4PC:4PD:7BF:8MC:8PZ:8Q0:8TR:8TU:8XG:8XL:93H:9EU:9EV:9MC:9MD:9MG:9MJ:9MK:9ML:9QK:ANS:BXD:BXE:BXT:CZ2:CZ3:CZ4:E1C:E1D:E1E:EAA:EYX:EYY:F6H:GYH:
Mac Pro (Late 2013):MacPro6,1:
Mac Pro (Mid 2010):MacPro5,1:EUE:EUF:EUG:EUH:GWR:GY5:GZH:GZJ:GZK:GZL:GZM:H0X:H2N:H2P:H97:H99:HF7:HF8:HF9:HFA:HFC:HFD:HFF:HFG:HFJ:HFK:HFL:HFN:HG1:HG3:HP9:HPA:
Mac Pro (Mid 2012):MacPro5,1:F4MC:F4MD:F4MG:F4MH:F4YY:F500:F648:F649:F64C:F64D:F64F:F6T9:F6TC:F6TD:F6TF:F6TG:
Mac Pro (Rack, 2019):MacPro7,1:N5RH:N5RN:P7QQ:P7QR:P7QT:P7QV:PNTN:PNTP:PNTQ:PP3Y:
Mac Pro Server (Mid 2010):MacPro5,1:HPV:HPW:HPY:
Mac Pro Server (Mid 2012):MacPro5,1:F4MF:F4MJ:F501:
Mac Pro:MacPro1,1:MacPro2,1:
MacBook (13-inch):MacBook1,1:
MacBook (13-inch, Aluminum, Late 2008):MacBook5,1:
MacBook (13-inch, Early 2008):MacBook4,1:0P0:0P1:0P2:0P4:0P5:0P6:1LX:1PX:1Q2:1Q7:1QA:1QB:1QE:1ZY:27H:27J:28C:28D:28E:385:3N9:3NA:3ND:3NE:3NF:3X6:47Z:4R7:4R8:
MacBook (13-inch, Early 2009):MacBook5,2:4R1:4R2:4R3:79D:79E:79F:7A2:85D:88J:8CP:8SJ:93K:
MacBook (13-inch, Late 2006):MacBook2,1:WGK:WGL:WGM:WGN:WGP:WGQ:WGS:WGT:WGU:WVN:X6G:X6H:X6J:X6K:X6L:X7X:X97:X98:XAR:XAT:XC5:XDN:XDR:XDS:XDT:XDU:XDV:XDW:XDX:XDY:XDZ:XE0:XE1:XE2:XE3:XHB:XHC:XKT:XMF:Y6L:Y6M:Y9A:YCU:
MacBook (13-inch, Late 2007):MacBook3,1:
MacBook (13-inch, Late 2008):MacBook4,1:3VY:5AQ:5HS:5HU:67C:6ES:6HY:6LL:6LM:6M1:6V9:6YP:7XD:
MacBook (13-inch, Late 2009):MacBook6,1:
MacBook (13-inch, Mid 2007):MacBook2,1:YA2:YA3:YA4:YA5:YA6:YA7:YA8:YA9:YJJ:YJK:YJL:YJM:YJN:YQ7:YQ8:YRG:YRH:YRJ:YRK:YSH:YSJ:YSK:YSL:YSM:YTK:YTL:YV8:YX1:YX2:YX4:YX5:YXZ:YY1:YYW:Z5V:Z5W:Z5X:Z5Y:Z5Z:Z60:Z88:ZA8:ZA9:ZAP:ZAQ:ZAS:ZAU:ZAV:ZAW:ZAX:ZAY:ZAZ:ZB0:ZB1:ZB2:ZB7:ZB8:ZB9:ZBA:ZBB:ZBE:ZBF:ZBG:ZBH:ZBJ:ZBK:ZCN:
MacBook (13-inch, Mid 2009):MacBook5,2:9GU:9GV:A1W:A1X:A1Y:A9P:A9Q:A9Y:ABW:ASC:
MacBook (13-inch, Mid 2010):MacBook7,1:
MacBook (Retina, 12-inch, 2017):MacBook10,1:
MacBook (Retina, 12-inch, Early 2015):MacBook8,1:
MacBook (Retina, 12-inch, Early 2016):MacBook9,1:
MacBook Air (11-inch, Early 2014):MacBookAir6,1:FM72:G083:G084:G2CF:G2GH:G2GJ:G2PY:G2Q0:G4FY:G4H0:G4H4:G4HK:G4HM:G58J:G5RK:G5RL:G5RM:G6D3:GLK9:GP4N:GP4P:
MacBook Air (11-inch, Early 2015):MacBookAir7,1:
MacBook Air (11-inch, Late 2010):MacBookAir3,1:
MacBook Air (11-inch, Mid 2011):MacBookAir4,1:
MacBook Air (11-inch, Mid 2012):MacBookAir5,1:
MacBook Air (11-inch, Mid 2013):MacBookAir6,1:F5N7:F5N8:F5YV:F5YW:FH51:FH52:FKYN:FKYP:FLCF:FMR5:FMR6:FMR9:FMRC:FMRD:FMRF:FMRG:FMRM:FMRN:FN5M:FN7F:FP2N:FP3C:FQLG:FT30:
MacBook Air (13-inch, 2017):MacBookAir7,2:J1WK:J1WL:J1WM:J1WT:J1WV:J8N7:J8XG:J8XH:J9HX:J9TN:J9TP:J9TQ:JC9H:JCD6:JFLY:JKHD:JKHF:LQ07:LQF1:MFWJ:
MacBook Air (13-inch, Early 2014):MacBookAir6,2:G085:G086:G2CC:G2CD:G2GK:G2GL:G2GM:G2GN:G356:G4H1:G4H2:G4H3:G4HN:G4HP:G58K:G5RN:G5RP:G5RQ:G6D4:G6D5:G829:G8J1:GLK7:GLK8:GP4L:GP4M:
MacBook Air (13-inch, Early 2015):MacBookAir7,2:G940:G941:G942:G943:G944:GKJT:GKJV:GL20:GL21:GL22:GL23:GL24:GL25:GLCN:GLCP:GM14:GM15:GM38:GM6M:GM9G:GMC3:GMD3:GN8C:GNJJ:GNKM:H3QD:H3QF:H3QJ:H3QK:H569:H8VT:H8VV:H8VW:H8VX:HD7X:HD80:HD98:HDV4:HDV5:HDV6:HF4F:HF4H:HF9N:J6VL:
MacBook Air (13-inch, Late 2010):MacBookAir3,2:
MacBook Air (13-inch, Mid 2011):MacBookAir4,2:
MacBook Air (13-inch, Mid 2012):MacBookAir5,2:
MacBook Air (13-inch, Mid 2013):MacBookAir6,2:F5V7:F5V8:F6T5:F6T6:FH53:FKYQ:FKYR:FLCG:FM23:FM3Y:FM74:FMR7:FMR8:FMRH:FMRJ:FMRK:FMRL:FMRV:FMRW:FMRY:FN3Y:FN40:FN7G:FP2P:FQL9:FQLC:FQLD:FQLF:G6PM:
MacBook Air (Late 2008):MacBookAir2,1:22D:22E:5L9:5LA:5TX:5U1:5U7:60R:62W:63V:63W:6JN:
MacBook Air (Mid 2009):MacBookAir2,1:9A5:9A6:9A7:9A8:
MacBook Air (Original):MacBookAir1,1:
MacBook Air (Retina, 13-inch, 2018):MacBookAir8,1:
MacBook Air (Retina, 13-inch, 2019):MacBookAir8,2:
MacBook Air (Retina, 13-inch, 2020):MacBookAir9,1:
MacBook Pro (13-inch, 2016, Four Thunderbolt 3 Ports):MacBookPro13,2:
MacBook Pro (13-inch, 2016, Two Thunderbolt 3 ports):MacBookPro13,1:
MacBook Pro (13-inch, 2017, Four Thunderbolt 3 Ports):MacBookPro14,2:
MacBook Pro (13-inch, 2017, Two Thunderbolt 3 ports):MacBookPro14,1:
MacBook Pro (13-inch, 2018, Four Thunderbolt 3 Ports):MacBookPro15,2:JHC8:JHC9:JHCC:JHCD:JHCF:JHD2:JHD3:JHD4:JHD5:KK98:KK99:KK9C:KQ1X:KQ1Y:KQ20:KQ21:KQ22:KQ23:KQ24:KQ25:KQ26:KQ27:L42X:L4FC:L4FD:L4FF:L4FG:L4FJ:L4JT:L7GD:LK8C:
MacBook Pro (13-inch, 2019, Four Thunderbolt 3 ports):MacBookPro15,2:LVDC:LVDD:LVDF:LVDG:LVDH:LVDL:LVDM:LVDN:LVDP:MV9K:MV9R:N5T5:NCLV:NCLW:NCLX:NCLY:NCM0:NCM1:NCM2:NQM8:P4G1:P4G2:
MacBook Pro (13-inch, 2019, Two Thunderbolt 3 ports):MacBookPro15,4:
MacBook Pro (13-inch, 2020, Four Thunderbolt 3 ports):MacBookPro16,2:
MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports):MacBookPro16,3:
MacBook Pro (13-inch, Early 2011):MacBookPro8,1:DH2G:DH2H:DH2L:DH2M:DLN5:DLN6:DM75:DMLF:DMLH:DMLJ:DNCM:DNGD:DNKP:DNKQ:DNTK:DNVY:DR7W:DRJ7:DRJ9:DRJJ:DRJK:DRW1:DRW2:DRW7:DT4G:DT4H:DT60:DT61:DT62:DT63:DT64:DT65:DT66:DT67:ST61:
MacBook Pro (13-inch, Late 2011):MacBookPro8,1:DV13:DV14:DV16:DV17:DVHJ:DVHK:DVHP:DVHQ:DW13:DY1J:DY1K:DY5T:DY5V:DY6C:DY77:DYL0:DYL1:DYL2:F298:F299:
MacBook Pro (13-inch, Mid 2009):MacBookPro5,5:
MacBook Pro (13-inch, Mid 2010):MacBookPro7,1:
MacBook Pro (13-inch, Mid 2012):MacBookPro9,2:
MacBook Pro (15-inch, 2.4/2.2GHz):MacBookPro3,1:02V:0LQ:0LZ:0M0:0PA:0S3:0S6:1CY:1CZ:2QU:2QV:X91:X92:XAG:XAH:Y9S:Y9T:YAL:YAM:YKX:YKY:YKZ:YL0:YQ3:YW5:YW9:YWA:YWD:YYV:YYX:YZ0:Z05:Z09:Z0G:
MacBook Pro (15-inch, 2.53GHz, Mid 2009):MacBookPro5,4:
MacBook Pro (15-inch, 2016):MacBookPro13,3:
MacBook Pro (15-inch, 2017):MacBookPro14,3:
MacBook Pro (15-inch, 2018):MacBookPro15,1:MacBookPro15,3:JG5H:JG5J:JG5K:JG5L:JG5M:JGH5:JGH6:JGH7:JGH8:KGYF:KGYG:KGYH:KQ9Q:KQ9R:KQ9T:KQ9V:KQ9W:KQ9X:KQ9Y:KQC0:KQC1:KQC2:KQC3:KQC4:KQC5:KQC6:KQC7:KQC8:KQC9:KQCC:KQCD:KQCF:KQCG:KQCH:KQCJ:KQCK:KQCL:KQCM:KQCN:KQCP:KQCQ:KQCR:KQCT:KQCV:KQCW:KQCX:KWJ2:L4HW:L4HX:L539:L53D:L7GC:LC8J:LC8K:LC8L:LCM6:MJLR:MJLT:
MacBook Pro (15-inch, 2019):MacBookPro15,1:MacBookPro15,3:LVCF:LVCG:LVCH:LVCJ:LVCK:LVCL:LVDQ:LVDR:LVDT:LVDV:MV9T:MVC0:N5T6:N6KF:N6RJ:NCM3:NCM4:NCM5:NCM6:NQM9:NQMC:NQMD:NQMF:
MacBook Pro (15-inch, Core 2 Duo):MacBookPro2,2:
MacBook Pro (15-inch, Early 2008):MacBookPro4,1:1AJ:1EK:1EM:1JZ:1K0:1SH:1XR:1XW:27N:2AZ:2B0:2CE:2DT:2DX:2MF:2PK:33B:3LY:3LZ:48T:4R5:4R6:YJX:YJY:YJZ:YK0:ZLU:
MacBook Pro (15-inch, Early 2011):MacBookPro8,2:DF8V:DF8X:DF8Y:DF91:DLN7:DLN8:DMC8:DMC9:DMDG:DMDH:DMDJ:DMGG:DMMF:DMMH:DMMJ:DMPG:DMPK:DMPL:DMPM:DMPN:DMPP:DMPQ:DMPR:DMQP:DNC3:DNCN:DNGF:DNH5:DNHY:DNKM:DNKY:DNM4:DNMW:DNRD:DNVK:DRJC:DRJD:DRJF:DRJL:DRJM:DRW3:DRW4:DRWD:DT4J:DT54:DT55:DT56:DT57:DT58:DT59:DT5C:DT5D:DT5F:DT5G:DT5H:DT5J:DT5L:DT68:DT69:DT6C:DT6D:DT6F:DT6G:DT6H:DT6J:DT6K:DT6L:DT6M:DT6R:
MacBook Pro (15-inch, Glossy):MacBookPro1,1:VWW:VWX:VWY:VWZ:W3N:W92:W93:W94:W9F:W9Q:WAG:WAW:WB8:WBE:WBF:WBH:WBJ:WD7:WD8:WD9:WDA:WDB:WDC:WDD:WTS:WW0:WW1:WW2:WW3:
MacBook Pro (15-inch, Late 2008):MacBookPro5,1:
MacBook Pro (15-inch, Late 2011):MacBookPro8,2:DV7L:DV7M:DV7N:DV7P:DVHL:DVHM:DVHR:DW3G:DW3H:DW3J:DW47:DY1L:DY1M:DY1N:DY1P:DY1Q:DY1R:DY1T:DY1V:DY1W:DY1Y:DY20:DY21:DY5K:DY5P:DY5Q:DY5R:DY5Y:DY60:DY7G:DYG6:DYG7:DYK9:DYKC:DYR1:F0K6:F0V2:
MacBook Pro (15-inch, Mid 2009):MacBookPro5,3:
MacBook Pro (15-inch, Mid 2010):MacBookPro6,2:
MacBook Pro (15-inch, Mid 2012):MacBookPro9,1:
MacBook Pro (16-inch, 2019):MacBookPro16,1:MacBookPro16,4:
MacBook Pro (17-inch):MacBookPro1,2:
MacBook Pro (17-inch, 2.4GHz):MacBookPro3,1:027:028:02D:09R:09S:0LR:0ND:0NM:0PD:1CW:1CX:1MF:1MG:2QW:X94:XA9:YAA:YAN:YAP:YNQ:YNS:YNW:YQ4:YQ5:YR2:YRD:YRE:YRF:YWB:YWC:YZ1:YZ2:Z5M:
MacBook Pro (17-inch, Core 2 Duo):MacBookPro2,1:
MacBook Pro (17-inch, Early 2008):MacBookPro4,1:1BY:1ED:1EN:1ER:1K2:1K8:1K9:1KA:1Q3:1SG:2CF:2DY:2DZ:2ED:3DC:3DD:3DE:3DF:3M0:3M4:3M5:YP3:YP4:ZLV:
MacBook Pro (17-inch, Early 2009):MacBookPro5,2:2QP:2QT:776:77A:7AP:7AS:7XQ:7XR:7XS:87K:87L:87M:87N:8FK:8FL:8FM:8FY:8FZ:8G0:
MacBook Pro (17-inch, Early 2011):MacBookPro8,3:DF92:DF93:DLN9:DLNC:DMGH:DMQT:DMQW:DMR2:DMR4:DMR5:DMR7:DMR8:DMR9:DMRC:DNGG:DNKN:DRJG:DRJH:DRJN:DRW5:DRW6:DT5M:DT5N:DT5P:DT5Q:DT5R:DT5T:DT5V:DT5W:DT5Y:DT6N:DT6P:
MacBook Pro (17-inch, Late 2008):MacBookPro4,1:3R8:3R9:4RT:4RW:57J:5U0:634:65A:663:664:666:668:6CT:6JK:
MacBook Pro (17-inch, Late 2011):MacBookPro8,3:AY5W:DV10:DV11:DVHN:DVHV:DVHW:DW48:DY22:DY23:DY24:DY25:DY26:DY5W:DYG8:F13Y:F140:
MacBook Pro (17-inch, Mid 2009):MacBookPro5,2:8YA:8YB:91T:A3M:A3N:A5R:A5W:AF3:AKV:AKW:AMV:AMW:AN1:ANC:AND:ANE:ANF:ANJ:AUU:E6L:
MacBook Pro (17-inch, Mid 2010):MacBookPro6,1:
MacBook Pro (Original):MacBookPro1,1:THV:VGW:VGX:VGY:VJ0:VJ1:VJ2:VJ3:VJ5:VJ6:VJ7:VJM:VMU:VSD:VTZ:VU0:VWA:VWB:VXW:VXX:W2Q:
MacBook Pro (Retina, 13-inch, Early 2013):MacBookPro10,2:FFRP:FFRR:FG1F:FG28:FGM8:FGN5:FGN6:FGPJ:FHCH:FHN0:
MacBook Pro (Retina, 13-inch, Early 2015):MacBookPro12,1:
MacBook Pro (Retina, 13-inch, Late 2012):MacBookPro10,2:DR53:DR54:DR55:DR56:F775:F776:F7YF:F897:F8V6:F8V7:F8V8:F9JT:F9V1:F9VQ:FG7Q:FG7R:FL85:FMLJ:
MacBook Pro (Retina, 13-inch, Late 2013):MacBookPro11,1:FGYY:FH00:FH01:FH02:FH03:FH04:FH05:FRF6:FRF7:FRQF:FT4Q:FT4R:FT4T:FT4V:FTC9:FTCD:FTCH:FTCK:FTCL:FTPH:FTPJ:FTPK:FTT4:FVVW:FVWQ:FWKF:G4N6:G4N7:
MacBook Pro (Retina, 13-inch, Mid 2014):MacBookPro11,1:G3QH:G3QJ:G3QK:G3QL:G3QQ:G3QR:G3QT:G7RD:G7RF:G7YQ:G7YR:G8L0:G96R:G96T:G96V:G96W:G96Y:G970:G971:G972:G9FL:G9FM:G9FN:G9FP:G9FQ:G9FR:GDJM:
MacBook Pro (Retina, 15-inch, Early 2013):MacBookPro10,1:FFT0:FFT1:FFT2:FFT3:FFT4:FG1H:FG1J:FGFH:FGFJ:FGFK:FGFL:FGN7:FGWF:FGWG:FGWH:FHCQ:FHCR:FJ47:FJVJ:FL94:FMLK:FR8D:
MacBook Pro (Retina, 15-inch, Late 2013):MacBookPro11,2:MacBookPro11,3:FD56:FD57:FD58:FD59:FR1M:FRDM:FRG2:FRG3:FRQH:FRQJ:FRQK:FRQL:FT4P:FTK0:FTK1:FTPL:FTPM:FTPN:FTPP:FTPQ:FTPR:FTPT:FTPV:FTPW:FTPY:FTTJ:FVN4:FVYN:FWFY:FWHW:FWKK:FWKL:G4JQ:G5HL:
MacBook Pro (Retina, 15-inch, Mid 2014):MacBookPro11,2:MacBookPro11,3:G3QC:G3QD:G3QG:G3QN:G3QP:G85Y:G86P:G86Q:G86R:G8F4:G8J7:G8L1:G96K:G96L:G96M:G96N:G96P:G96Q:G973:G974:G9FT:G9JN:G9L6:G9L7:G9L8:G9L9:GDPP:ZORD:
MacBook Pro (Retina, 15-inch, Mid 2015):MacBookPro11,4:MacBookPro11,5:
MacBook Pro (Retina, Mid 2012):MacBookPro10,1:DKQ1:DKQ2:DKQ4:DKQ5:F51R:F5Y2:F69W:F69Y:F6DN:F6F3:F6L9:F8JY:F96W:F9F1:F9F2:FCQ3:
Xserve (Early 2008):Xserve2,1:
Xserve (Early 2009):Xserve3,1:
Xserve (Late 2006):Xserve1,1:'

		while IFS=':' read -r this_marketing_model_name these_model_ids_and_serial_config_codes; do
			if [[ -n "${SERIAL_CONFIG_CODE}" && ":${these_model_ids_and_serial_config_codes}:" == *":${SERIAL_CONFIG_CODE}:"* ]]; then
				if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOCAL LIST SERIAL CONFIG CODE MATCH: ${this_marketing_model_name}"; fi
				possible_marketing_model_name="${this_marketing_model_name}"
				break
			elif [[ ":${these_model_ids_and_serial_config_codes}:" == *":${MODEL_IDENTIFIER}:"* ]]; then
				if $VERBOSE_LOGGING; then >&2 echo "DEBUG - LOCAL LIST MODEL IDENTIFIER MATCH: ${this_marketing_model_name}"; fi
				if [[ -n "${possible_marketing_model_name}" ]]; then possible_marketing_model_name+=$'\n'; fi
				possible_marketing_model_name+="${this_marketing_model_name}"
			fi
		done <<< "${every_intel_mac_marketing_model_name_with_grouped_model_ids_and_serial_config_codes}"

		if [[ "${possible_marketing_model_name}" == *$'\n'* ]]; then
			if $VERBOSE_LOGGING; then >&2 echo 'DEBUG - LOADED MULTIPLE POSSIBILITIES FROM LOCAL LIST (NO SERIAL CONFIG CODE MATCH)'; fi
			marketing_model_name="${MODEL_IDENTIFIER} (No Serial Number for Marketing Model Name) / ${possible_marketing_model_name//$'\n'/ or } - $(echo "${possible_marketing_model_name}" | wc -l | tr -d '[:space:]') POSSIBLE MODELS"
		elif [[ -n "${possible_marketing_model_name}" ]]; then
			if $VERBOSE_LOGGING; then >&2 echo 'DEBUG - LOADED FROM LOCAL LIST'; fi
			marketing_model_name="${possible_marketing_model_name}"
		else
			marketing_model_name="${MODEL_IDENTIFIER} (UNKNOWN Marketing Model Name)"
		fi

		if $IS_VIRTUAL_MACHINE; then
			marketing_model_name="Intel Virtual Machine: ${marketing_model_name}"
		fi
	fi

	if $ALWAYS_INCLUDE_MODEL_ID && [[ "${marketing_model_name}" != *"${MODEL_IDENTIFIER}"* ]]; then
		marketing_model_name+=" / ${MODEL_IDENTIFIER}"
	fi

	if $INCLUDE_MODEL_PART_NUMBER && { $IS_APPLE_SILICON || [[ -n "$(ioreg -rc AppleUSBDevice -n 'Apple T2 Controller' -d 1)" ]]; }; then # The "M####LL/A" style Model Part Number is only be accessible in software on Apple Silicon or T2 Macs.
		local possible_model_part_number
		possible_model_part_number="$(/usr/libexec/remotectl dumpstate | awk '($1 == "RegionInfo") { if ($NF == "=>") { region_info = "LL/A" } else { region_info = $NF } } ($1 == "ModelNumber") { if ($NF ~ /\//) { print $NF } else { print $NF region_info } exit }')" # I have seen a T2 Mac without any "RegionInfo" specified, so just assume "LL/A" (USA) in that case.
		if [[ "${possible_model_part_number}" == *'/'* ]]; then
			marketing_model_name+=" / ${possible_model_part_number}"
		fi
	fi

	echo "${marketing_model_name}"
}

get_marketing_model_name "$@"

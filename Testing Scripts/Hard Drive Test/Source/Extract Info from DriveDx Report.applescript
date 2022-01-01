-- By: Pico Mitchell
-- For: MacLand @ Free Geek
--
-- MIT License
--
-- Copyright (c) 2021 Free Geek
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--

-- This is just a proof-of-concept for a possible future applet.

set driveDxReport to read "/Users/Shared/DriveDxReport.txt"

set AppleScript's text item delimiters to " ###"
repeat with thisDriveDxReportSection in (every text item of driveDxReport)
	set thisAdvancedSmartStatus to "UNKNOWN"
	set thisOverallHealthRating to "UNKNOWN"
	set thisOverallPerformanceRating to "UNKNOWN"
	set thisSSDLifetimeLeftIndicator to "UNKNOWN"
	set thisIssuesFound to "UNKNOWN"
	set thisSerialNumber to "UNKNOWN"
	repeat with thisDriveDxReportSectionLine in (paragraphs of thisDriveDxReportSection)
		if (((offset of "### " in thisDriveDxReportSectionLine) is equal to 1) or ((offset of "Report Timestamp" in thisDriveDxReportSectionLine) is equal to 1)) then exit repeat
		if ((length of thisDriveDxReportSectionLine) is not equal to 0) then
			if ((offset of "Advanced SMART Status" in thisDriveDxReportSectionLine) is equal to 1) then set thisAdvancedSmartStatus to (text 40 thru -1 of thisDriveDxReportSectionLine)
			if ((offset of "Overall Health Rating" in thisDriveDxReportSectionLine) is equal to 1) then set thisOverallHealthRating to (text 40 thru -1 of thisDriveDxReportSectionLine)
			if ((offset of "Overall Performance Rating" in thisDriveDxReportSectionLine) is equal to 1) then set thisOverallPerformanceRating to (text 40 thru -1 of thisDriveDxReportSectionLine)
			if ((offset of "SSD Lifetime Left Indicator" in thisDriveDxReportSectionLine) is equal to 1) then set thisSSDLifetimeLeftIndicator to (text 40 thru -1 of thisDriveDxReportSectionLine)
			if ((offset of "Issues found" in thisDriveDxReportSectionLine) is equal to 1) then set thisIssuesFound to (text 40 thru -1 of thisDriveDxReportSectionLine)
			if ((offset of "Serial Number" in thisDriveDxReportSectionLine) is equal to 1) then
				set thisSerialNumber to (text 40 thru -1 of thisDriveDxReportSectionLine)
				exit repeat -- Serial Number is the last row we care about
			end if
		end if
	end repeat
	if ((thisSerialNumber is not equal to "UNKNOWN") and (thisAdvancedSmartStatus is not equal to "UNKNOWN") and (thisOverallHealthRating is not equal to "UNKNOWN") and (thisIssuesFound is not equal to "UNKNOWN")) then
		log "thisSerialNumber: " & thisSerialNumber
		log "thisAdvancedSmartStatus: " & thisAdvancedSmartStatus
		log "thisOverallHealthRating: " & thisOverallHealthRating
		if (thisOverallPerformanceRating is not equal to "UNKNOWN") then log "thisOverallPerformanceRating: " & thisOverallPerformanceRating
		if (thisSSDLifetimeLeftIndicator is not equal to "UNKNOWN") then log "thisSSDLifetimeLeftIndicator: " & thisSSDLifetimeLeftIndicator
		log "thisIssuesFound: " & thisIssuesFound
		log "-----"
	end if
end repeat
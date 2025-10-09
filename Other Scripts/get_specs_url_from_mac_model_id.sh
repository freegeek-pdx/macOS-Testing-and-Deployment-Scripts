#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 10/15/24.
#
# MIT License
#
# Copyright (c) 2024 Free Geek
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

model_identifier="$1" # Use a specified Model Identifier from the first argument.

if [[ -z "$1" ]]; then # Get the current Mac Model Identifier if no argument specified.
	model_identifier="$(sysctl -n hw.model 2> /dev/null)"
fi

echo "Model ID: ${model_identifier}"

# The following list of Specs URLs with grouped Model IDs is generated from: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_every_docs_and_specs_id_with_marketing_model_name_and_model_ids_from_support_pages.sh
# List last updated on 5/15/2025
every_mac_specs_url_with_grouped_model_ids='Mac Laptop;121552;MacBook Pro (14-inch, 2024):MacBook Pro (14-inch, M4, 2024):Mac16,1:
Mac Laptop;121553;MacBook Pro (14-inch, 2024):MacBook Pro (14-inch, M4 Pro or M4 Max, 2024):Mac16,6:Mac16,8:
Mac Laptop;121554;MacBook Pro (16-inch, 2024):MacBook Pro (16-inch, 2024):Mac16,7:Mac16,5:
Mac Laptop;117735;MacBook Pro (14-inch, Nov 2023):MacBook Pro (14-inch, M3, Nov 2023):Mac15,3:
Mac Laptop;117736;MacBook Pro (14-inch, Nov 2023):MacBook Pro (14-inch, M3 Pro or M3 Max, Nov 2023):Mac15,6:Mac15,8:Mac15,10:
Mac Laptop;117737;MacBook Pro (16-inch, Nov 2023):MacBook Pro (16-inch, Nov 2023):Mac15,7:Mac15,9:Mac15,11:
Mac Laptop;111340;MacBook Pro (14-inch, 2023):MacBook Pro (14-inch, 2023):Mac14,5:Mac14,9:
Mac Laptop;111838;MacBook Pro (16-inch, 2023):MacBook Pro (16-inch, 2023):Mac14,6:Mac14,10:
Mac Laptop;111869;MacBook Pro (13-inch, M2, 2022):MacBook Pro (13-inch, M2, 2022):Mac14,7:
Mac Laptop;111902;MacBook Pro (14-inch, 2021):MacBook Pro (14-inch, 2021):MacBookPro18,3:MacBookPro18,4:
Mac Laptop;111901;MacBook Pro (16-inch, 2021):MacBook Pro (16-inch, 2021):MacBookPro18,1:MacBookPro18,2:
Mac Laptop;111893;MacBook Pro (13-inch, M1, 2020):MacBook Pro (13-inch, M1, 2020):MacBookPro17,1:
Mac Laptop;111981;MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports):MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports):MacBookPro16,3:
Mac Laptop;111339;MacBook Pro (13-inch, 2020, Four Thunderbolt 3 ports):MacBook Pro (13-inch, 2020, Four Thunderbolt 3 ports):MacBookPro16,2:
Mac Laptop;111932;MacBook Pro (16-inch, 2019):MacBook Pro (16-inch, 2019):MacBookPro16,1:MacBookPro16,4:
Mac Laptop;111945;MacBook Pro (13-inch, 2019, Two Thunderbolt 3 ports):MacBook Pro (13-inch, 2019, Two Thunderbolt 3 ports):MacBookPro15,4:
Mac Laptop;111941;MacBook Pro (15-inch, 2019):MacBook Pro (15-inch, 2019):MacBookPro15,1:MacBookPro15,3:
Mac Laptop;111997;MacBook Pro (13-inch, 2019, Four Thunderbolt 3 ports):MacBook Pro (13-inch, 2019, Four Thunderbolt 3 ports):MacBookPro15,2:
Mac Laptop;111949;MacBook Pro (15-inch, 2018):MacBook Pro (15-inch, 2018):MacBookPro15,1:
Mac Laptop;111925;MacBook Pro (13-inch, 2018, Four Thunderbolt 3 ports):MacBook Pro (13-inch, 2018, Four Thunderbolt 3 ports):MacBookPro15,2:
Mac Laptop;111947;MacBook Pro (15-inch, 2017):MacBook Pro (15-inch, 2017):MacBookPro14,3:
Mac Laptop;111972;MacBook Pro (13-inch, 2017, Four Thunderbolt 3 ports):MacBook Pro (13-inch, 2017, Four Thunderbolt 3 ports):MacBookPro14,2:
Mac Laptop;111951;MacBook Pro (13-inch, 2017, Two Thunderbolt 3 ports):MacBook Pro (13-inch, 2017, Two Thunderbolt 3 ports):MacBookPro14,1:
Mac Laptop;111975;MacBook Pro (15-inch, 2016):MacBook Pro (15-inch, 2016):MacBookPro13,3:
Mac Laptop;112003;MacBook Pro (13-inch, 2016, Four Thunderbolt 3 ports):MacBook Pro (13-inch, 2016, Four Thunderbolt 3 ports):MacBookPro13,2:
Mac Laptop;111999;MacBook Pro (13-inch, 2016, Two Thunderbolt 3 ports):MacBook Pro (13-inch, 2016, Two Thunderbolt 3 ports):MacBookPro13,1:
Mac Laptop;111955;MacBook Pro (Retina, 15-inch, Mid 2015):MacBook Pro (Retina, 15-inch, Mid 2015):MacBookPro11,4:MacBookPro11,5:
Mac Laptop;111959;MacBook Pro (Retina, 13-inch, Early 2015):MacBook Pro (Retina, 13-inch, Early 2015):MacBookPro12,1:
Mac Laptop;111935;MacBook Pro (Retina, 15-inch, Mid 2014):MacBook Pro (Retina, 15-inch, Mid 2014):MacBookPro11,2:MacBookPro11,3:
Mac Laptop;111942;MacBook Pro (Retina, 13-inch, Mid 2014):MacBook Pro (Retina, 13-inch, Mid 2014):MacBookPro11,1:
Mac Laptop;111971;MacBook Pro (Retina, 15-inch, Late 2013):MacBook Pro (Retina, 15-inch, Late 2013):MacBookPro11,2:MacBookPro11,3:
Mac Laptop;111946;MacBook Pro (Retina, 13-inch, Late 2013):MacBook Pro (Retina, 13-inch, Late 2013):MacBookPro11,1:
Mac Laptop;118465;MacBook Pro (Retina, 15-inch, Early 2013):MacBook Pro (Retina, 15-inch, Early 2013):MacBookPro10,1:
Mac Laptop;118466;MacBook Pro (Retina, 13-inch, Early 2013):MacBook Pro (Retina, 13-inch, Early 2013):MacBookPro10,2:
Mac Laptop;118463;MacBook Pro (Retina, 13-inch, Late 2012):MacBook Pro (Retina, 13-inch, Late 2012):MacBookPro10,2:
Mac Laptop;112576;MacBook Pro (Retina, 15-inch, Mid 2012):MacBook Pro (Retina, 15-inch, Mid 2012):MacBookPro10,1:
Mac Laptop;112568;MacBook Pro (15-inch, Mid 2012):MacBook Pro (15-inch, Mid 2012):MacBookPro9,1:
Mac Laptop;111958;MacBook Pro (13-inch, Mid 2012):MacBook Pro (13-inch, Mid 2012):MacBookPro9,2:
Mac Laptop;112418;MacBook Pro (17-inch, Late 2011):MacBook Pro (17-inch, Late 2011):MacBookPro8,3:
Mac Laptop;112586;MacBook Pro (15-inch, Late 2011):MacBook Pro (15-inch, Late 2011):MacBookPro8,2:
Mac Laptop;111341;MacBook Pro (13-inch, Late 2011):MacBook Pro (13-inch, Late 2011):MacBookPro8,1:
Mac Laptop;112598;MacBook Pro (17-inch, Early 2011):MacBook Pro (17-inch, Early 2011):MacBookPro8,3:
Mac Laptop;112599;MacBook Pro (15-inch, Early 2011):MacBook Pro (15-inch, Early 2011):MacBookPro8,2:
Mac Laptop;112600;MacBook Pro (13-inch, Early 2011):MacBook Pro (13-inch, Early 2011):MacBookPro8,1:
Mac Laptop;112606;MacBook Pro (17-inch, Mid 2010):MacBook Pro (17-inch, Mid 2010):MacBookPro6,1:
Mac Laptop;112605;MacBook Pro (15-inch, Mid 2010):MacBook Pro (15-inch, Mid 2010):MacBookPro6,2:
Mac Laptop;112604;MacBook Pro (13-inch, Mid 2010):MacBook Pro (13-inch, Mid 2010):MacBookPro7,1:
Mac Laptop;112473;MacBook Pro (17-inch, Mid 2009):MacBook Pro (17-inch, Mid 2009):MacBookPro5,2:
Mac Laptop;112624;MacBook Pro (15-inch, Mid 2009):MacBook Pro (15-inch, Mid 2009) or (15-inch, 2.53 GHz, Mid 2009):MacBookPro5,3:
Mac Laptop;112624;MacBook Pro (15-inch, 2.53GHz, Mid 2009):MacBook Pro (15-inch, Mid 2009) or (15-inch, 2.53 GHz, Mid 2009):MacBookPro5,3:
Mac Laptop;112474;MacBook Pro (13-inch, Mid 2009):MacBook Pro (13-inch, Mid 2009):MacBookPro5,5:
Mac Laptop;112526;MacBook Pro (17-inch, Early 2009):MacBook Pro (17-inch, Early 2009):MacBookPro5,2:
Mac Laptop;122210;MacBook Air (15-inch, M4, 2025):MacBook Air (15-inch, M4, 2025):Mac16,13:
Mac Laptop;122209;MacBook Air (13-inch, M4, 2025):MacBook Air (13-inch, M4, 2025):Mac16,12:
Mac Laptop;118552;MacBook Air (15-inch, M3, 2024):MacBook Air (15-inch, M3, 2024):Mac15,13:
Mac Laptop;118551;MacBook Air (13-inch, M3, 2024):MacBook Air (13-inch, M3, 2024):Mac15,12:
Mac Laptop;111346;MacBook Air (15-inch, M2, 2023):MacBook Air (15-inch, M2, 2023):Mac14,15:
Mac Laptop;111867;MacBook Air (M2, 2022):MacBook Air (M2, 2022):Mac14,2:
Mac Laptop;111883;MacBook Air (M1, 2020):MacBook Air (M1, 2020):MacBookAir10,1:
Mac Laptop;111991;MacBook Air (Retina, 13-inch, 2020):MacBook Air (Retina, 13-inch, 2020):MacBookAir9,1:
Mac Laptop;111948;MacBook Air (Retina, 13-inch, 2019):MacBook Air (Retina, 13-inch, 2019):MacBookAir8,2:
Mac Laptop;111933;MacBook Air (Retina, 13-inch, 2018):MacBook Air (Retina, 13-inch, 2018):MacBookAir8,1:
Mac Laptop;111924;MacBook Air (13-inch, 2017):MacBook Air (13-inch, 2017):MacBookAir7,2:
Mac Laptop;111956;MacBook Air (13-inch, Early 2015):MacBook Air (13-inch, Early 2015):MacBookAir7,2:
Mac Laptop;112441;MacBook Air (11-inch, Early 2015):MacBook Air (11-inch, Early 2015):MacBookAir7,1:
Mac Laptop;111944;MacBook Air (13-inch, Early 2014):MacBook Air (13-inch, Early 2014):MacBookAir6,2:
Mac Laptop;112032;MacBook Air (11-inch, Early 2014):MacBook Air (11-inch, Early 2014):MacBookAir6,1:
Mac Laptop;111938;MacBook Air (13-inch, Mid 2013):MacBook Air (13-inch, Mid 2013):MacBookAir6,2:
Mac Laptop;112437;MacBook Air (11-inch, Mid 2013):MacBook Air (11-inch, Mid 2013):MacBookAir6,1:
Mac Laptop;111966;MacBook Air (13-inch, Mid 2012):MacBook Air (13-inch, Mid 2012):MacBookAir5,2:
Mac Laptop;112008;MacBook Air (11-inch, Mid 2012):MacBook Air (11-inch, Mid 2012):MacBookAir5,1:
Mac Laptop;112038;MacBook Air (13-inch, Mid 2011):MacBook Air (13-inch, Mid 2011):MacBookAir4,2:
Mac Laptop;112439;MacBook Air (11-inch, Mid 2011):MacBook Air (11-inch, Mid 2011):MacBookAir4,1:
Mac Laptop;112585;MacBook Air (13-inch, Late 2010):MacBook Air (13-inch, Late 2010):MacBookAir3,2:
Mac Laptop;112580;MacBook Air (11-inch, Late 2010):MacBook Air (11-inch, Late 2010):MacBookAir3,1:
Mac Laptop;112660;MacBook Air (Mid 2009):MacBook Air (Mid 2009):MacBookAir2,1:
Mac Laptop;111986;MacBook (Retina, 12-inch, 2017):MacBook (Retina, 12-inch, 2017):MacBook10,1:
Mac Laptop;112033;MacBook (Retina, 12-inch, Early 2016):MacBook (Retina, 12-inch, Early 2016):MacBook9,1:
Mac Laptop;112442;MacBook (Retina, 12-inch, Early 2015):MacBook (Retina, 12-inch, Early 2015):MacBook8,1:
Mac Laptop;112581;MacBook (13-inch, Mid 2010):MacBook (13-inch, Mid 2010):MacBook7,1:
Mac Laptop;112623;MacBook (13-inch, Late 2009):MacBook (13-inch, Late 2009):MacBook6,1:
Mac Laptop;112459;MacBook (13-inch, Mid 2009):MacBook (13-inch, Mid 2009):MacBook5,2:
Mac Laptop;111344;MacBook (13-inch, Early 2009):MacBook (13-inch, Early 2009):MacBook5,2:
Mac Desktop;121557;iMac (24-inch, 2024, Four ports):iMac (24-inch, 2024, Four ports):Mac16,3:
Mac Desktop;121556;iMac (24-inch, 2024, Two ports):iMac (24-inch, 2024, Two ports):Mac16,2:
Mac Desktop;117734;iMac (24-inch, 2023, Four ports):iMac (24-inch, 2023, Four ports):Mac15,5:
Mac Desktop;117733;iMac (24-inch, 2023, Two ports):iMac (24-inch, 2023, Two ports):Mac15,4:
Mac Desktop;111895;iMac (24-inch, M1, 2021):iMac (24-inch, M1, 2021):iMac21,1:
Mac Desktop;111895;iMac (24-inch, M1, 2021):iMac (24-inch, M1, 2021):iMac21,2:
Mac Desktop;111913;iMac (Retina 5K, 27-inch, 2020):iMac (Retina 5K, 27-inch, 2020):iMac20,1:iMac20,2:
Mac Desktop;111998;iMac (Retina 5K, 27-inch, 2019):iMac (Retina 5K, 27-inch, 2019):iMac19,1:
Mac Desktop;111963;iMac (Retina 4K, 21.5-inch, 2019):iMac (Retina 4K, 21.5-inch, 2019):iMac19,2:
Mac Desktop;111995;iMac Pro (2017):iMac Pro (2017):iMacPro1,1:
Mac Desktop;111969;iMac (Retina 5K, 27-inch, 2017):iMac (Retina 5K, 27-inch, 2017):iMac18,3:
Mac Desktop;112026;iMac (Retina 4K, 21.5-inch, 2017):iMac (Retina 4K, 21.5-inch, 2017):iMac18,2:
Mac Desktop;111921;iMac (21.5-inch, 2017):iMac (21.5-inch, 2017):iMac18,1:
Mac Desktop;112035;iMac (Retina 5K, 27-inch, Late 2015):iMac (Retina 5K, 27-inch, Late 2015):iMac17,1:
Mac Desktop;112034;iMac (Retina 4K, 21.5-inch, Late 2015):iMac (Retina 4K, 21.5-inch, Late 2015):iMac16,2:
Mac Desktop;112036;iMac (21.5-inch, Late 2015):iMac (21.5-inch, Late 2015):iMac16,1:
Mac Desktop;112434;iMac (Retina 5K, 27-inch, Mid 2015):iMac (Retina 5K, 27-inch, Mid 2015):iMac15,1:
Mac Desktop;112436;iMac (Retina 5K, 27-inch, Late 2014):iMac (Retina 5K, 27-inch, Late 2014):iMac15,1:
Mac Desktop;112031;iMac (21.5-inch, Mid 2014):iMac (21.5-inch, Mid 2014):iMac14,4:
Mac Desktop;111970;iMac (27-inch, Late 2013):iMac (27-inch, Late 2013):iMac14,2:
Mac Desktop;111967;iMac (21.5-inch, Late 2013):iMac (21.5-inch, Late 2013):iMac14,1:
Mac Desktop;112433;iMac (27-inch, Late 2012):iMac (27-inch, Late 2012):iMac13,2:
Mac Desktop;112435;iMac (21.5-inch, Late 2012):iMac (21.5-inch, Late 2012):iMac13,1:
Mac Desktop;112569;iMac (27-inch, Mid 2011):iMac (27-inch, Mid 2011):iMac12,2:
Mac Desktop;111983;iMac (21.5-inch, Mid 2011):iMac (21.5-inch, Mid 2011):iMac12,1:
Mac Desktop;112566;iMac (27-inch, Mid 2010):iMac (27-inch, Mid 2010):iMac11,3:
Mac Desktop;112567;iMac (21.5-inch, Mid 2010):iMac (21.5-inch, Mid 2010):iMac11,2:
Mac Desktop;112564;iMac (27-inch, Late 2009):iMac (27-inch, Late 2009):iMac10,1:
Mac Desktop;112565;iMac (21.5-inch, Late 2009):iMac (21.5-inch, Late 2009):iMac10,1:
Mac Desktop;112427;iMac (24-inch, Early 2009):iMac (Early 2009):iMac9,1:
Mac Desktop;112427;iMac (20-inch, Early 2009):iMac (Early 2009):iMac9,1:
Mac Desktop;121555;Mac mini (2024):Mac mini (2024):Mac16,11:Mac16,10:
Mac Desktop;111837;Mac mini (2023):Mac mini (2023):Mac14,3:
Mac Desktop;111837;Mac mini (2023):Mac mini (2023):Mac14,12:
Mac Desktop;111894;Mac mini (M1, 2020):Mac mini (M1, 2020):Macmini9,1:
Mac Desktop;111912;Mac mini (2018):Mac mini (2018):Macmini8,1:
Mac Desktop;111931;Mac mini (Late 2014):Mac mini (Late 2014):Macmini7,1:
Mac Desktop;111926;Mac mini (Late 2012):Mac mini (Late 2012):Macmini6,1:Macmini6,2:
Mac Desktop;112007;Mac mini (Mid 2011):Mac mini (Mid 2011):Macmini5,1:Macmini5,2:
Mac Desktop;112588;Mac mini (Mid 2010):Mac mini (Mid 2010):Macmini4,1:
Mac Desktop;112482;Mac mini (Late 2009):Mac mini (Late 2009):Macmini3,1:
Mac Desktop;111345;Mac mini (Early 2009):Mac mini (Early 2009):Macmini3,1:
Mac Desktop;122211;Mac Studio (2025):Mac Studio (2025):Mac16,9:
Mac Desktop;122211;Mac Studio (2025):Mac Studio (2025):Mac15,14:
Mac Desktop;111835;Mac Studio (2023):Mac Studio (2023):Mac14,13:
Mac Desktop;111835;Mac Studio (2023):Mac Studio (2023):Mac14,14:
Mac Desktop;111900;Mac Studio (2022):Mac Studio (2022):Mac13,1:
Mac Desktop;111900;Mac Studio (2022):Mac Studio (2022):Mac13,2:
Mac Desktop;111343;Mac Pro (2023):Mac Pro (2023):Mac14,8:
Mac Desktop;111343;Mac Pro (Rack, 2023):Mac Pro (2023):Mac14,8:
Mac Desktop;118461;Mac Pro (2019):Mac Pro (2019):MacPro7,1:
Mac Desktop;111907;Mac Pro (Rack, 2019):Mac Pro (Rack, 2019):MacPro7,1:
Mac Desktop;112025;Mac Pro (Late 2013):Mac Pro (Late 2013):MacPro6,1:
Mac Desktop;118464;Mac Pro (Mid 2012):Mac Pro (Mid 2012):MacPro5,1:
Mac Desktop;118464;Mac Pro Server (Mid 2012):Mac Pro (Mid 2012):MacPro5,1:
Mac Desktop;112578;Mac Pro (Mid 2010):Mac Pro (Mid 2010):MacPro5,1:
Mac Desktop;112578;Mac Pro Server (Mid 2010):Mac Pro (Mid 2010):MacPro5,1:
Mac Desktop;112590;Mac Pro (Early 2009):Mac Pro (Early 2009):MacPro4,1:'

while IFS=';:' read -r this_product_type this_specs_url_id this_marketing_model_name_from_identification_page _ these_model_ids; do
	if [[ ":${these_model_ids}:" == *":${model_identifier}:"* ]]; then
		specs_url="https://support.apple.com/${this_specs_url_id}"

		echo "
Marketing Model Name: ${this_marketing_model_name_from_identification_page}
Product Type: ${this_product_type}
Specs URL: ${specs_url}"
	fi
done <<< "${every_mac_specs_url_with_grouped_model_ids}"

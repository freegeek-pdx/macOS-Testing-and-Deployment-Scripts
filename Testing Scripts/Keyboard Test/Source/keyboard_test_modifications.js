/*
* By: Pico Mitchell
* For: MacLand @ Free Geek
* Last Updated: December 30th, 2021
*
* MIT License
*
* Copyright (c) 2021 Free Geek
*
* Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
* to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
* and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
*/

try
{
	document.title = 'Keyboard Test';
	
	window.addEventListener('scroll', function() { window.scrollTo(0, 0); });
	
	document.getElementById('resetbutton').outerHTML =
		'<div style="text-align: center;"><a href="https://www.keyboardtester.com/" target="_blank"><img src="https://www.keyboardtester.com/images/keyboardtester.gif" height="23"></a></div>' +
		document.getElementById('resetbutton').outerHTML;
	
	document.getElementById('soundSelect').selectedIndex = 0;
	
	var testTextarea = document.getElementById('testarea');
	testTextarea.style.marginTop = '5px';
	testTextarea.placeholder = '\n\nBegin testing this keyboard by typing “The quick brown fox jumps over the lazy dog.”';
	testTextarea.outerHTML = '<input type="text" id="hidden_text_before" onfocus="go_testarea();">' + testTextarea.outerHTML;
	document.getElementById('testarea').addEventListener('blur', function(thisEvent) { thisEvent.target.focus(); });
	
	var leftOptionKey = document.getElementById('key18');
	var leftCommandKey = document.getElementById('key91');
	var rightOptionKey = document.getElementById('key18b');
	var rightCommandKey = document.getElementById('key93');
	
	leftOptionKey.parentNode.insertBefore(leftOptionKey, leftCommandKey);
	rightCommandKey.parentNode.insertBefore(rightCommandKey, rightOptionKey);
	
	document.getElementById('key8').innerHTML = 'Delete';
	document.getElementById('key13').innerHTML = 'Return';
	document.getElementById('key17').innerHTML = 'Control';
	leftOptionKey.innerHTML = 'Option';
	leftCommandKey.innerHTML = 'Command';
	rightOptionKey.innerHTML = 'Option';
	rightCommandKey.innerHTML = 'Command';
	
	document.getElementById('key38').innerHTML = '▲';
	document.getElementById('key37').innerHTML = '◀';
	document.getElementById('key40').innerHTML = '▼';
	document.getElementById('key39').innerHTML = '▶';
	
	document.body.style.display = 'block';
	
	setTimeout(function()
	{
		var escapeKey = document.getElementById('key27');
		if (escapeKey.className == 'key_un') // Don't show intro alerts if escape key pressed.
		{
			alert('👇\tWhen a key is pressed on the keyboard,\n\tit will momentarily turn ✴️ orange\n\tand then turn ❇️ green in this window.\n\n✅\tThe best way to test a keyboard is to\n\ttype actual information and make sure\n\tthat exactly what you typed shows up\n\tin the text box and that each key turns\n\tgreen in this window as you type it.\n\n🚫\tYou SHOULD NOT just slide your finger\n\tacross the keyboard to hit every key.\n\tWith water damaged keyboards, it’s\n\tcommon that one key on the keyboard\n\tmay trigger the wrong key, or multiple\n\tkeys. Also, modifier keys such as\n\tShift, Control, or Option could be stuck\n\tdown which could make other keys\n\tbehave incorrectly.');
			
			alert('‼️\tDon\'t just press the Shift, Option, and\n\tCaps Lock keys by themselves.\n\tType while using these keys to make\n\tsure they are working properly.\n\n⚠️\tMake sure to test both the left and right\n\tShift and Option keys since this test\n\tcannot tell which side is being pressed.\n\n⚠️\tThe Caps Lock key WILL NOT turn\n\tgreen when being turned ON, but\n\tWILL turn green when turned OFF.\n\n⚠️\tThe Tab key WILL turn green but\n\tWILL NOT output a tab character.\n\n☝️\tHold down the FN key to test the\n\ttop row of Function keys.\n\n👉\tAlso, make sure that no keys feel funky,\n\tsticky, or get stuck down as you type.\n\n😎\tPRO TIP: To avoid seeing these intro\n\talerts again, hit the Escape key within\n\tone second of opening Keyboard Test.');
		}
		
		setTimeout(function() { checkEveryKeyPressed(); }, 1000);
	}, 900);
}
catch (loadError)
{
	var errorAlertReply = confirm('\t‼️ AN ERROR OCCURRED ‼️\n\nMake sure you\'re connected to the Internet.\n\n\tClick OK to Reload and Try Again\n\n\tClick Cancel to Quit and Open\n\tKeyboardTester.com in Safari');
	if (errorAlertReply)
	{
		document.body.style.display = 'none';
		location.reload();
	}
	else
	{
		window.open('https://keyboardtester.com/tester.html'); // Exclude www so it opens in browser.
		window.close();
	}
}

function checkEveryKeyPressed()
{
	var everyKey = ['key27', 'key112', 'key113', 'key114', 'key115', 'key116', 'key117', 'key118', 'key119', 'key120', 'key121', 'key122', 'key123', 'key192', 'key49', 'key50', 'key51', 'key52', 'key53', 'key54', 'key55', 'key56', 'key57', 'key48', 'key173', 'key61', 'key8', 'key9', 'key81', 'key87', 'key69', 'key82', 'key84', 'key89', 'key85', 'key73', 'key79', 'key80', 'key219', 'key221', 'key220', 'key20', 'key65', 'key83', 'key68', 'key70', 'key71', 'key72', 'key74', 'key75', 'key76', 'keycolon', 'key222', 'key13', 'key16', 'key90', 'key88', 'key67', 'key86', 'key66', 'key78', 'key77', 'key188', 'key190', 'key191', 'key16b', 'key91', 'key18', 'key32', 'key18b', 'key93', 'key17b', 'key38', 'key37', 'key40', 'key39'];
	
	var everyKeyIsPressed = true;
	for (var i = 0; i < everyKey.length; i ++)
		if (document.getElementById(everyKey[i]).className == 'key_un')
		{
			everyKeyIsPressed = false;
			break;
		}
	
	if (everyKeyIsPressed)
	{
		setTimeout(function()
		{
			var everyKeyAlertReply = confirm('🎉\tEVERY KEY HAS BEEN PRESSED!\t🎊\n\n\n✅\tKEYBOARD TEST PASSED IF:\n\t⁃ Every key functioned correctly.\n\t⁃ No keys felt funky in any way.\n\t⁃ No keys felt sticky or got stuck down.\n\t⁃ No key caps are broken or missing.\n\n❌\tKEYBOARD TEST FAILED IF:\n\t⁃ Any key did not function correctly.\n\t⁃ Any key triggered the wrong key.\n\t⁃ Any key triggered multiple keys.\n\t⁃ Any key felt funky in any way.\n\t⁃ Any key felt sticky or got stuck down.\n\t⁃ Any key caps are broken or missing.\n\n\t👉\tCONSULT AN INSTRUCTOR\n\t\tIF KEYBOARD TEST FAILED ‼️\n\n\nIf Keyboard Test passed, quit and proceed to test this Macs Ports and Disc Drive.\n\n👋\tClick OK to Quit Keyboard Test\n\n🔄\tClick Cancel to Redo Keyboard Test');
			if (everyKeyAlertReply)
				window.close();
			else
			{
				document.body.style.display = 'none';
				location.reload();
			}
		}, 500);
	}
	else
		setTimeout(function() { checkEveryKeyPressed(); }, 1000);
}
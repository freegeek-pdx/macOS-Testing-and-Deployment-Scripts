/*
* By: Pico Mitchell
* For: MacLand @ Free Geek
* Last Updated: June 13th, 2024
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

try {
	document.title = 'Keyboard Test'
	
	window.addEventListener('scroll', function() { window.scrollTo(0, 0) })
	
	const resetButton = document.getElementById('resetbutton')
	resetButton.outerHTML = '<div id="logo"><a href="https://www.keyboardtester.com/" target="_blank">KeyboardTester.com</a></div>' + resetButton.outerHTML

	navigator.userAgentData.getHighEntropyValues(["platformVersion"]).then(ua => { // https://learn.microsoft.com/en-us/microsoft-edge/web-platform/how-to-detect-win11#sample-code-for-detecting-windows-11
		if (navigator.userAgentData.platform === 'Windows') {
			const majorPlatformVersion = parseInt(ua.platformVersion.split('.')[0]);
			if (majorPlatformVersion < 13)
				document.getElementById('logo').style.marginTop = '0px' // Set logo top margin to 10px on Windows 10 because the title bar is white and has no border, so it looks better being closer to the top.
		}
	});

	document.getElementById('soundSelect').selectedIndex = 0

	const testTextarea = document.getElementById('testarea')
	testTextarea.placeholder = `🏆 The best way to test a keyboard is to TYPE ACTUAL WORDS and make sure that exactly what you typed
shows up in this text box and that each key below this text box turns green as you type it.

When a key is pressed on the keyboard, it will momentarily turn ✴️ orange and then turn ❇️ green in this window.

👇 SCROLL DOWN FOR MORE KEYBOARD TESTING TIPS 👇


🚫 You SHOULD NOT just slide your finger across the keyboard to hit every key.
With water damaged keyboards, it’s common that one key on the keyboard may trigger the wrong key, or multiple keys.
Also, modifier keys such as Shift, Control, or Alternate could be stuck down which can make other keys behave incorrectly.

⚠️ DO NOT just press the Shift, Alternate, and Caps Lock keys by themselves.
Type while using these keys to make sure they are working properly.

⚠️ Make sure to test both the left and right Shift, Control, and Alternate keys since this test cannot tell which side is being pressed.

⚠️ The Caps Lock key MAY NOT turn green when being turned ON, but WILL turn green when turned OFF.

⚠️ The Tab key WILL turn green but WILL NOT output a tab character.

☝️ Hold down the FN key to test the top row of Function keys.

👉 Also, make sure that no keys feel funky, sticky, or get stuck down as you type.`

	testTextarea.outerHTML = '<input type="text" id="hidden_text_before" onfocus="go_testarea()">' + testTextarea.outerHTML
	document.getElementById('testarea').addEventListener('blur', function(thisEvent) { thisEvent.target.focus() })

	document.getElementById('key44').innerHTML = 'PrtScr'
	document.getElementById('key145').innerHTML = 'ScrLck'
	document.getElementById('key19').innerHTML = 'Pause'
	document.getElementById('key33').innerHTML = 'PgUp' // To remove extra space for padding that we don't want.
	document.getElementById('key35').innerHTML = 'End' // To remove extra space for padding that we don't want.
	document.getElementById('key34').innerHTML = 'PgDn'
	document.getElementById('key192').innerHTML = '`'
	document.getElementById('key61').innerHTML = '='
	document.getElementById('key8').innerHTML = 'Backspc'
	document.getElementById('key144').innerHTML = 'Num<br/>Lock'
	document.getElementById('key144').style = 'font-size: 8px !important;'
	document.getElementById('key13b').innerHTML = 'Enter'
	document.getElementById('key13b').style = 'font-size: 10px !important;'
	document.getElementById('key219').innerHTML = '['
	document.getElementById('key221').innerHTML = ']'
	document.getElementById('key220').innerHTML = '\\' // To remove extra space for padding that we don't want.
	document.getElementById('key91').innerHTML = 'Start'
	document.getElementById('key93').innerHTML = 'Menu'
	document.getElementById('key32').innerHTML = 'Space'

	document.body.style.display = 'block'
	
	setTimeout(function() { checkEveryKeyPressed() }, 1000)
} catch (loadError) {
	const errorAlertReply = confirm('\t‼️ AN ERROR OCCURRED ‼️\n\nMake sure you\'re connected to the internet.\n\n\tClick OK to Reload and Try Again\n\n\tClick Cancel to Quit and Open\n\tKeyboardTester.com in Safari')
	if (errorAlertReply) {
		document.body.style.display = 'none'
		location.reload()
	} else {
		window.open('https://keyboardtester.com/tester.html') // Exclude www so it opens in browser.
		window.close()
	}
}

function checkEveryKeyPressed() {
	// Remove all ad "script", "ins", and "iframe" tags in this loop (every 1 second) because they seem to not all load immediately and not all at once.
	const scriptElements = document.getElementsByTagName('script')
	for (const thisScriptElement of scriptElements)
		if (thisScriptElement.src.includes('googlesyndication') || thisScriptElement.src.includes('googletagmanager'))
			thisScriptElement.remove()

	const insElements = document.getElementsByTagName('ins')
	for (const thisInsElement of insElements)
		thisInsElement.remove()

	const iframeElements = document.getElementsByTagName('iframe')
	for (const thisIframeElement of iframeElements)
		thisIframeElement.remove()

	const everyKey = ['key27', 'key112', 'key113', 'key114', 'key115', 'key116', 'key117', 'key118', 'key119', 'key120', 'key121', 'key122', 'key123', 'key192', 'key49', 'key50', 'key51', 'key52', 'key53', 'key54', 'key55', 'key56', 'key57', 'key48', 'key173', 'key61', 'key8', 'key9', 'key81', 'key87', 'key69', 'key82', 'key84', 'key89', 'key85', 'key73', 'key79', 'key80', 'key219', 'key221', 'key220', 'key20', 'key65', 'key83', 'key68', 'key70', 'key71', 'key72', 'key74', 'key75', 'key76', 'keycolon', 'key222', 'key13', 'key16', 'key90', 'key88', 'key67', 'key86', 'key66', 'key78', 'key77', 'key188', 'key190', 'key191', 'key16b', 'key91', 'key18', 'key32', 'key18b', 'key93', 'key17b', 'key38', 'key37', 'key40', 'key39', 'key44', 'key145', 'key19', 'key45', 'key36', 'key33', 'key46', 'key35', 'key34', 'key144', 'key111', 'key106', 'key109b', 'key103', 'key104', 'key105', 'key107b', 'key100', 'key101', 'key102', 'key97', 'key98', 'key99', 'key13b', 'key96', 'key110', 'key17b']

	let everyKeyIsPressed = true
	for (let i = 0; i < everyKey.length; i ++)
		if (document.getElementById(everyKey[i]).className == 'key_un') {
			everyKeyIsPressed = false
			break
		}
	
	if (everyKeyIsPressed) {
		setTimeout(function() {
			const everyKeyAlertReply = confirm('🎉\tEVERY KEY WAS PRESSED!\n\n\n✅\tKEYBOARD TEST PASSED IF:\n\t⁃ Every key functioned correctly.\n\t⁃ No keys felt funky in any way.\n\t⁃ No keys felt sticky or got stuck down.\n\t⁃ No key caps are broken or missing.\n\n❌\tKEYBOARD TEST FAILED IF:\n\t⁃ Any key did not function correctly.\n\t⁃ Any key triggered the wrong key.\n\t⁃ Any key triggered multiple keys.\n\t⁃ Any key felt funky in any way.\n\t⁃ Any key felt sticky or got stuck down.\n\t⁃ Any key caps are broken or missing.\n\n\t👉\tCONSULT AN INSTRUCTOR\n\t\tIF KEYBOARD TEST FAILED ‼️\n\n\nIf Keyboard Test passed, quit and continue testing this computer.\n\n👋\tClick OK to Quit Keyboard Test\n\n🔄\tClick Cancel to Redo Keyboard Test')
			if (everyKeyAlertReply)
				window.close()
			else {
				document.body.style.display = 'none'
				location.reload()
			}
		}, 500)
	}
	else
		setTimeout(function() { checkEveryKeyPressed() }, 1000)
}

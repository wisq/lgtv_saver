#SingleInstance force
; #NoTrayIcon

; Requires Socket.ahk from https://github.com/G33kDude/Socket.ahk
#include include/Socket.ahk

; Kill any running lgtv_saver:
DetectHiddenWindows, ON
WinGet, id, list, ahk_class AutoHotkey 
Loop, %id% ; retrieves the  ID of the specified windows, one at a time
{
	StringTrimRight, id, id%a_index%, 0
	WinGetTitle, title, ahk_id %id%
	If InStr(title, "lgtv_saver") {
		WinClose, %title%
	}
}

; Every ten seconds, send a UDP packet to lgtv_saver,
; running on the target address, containing a zero.

socket := new SocketUDP()
socket.Connect(["192.168.2.1", "3232"])
SetTimer Activity, 10000
return

Activity:
try {
	socket.SendText(0)
} catch {
	Sleep 5000
	Reload
}
return

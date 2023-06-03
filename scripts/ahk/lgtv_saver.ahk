#SingleInstance force
#NoTrayIcon

; These are needed for A_TimeIdlePhysical to work.
; If you don't want one of these to count as activity,
; just comment it out.
#InstallKeybdHook
#InstallMouseHook

; Requires Socket.ahk from https://github.com/G33kDude/Socket.ahk
#include include/Socket.ahk

; Kill any running lgtv_keepalive:
DetectHiddenWindows, ON
WinGet, id, list, ahk_class AutoHotkey 
Loop, %id% ; retrieves the  ID of the specified windows, one at a time
{
	StringTrimRight, id, id%a_index%, 0
	WinGetTitle, title, ahk_id %id%
	If InStr(title, "lgtv_keepalive") {
		WinClose, %title%
	}
}

; Every second, send a UDP packet to lgtv_saver,
; running on the target address, containing the number
; of milliseconds this computer has been idle.
;
; You can compile this script and then stick it 
; (or a shortcut to it) in the startup directory.
; Access that directory using Win-R + "shell:startup".

socket := new SocketUDP()
socket.Connect(["192.168.2.1", "3232"])
SetTimer Activity, 1000
return

Activity:
try {
	socket.SendText(A_TimeIdlePhysical)
} catch {
	Sleep 5000
	Reload
}
return

;Left::return

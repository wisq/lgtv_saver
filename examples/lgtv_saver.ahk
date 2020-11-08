#SingleInstance force
#NoTrayIcon

; Requires Socket.ahk from https://github.com/G33kDude/Socket.ahk
#include include/Socket.ahk

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
socket.SendText(A_TimeIdlePhysical)
return

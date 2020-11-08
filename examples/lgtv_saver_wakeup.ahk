#SingleInstance force
#NoTrayIcon

; Requires Socket.ahk from https://github.com/G33kDude/Socket.ahk
#include include/Socket.ahk

; Send a UDP packet to lgtv_saver,
; running on the target address, containing 
; a simple zero ("0") to wake up immediately.
;
; You can stick this in your Task Scheduler
; and set it to run before anyone has logged in.
; This will conveniently switch back to
; your computer on startup so you can log in.

socket := new SocketUDP()
socket.Connect(["192.168.2.1", "3232"])
socket.SendText(0)
ExitApp

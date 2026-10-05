; ============================================================
;  RamboOS demo app - loaded and run by the 'run' command.
;  This IS a real user app: it's loaded from disk into memory
;  at segment 0x1000, offset 0, and executed with a far call.
;  It ends with RETF to hand control back to RamboOS cleanly.
; ============================================================
BITS 16
ORG 0x0000

start:
    ; set up our own DS/ES to point at our own segment (0x1000),
    ; since RamboOS's DS is not guaranteed to match ours.
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov si, msg1
    call print_string
    mov si, msg2
    call print_string
    mov si, msg3
    call print_string

    retf                     ; return control to RamboOS

print_string:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .loop
.done:
    popa
    ret

msg1: db 13, 10, "  >> Hello from a user-written RamboOS app! <<", 13, 10, 0
msg2: db "  This program was assembled separately and installed", 13, 10
      db "  into its own disk slot. Type 'run' any time to launch it.", 13, 10, 0
msg3: db "  Edit demo-app.asm (or write your own from APPDEV.txt),", 13, 10
      db "  reassemble it, and reinstall it into this slot to replace me.", 13, 10, 13, 10, 0

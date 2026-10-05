; ============================================================
;  RamboOS - Stage 1 Bootloader (MBR, 512 bytes)
;  In memory of Rambo, a very good and very tough cat.
; ============================================================
BITS 16
ORG 0x7C00

STAGE2_OFF   equ 0x8000
STAGE2_SECT  equ 40        ; kernel sectors (BIOS sectors 2..41)

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov si, msg_loading
    call print_string

    xor ah, ah
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov bx, STAGE2_OFF
    mov ah, 0x02
    mov al, STAGE2_SECT
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov dl, [boot_drive]
    jmp 0x0000:STAGE2_OFF

disk_error:
    mov si, msg_disk_err
    call print_string
    cli
    hlt

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp print_string
.done:
    ret

boot_drive: db 0
msg_loading: db "RamboOS bootloader: loading kernel...", 13, 10, 0
msg_disk_err: db "Disk read error!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55

; ============================================================
;  RamboOS - Stage 2 "Kernel"  v1.5 "Semper Felix"
;  Written in loving memory of Rambo. One tough, good cat.
;  A real-mode x86 OS, hand-written in assembly.
; ============================================================
BITS 16
ORG 0x8000

MIXI_STACK_SEG equ 0x9000
APP_SEG        equ 0x1000     ; user apps load here (segment)
; App slot = LBA 41 (right after the 40-sector kernel). On a standard
; 1.44MB floppy (2 heads, 18 sectors/track) that's CHS (C=1,H=0,S=6):
;   LBA = (C*heads + H) * spt + (S-1) = (1*2+0)*18 + 5 = 41
APP_START_CH   equ 1
APP_START_DH   equ 0
APP_START_CL   equ 6
APP_SECT_COUNT equ 20         ; sectors reserved for a user app (10KB)

entry:
    push dx
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ax, MIXI_STACK_SEG
    mov ss, ax
    mov sp, 0xFFFE
    sti

    pop dx
    mov [boot_drive], dl

    ; remember boot time for a real "since boot" uptime counter
    xor ah, ah
    int 0x1A
    mov [boot_tick_start], dx

    call clear_screen
    call print_art
    call snd_meow
    mov si, msg_welcome
    call print_string
    mov si, msg_help_hint
    call print_string

    mov si, msg_boot_menu
    call print_string
.bootkey:
    mov ah, 0
    int 0x16
    cmp al, '2'
    je .go_gui
    cmp al, '1'
    je .go_cli
    cmp al, 13
    je .go_cli
    jmp .bootkey
.go_gui:
    call do_gui
.go_cli:

; ============================================================
; Main shell loop
; ============================================================
shell_loop:
    mov si, prompt
    mov byte [cur_color], 0x0A     ; bright green prompt
    call print_color

    mov di, cmdbuf
    call read_line

    ; remember this command in the history ring, if non-empty
    cmp byte [cmdbuf], 0
    je .skip_history
    call history_add
.skip_history:
    mov si, cmdbuf
    mov di, echo_prefix
    call startswith
    cmp ax, 1
    je do_echo

    mov si, cmdbuf
    mov di, calc_prefix
    call startswith
    cmp ax, 1
    je do_calc

    mov si, cmdbuf
    mov di, note_prefix
    call startswith
    cmp ax, 1
    je do_note

    mov si, cmdbuf
    mov di, hex_prefix
    call startswith
    cmp ax, 1
    je do_hex

    mov si, cmdbuf
    mov di, roll_prefix
    call startswith
    cmp ax, 1
    je do_roll_n

    mov si, cmdbuf
    mov di, bin_prefix
    call startswith
    cmp ax, 1
    je do_bin

    mov si, cmdbuf
    mov di, dump_prefix
    call startswith
    cmp ax, 1
    je do_dump

    mov al, [cmdbuf]
    or al, al
    jz shell_loop

    mov bx, cmd_table
.table_loop:
    mov ax, [bx]
    or ax, ax
    jz .not_found
    mov si, cmdbuf
    mov di, ax
    call strcmp
    cmp ax, 1
    je .found
    add bx, 4
    jmp .table_loop
.found:
    mov ax, [bx+2]
    call ax
    jmp shell_loop
.not_found:
    mov si, msg_unknown
    call print_string
    mov si, cmdbuf
    call print_string
    mov si, newline
    call print_string
    jmp shell_loop

do_echo:
    mov si, cmdbuf
    add si, 5
    call print_string
    mov si, newline
    call print_string
    jmp shell_loop

do_note:
    cmp byte [notes_count], 5
    jae .full
    mov al, [notes_count]
    mov ah, 64
    mul ah
    mov di, notes_buf
    add di, ax
    mov si, cmdbuf
    add si, 5
    call strcpy
    inc byte [notes_count]
    mov si, msg_noted
    call print_string
    jmp shell_loop
.full:
    mov si, msg_notes_full
    call print_string
    jmp shell_loop

; ============================================================
; Command handlers
; ============================================================
do_help:
    mov si, msg_help
    call print_string
    ret

do_help2:
    mov si, msg_help2
    call print_string
    ret

do_clear:
    call clear_screen
    call print_art
    ret

do_about:
    mov si, msg_about
    call print_string
    ret

do_tribute:
    mov si, msg_tribute
    call print_string
    ret

do_credits:
    mov si, msg_credits
    call print_string
    ret

do_reboot:
    mov si, msg_reboot
    call print_string
    mov ah, 0
    int 0x16
    int 0x19
    ret

do_shutdown:
    mov si, msg_shutdown
    call print_string
    cli
.halt:
    hlt
    jmp .halt

do_rambofetch:
    call rambofetch
    ret

do_cpu:
    call cpu_info
    ret

do_mem:
    call mem_info
    ret

do_disk:
    call disk_info
    ret

do_uptime:
    call uptime_info
    ret

do_logo:
    call print_art
    ret

do_ver:
    mov si, mf_val_os
    call print_string
    ret

do_date:
    mov si, mf_lbl_date
    call print_string
    mov bl, 0x07
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov si, slash
    call print_string
    mov bl, 0x08
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov si, slash
    call print_string
    mov si, twenty
    call print_string
    mov bl, 0x09
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov si, mf_cmos_note
    call print_string
    ret

do_time:
    mov si, mf_lbl_time
    call print_string
    mov bl, 0x04
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov si, colon
    call print_string
    mov bl, 0x02
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov si, colon
    call print_string
    mov bl, 0x00
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov si, mf_cmos_note
    call print_string
    ret

do_beep:
    call beep
    mov si, msg_beep
    call print_string
    ret

do_roar:
    call beep
    mov si, msg_roar
    call print_string
    ret

do_growl:
    mov si, msg_growl
    call print_string
    ret

do_rambofact:
    mov bx, rambofacts
    mov cx, FACT_COUNT
    call print_random_msg
    ret

do_joke:
    mov bx, jokes
    mov cx, JOKE_COUNT
    call print_random_msg
    ret

do_camo:
    mov si, camo_text
    call print_camo
    mov si, newline
    call print_string
    ret

do_secret:
    mov si, msg_secret
    call print_string
    ret

do_hello:
    mov si, msg_hello
    call print_string
    ret

do_sleep:
    mov si, msg_sleep
    call print_string
    mov ah, 0
    int 0x16
    mov si, msg_wake
    call print_string
    ret

do_orders:
    mov si, msg_orders_intro
    call print_string
    mov di, cmdbuf
    call read_line
    mov bx, orders_answers
    mov cx, ORDERS_COUNT
    call print_random_msg
    ret

do_dance:
    pusha
    mov byte [dance_toggle], 0
    mov si, tune_dance
.next_note:
    mov ax, [si]
    cmp ax, 0xFFFF
    je .finish
    mov dx, [si+2]
    push si
    push ax
    push dx
    call clear_screen
    cmp byte [dance_toggle], 0
    jne .frame2
    mov si, dance_frame1
    call print_string
    jmp .frame_done
.frame2:
    mov si, dance_frame2
    call print_string
.frame_done:
    xor byte [dance_toggle], 1
    pop dx
    pop ax
    or ax, ax
    jz .rest
    mov bx, ax
    push dx
    mov dx, 0x0012
    mov ax, 0x34DC
    div bx
    mov cx, ax
    mov al, 0xB6
    out 0x43, al
    mov ax, cx
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    pop dx
    jmp .delaynote
.rest:
    in al, 0x61
    and al, 0xFC
    out 0x61, al
.delaynote:
    call delay_n
    pop si
    add si, 4
    jmp .next_note
.finish:
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    call clear_screen
    call print_art
    popa
    ret

do_calc:
    mov si, cmdbuf
    add si, 5
    call parse_int
    mov [calc_a], ax
.skip1:
    cmp byte [si], ' '
    jne .readop
    inc si
    jmp .skip1
.readop:
    mov al, [si]
    mov [calc_op], al
    inc si
.skip2:
    cmp byte [si], ' '
    jne .num2
    inc si
    jmp .skip2
.num2:
    call parse_int
    mov bx, ax
    mov ax, [calc_a]
    mov cl, [calc_op]
    cmp cl, '+'
    je .op_add
    cmp cl, '-'
    je .op_sub
    cmp cl, '*'
    je .op_mul
    cmp cl, '/'
    je .op_div
    mov si, msg_calc_badop
    call print_string
    jmp shell_loop
.op_add:
    add ax, bx
    jmp .op_result
.op_sub:
    sub ax, bx
    jmp .op_result
.op_mul:
    imul bx
    jmp .op_result
.op_div:
    or bx, bx
    jnz .do_div
    mov si, msg_calc_divzero
    call print_string
    jmp shell_loop
.do_div:
    cwd
    idiv bx
.op_result:
    mov byte [cur_color], 0x0E
    mov si, msg_calc_eq
    call print_color
    call print_signed_dec
    mov si, newline
    call print_string
    jmp shell_loop

; ------------------------------------------------------------
; do_mission : reflex mini-game - recon mission with Rambo
; ------------------------------------------------------------
do_mission:
    pusha
    mov word [cm_score], 0
    mov byte [cm_rounds_left], 5
    mov si, msg_game_intro
    call print_string
.round_loop:
    cmp byte [cm_rounds_left], 0
    je .game_over
    mov si, msg_target_appear
    call print_string
    xor ah, ah
    int 0x1A
    mov [cm_start_tick], dx
.wait_loop:
    mov ah, 0x01
    int 0x16
    jnz .key_hit
    xor ah, ah
    int 0x1A
    mov ax, dx
    sub ax, [cm_start_tick]
    cmp ax, 20
    jae .timeout
    jmp .wait_loop
.key_hit:
    mov ah, 0
    int 0x16
    mov byte [cur_color], 0x0A
    mov si, msg_target_hit
    call print_color
    inc word [cm_score]
    jmp .round_done
.timeout:
    mov byte [cur_color], 0x0C
    mov si, msg_target_missed
    call print_color
.round_done:
    dec byte [cm_rounds_left]
    push dx
    mov dx, 2
    call delay_n
    pop dx
    jmp .round_loop
.game_over:
    mov si, msg_game_over
    call print_string
    mov ax, [cm_score]
    call print_dec
    mov si, msg_game_over2
    call print_string
    cmp ax, 5
    je .perfect
    cmp ax, 3
    jae .good
    jmp .practice
.perfect:
    mov si, msg_score_perfect
    call print_string
    jmp .enddone
.good:
    mov si, msg_score_good
    call print_string
    jmp .enddone
.practice:
    mov si, msg_score_practice
    call print_string
.enddone:
    popa
    ret

; ------------------------------------------------------------
; do_numguess : the computer picks 1-100, you guess, get hints
; ------------------------------------------------------------
do_numguess:
    pusha
    xor ah, ah
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov cx, 100
    div cx
    inc dx                       ; dx = secret number, 1-100
    mov [ng_secret], dx
    mov word [ng_tries], 0
    mov si, msg_ng_intro
    call print_string
.guess_loop:
    mov si, msg_ng_prompt
    call print_string
    mov di, cmdbuf
    call read_line
    mov si, cmdbuf
    call parse_int
    inc word [ng_tries]
    cmp ax, [ng_secret]
    je .correct
    jg .toohigh
    mov si, msg_ng_low
    call print_string
    jmp .check_tries
.toohigh:
    mov si, msg_ng_high
    call print_string
.check_tries:
    cmp word [ng_tries], 10
    jae .out_of_tries
    jmp .guess_loop
.correct:
    mov si, msg_ng_correct
    call print_string
    mov ax, [ng_tries]
    call print_dec
    mov si, msg_ng_tries
    call print_string
    jmp .done
.out_of_tries:
    mov si, msg_ng_out
    call print_string
    mov ax, [ng_secret]
    call print_dec
    mov si, newline
    call print_string
.done:
    popa
    ret

; ------------------------------------------------------------
; do_notes / do_note : a tiny in-memory notepad for this session
; ------------------------------------------------------------
do_notes:
    pusha
    mov al, [notes_count]
    or al, al
    jnz .haveany
    mov si, msg_notes_empty
    call print_string
    jmp .done
.haveany:
    xor ch, ch
    mov cl, [notes_count]
.loop:
    or cl, cl
    jz .done
    push cx
    mov al, [notes_count]
    sub al, cl
    mov ah, 64
    mul ah
    mov si, notes_buf
    add si, ax
    push si
    mov si, dash_prefix
    call print_string
    pop si
    call print_string
    mov si, newline
    call print_string
    pop cx
    dec cl
    jmp .loop
.done:
    popa
    ret

do_history:
    pusha
    mov al, [history_count]
    or al, al
    jnz .haveany
    mov si, msg_history_empty
    call print_string
    jmp .done
.haveany:
    mov al, [history_pos]
    sub al, [history_count]
    cmp al, 0
    jge .noadd
    add al, 5
.noadd:
    mov cl, al
    mov ch, [history_count]
.loop:
    or ch, ch
    jz .done
    push cx
    xor ah, ah
    mov al, cl
    mov bl, 64
    mul bl
    mov si, history_buf
    add si, ax
    push si
    mov si, dash_prefix
    call print_string
    pop si
    call print_string
    mov si, newline
    call print_string
    pop cx
    inc cl
    cmp cl, 5
    jne .nowrap
    xor cl, cl
.nowrap:
    dec ch
    jmp .loop
.done:
    popa
    ret

; ------------------------------------------------------------
; history_add : copies cmdbuf into the history ring buffer
; ------------------------------------------------------------
history_add:
    pusha
    mov al, [history_pos]
    mov ah, 64
    mul ah
    mov di, history_buf
    add di, ax
    mov si, cmdbuf
    call strcpy
    mov al, [history_pos]
    inc al
    cmp al, 5
    jne .store
    xor al, al
.store:
    mov [history_pos], al
    cmp byte [history_count], 5
    je .done
    inc byte [history_count]
.done:
    popa
    ret

; ------------------------------------------------------------
; strcpy : copies null-terminated string SI -> DI (incl. the 0)
; ------------------------------------------------------------
strcpy:
    push ax
    push si
    push di
.loop:
    lodsb
    stosb
    or al, al
    jnz .loop
    pop di
    pop si
    pop ax
    ret

; ------------------------------------------------------------
; do_run : load a user-written app from its disk slot and
;          execute it via a far call (app returns with RETF)
; ------------------------------------------------------------
do_run:
    pusha
    mov si, msg_run_loading
    call print_string
    mov ax, APP_SEG
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, APP_SECT_COUNT
    mov ch, APP_START_CH
    mov cl, APP_START_CL
    mov dh, APP_START_DH
    mov dl, [boot_drive]
    int 0x13
    jc .load_fail
    push ds
    call APP_SEG:0x0000
    pop ds
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov si, msg_run_done
    call print_string
    popa
    ret
.load_fail:
    mov si, msg_run_fail
    call print_string
    popa
    ret

; ============================================================
; v1.4 additions: rng, snake, roll, hex, stopwatch
; ============================================================

; ------------------------------------------------------------
; rng_next : returns a pseudo-random 16-bit number in AX.
;            A 16-bit LCG, re-mixed with the BIOS timer on every
;            call so it never repeats the same sequence.
; ------------------------------------------------------------
rng_next:
    push bx
    push cx
    push dx
    xor ah, ah
    int 0x1A
    xor [rng_seed], dx
    mov ax, [rng_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [rng_seed], ax
    mov bx, ax
    shr bx, 7                    ; fold high bits into the weak low bits
    xor ax, bx
    pop dx
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; print_hex16 : prints AX as 4 hex digits
; ------------------------------------------------------------
print_hex16:
    pusha
    mov cx, 4
.digit:
    rol ax, 4
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .emit
    add al, 7
.emit:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    pop ax
    loop .digit
    popa
    ret

; ------------------------------------------------------------
; do_hex : "hex <number>"  ->  decimal to hexadecimal (16-bit)
; ------------------------------------------------------------
do_hex:
    mov si, cmdbuf
    add si, 4
    call parse_int
    push ax
    mov si, msg_hex_pre
    call print_string
    pop ax
    push ax
    call print_dec
    mov si, msg_hex_mid
    call print_string
    pop ax
    call print_hex16
    mov si, msg_hex_post
    call print_string
    jmp shell_loop

; ------------------------------------------------------------
; do_roll / do_roll_n : roll a die. "roll" = d6, "roll 20" = d20
; ------------------------------------------------------------
do_roll_n:
    mov si, cmdbuf
    add si, 5
    call parse_int
    cmp ax, 2
    jl .bad
    call roll_common
    jmp shell_loop
.bad:
    mov si, msg_roll_bad
    call print_string
    jmp shell_loop

do_roll:
    mov ax, 6
    ; fall through

roll_common:                     ; AX = number of sides (>= 2)
    pusha
    mov bx, ax
    call rng_next
    xor dx, dx
    div bx
    inc dx                       ; dx = 1..sides
    mov si, msg_roll1
    call print_string
    mov ax, bx
    call print_dec
    mov si, msg_roll2
    call print_string
    mov ax, dx
    call print_dec
    mov si, newline
    call print_string
    popa
    ret

; ------------------------------------------------------------
; do_stopwatch : any key starts it, any key stops it
; ------------------------------------------------------------
do_stopwatch:
    pusha
    mov si, msg_sw_start
    call print_string
    xor ah, ah
    int 0x16
    xor ah, ah
    int 0x1A
    mov [sw_t0], dx
    mov si, msg_sw_run
    call print_string
    xor ah, ah
    int 0x16
    xor ah, ah
    int 0x1A
    sub dx, [sw_t0]
    mov ax, dx                   ; ticks (18.2 per second)
    mov bx, 50
    mul bx
    mov bx, 91
    div bx                       ; ax = tenths of a second
    xor dx, dx
    mov bx, 10
    div bx                       ; ax = seconds, dx = tenth
    push dx
    mov si, msg_sw_res
    call print_string
    call print_dec
    mov ah, 0x0E
    xor bh, bh
    mov al, '.'
    int 0x10
    pop ax
    call print_dec
    mov si, msg_sw_res2
    call print_string
    popa
    ret

; ------------------------------------------------------------
; do_snake : classic Snake in VGA text mode (direct video RAM).
;   Arrows or WASD steer, ESC quits. It speeds up as you score.
;   Playfield = rows 2-23, cols 1-78; cell index = row*80+col.
; ------------------------------------------------------------
SNAKE_MAX equ 250

do_snake:
    pusha
    push es
    call clear_screen
    mov ah, 0x01                 ; hide the hardware cursor
    mov cx, 0x2000
    int 0x10

    mov ax, 0xB800
    mov es, ax
    cld

    ; --- border ---
    mov ax, 0x0B23               ; cyan '#'
    mov di, 80*2
    mov cx, 80
    rep stosw
    mov di, 24*80*2
    mov cx, 80
    rep stosw
    mov di, 2*80*2
    mov cx, 22
.side:
    mov [es:di], ax
    mov [es:di+158], ax
    add di, 160
    loop .side

    ; --- initial state: length 3, heading right ---
    xor ah, ah
    int 0x1A
    mov [rng_seed], dx
    mov word [sn_score], 0
    mov word [sn_len], 3
    mov word [sn_dir], 1
    mov word [sn_moved], 1
    mov byte [sn_quit], 0
    mov byte [sn_food_new], 0
    mov word [sn_tail], 0
    mov word [sn_head], 4
    mov word [sn_buf],   12*80+38
    mov word [sn_buf+2], 12*80+39
    mov word [sn_buf+4], 12*80+40
    mov word [es:(12*80+38)*2], 0x026F
    mov word [es:(12*80+39)*2], 0x026F
    mov word [es:(12*80+40)*2], 0x0A4F
    call sn_place_food
    call sn_draw_score

; ---------------- main loop: wait, read keys, step ----------------
.loop:
    xor ah, ah
    int 0x1A
    mov [sn_t0], dx
    mov ax, 2                    ; ~9 steps/s ...
    cmp word [sn_score], 8
    jb .setdelay
    mov ax, 1                    ; ... ~18 steps/s once you're good
.setdelay:
    mov [sn_delay], ax
.wait:
    mov ah, 1
    int 0x16
    jz .nokey
    xor ah, ah
    int 0x16
    call sn_key
.nokey:
    xor ah, ah
    int 0x1A
    sub dx, [sn_t0]
    cmp dx, [sn_delay]
    jb .wait

    cmp byte [sn_quit], 0
    jne .quit

    ; --- compute the new head cell ---
    mov ax, [sn_dir]
    mov [sn_moved], ax
    mov bx, [sn_head]
    mov si, [sn_buf + bx]
    add si, ax                   ; si = new head cell index
    mov di, si
    shl di, 1
    mov dl, [es:di]
    cmp dl, '*'
    je .eat
    call sn_erase_tail           ; tail moves away before we check
    mov dl, [es:di]
    cmp dl, '#'
    je .dead
    cmp dl, 'o'
    je .dead
    jmp .advance
.eat:
    inc word [sn_score]
    inc word [sn_len]
    mov byte [sn_food_new], 1

.advance:
    mov bx, [sn_head]
    mov di, [sn_buf + bx]
    shl di, 1
    mov word [es:di], 0x026F     ; old head becomes body
    add bx, 2
    and bx, 0x1FE
    mov [sn_head], bx
    mov [sn_buf + bx], si
    mov di, si
    shl di, 1
    mov word [es:di], 0x0A4F     ; new head
    cmp byte [sn_food_new], 0
    je .loop
    mov byte [sn_food_new], 0
    call sn_beep
    cmp word [sn_len], SNAKE_MAX
    jae .win
    call sn_place_food
    call sn_draw_score
    jmp .loop

.dead:
    mov si, msg_sn_dead
    jmp .finish
.win:
    mov si, msg_sn_win
.finish:
    mov ah, 0x02
    xor bh, bh
    mov dh, 12
    mov dl, 24
    int 0x10
    call print_string
    call sn_pause1s              ; so a held key can't skip the message
.flush:
    mov ah, 1
    int 0x16
    jz .waitkey
    xor ah, ah
    int 0x16
    jmp .flush
.waitkey:
    xor ah, ah
    int 0x16
.quit:
    mov ah, 0x01                 ; restore the cursor
    mov cx, 0x0607
    int 0x10
    pop es
    call do_clear
    popa
    ret

; sn_key : AH = scan code, AL = ascii  ->  updates direction / quit
sn_key:
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp ah, 0x01
    je .esc
    or al, 0x20
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'a'
    je .left
    cmp al, 'd'
    je .right
    ret
.up:
    mov bx, -80
    jmp .set
.down:
    mov bx, 80
    jmp .set
.left:
    mov bx, -1
    jmp .set
.right:
    mov bx, 1
.set:
    mov ax, [sn_moved]
    neg ax
    cmp ax, bx                   ; no 180-degree turns
    je .done
    mov [sn_dir], bx
.done:
    ret
.esc:
    mov byte [sn_quit], 1
    ret

; sn_erase_tail : blank the tail cell and advance the tail index
sn_erase_tail:
    push bx
    push di
    mov bx, [sn_tail]
    mov di, [sn_buf + bx]
    shl di, 1
    mov word [es:di], 0x0720
    add bx, 2
    and bx, 0x1FE
    mov [sn_tail], bx
    pop di
    pop bx
    ret

; sn_place_food : drop a '*' on a random empty cell
sn_place_food:
    push ax
    push bx
    push dx
    push di
.try:
    call rng_next
    xor dx, dx
    mov bx, 22
    div bx
    add dx, 2                    ; row 2..23
    mov ax, dx
    mov bx, 80
    mul bx                       ; ax = row*80
    push ax
    call rng_next
    xor dx, dx
    mov bx, 78
    div bx
    inc dx                       ; col 1..78
    pop ax
    add ax, dx
    mov di, ax
    shl di, 1
    cmp byte [es:di], ' '
    jne .try
    mov word [es:di], 0x0C2A     ; red '*'
    pop di
    pop dx
    pop bx
    pop ax
    ret

; sn_draw_score : HUD on row 0
sn_draw_score:
    pusha
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 0x10
    mov si, msg_sn_hud
    call print_string
    mov ax, [sn_score]
    call print_dec
    mov si, msg_sn_hud2
    call print_string
    popa
    ret

; sn_beep : short PC-speaker blip when food is eaten
sn_beep:
    push ax
    push cx
    mov al, 0xB6
    out 0x43, al
    mov ax, 1500
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    mov cx, 0x3000
.d: loop .d
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    pop cx
    pop ax
    ret

; sn_pause1s : wait ~1 second on the BIOS timer
sn_pause1s:
    push ax
    push cx
    push dx
    xor ah, ah
    int 0x1A
    mov [sn_t0], dx
.w:
    xor ah, ah
    int 0x1A
    sub dx, [sn_t0]
    cmp dx, 18
    jb .w
    pop dx
    pop cx
    pop ax
    ret

; ============================================================
; v1.5 additions: pong, matrix, pet, dump, bin
; ============================================================

; ------------------------------------------------------------
; print_hex8 : prints AL as 2 hex digits (preserves all regs)
; ------------------------------------------------------------
print_hex8:
    push ax
    push bx
    push cx
    mov cl, al
    shr al, 4
    call .nib
    mov al, cl
    call .nib
    pop cx
    pop bx
    pop ax
    ret
.nib:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .e
    add al, 7
.e:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret

; ------------------------------------------------------------
; parse_hex : SI -> text, returns AX = value (skips leading spaces)
; ------------------------------------------------------------
parse_hex:
    push bx
    xor bx, bx
.skip:
    cmp byte [si], ' '
    jne .lp
    inc si
    jmp .skip
.lp:
    mov al, [si]
    cmp al, '0'
    jb .done
    cmp al, '9'
    jbe .dig
    or al, 0x20
    cmp al, 'a'
    jb .done
    cmp al, 'f'
    ja .done
    sub al, 'a' - 10
    jmp .add
.dig:
    sub al, '0'
.add:
    shl bx, 4
    xor ah, ah
    add bx, ax
    inc si
    jmp .lp
.done:
    mov ax, bx
    pop bx
    ret

; ------------------------------------------------------------
; do_bin : "bin <number>"  ->  16-bit binary, in nibbles
; ------------------------------------------------------------
do_bin:
    mov si, cmdbuf
    add si, 4
    call parse_int
    push ax
    mov si, msg_hex_pre
    call print_string
    pop ax
    push ax
    call print_dec
    mov si, msg_bin_mid
    call print_string
    pop bx
    mov cx, 16
.bit:
    mov al, '0'
    test bx, 0x8000
    jz .z
    inc al
.z:
    mov ah, 0x0E
    push bx
    xor bh, bh
    int 0x10
    pop bx
    shl bx, 1
    dec cx
    jz .end
    test cl, 3
    jnz .bit
    mov al, ' '
    mov ah, 0x0E
    push bx
    xor bh, bh
    int 0x10
    pop bx
    jmp .bit
.end:
    mov si, newline
    call print_string
    jmp shell_loop

; ------------------------------------------------------------
; do_dump : "dump <hex address>" -> 8 rows x 16 bytes of memory
;           (segment 0). Try "dump 7C00" - that is the boot sector!
; ------------------------------------------------------------
do_dump:
    mov si, cmdbuf
    add si, 5
    call parse_hex
    and ax, 0xFFF0
    mov [dump_addr], ax
    mov word [dump_row], 8
.row:
    mov si, msg_hex_pre
    call print_string
    mov ax, [dump_addr]
    call print_hex16
    mov si, msg_dump_sep
    call print_string
    mov si, [dump_addr]
    mov cx, 16
.b:
    lodsb
    call print_hex8
    mov al, ' '
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    loop .b
    mov si, [dump_addr]
    mov cx, 16
.a:
    lodsb
    cmp al, 32
    jb .dot
    cmp al, 126
    ja .dot
    jmp .p
.dot:
    mov al, '.'
.p:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    loop .a
    mov si, newline
    call print_string
    add word [dump_addr], 16
    dec word [dump_row]
    jnz .row
    jmp shell_loop

; ------------------------------------------------------------
; do_pet : pet Rambo. He purrs (alternating low tones on the
;          PC speaker for ~2 seconds).
; ------------------------------------------------------------
do_pet:
    pusha
    mov si, msg_pet1
    call print_string
    mov si, 36
.p:
    mov ax, 19886                ; ~60 Hz
    test si, 1
    jz .f
    mov ax, 13258                ; ~90 Hz
.f:
    push ax
    mov al, 0xB6
    out 0x43, al
    pop ax
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    xor ah, ah
    int 0x1A
    mov bx, dx
.w:
    xor ah, ah
    int 0x1A
    cmp dx, bx
    je .w
    dec si
    jnz .p
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    mov si, msg_pet2
    call print_string
    popa
    ret

; ------------------------------------------------------------
; do_matrix : falling green code in VGA text memory. Any key stops.
; ------------------------------------------------------------
do_matrix:
    pusha
    push es
    call clear_screen
    mov ah, 0x01
    mov cx, 0x2000
    int 0x10
    mov ax, 0xB800
    mov es, ax
    xor ah, ah
    int 0x1A
    mov [rng_seed], dx
    mov byte [mx_frame], 0
    mov di, mx_heads
    mov cx, 80
.init:
    call rng_next
    and ax, 31
    neg ax
    mov [di], ax
    add di, 2
    loop .init

.frame:
    xor ah, ah
    int 0x1A
    mov [sn_t0], dx
    inc byte [mx_frame]
    xor bx, bx                   ; bx = column
.col:
    test bl, 1                   ; odd columns fall at half speed
    jz .go
    test byte [mx_frame], 1
    jz .next
.go:
    mov si, bx
    shl si, 1
    mov ax, [mx_heads + si]
    inc ax
    cmp ax, 36
    jl .store
    call rng_next
    and ax, 15
    neg ax
.store:
    mov [mx_heads + si], ax
    mov cx, ax                   ; cx = head row
    call mx_addr
    jc .t1
    call rng_next
    and ax, 0x3F
    add al, 0x30
    mov ah, 0x0F
    mov [es:di], ax              ; bright head
.t1:
    mov ax, cx
    dec ax
    call mx_addr
    jc .t2
    mov byte [es:di+1], 0x0A     ; light green just behind
.t2:
    mov ax, cx
    sub ax, 5
    call mx_addr
    jc .t3
    mov byte [es:di+1], 0x02     ; dark green further back
.t3:
    mov ax, cx
    sub ax, 10
    call mx_addr
    jc .next
    mov word [es:di], 0x0720     ; tail fades out
.next:
    inc bx
    cmp bx, 80
    jb .col

.wait:
    mov ah, 1
    int 0x16
    jnz .exit
    xor ah, ah
    int 0x1A
    cmp dx, [sn_t0]
    je .wait
    jmp .frame
.exit:
    xor ah, ah
    int 0x16
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10
    pop es
    call do_clear
    popa
    ret

; mx_addr : AX = row (signed), BX = col -> DI = video offset, CF=1 if off-screen
mx_addr:
    cmp ax, 0
    jl .bad
    cmp ax, 24
    jg .bad
    push dx
    push ax
    mov dx, 80
    mul dx
    add ax, bx
    shl ax, 1
    mov di, ax
    pop ax
    pop dx
    clc
    ret
.bad:
    stc
    ret

; ------------------------------------------------------------
; do_pong : you (left, W/S or arrows) vs the CPU (right).
;           First to 7 wins. ESC quits.
;   Playfield rows 2-23, cols 0-79. Ball moves 1 column/frame.
; ------------------------------------------------------------
PONG_WIN equ 7

do_pong:
    pusha
    push es
    call clear_screen
    mov ah, 0x01
    mov cx, 0x2000
    int 0x10
    mov ax, 0xB800
    mov es, ax
    cld
    xor ah, ah
    int 0x1A
    mov [rng_seed], dx
    mov word [pg_sp], 0
    mov word [pg_sc], 0
    mov word [pg_pl], 10
    mov word [pg_cp], 10
    mov word [pg_dir], 1
    mov word [pg_frame], 0
    call pg_serve
    call pg_hud
    mov ax, 0x0B3D               ; cyan '=' walls on rows 1 and 24
    mov di, 80*1*2
    mov cx, 80
    rep stosw
    mov di, 80*24*2
    mov cx, 80
    rep stosw

.frame:
    xor ah, ah
    int 0x1A
    mov [sn_t0], dx
    inc word [pg_frame]

    ; ---- keys (drain the whole keyboard buffer) ----
.keys:
    mov ah, 1
    int 0x16
    jz .cpu
    xor ah, ah
    int 0x16
    cmp ah, 0x01
    je .quit
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    or al, 0x20
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    jmp .keys
.up:
    sub word [pg_pl], 2
    cmp word [pg_pl], 2
    jge .keys
    mov word [pg_pl], 2
    jmp .keys
.down:
    add word [pg_pl], 2
    cmp word [pg_pl], 19
    jle .keys
    mov word [pg_pl], 19
    jmp .keys

    ; ---- CPU paddle: half speed, only chases a ball coming its way ----
.cpu:
    test word [pg_frame], 1
    jnz .ball
    cmp word [pg_vx], 0
    jle .ball
    mov ax, [pg_by]
    mov bx, [pg_cp]
    add bx, 2
    cmp ax, bx
    jl .cup
    jg .cdown
    jmp .ball
.cup:
    dec word [pg_cp]
    cmp word [pg_cp], 2
    jge .ball
    mov word [pg_cp], 2
    jmp .ball
.cdown:
    inc word [pg_cp]
    cmp word [pg_cp], 19
    jle .ball
    mov word [pg_cp], 19

    ; ---- ball ----
.ball:
    mov ax, [pg_vx]
    add [pg_bx], ax
    mov ax, [pg_vy]
    add [pg_by], ax
    cmp word [pg_by], 2
    jg .nt
    mov word [pg_by], 2
    mov word [pg_vy], 1
.nt:
    cmp word [pg_by], 23
    jl .nb
    mov word [pg_by], 23
    mov word [pg_vy], -1
.nb:
    ; hit on your paddle (column 2)? where it lands changes the angle
    cmp word [pg_bx], 3
    jne .chkr
    cmp word [pg_vx], 0
    jge .chkr
    mov ax, [pg_by]
    sub ax, [pg_pl]
    cmp ax, 0
    jl .chkr
    cmp ax, 4
    jg .chkr
    mov word [pg_vx], 1
    cmp ax, 1
    jg .l2
    mov word [pg_vy], -1
    jmp .lhit
.l2:
    cmp ax, 3
    jl .lhit
    mov word [pg_vy], 1
.lhit:
    call sn_beep
.chkr:
    ; hit on the CPU paddle (column 77)?
    cmp word [pg_bx], 76
    jne .chks
    cmp word [pg_vx], 0
    jle .chks
    mov ax, [pg_by]
    sub ax, [pg_cp]
    cmp ax, 0
    jl .chks
    cmp ax, 4
    jg .chks
    mov word [pg_vx], -1
    call sn_beep
.chks:
    ; scoring
    cmp word [pg_bx], 1
    jg .s2
    inc word [pg_sc]             ; ball got past you: CPU scores
    mov word [pg_dir], -1
    jmp .point
.s2:
    cmp word [pg_bx], 78
    jl .draw
    inc word [pg_sp]             ; ball got past the CPU: you score
    mov word [pg_dir], 1
.point:
    call sn_beep
    call pg_serve
    call pg_hud
    cmp word [pg_sp], PONG_WIN
    jae .win
    cmp word [pg_sc], PONG_WIN
    jae .lose
    call sn_pause1s

    ; ---- draw ----
.draw:
    mov ax, 0x0720
    mov di, 80*2*2
    mov cx, 80*22
    rep stosw
    mov di, (2*80+40)*2          ; dotted centre line
    mov cx, 11
.cl:
    mov word [es:di], 0x083A
    add di, 320
    loop .cl
    mov ax, [pg_pl]
    mov bx, 2
    mov dl, 0x0A
    call pg_paddle
    mov ax, [pg_cp]
    mov bx, 77
    mov dl, 0x0C
    call pg_paddle
    mov ax, [pg_by]
    mov bx, [pg_bx]
    call pg_cell
    mov word [es:di], 0x0F4F     ; the ball

.wait:
    xor ah, ah
    int 0x1A
    cmp dx, [sn_t0]
    je .wait
    jmp .frame

.win:
    mov si, msg_pg_win
    jmp .fin
.lose:
    mov si, msg_pg_lose
.fin:
    mov ah, 0x02
    xor bh, bh
    mov dh, 12
    mov dl, 24
    int 0x10
    call print_string
    call sn_pause1s
.flush:
    mov ah, 1
    int 0x16
    jz .waitkey
    xor ah, ah
    int 0x16
    jmp .flush
.waitkey:
    xor ah, ah
    int 0x16
.quit:
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10
    pop es
    call do_clear
    popa
    ret

; pg_cell : AX = row, BX = col -> DI = video offset (preserves AX, DX)
pg_cell:
    push ax
    push dx
    mov dx, 80
    mul dx
    add ax, bx
    shl ax, 1
    mov di, ax
    pop dx
    pop ax
    ret

; pg_paddle : AX = top row, BX = col, DL = attribute (5 cells tall)
pg_paddle:
    push cx
    push ax
    mov cx, 5
.p:
    call pg_cell
    mov byte [es:di], 0xDB
    mov [es:di+1], dl
    inc ax
    loop .p
    pop ax
    pop cx
    ret

; pg_serve : ball to the centre, random row and slope, heading pg_dir
pg_serve:
    push ax
    push bx
    push dx
    mov word [pg_bx], 40
    call rng_next
    xor dx, dx
    mov bx, 17
    div bx
    add dx, 4
    mov [pg_by], dx
    call rng_next
    mov word [pg_vy], 1
    test ax, 0x100
    jz .k
    mov word [pg_vy], -1
.k:
    mov ax, [pg_dir]
    mov [pg_vx], ax
    pop dx
    pop bx
    pop ax
    ret

; pg_hud : score line on row 0
pg_hud:
    pusha
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 0x10
    mov si, msg_pg_hud1
    call print_string
    mov ax, [pg_sp]
    call print_dec
    mov si, msg_pg_hud2
    call print_string
    mov ax, [pg_sc]
    call print_dec
    mov si, msg_pg_hud3
    call print_string
    popa
    ret

; ============================================================
; v1.5 extra features: meow boot sound, boot menu, kernel panic,
; dice game, Rambo RPG, MeowPad text editor
; ============================================================

; ------------------------------------------------------------
; snd_meow : a little rising-then-falling "mrreow" on the PC
;            speaker. Called once at boot.
; ------------------------------------------------------------
snd_meow:
    pusha
    mov al, 0xB6
    out 0x43, al
    in al, 0x61
    or al, 3
    out 0x61, al
    mov cx, 20
    mov bx, 1800
.up:
    push cx
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    mov cx, 0x0700
.d1:
    loop .d1
    pop cx
    sub bx, 45
    loop .up
    mov cx, 16
    mov bx, 900
.down:
    push cx
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    mov cx, 0x0A00
.d2:
    loop .d2
    pop cx
    add bx, 60
    loop .down
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

; ------------------------------------------------------------
; do_panic : a fake, friendly "kernel panic" easter egg.
;            Blue screen, sad meow, reboots on a keypress.
; ------------------------------------------------------------
do_panic:
    pusha
    push es
    mov ax, 0xB800
    mov es, ax
    mov ax, 0x1F20            ; white on blue, space
    xor di, di
    mov cx, 80*25
    rep stosw
    mov dh, 7
    mov dl, 10
    call gfx_cursor
    mov si, msg_panic1
    call print_string
    mov dh, 9
    mov dl, 10
    call gfx_cursor
    mov si, msg_panic2
    call print_string
    mov dh, 11
    mov dl, 10
    call gfx_cursor
    mov si, msg_panic3
    call print_string
    mov dh, 13
    mov dl, 10
    call gfx_cursor
    mov si, msg_panic4
    call print_string
    call snd_sad_meow
    xor ah, ah
    int 0x16
    pop es
    popa
    mov si, msg_reboot
    call print_string
    mov ah, 0
    int 0x16
    int 0x19
    ret

; snd_sad_meow : a slow descending tone for the panic screen
snd_sad_meow:
    pusha
    mov al, 0xB6
    out 0x43, al
    in al, 0x61
    or al, 3
    out 0x61, al
    mov cx, 18
    mov bx, 1000
.down:
    push cx
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    mov cx, 0x1600
.d:
    loop .d
    pop cx
    add bx, 90
    loop .down
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

; ------------------------------------------------------------
; do_dice : "dice" - you vs the CPU, 3d6 per round, best of 5.
; ------------------------------------------------------------
do_dice:
    pusha
    mov word [dc_round], 1
    mov word [dc_you], 0
    mov word [dc_cpu], 0
    mov si, msg_dice_title
    call print_string
.round:
    mov si, msg_dice_round
    call print_string
    mov ax, [dc_round]
    call print_dec
    mov si, newline
    call print_string

    call roll3d6
    mov [dc_roll_you], ax
    mov si, msg_dice_you
    call print_string
    call print_dec
    mov si, newline
    call print_string

    call roll3d6
    mov [dc_roll_cpu], ax
    mov si, msg_dice_cpu
    call print_string
    call print_dec
    mov si, newline
    call print_string

    mov ax, [dc_roll_you]
    cmp ax, [dc_roll_cpu]
    je .tie
    jg .win
    mov si, msg_dice_lose
    call print_string
    inc word [dc_cpu]
    jmp .next
.win:
    mov si, msg_dice_win
    call print_string
    inc word [dc_you]
    jmp .next
.tie:
    mov si, msg_dice_tie
    call print_string
.next:
    mov si, newline
    call print_string
    inc word [dc_round]
    cmp word [dc_round], 6
    jl .round

    mov si, msg_dice_final
    call print_string
    mov ax, [dc_you]
    call print_dec
    mov si, msg_dice_sep
    call print_string
    mov ax, [dc_cpu]
    call print_dec
    mov si, newline
    call print_string

    mov ax, [dc_you]
    cmp ax, [dc_cpu]
    je .ftie
    jg .fwin
    mov si, msg_dice_floss
    call print_string
    jmp .fdone
.fwin:
    mov si, msg_dice_fwin
    call print_string
    jmp .fdone
.ftie:
    mov si, msg_dice_fdraw
    call print_string
.fdone:
    popa
    ret

; roll3d6 : returns AX = sum of three d6 (3-18)
roll3d6:
    push bx
    push cx
    push dx
    push si
    xor si, si
    mov cx, 3
.r:
    push cx
    call rng_next
    xor dx, dx
    mov bx, 6
    div bx
    inc dx
    add si, dx
    pop cx
    loop .r
    mov ax, si
    pop si
    pop dx
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; do_meowpad : a tiny text editor. Up to 8 lines, blank line
;              or ESC-then-Enter to finish, then shows them back.
; ------------------------------------------------------------
MEOWPAD_LINES equ 8

do_meowpad:
    pusha
    mov si, msg_mp_title
    call print_string
    xor bx, bx
.loop:
    cmp bx, MEOWPAD_LINES
    je .show
    mov ax, bx
    inc ax
    call print_dec
    mov si, msg_mp_prompt
    call print_string
    push bx
    mov ax, bx
    mov cl, 64
    mul cl
    mov di, meow_lines
    add di, ax
    call read_line
    pop bx
    mov di, meow_lines
    mov ax, bx
    mov cl, 64
    mul cl
    add di, ax
    cmp byte [di], 0
    je .show
    inc bx
    jmp .loop
.show:
    mov [mp_count], bx
    mov si, msg_mp_out
    call print_string
    xor bx, bx
.plines:
    cmp bx, [mp_count]
    je .pend
    mov ax, bx
    mov cl, 64
    mul cl
    mov si, meow_lines
    add si, ax
    call print_string
    mov si, newline
    call print_string
    inc bx
    jmp .plines
.pend:
    mov si, msg_mp_end
    call print_string
    popa
    ret

; ------------------------------------------------------------
; do_rpg : a short Rambo text adventure
; ------------------------------------------------------------
do_rpg:
    pusha
    mov si, msg_rpg_intro
    call print_string
.q1:
    mov si, msg_rpg_q1
    call print_string
    call rpg_key
    cmp al, '2'
    je .sleepy_end
.patrol:
    mov si, msg_rpg_patrol
    call print_string
    mov si, msg_rpg_q2
    call print_string
    call rpg_key
    cmp al, '2'
    je .closet_end
.standground:
    mov si, msg_rpg_fight
    call print_string
    call roll3d6
    mov bx, ax
    mov si, msg_rpg_you_rolled
    call print_string
    mov ax, bx
    call print_dec
    mov si, newline
    call print_string

    call roll3d6
    mov cx, ax
    mov si, msg_rpg_dog_rolled
    call print_string
    mov ax, cx
    call print_dec
    mov si, newline
    call print_string

    cmp bx, cx
    jl .lose_end
    mov si, msg_rpg_win_end
    jmp .finish
.closet_end:
    mov si, msg_rpg_closet_end
    jmp .finish
.sleepy_end:
    mov si, msg_rpg_sleepy_end
    jmp .finish
.lose_end:
    mov si, msg_rpg_lose_end
.finish:
    call print_string
    popa
    ret

; rpg_key : waits for '1' or '2', returns it in AL
rpg_key:
    mov ah, 0
    int 0x16
    cmp al, '1'
    je .ok
    cmp al, '2'
    je .ok
    jmp rpg_key
.ok:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    mov si, newline
    call print_string
    ret

; ============================================================
; GUI - a real VGA mode 0x13 (320x200, 256-color) desktop.
; Arrow keys move between icons, Enter activates, ESC exits.
; ============================================================
GFX_SEG equ 0xA000

set_gfx_mode:
    mov ax, 0x0013
    int 0x10
    ret

set_text_mode:
    mov ax, 0x0003
    int 0x10
    ret

; ------------------------------------------------------------
; fill_rect : fills [rect_x,rect_y,rect_w,rect_h] with rect_color
; ------------------------------------------------------------
fill_rect:
    pusha
    push es
    mov ax, GFX_SEG
    mov es, ax
    mov dx, [rect_y]
    mov cx, [rect_h]
.rowloop:
    or cx, cx
    jz .done
    push cx
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, [rect_x]
    mov di, ax
    pop dx
    mov al, [rect_color]
    mov cx, [rect_w]
    rep stosb
    pop cx
    inc dx
    dec cx
    jmp .rowloop
.done:
    pop es
    popa
    ret

; ------------------------------------------------------------
; put_pixel : plots [px_x,px_y] in px_color
; ------------------------------------------------------------
put_pixel:
    pusha
    push es
    mov ax, GFX_SEG
    mov es, ax
    mov ax, [px_y]
    mov bx, 320
    mul bx
    add ax, [px_x]
    mov di, ax
    mov al, [px_color]
    mov [es:di], al
    pop es
    popa
    ret

; ------------------------------------------------------------
; gfx_cursor : sets BIOS text cursor to row DH, col DL (works
;              in graphics modes too - used to position labels)
; ------------------------------------------------------------
gfx_cursor:
    push ax
    push bx
    mov ah, 0x02
    mov bh, 0
    int 0x10
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; draw_icon : draws one desktop icon using icon_* globals
; ------------------------------------------------------------
draw_icon:
    pusha
    mov ax, [icon_x]
    sub ax, 3
    mov [rect_x], ax
    mov ax, [icon_y]
    sub ax, 3
    mov [rect_y], ax
    mov ax, [icon_size]
    add ax, 6
    mov [rect_w], ax
    mov [rect_h], ax
    mov al, [icon_border]
    mov [rect_color], al
    call fill_rect

    mov ax, [icon_x]
    mov [rect_x], ax
    mov ax, [icon_y]
    mov [rect_y], ax
    mov ax, [icon_size]
    mov [rect_w], ax
    mov [rect_h], ax
    mov al, [icon_color]
    mov [rect_color], al
    call fill_rect

    ; label below the icon
    mov ax, [icon_y]
    add ax, [icon_size]
    add ax, 6
    mov cl, 8
    xor ch, ch
    div cl
    mov dh, al                 ; row = (y+size+6)/8
    mov ax, [icon_x]
    div cl
    mov dl, al                 ; col = x/8
    call gfx_cursor
    mov byte [cur_color], 0x0F
    mov si, [icon_label]
    call print_color
    popa
    ret

; ------------------------------------------------------------
; draw_desktop : full GUI desktop with 4 icons
; ------------------------------------------------------------
NUM_ICONS equ 4

draw_desktop:
    pusha
    mov word [rect_x], 0
    mov word [rect_y], 0
    mov word [rect_w], 320
    mov word [rect_h], 200
    mov byte [rect_color], 0x01
    call fill_rect

    mov word [rect_x], 0
    mov word [rect_y], 182
    mov word [rect_w], 320
    mov word [rect_h], 18
    mov byte [rect_color], 0x08
    call fill_rect

    mov dh, 23
    mov dl, 1
    call gfx_cursor
    mov byte [cur_color], 0x0F
    mov si, msg_gui_hint
    call print_color

    xor bx, bx
.icon_loop:
    cmp bx, NUM_ICONS
    je .icons_done
    mov ax, bx
    mov cx, 70
    mul cx
    add ax, 25
    mov [icon_x], ax
    mov word [icon_y], 50
    mov word [icon_size], 40

    cmp bl, [gui_selected]
    jne .notsel
    mov byte [icon_border], 0x0E
    jmp .setcolor
.notsel:
    mov byte [icon_border], 0x07
.setcolor:
    mov al, bl
    mov si, icon_colors
    add si, ax
    mov al, [si]
    mov [icon_color], al

    mov al, bl
    xor ah, ah
    shl ax, 1
    mov si, icon_labels
    add si, ax
    mov si, [si]
    mov [icon_label], si

    call draw_icon
    inc bx
    jmp .icon_loop
.icons_done:
    popa
    ret

; ------------------------------------------------------------
; draw_fetch_panel : rambofetch, rendered inside the GUI
; ------------------------------------------------------------
draw_fetch_panel:
    pusha
    mov word [rect_x], 0
    mov word [rect_y], 0
    mov word [rect_w], 320
    mov word [rect_h], 200
    mov byte [rect_color], 0x01
    call fill_rect

    mov word [rect_x], 10
    mov word [rect_y], 10
    mov word [rect_w], 300
    mov word [rect_h], 180
    mov byte [rect_color], 0x0F
    call fill_rect

    mov dh, 2
    mov dl, 2
    call gfx_cursor
    call rambofetch

    mov dh, 24
    mov dl, 1
    call gfx_cursor
    mov byte [cur_color], 0x0F
    mov si, msg_gui_anykey
    call print_color
    popa
    ret

; ------------------------------------------------------------
; draw_rambo_panel : a real pixel-drawn cat face - no ASCII!
; ------------------------------------------------------------
draw_rambo_panel:
    pusha
    mov word [rect_x], 0
    mov word [rect_y], 0
    mov word [rect_w], 320
    mov word [rect_h], 200
    mov byte [rect_color], 0x09
    call fill_rect

    ; head
    mov word [rect_x], 100
    mov word [rect_y], 60
    mov word [rect_w], 120
    mov word [rect_h], 90
    mov byte [rect_color], 0x06
    call fill_rect

    ; ears (stepped triangles)
    mov si, ear_widths
    mov cx, 6
    mov dx, 55                   ; starting y
.earloop:
    push cx
    push dx
    lodsb
    xor ah, ah
    mov [rect_w], ax
    ; left ear: x = 108 - width/2
    mov bx, ax
    shr bx, 1
    mov ax, 118
    sub ax, bx
    mov [rect_x], ax
    mov [rect_y], dx
    mov word [rect_h], 1
    mov byte [rect_color], 0x06
    call fill_rect
    ; right ear: x = 202 - width/2
    mov ax, 202
    sub ax, bx
    mov [rect_x], ax
    call fill_rect
    pop dx
    pop cx
    inc dx
    loop .earloop

    ; eyes
    mov word [rect_x], 130
    mov word [rect_y], 95
    mov word [rect_w], 14
    mov word [rect_h], 14
    mov byte [rect_color], 0x00
    call fill_rect
    mov word [rect_x], 176
    call fill_rect
    mov word [rect_x], 134
    mov word [rect_y], 99
    mov word [rect_w], 6
    mov word [rect_h], 6
    mov byte [rect_color], 0x0F
    call fill_rect
    mov word [rect_x], 180
    call fill_rect

    ; nose
    mov word [rect_x], 156
    mov word [rect_y], 120
    mov word [rect_w], 8
    mov word [rect_h], 6
    mov byte [rect_color], 0x0D
    call fill_rect

    ; mouth
    mov word [rect_x], 148
    mov word [rect_y], 128
    mov word [rect_w], 24
    mov word [rect_h], 2
    mov byte [rect_color], 0x00
    call fill_rect

    ; whiskers
    mov word [rect_x], 60
    mov word [rect_y], 108
    mov word [rect_w], 35
    mov word [rect_h], 1
    mov byte [rect_color], 0x0F
    call fill_rect
    mov word [rect_y], 114
    call fill_rect
    mov word [rect_x], 225
    mov word [rect_y], 108
    call fill_rect
    mov word [rect_y], 114
    call fill_rect

    mov dh, 22
    mov dl, 9
    call gfx_cursor
    mov byte [cur_color], 0x0F
    mov si, msg_gui_rambo_caption
    call print_color
    mov dh, 24
    mov dl, 1
    call gfx_cursor
    mov si, msg_gui_anykey
    call print_color
    popa
    ret

; ------------------------------------------------------------
; show_cursor / hide_cursor : the Paint mode's pixel cursor
; ------------------------------------------------------------
show_cursor:
    pusha
    push es
    mov ax, GFX_SEG
    mov es, ax
    mov ax, [paint_y]
    mov bx, 320
    mul bx
    add ax, [paint_x]
    mov di, ax
    mov al, [es:di]
    mov [paint_under], al
    mov byte [es:di], 0x0F
    pop es
    popa
    ret

hide_cursor:
    pusha
    push es
    mov ax, GFX_SEG
    mov es, ax
    mov ax, [paint_y]
    mov bx, 320
    mul bx
    add ax, [paint_x]
    mov di, ax
    mov al, [paint_under]
    mov [es:di], al
    pop es
    popa
    ret

; ------------------------------------------------------------
; PS/2 mouse driver - written from scratch against the 8042
; controller ports (0x60/0x64). RamboOS has no DOS mouse driver
; to call, so this talks to the hardware directly and polls
; (no IRQ hook needed, so it can't clash with the BIOS keyboard
; handler or hang if no mouse is present - both waits below are
; timeout-guarded).
; ------------------------------------------------------------
kbc_wait_input:
    push ax
    push cx
    mov cx, 0xFFFF
.loop:
    in al, 0x64
    test al, 0x02
    jz .done
    loop .loop
.done:
    pop cx
    pop ax
    ret

kbc_wait_output:
    push ax
    push cx
    mov cx, 0xFFFF
.loop:
    in al, 0x64
    test al, 0x01
    jnz .done
    loop .loop
.done:
    pop cx
    pop ax
    ret

mouse_init:
    pusha
    call kbc_wait_input
    mov al, 0xA8              ; enable auxiliary (mouse) device
    out 0x64, al

    call kbc_wait_input
    mov al, 0x20               ; read controller command byte
    out 0x64, al
    call kbc_wait_output
    in al, 0x60
    and al, 0xDD                ; clear bit1 (no mouse IRQ - we poll)
                                  ; and bit5 (enable mouse clock)
    mov [mouse_status_tmp], al
    call kbc_wait_input
    mov al, 0x60
    out 0x64, al
    call kbc_wait_input
    mov al, [mouse_status_tmp]
    out 0x60, al

    call kbc_wait_input          ; set defaults
    mov al, 0xD4
    out 0x64, al
    call kbc_wait_input
    mov al, 0xF6
    out 0x60, al
    call kbc_wait_output
    in al, 0x60

    call kbc_wait_input           ; enable data reporting
    mov al, 0xD4
    out 0x64, al
    call kbc_wait_input
    mov al, 0xF4
    out 0x60, al
    call kbc_wait_output
    in al, 0x60
    popa
    ret

; ------------------------------------------------------------
; poll_mouse : non-blocking. If a full 3-byte PS/2 packet has
; arrived, updates cursor_x/cursor_y (clamped) and mouse_left_btn.
; Only ever reads a byte when the controller confirms it's AUX
; (mouse) data, so it never steals a keyboard byte.
; ------------------------------------------------------------
poll_mouse:
    pusha
.drain:
    in al, 0x64
    and al, 0x21
    cmp al, 0x21
    jne .done
    in al, 0x60
    mov bl, [mouse_stage]
    cmp bl, 0
    je .stage0
    cmp bl, 1
    je .stage1
    jmp .stage2
.stage0:
    test al, 0x08
    jz .drain
    mov [mouse_byte1], al
    mov byte [mouse_stage], 1
    jmp .drain
.stage1:
    mov [mouse_byte2], al
    mov byte [mouse_stage], 2
    jmp .drain
.stage2:
    mov [mouse_byte3], al
    mov byte [mouse_stage], 0

    xor ah, ah
    mov al, [mouse_byte2]
    test byte [mouse_byte1], 0x10
    jz .dxdone
    mov ah, 0xFF
.dxdone:
    mov [tmp_dx], ax

    xor ah, ah
    mov al, [mouse_byte3]
    test byte [mouse_byte1], 0x20
    jz .dydone
    mov ah, 0xFF
.dydone:
    neg ax
    mov [tmp_dy], ax

    mov ax, [cursor_x]
    add ax, [tmp_dx]
    cmp ax, 0
    jge .xoklow
    xor ax, ax
.xoklow:
    cmp ax, 319
    jle .xokhigh
    mov ax, 319
.xokhigh:
    mov [cursor_x], ax

    mov ax, [cursor_y]
    add ax, [tmp_dy]
    cmp ax, 0
    jge .yoklow
    xor ax, ax
.yoklow:
    cmp ax, 199
    jle .yokhigh
    mov ax, 199
.yokhigh:
    mov [cursor_y], ax

    mov al, [mouse_byte1]
    and al, 0x01
    mov [mouse_left_btn], al
    jmp .drain
.done:
    popa
    ret

; ------------------------------------------------------------
; toggle_gui_cursor : XOR-plots a small cursor shape - calling
; it twice at the same spot is a no-op, so the SAME proc both
; shows and hides it (no separate "under" storage needed).
; ------------------------------------------------------------
toggle_gui_cursor:
    pusha
    push es
    mov ax, GFX_SEG
    mov es, ax
    mov si, cursor_shape
    mov cx, 6
.loop:
    push cx
    lodsb
    xor ah, ah
    add ax, [cursor_x]
    mov bx, ax
    lodsb
    xor ah, ah
    add ax, [cursor_y]
    mov cx, 320
    mul cx
    add ax, bx
    mov di, ax
    mov al, [es:di]
    xor al, 0x0F
    mov [es:di], al
    pop cx
    loop .loop
    pop es
    popa
    ret

; ------------------------------------------------------------
; hit_test_icons : AL = icon index (0..3) under cursor_x/y,
;                  or 0xFF if the cursor isn't over any icon
; ------------------------------------------------------------
hit_test_icons:
    push bx
    push cx
    push dx
    xor bx, bx
.loop:
    cmp bx, NUM_ICONS
    je .none
    mov ax, bx
    mov cx, 70
    mul cx
    add ax, 25
    mov cx, ax
    add ax, 40
    mov dx, ax
    mov ax, [cursor_x]
    cmp ax, cx
    jl .next
    cmp ax, dx
    jge .next
    mov ax, [cursor_y]
    cmp ax, 50
    jl .next
    cmp ax, 90
    jge .next
    mov al, bl
    jmp .found
.next:
    inc bx
    jmp .loop
.none:
    mov al, 0xFF
.found:
    pop dx
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; hit_test_clock : AL=1 if cursor_x/y is over the taskbar clock
; ------------------------------------------------------------
hit_test_clock:
    mov ax, [cursor_x]
    cmp ax, 250
    jl .no
    cmp ax, 310
    jg .no
    mov ax, [cursor_y]
    cmp ax, 184
    jl .no
    cmp ax, 199
    jg .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; ------------------------------------------------------------
; draw_clock : live HH:MM:SS in the taskbar, from the real CMOS
;              RTC. Cheap to call every frame - only repaints
;              when the second has actually changed.
; ------------------------------------------------------------
draw_clock:
    push ax
    push bx
    mov bl, 0x00
    call read_cmos
    call bcd_to_bin
    cmp al, [last_clock_sec]
    je .skip
    mov [last_clock_sec], al
    push ax
    mov word [rect_x], 248
    mov word [rect_y], 184
    mov word [rect_w], 64
    mov word [rect_h], 14
    mov byte [rect_color], 0x08
    call fill_rect
    mov dh, 23
    mov dl, 31
    call gfx_cursor
    mov bl, 0x04
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    mov bl, 0x02
    call read_cmos
    call bcd_to_bin
    call print_dec2
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    pop ax
    call print_dec2
    call draw_bowl
.skip:
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; draw_bowl : a little food bowl "battery" - kibble drains and
;             refills on a loop, so the cat never goes hungry.
; ------------------------------------------------------------
draw_bowl:
    pusha
    mov word [rect_x], 206
    mov word [rect_y], 187
    mov word [rect_w], 32
    mov word [rect_h], 11
    mov byte [rect_color], 0x06
    call fill_rect
    mov word [rect_x], 208
    mov word [rect_y], 189
    mov word [rect_w], 28
    mov word [rect_h], 7
    mov byte [rect_color], 0x00
    call fill_rect
    xor ah, ah
    int 0x1A
    sub dx, [boot_tick_start]
    mov ax, dx
    xor dx, dx
    mov bx, 650
    div bx
    xor dx, dx
    mov bx, 6
    div bx
    mov ax, 5
    sub ax, dx
    mov cx, ax
    or cx, cx
    jz .done
    xor bx, bx
.kloop:
    mov ax, bx
    mov dx, 6
    mul dx
    add ax, 208
    mov [rect_x], ax
    mov word [rect_y], 190
    mov word [rect_w], 5
    mov word [rect_h], 5
    mov byte [rect_color], 0x0E
    call fill_rect
    inc bx
    loop .kloop
.done:
    popa
    ret

; ------------------------------------------------------------
; confetti_burst : a little surprise for clicking the clock
; ------------------------------------------------------------
CONFETTI_COUNT equ 24

confetti_burst:
    pusha
    mov si, confetti_offsets
    mov cx, CONFETTI_COUNT
    xor bx, bx
.loop:
    push cx
    lodsb
    cbw
    add ax, [cursor_x]
    mov [px_x], ax
    lodsb
    cbw
    add ax, [cursor_y]
    mov [px_y], ax
    push si
    mov si, confetti_colors
    mov al, bl
    and al, 0x07
    xor ah, ah
    add si, ax
    mov al, [si]
    mov [px_color], al
    pop si
    mov ax, [px_x]
    cmp ax, 0
    jl .skip
    cmp ax, 319
    jg .skip
    mov ax, [px_y]
    cmp ax, 0
    jl .skip
    cmp ax, 199
    jg .skip
    call put_pixel
.skip:
    inc bx
    pop cx
    loop .loop
    push dx
    mov dx, 3
    call delay_n
    pop dx
    popa
    ret

; ------------------------------------------------------------
; do_paint : a genuinely interactive pixel drawing pad - now
; usable with the real PS/2 mouse (move + click) or the
; keyboard (arrows + space), whichever you reach for.
; ------------------------------------------------------------
PAINT_STEP equ 3

do_paint:
    pusha
    mov word [rect_x], 0
    mov word [rect_y], 0
    mov word [rect_w], 320
    mov word [rect_h], 180
    mov byte [rect_color], 0x00
    call fill_rect
    mov word [rect_x], 0
    mov word [rect_y], 180
    mov word [rect_w], 320
    mov word [rect_h], 20
    mov byte [rect_color], 0x08
    call fill_rect
    mov dh, 23
    mov dl, 0
    call gfx_cursor
    mov byte [cur_color], 0x0F
    mov si, msg_paint_hint
    call print_color

    mov word [cursor_x], 160
    mov word [cursor_y], 90
    mov word [paint_x], 160
    mov word [paint_y], 90
    mov byte [paint_color], 0x0A
    mov byte [mouse_left_prev], 0
    call show_cursor
.loop:
    mov ah, 0x01
    int 0x16
    jz .checkmouse
    mov ah, 0x00
    int 0x16
    cmp al, 0x1B
    je .exit
    cmp al, ' '
    je .plot
    or al, al
    jnz .checknum
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    jmp .checkmouse
.checknum:
    cmp al, '1'
    jb .checkmouse
    cmp al, '8'
    ja .checkmouse
    sub al, '0'
    mov [paint_color], al
    jmp .checkmouse
.checkmouse:
    call poll_mouse
    call hide_cursor
    mov ax, [cursor_x]
    mov [paint_x], ax
    mov ax, [cursor_y]
    cmp ax, 179
    jle .yclampok
    mov ax, 179
.yclampok:
    mov [paint_y], ax
    call show_cursor
    mov al, [mouse_left_btn]
    mov bl, [mouse_left_prev]
    mov [mouse_left_prev], al
    cmp al, 1
    jne .loop
    cmp bl, 1
    je .loop
    jmp .plot
.plot:
    call hide_cursor
    push es
    mov ax, GFX_SEG
    mov es, ax
    mov ax, [paint_y]
    mov bx, 320
    mul bx
    add ax, [paint_x]
    mov di, ax
    mov al, [paint_color]
    mov [es:di], al
    pop es
    call show_cursor
    jmp .loop
.up:
    call hide_cursor
    cmp word [paint_y], PAINT_STEP
    jl .noup
    sub word [paint_y], PAINT_STEP
    jmp .doneup
.noup:
    mov word [paint_y], 0
.doneup:
    mov ax, [paint_y]
    mov [cursor_y], ax
    call show_cursor
    jmp .checkmouse
.down:
    call hide_cursor
    mov ax, [paint_y]
    add ax, PAINT_STEP
    cmp ax, 179
    jle .setdown
    mov ax, 179
.setdown:
    mov [paint_y], ax
    mov [cursor_y], ax
    call show_cursor
    jmp .checkmouse
.left:
    call hide_cursor
    cmp word [paint_x], PAINT_STEP
    jl .noleft
    sub word [paint_x], PAINT_STEP
    jmp .doneleft
.noleft:
    mov word [paint_x], 0
.doneleft:
    mov ax, [paint_x]
    mov [cursor_x], ax
    call show_cursor
    jmp .checkmouse
.right:
    call hide_cursor
    mov ax, [paint_x]
    add ax, PAINT_STEP
    cmp ax, 319
    jle .setright
    mov ax, 319
.setright:
    mov [paint_x], ax
    mov [cursor_x], ax
    call show_cursor
    jmp .checkmouse
.exit:
    call hide_cursor
    popa
    ret

; ------------------------------------------------------------
; do_gui : the main GUI desktop loop - real PS/2 mouse (hover
; to highlight, click to open) plus full keyboard support, a
; live taskbar clock, and a confetti easter egg if you click it.
; ------------------------------------------------------------
do_gui:
    call mouse_init
    mov word [cursor_x], 160
    mov word [cursor_y], 100
    mov byte [mouse_left_prev], 0
    mov byte [gui_selected], 0
    call set_gfx_mode
    call draw_desktop
    mov byte [last_clock_sec], 0xFF
    call draw_clock
    call toggle_gui_cursor
.loop:
    mov ah, 0x01
    int 0x16
    jz .checkmouse
    mov ah, 0x00
    int 0x16
    cmp al, 0x1B
    je .exit_gui
    cmp al, 0x0D
    je .kb_activate
    or al, al
    jnz .checkmouse
    cmp ah, 0x4B
    je .kb_left
    cmp ah, 0x4D
    je .kb_right
    jmp .checkmouse
.kb_left:
    cmp byte [gui_selected], 0
    je .checkmouse
    dec byte [gui_selected]
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
    jmp .checkmouse
.kb_right:
    mov al, [gui_selected]
    cmp al, NUM_ICONS-1
    je .checkmouse
    inc byte [gui_selected]
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
    jmp .checkmouse
.kb_activate:
    call toggle_gui_cursor
    jmp .do_activate
.checkmouse:
    call toggle_gui_cursor
    call poll_mouse
    call toggle_gui_cursor

    call hit_test_icons
    cmp al, 0xFF
    je .hovernone
    cmp al, [gui_selected]
    je .afterhover
    mov [gui_selected], al
    call toggle_gui_cursor
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
.afterhover:
.hovernone:
    mov al, [mouse_left_btn]
    mov bl, [mouse_left_prev]
    mov [mouse_left_prev], al
    cmp al, 1
    jne .clocktick
    cmp bl, 1
    je .clocktick
    call hit_test_clock
    cmp al, 1
    je .do_confetti
    call hit_test_icons
    cmp al, 0xFF
    je .clocktick
    mov [gui_selected], al
    call toggle_gui_cursor
    jmp .do_activate
.do_confetti:
    call toggle_gui_cursor
    call confetti_burst
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
    jmp .clocktick
.clocktick:
    call draw_clock
    jmp .loop
.do_activate:
    mov al, [gui_selected]
    cmp al, 0
    je .panel_fetch
    cmp al, 1
    je .panel_rambo
    cmp al, 2
    je .panel_paint
    jmp .exit_gui
.panel_fetch:
    call draw_fetch_panel
    mov ah, 0
    int 0x16
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
    jmp .loop
.panel_rambo:
    call draw_rambo_panel
    mov ah, 0
    int 0x16
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
    jmp .loop
.panel_paint:
    call do_paint
    call draw_desktop
    call draw_clock
    call toggle_gui_cursor
    jmp .loop
.exit_gui:
    call set_text_mode
    call clear_screen
    call print_art
    ret

; ============================================================
; rambofetch : neofetch-style system summary
; ============================================================
rambofetch:
    pusha
    mov byte [cur_color], 0x0B
    mov si, mf_border
    call print_color

    mov byte [cur_color], 0x0B
    mov si, mf_icon1
    call print_color
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_os
    call print_color
    mov byte [cur_color], 0x0A
    mov si, mf_val_os
    call print_color

    mov byte [cur_color], 0x0B
    mov si, mf_icon2
    call print_color
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_kernel
    call print_color
    mov byte [cur_color], 0x0A
    mov si, mf_val_kernel
    call print_color

    mov byte [cur_color], 0x0B
    mov si, mf_icon3
    call print_color
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_owner
    call print_color
    mov byte [cur_color], 0x0A
    mov si, mf_val_owner
    call print_color

    mov byte [cur_color], 0x0B
    mov si, mf_icon4
    call print_color
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_shell
    call print_color
    mov byte [cur_color], 0x0A
    mov si, mf_val_shell
    call print_color

    mov byte [cur_color], 0x0B
    mov si, mf_icon5
    call print_color
    call cpu_info

    mov byte [cur_color], 0x0B
    mov si, mf_icon6
    call print_color
    call mem_info

    mov byte [cur_color], 0x0B
    mov si, mf_icon7
    call print_color
    call disk_info

    mov byte [cur_color], 0x0B
    mov si, mf_icon8
    call print_color
    call uptime_info

    mov byte [cur_color], 0x0B
    mov si, mf_icon9
    call print_color
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_colors
    call print_color
    call print_color_bar
    mov si, newline
    call print_string

    mov byte [cur_color], 0x0B
    mov si, mf_border
    call print_color
    popa
    ret

cpu_info:
    push si
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_cpu
    call print_color
    call print_cpu_vendor
    mov si, newline
    call print_string
    pop si
    ret

mem_info:
    push ax
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_mem
    call print_color
    int 0x12
    call print_dec
    mov si, mf_kb
    call print_string
    mov ah, 0x88
    int 0x15
    call print_dec
    mov si, mf_kb_ext
    call print_string
    pop ax
    ret

disk_info:
    pusha
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_disk
    call print_color
    mov dl, [boot_drive]
    cmp dl, 0x80
    jae .is_hd
    mov si, mf_disk_fd
    call print_string
    jmp .disk_geom
.is_hd:
    mov si, mf_disk_hd
    call print_string
.disk_geom:
    mov ah, 0x08
    mov dl, [boot_drive]
    push es
    int 0x13
    pop es
    jc .geom_fail
    mov al, dh
    inc ax
    call print_dec
    mov si, mf_heads
    call print_string
    mov al, cl
    and al, 0x3F
    xor ah, ah
    call print_dec
    mov si, mf_spt
    call print_string
    jmp .geom_done
.geom_fail:
    mov si, mf_geom_unknown
    call print_string
.geom_done:
    popa
    ret

uptime_info:
    pusha
    mov byte [cur_color], 0x0F
    mov si, mf_lbl_uptime
    call print_color
    xor ah, ah
    int 0x1A
    mov ax, dx
    sub ax, [boot_tick_start]  ; unsigned wraparound handles the ~1hr
                                ; rollover of the low tick word correctly
    mov cx, 18
    xor dx, dx
    div cx                    ; ax = elapsed seconds (approx)
    xor dx, dx
    mov cx, 60
    div cx                    ; ax = minutes, dx = seconds
    push dx
    call print_dec
    mov si, mf_min_label
    call print_string
    pop ax
    call print_dec
    mov si, mf_sec_label
    call print_string
    popa
    ret

print_cpu_vendor:
    pusha
    xor eax, eax
    cpuid
    mov [cpu_id_str+0], ebx
    mov [cpu_id_str+4], edx
    mov [cpu_id_str+8], ecx
    mov byte [cpu_id_str+12], 0
    mov si, cpu_id_str
    call print_string
    popa
    ret

print_color_bar:
    pusha
    mov cx, 7
    mov bl, 1
.loop:
    push cx
    mov ah, 0x09
    mov al, 0xDB
    mov bh, 0
    mov cx, 3
    int 0x10
    mov ah, 0x03
    mov bh, 0
    int 0x10
    add dl, 3
    mov ah, 0x02
    int 0x10
    inc bl
    pop cx
    loop .loop
    popa
    ret

print_camo:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    push ax
    mov ah, 0x09
    mov cx, 1
    mov bh, 0
    mov bl, [color_idx]
    int 0x10
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    mov al, [color_idx]
    inc al
    cmp al, 7
    jne .setidx
    mov al, 1
.setidx:
    mov [color_idx], al
    pop ax
    jmp .loop
.done:
    popa
    ret

; ------------------------------------------------------------
; print_color : prints string at SI in a fixed color [cur_color].
;               Handles CR/LF properly (ah=0x09 doesn't).
; ------------------------------------------------------------
print_color:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    cmp al, 13
    je .cr
    cmp al, 10
    je .lf
    push ax
    mov ah, 0x09
    mov bl, [cur_color]
    mov bh, 0
    mov cx, 1
    int 0x10
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop ax
    jmp .loop
.cr:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    mov dl, 0
    mov ah, 0x02
    int 0x10
    jmp .loop
.lf:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dh
    mov ah, 0x02
    int 0x10
    jmp .loop
.done:
    popa
    ret

read_cmos:
    push bx
    mov al, bl
    out 0x70, al
    in al, 0x71
    pop bx
    ret

bcd_to_bin:
    push bx
    mov bl, al
    and al, 0x0F
    mov ah, 0
    shr bl, 4
    push ax
    mov al, bl
    mov bl, 10
    mul bl
    mov bl, al
    pop ax
    add al, bl
    pop bx
    ret

beep:
    pusha
    mov al, 0xB6
    out 0x43, al
    mov ax, 1500
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    mov cx, 0xFFFF
.d1:
    loop .d1
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

delay_long:
    push dx
    mov dx, 6
    call delay_n
    pop dx
    ret

delay_n:
    push cx
.outer:
    mov cx, 0xFFFF
.inner:
    loop .inner
    dec dx
    jnz .outer
    pop cx
    ret

parse_int:
    push bx
    push cx
    push dx
    xor bx, bx
    xor cx, cx
    mov al, [si]
    cmp al, '-'
    jne .loop
    mov cx, 1
    inc si
.loop:
    mov al, [si]
    cmp al, '0'
    jb .done
    cmp al, '9'
    ja .done
    sub al, '0'
    xor ah, ah
    push ax
    mov ax, bx
    mov dx, 10
    mul dx
    mov bx, ax
    pop ax
    add bx, ax
    inc si
    jmp .loop
.done:
    mov ax, bx
    or cx, cx
    jz .positive
    neg ax
.positive:
    pop dx
    pop cx
    pop bx
    ret

print_signed_dec:
    push ax
    or ax, ax
    jns .pos
    mov ah, 0x0E
    mov al, '-'
    int 0x10
    pop ax
    neg ax
    push ax
.pos:
    pop ax
    call print_dec
    ret

print_random_msg:
    push ax
    push dx
    mov dx, cx
    xor ah, ah
    int 0x1A
    mov ax, dx
    pop dx
    xor dx, dx
    div cx
    shl dx, 1
    add bx, dx
    mov si, [bx]
    call print_string
    pop ax
    ret

read_line:
    pusha
    xor cx, cx
.next:
    xor ah, ah
    int 0x16
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace
    cmp cx, 62
    jae .next
    mov [di], al
    inc di
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .next
.backspace:
    or cx, cx
    jz .next
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .next
.done:
    mov byte [di], 0
    mov si, newline
    call print_string
    popa
    ret

strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .neq
    or al, al
    jz .eq
    inc si
    inc di
    jmp .loop
.eq:
    mov ax, 1
    jmp .out
.neq:
    xor ax, ax
.out:
    pop di
    pop si
    ret

startswith:
    push si
    push di
.loop:
    mov al, [di]
    or al, al
    jz .yes
    mov ah, [si]
    cmp al, ah
    jne .no
    inc si
    inc di
    jmp .loop
.yes:
    mov ax, 1
    jmp .out
.no:
    xor ax, ax
.out:
    pop di
    pop si
    ret

print_dec:
    pusha
    mov cx, 0
    mov bx, 10
    or ax, ax
    jnz .conv
    mov si, zero_str
    call print_string
    popa
    ret
.conv:
    or ax, ax
    jz .print
    xor dx, dx
    div bx
    push dx
    inc cx
    jmp .conv
.print:
    or cx, cx
    jz .fin
    pop dx
    add dl, '0'
    mov ah, 0x0E
    mov al, dl
    int 0x10
    dec cx
    jmp .print
.fin:
    popa
    ret

print_dec2:
    pusha
    xor ah, ah
    mov bl, 10
    div bl
    push ax
    add al, '0'
    mov ah, 0x0E
    int 0x10
    pop ax
    mov al, ah
    add al, '0'
    mov ah, 0x0E
    int 0x10
    popa
    ret

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

clear_screen:
    pusha
    mov ax, 0x0003
    int 0x10
    popa
    ret

print_art:
    mov byte [cur_color], 0x0F
    mov si, art_rule
    call print_color
    mov byte [cur_color], 0x0A
    mov si, art_title
    call print_color
    mov byte [cur_color], 0x0B
    mov si, art_cat
    call print_color
    mov byte [cur_color], 0x0F
    mov si, art_rule
    call print_color
    ret

; ============================================================
; Command dispatch table
; ============================================================
cmd_table:
    dw cmd_rambofetch, do_rambofetch
    dw cmd_help,       do_help
    dw cmd_commands,   do_help2
    dw cmd_clear,      do_clear
    dw cmd_cls,        do_clear
    dw cmd_about,      do_about
    dw cmd_tribute,    do_tribute
    dw cmd_credits,    do_credits
    dw cmd_reboot,     do_reboot
    dw cmd_shutdown,   do_shutdown
    dw cmd_cpu,        do_cpu
    dw cmd_mem,        do_mem
    dw cmd_disk,       do_disk
    dw cmd_uptime,     do_uptime
    dw cmd_logo,       do_logo
    dw cmd_ver,        do_ver
    dw cmd_date,       do_date
    dw cmd_time,       do_time
    dw cmd_beep,       do_beep
    dw cmd_roar,       do_roar
    dw cmd_growl,      do_growl
    dw cmd_rambofact,  do_rambofact
    dw cmd_joke,       do_joke
    dw cmd_camo,       do_camo
    dw cmd_dance,      do_dance
    dw cmd_secret,     do_secret
    dw cmd_hello,      do_hello
    dw cmd_sleep,      do_sleep
    dw cmd_orders,     do_orders
    dw cmd_mission,    do_mission
    dw cmd_run,        do_run
    dw cmd_numguess,   do_numguess
    dw cmd_history,    do_history
    dw cmd_notes,      do_notes
    dw cmd_gui,        do_gui
    dw cmd_snake,      do_snake
    dw cmd_roll,       do_roll
    dw cmd_stopwatch,  do_stopwatch
    dw cmd_pong,       do_pong
    dw cmd_matrix,     do_matrix
    dw cmd_pet,        do_pet
    dw cmd_dice,       do_dice
    dw cmd_rpg,        do_rpg
    dw cmd_meowpad,    do_meowpad
    dw cmd_panic,      do_panic
    dw 0, 0

; ============================================================
; Data
; ============================================================
boot_drive: db 0
color_idx:  db 1
dance_toggle: db 0
cur_color:  db 0x07
boot_tick_start: dw 0

notes_buf:      times 5*64 db 0
notes_count:    db 0
history_buf:    times 5*64 db 0
history_count:  db 0
history_pos:    db 0
ng_secret:      dw 0
ng_tries:       dw 0
rng_seed:       dw 0x5A17
sw_t0:          dw 0
sn_score:       dw 0
sn_len:         dw 0
sn_dir:         dw 1
sn_moved:       dw 1
sn_head:        dw 0
sn_tail:        dw 0
sn_t0:          dw 0
sn_delay:       dw 2
sn_quit:        db 0
sn_food_new:    db 0
sn_buf:         times 512 db 0
dump_addr:      dw 0
dump_row:       dw 0
mx_frame:       db 0
mx_heads:       times 80 dw 0
dc_round:       dw 0
dc_you:         dw 0
dc_cpu:         dw 0
dc_roll_you:    dw 0
dc_roll_cpu:    dw 0
mp_count:       dw 0
meow_lines:     times 512 db 0
pg_bx:          dw 40
pg_by:          dw 10
pg_vx:          dw 1
pg_vy:          dw 1
pg_pl:          dw 10
pg_cp:          dw 10
pg_sp:          dw 0
pg_sc:          dw 0
pg_dir:         dw 1
pg_frame:       dw 0
dash_prefix:    db "  - ", 0
note_prefix:    db "note ", 0
hex_prefix:     db "hex ", 0
roll_prefix:    db "roll ", 0
bin_prefix:     db "bin ", 0
dump_prefix:    db "dump ", 0

; ------------------ GUI variables ------------------
rect_x:      dw 0
rect_y:      dw 0
rect_w:      dw 0
rect_h:      dw 0
rect_color:  db 0
px_x:        dw 0
px_y:        dw 0
px_color:    db 0
icon_x:      dw 0
icon_y:      dw 0
icon_size:   dw 0
icon_color:  db 0
icon_border: db 0
icon_label:  dw 0
gui_selected: db 0
ear_widths:  db 4, 8, 12, 16, 20, 24
icon_colors: db 0x02, 0x06, 0x0B, 0x04       ; Fetch, Rambo, Paint, Exit
icon_labels: dw lbl_fetch, lbl_rambo, lbl_paint, lbl_exit
lbl_fetch: db "Fetch", 0
lbl_rambo: db "Rambo", 0
lbl_paint: db "Paint", 0
lbl_exit:  db "Exit", 0

paint_x:     dw 0
paint_y:     dw 0
paint_color: db 0
paint_under: db 0

; ------------------ PS/2 mouse + cursor + clock ------------------
cursor_x:     dw 160
cursor_y:     dw 100
mouse_stage:  db 0
mouse_byte1:  db 0
mouse_byte2:  db 0
mouse_byte3:  db 0
mouse_status_tmp: db 0
tmp_dx:       dw 0
tmp_dy:       dw 0
mouse_left_btn:  db 0
mouse_left_prev: db 0
cursor_shape: db 0,0, 0,1, 0,2, 0,3, 1,1, 2,2
last_clock_sec: db 0xFF
confetti_offsets: db -20,-15, -10,-18, 0,-20, 10,-18, 20,-15, -18,-5, 18,-5, -22,0, 22,0, -18,5, 18,5, -20,15, -10,18, 0,20, 10,18, 20,15, -12,-12, 12,-12, -12,12, 12,12, -6,-20, 6,-20, -6,20, 6,20
confetti_colors: db 0x0C, 0x0E, 0x0A, 0x0B, 0x0D, 0x09, 0x02, 0x04

msg_gui_hint:  db "RamboOS GUI - Left/Right+Enter or mouse. ESC exits.", 0
msg_gui_anykey: db "Press any key to go back...", 0
msg_gui_rambo_caption: db "Rambo - Semper Felix", 0
msg_paint_hint: db "Arrows/mouse=move  Space/click=draw  1-8=color  ESC=exit", 0


newline:   db 13, 10, 0
zero_str:  db "0", 0
slash:     db "/", 0
colon:     db ":", 0
twenty:    db "20", 0

prompt:      db "RamboOS> ", 0
echo_prefix: db "echo ", 0
calc_prefix: db "calc ", 0

cmd_rambofetch: db "rambofetch", 0
cmd_help:       db "help", 0
cmd_commands:   db "commands", 0
cmd_clear:      db "clear", 0
cmd_cls:        db "cls", 0
cmd_about:      db "about", 0
cmd_tribute:    db "tribute", 0
cmd_credits:    db "credits", 0
cmd_reboot:     db "reboot", 0
cmd_shutdown:   db "shutdown", 0
cmd_cpu:        db "cpu", 0
cmd_mem:        db "mem", 0
cmd_disk:       db "disk", 0
cmd_uptime:     db "uptime", 0
cmd_logo:       db "logo", 0
cmd_ver:        db "ver", 0
cmd_date:       db "date", 0
cmd_time:       db "time", 0
cmd_beep:       db "beep", 0
cmd_roar:       db "roar", 0
cmd_growl:      db "growl", 0
cmd_rambofact:  db "rambofact", 0
cmd_joke:       db "joke", 0
cmd_camo:       db "camo", 0
cmd_dance:      db "dance", 0
cmd_secret:     db "secret", 0
cmd_hello:      db "hello", 0
cmd_sleep:      db "sleep", 0
cmd_orders:     db "orders", 0
cmd_mission:    db "mission", 0
cmd_run:        db "run", 0
cmd_numguess:   db "numguess", 0
cmd_history:    db "history", 0
cmd_notes:      db "notes", 0
cmd_gui:        db "gui", 0
cmd_snake:      db "snake", 0
cmd_roll:       db "roll", 0
cmd_stopwatch:  db "stopwatch", 0
cmd_pong:       db "pong", 0
cmd_matrix:     db "matrix", 0
cmd_pet:        db "pet", 0
cmd_dice:       db "dice", 0
cmd_rpg:        db "rpg", 0
cmd_meowpad:    db "meowpad", 0
cmd_panic:      db "panic", 0

cmdbuf:        times 64 db 0
cpu_id_str:    times 16 db 0

msg_unknown: db "Unknown command: ", 0

msg_welcome:
    db "   Welcome to RamboOS - built in memory of Rambo, one tough cat", 13, 10
    db "   ---------------------------------------------------------", 13, 10, 0

msg_help_hint:
    db "   Type 'help' or 'commands' to see everything RamboOS can do.", 13, 10, 13, 10, 0

msg_help:
    db 13, 10
    db "  rambofetch about    tribute    credits    logo      ver", 13, 10
    db "  cls/clear  cpu      mem        disk       uptime    date/time", 13, 10
    db "  beep       roar     growl      rambofact  joke      camo", 13, 10
    db "  dance      secret   hello      sleep      echo <x>  reboot", 13, 10
    db "  calc <a> <op> <b>   orders     mission    numguess  shutdown", 13, 10
    db "  note <x>  notes     history    run        gui", 13, 10
    db "  snake     roll [n]  hex <n>    stopwatch          (new in 1.4)", 13, 10
    db "  pong      matrix    pet        bin <n>    dump <hex>", 13, 10
    db "  dice      rpg       meowpad    panic                (new in 1.5)", 13, 10
    db "  commands (full list)  help (this list)", 13, 10, 13, 10, 0

msg_help2:
    db 13, 10
    db "  rambofetch - full system info, neofetch-style, Rambo edition", 13, 10
    db "  cpu/mem/disk/uptime - one rambofetch field on its own", 13, 10
    db "  date/time  - reads the real CMOS clock", 13, 10
    db "  calc a op b - a real calculator, e.g. calc 12 * 7", 13, 10
    db "  beep/roar/growl/rambofact/joke/hello/secret - sound and flavour text", 13, 10
    db "  camo/dance - camo-colored text / PC-speaker tune with a dancing cat", 13, 10
    db "  orders/mission/numguess - oracle, recon reflex game, guess 1-100", 13, 10
    db "  snake      - classic Snake (arrows/WASD, ESC quits)", 13, 10
    db "  pong       - NEW: Pong vs the CPU, first to 7 (W/S or arrows)", 13, 10
    db "  matrix     - NEW: falling green code, any key stops", 13, 10
    db "  pet        - NEW: pet Rambo. He purrs (PC speaker)", 13, 10
    db "  dump <hex> - hex dump of memory, e.g. dump 7C00 (the boot sector)", 13, 10
    db "  bin <n>    - number in binary      hex <n> - number in hex", 13, 10
    db "  dice       - NEW: dice game vs the CPU, best of 5 (3d6/round)", 13, 10
    db "  rpg        - NEW: a short Rambo text adventure", 13, 10
    db "  meowpad    - NEW: a tiny text editor, up to 8 lines", 13, 10
    db "  panic      - NEW: a joke kernel-panic screen (totally safe)", 13, 10
    db "  roll [n]   - roll a die (d6, or d<n>)   stopwatch - any key starts/stops", 13, 10
    db "  note <x> / notes / history - session notepad, last 5 commands", 13, 10
    db "  run        - load and execute your own app (see APPDEV.txt)", 13, 10
    db "  gui        - VGA desktop: icons, pixel cat, Paint, real mouse", 13, 10
    db "  sleep / echo x / logo / clear / cls / about / tribute", 13, 10
    db "  credits / ver / reboot / shutdown", 13, 10, 13, 10, 0

msg_about:
    db 13, 10
    db "  RamboOS v1.5 (Semper Felix)", 13, 10
    db "  A tiny real-mode x86 operating system, written from scratch", 13, 10
    db "  in assembly - no Linux, no borrowed kernel, just a bootloader,", 13, 10
    db "  a kernel, and one very good cat's name on the splash screen.", 13, 10
    db "  Type 'run' to load your own app - see APPDEV.txt.", 13, 10, 13, 10, 0

msg_tribute:
    db 13, 10
    db "  Rambo was a tough, good cat, and he is missed.", 13, 10
    db "  This whole operating system exists because someone loved him", 13, 10
    db "  enough to give him his own kernel. Not every cat gets that.", 13, 10
    db "  Wherever he is, we hope there are warm laps and full bowls.", 13, 10
    db "  Semper Felix, Rambo. Mission complete.", 13, 10, 13, 10, 0

msg_credits:
    db 13, 10
    db "  RamboOS was written for Rambo, a very good cat.", 13, 10
    db "  Boot sector, kernel and shell: 100% hand-written x86 asm.", 13, 10
    db "  You can add your own programs too - type 'run' or read", 13, 10
    db "  APPDEV.txt to find out how.", 13, 10, 13, 10, 0

msg_reboot:   db 13, 10, "  Rebooting... press any key.", 13, 10, 0
msg_shutdown:
    db 13, 10, "  It is now safe to turn off your computer.", 13, 10
    db "  (RamboOS halted the CPU. Mission complete, soldier.)", 13, 10, 0

msg_beep:  db "  *beep*", 13, 10, 0
msg_roar:  db "  ROOOAR!  a very small, very fierce roar.", 13, 10, 0
msg_growl: db "  grrrrrrrrr... (that's a happy growl, promise)", 13, 10, 0
msg_hello: db "  Hey soldier. RamboOS reporting for duty.", 13, 10, 0

msg_noted:       db "  Noted.", 13, 10, 0
msg_notes_full:  db "  Notepad's full for this session (max 5). Try 'notes' to review.", 13, 10, 0
msg_notes_empty: db "  No notes yet. Try: note <something>", 13, 10, 0
msg_history_empty: db "  No commands in history yet.", 13, 10, 0

msg_ng_intro:   db 13, 10, "  I'm thinking of a number, 1-100. You have 10 tries.", 13, 10, 0
msg_ng_prompt:  db "  Your guess: ", 0
msg_ng_low:     db "  Higher!", 13, 10, 0
msg_ng_high:    db "  Lower!", 13, 10, 0
msg_ng_correct: db "  Got it! That took ", 0
msg_ng_tries:   db " tries.", 13, 10, 13, 10, 0
msg_ng_out:     db "  Out of tries! The number was ", 0

msg_secret:
    db "  You found the secret command!", 13, 10
    db "  Somewhere, a tough cat is very proud of you.", 13, 10, 0
msg_sleep:
    db "  Rambo curls up after a hard day of missions... zzz...", 13, 10
    db "  (press any key to wake him up)", 13, 10, 0
msg_wake:
    db "  Rambo stretches, cracks his neck, and reports for duty.", 13, 10, 0

msg_run_loading: db "  Loading your app from disk...", 13, 10, 0
msg_run_done:    db "  App finished. Back in RamboOS.", 13, 10, 0
msg_run_fail:    db "  Could not read the app slot from disk.", 13, 10, 0

camo_text: db "RamboOS - mission ready", 0

; ------------------ v1.4 strings ------------------
msg_hex_pre:  db "  ", 0
msg_hex_mid:  db " = 0x", 0
msg_hex_post: db "  (16-bit)", 13, 10, 0
msg_roll1:    db "  d", 0
msg_roll2:    db "  ->  ", 0
msg_roll_bad: db "  Usage: roll   (d6)   or   roll <sides>, e.g. roll 20", 13, 10, 0
msg_sw_start: db "  Stopwatch ready. Press any key to START...", 13, 10, 0
msg_sw_run:   db "  Running... press any key to STOP.", 13, 10, 0
msg_sw_res:   db "  Time: ", 0
msg_sw_res2:  db " s", 13, 10, 0
msg_sn_hud:   db "  RamboOS SNAKE    Score: ", 0
msg_sn_hud2:  db "      Arrows/WASD = steer   ESC = quit", 0
msg_sn_dead:  db "  GAME OVER - press a key  ", 0
msg_sn_win:   db "  YOU WIN! Rambo salutes you.  ", 0
msg_bin_mid:  db " = 0b ", 0
msg_dump_sep: db ": ", 0
msg_pet1:     db "  You pet Rambo. He closes his eyes and leans in...", 13, 10, 0
msg_pet2:     db "  prrrrrrrr... (Semper Felix)", 13, 10, 0
msg_pg_hud1:  db "  PONG   You: ", 0
msg_pg_hud2:  db "   CPU: ", 0
msg_pg_hud3:  db "   (first to 7)   W/S or arrows = move   ESC = quit   ", 0
msg_pg_win:   db "  YOU WIN! Mission complete.  ", 0
msg_pg_lose:  db "  CPU WINS. Rambo says: again!  ", 0
msg_boot_menu: db 13, 10, "  [1] RamboOS CLI    [2] RamboOS GUI    (Enter = CLI)", 13, 10, 13, 10, 0
msg_panic1:   db "  ***  RAMBO OS - KERNEL PANIC  ***", 0
msg_panic2:   db "  Kotek zachorowal! :(", 0
msg_panic3:   db "  System nie moze kontynuowac. (To tylko zart - wszystko gra.)", 0
msg_panic4:   db "  Press any key to reboot...", 0
msg_dice_title: db "  DICE - best of 5, 3d6 per round.", 13, 10, 13, 10, 0
msg_dice_round: db "  -- Round ", 0
msg_dice_you:   db "  You rolled: ", 0
msg_dice_cpu:   db "  CPU rolled: ", 0
msg_dice_win:   db "  You win this round!", 13, 10, 0
msg_dice_lose:  db "  CPU wins this round.", 13, 10, 0
msg_dice_tie:   db "  Tie!", 13, 10, 0
msg_dice_final: db 13, 10, "  Final score -  You: ", 0
msg_dice_sep:   db "   CPU: ", 0
msg_dice_fwin:  db "  YOU WIN! Rambo approves.", 13, 10, 0
msg_dice_floss: db "  CPU wins overall. Roll again sometime.", 13, 10, 0
msg_dice_fdraw: db "  It's a draw!", 13, 10, 0
msg_mp_title: db "  MeowPad - up to 8 lines, blank line (just Enter) to finish.", 13, 10, 13, 10, 0
msg_mp_prompt: db "> ", 0
msg_mp_out:   db 13, 10, "  --- MeowPad ---", 13, 10, 0
msg_mp_end:   db "  --- end ---", 13, 10, 0
msg_rpg_intro: db "  RAMBO: A CAT'S MISSION", 13, 10, "  ------------------------", 13, 10, "  Rambo wakes at dawn. Today's mission: patrol the house.", 13, 10, 13, 10, 0
msg_rpg_q1:    db "  [1] Go on patrol   [2] Go back to sleep", 13, 10, 0
msg_rpg_patrol: db "  Rambo pads down the hallway... a can opener clicks in the kitchen!", 13, 10, 0
msg_rpg_q2:    db "  [1] Stand your ground   [2] Watch from the closet", 13, 10, 0
msg_rpg_fight: db "  The neighbor's dog is in the kitchen! Time to roll for it.", 13, 10, 0
msg_rpg_you_rolled: db "  You roll: ", 0
msg_rpg_dog_rolled: db "  Dog rolls: ", 0
msg_rpg_win_end: db 13, 10, "  Rambo stands tall and the dog backs off. Hero of the house!", 13, 10, "  THE END - Semper Felix.", 13, 10, 0
msg_rpg_lose_end: db 13, 10, "  The dog gets the last bark, but Rambo struts off anyway.", 13, 10, "  THE END - there's always tomorrow.", 13, 10, 0
msg_rpg_closet_end: db 13, 10, "  Rambo watches from the closet. Discretion is valor too.", 13, 10, "  THE END - a wise and comfy cat.", 13, 10, 0
msg_rpg_sleepy_end: db 13, 10, "  Rambo decides the house can patrol itself today.", 13, 10, "  THE END - a cat's got priorities.", 13, 10, 0

dance_frame1:
    db "                    ", 13, 10
    db "        /\_/\      ", 13, 10
    db "       ( -o- )     ", 13, 10
    db "        > = <      ", 13, 10
    db "      RamboOS on duty ~", 13, 10, 0
dance_frame2:
    db "                    ", 13, 10
    db "        /\_/\      ", 13, 10
    db "       ( o-o )     ", 13, 10
    db "        > w <      ", 13, 10
    db "      RamboOS on duty ~ ~", 13, 10, 0

; ------------------ rambofetch strings ------------------
mf_border:      db "  -----------------------------------------------------------", 13, 10, 0
mf_icon1: db "   /\_/\   ", 0
mf_icon2: db "  ( -o- )  ", 0
mf_icon3: db "   > = <   ", 0
mf_icon4: db "  /     \  ", 0
mf_icon5: db " (       ) ", 0
mf_icon6: db "  |     |  ", 0
mf_icon7: db "  \     /  ", 0
mf_icon8: db "   -----   ", 0
mf_icon9: db "           ", 0

mf_lbl_os:      db "OS:      ", 0
mf_val_os:      db "RamboOS v1.5 (Semper Felix)", 13, 10, 0
mf_lbl_kernel:  db "Kernel:  ", 0
mf_val_kernel:  db "rambokernel (custom, 16-bit real mode)", 13, 10, 0
mf_lbl_owner:   db "Cat:     ", 0
mf_val_owner:   db "Rambo - tough, good, and dearly missed", 13, 10, 0
mf_lbl_shell:   db "Shell:   ", 0
mf_val_shell:   db "rambosh 1.5", 13, 10, 0
mf_lbl_cpu:     db "CPU:     ", 0
mf_lbl_mem:     db "Memory:  ", 0
mf_kb:          db " KB conventional + ", 0
mf_kb_ext:      db " KB extended", 13, 10, 0
mf_lbl_disk:    db "Disk:    ", 0
mf_disk_fd:     db "floppy, ", 0
mf_disk_hd:     db "hard disk, ", 0
mf_heads:       db " heads x ", 0
mf_spt:         db " sectors/track", 13, 10, 0
mf_geom_unknown: db "geometry unavailable", 13, 10, 0
mf_lbl_uptime:  db "Uptime:  ", 0
mf_min_label:   db "m ", 0
mf_sec_label:   db "s (since boot)", 13, 10, 0
mf_lbl_colors:  db "Colors:  ", 0
mf_lbl_date:    db "Date:    ", 0
mf_lbl_time:    db "Time:    ", 0
mf_cmos_note:   db "  (from CMOS RTC)", 13, 10, 0

; ------------------ calculator ------------------
calc_a:  dw 0
calc_op: db 0
msg_calc_eq:      db " = ", 0
msg_calc_badop:   db "  Unknown operator - use + - * or /", 13, 10, 0
msg_calc_divzero: db "  Can't divide by zero. Rambo doesn't do the impossible.", 13, 10, 0

; ------------------ orders (oracle) ------------------
msg_orders_intro: db "  State your question, soldier, then press Enter:", 13, 10, "> ", 0
ORDERS_COUNT equ 8
orders_answers:
    dw or1, or2, or3, or4, or5, or6, or7, or8
or1: db "  Affirmative. Proceed with the mission.", 13, 10, 0
or2: db "  Negative. Stand down.", 13, 10, 0
or3: db "  Unclear. Recon more, then ask again.", 13, 10, 0
or4: db "  Rambo says yes. Rambo is rarely wrong.", 13, 10, 0
or5: db "  Command is napping. Try again after his nap.", 13, 10, 0
or6: db "  Odds are in your favor. Go for it.", 13, 10, 0
or7: db "  Hold position. Not yet.", 13, 10, 0
or8: db "  Outcome unclear. Bring treats, just in case.", 13, 10, 0

; ------------------ cat facts / jokes ------------------
FACT_COUNT equ 5
rambofacts:
    dw cf1, cf2, cf3, cf4, cf5
cf1: db "  A tough cat can still be the softest part of your day.", 13, 10, 0
cf2: db "  Cats spend 70% of their life asleep. Rambo trained hard for it.", 13, 10, 0
cf3: db "  Cats can rotate their ears 180 degrees - great recon gear.", 13, 10, 0
cf4: db "  A cat's purr runs 25-150 Hz - practically a repair frequency.", 13, 10, 0
cf5: db "  Good cats never really leave. They just go off duty.", 13, 10, 0

JOKE_COUNT equ 5
jokes:
    dw jk1, jk2, jk3, jk4, jk5
jk1: db "  Why was the cat sitting on the computer? Recon on the mouse.", 13, 10, 0
jk2: db "  What do you call an elite squad of cats? The purr-ranger corps.", 13, 10, 0
jk3: db "  RamboOS has zero bugs. Rambo cleared them all on sight.", 13, 10, 0
jk4: db "  Why don't cats need dog tags? Nine lives, one legend.", 13, 10, 0
jk5: db "  What's Rambo's favorite command? rambofetch, obviously.", 13, 10, 0

; ------------------ mission minigame ------------------
cm_score:       dw 0
cm_rounds_left: db 0
cm_start_tick:  dw 0
msg_game_intro:
    db 13, 10, "  RECON MISSION - 5 targets, move fast.", 13, 10
    db "  When a target appears, press ANY key before it disappears.", 13, 10, 13, 10, 0
msg_target_appear:  db "  Target spotted!  ", 0
msg_target_hit:     db "Direct hit!", 13, 10, 0
msg_target_missed:  db "Target got away...", 13, 10, 0
msg_game_over:  db 13, 10, "  Mission complete! Score: ", 0
msg_game_over2: db "/5", 13, 10, 0
msg_score_perfect:  db "  Flawless. Rambo would be proud.", 13, 10, 13, 10, 0
msg_score_good:     db "  Solid work, soldier.", 13, 10, 13, 10, 0
msg_score_practice: db "  Debrief and try again - you'll get it.", 13, 10, 13, 10, 0

; ------------------------------------------------------------
; note table for 'dance' : dw freq(Hz,0=rest), dw duration
; ------------------------------------------------------------
tune_dance:
    dw 392, 3
    dw 392, 3
    dw 392, 3
    dw 311, 4
    dw 466, 1
    dw 392, 3
    dw 311, 4
    dw 466, 1
    dw 392, 6
    dw 0xFFFF, 0

; ------------------ ASCII art (splash) ------------------
art_rule:
    db "  ==================================================================", 13, 10, 0
art_title:
    db "                                                                    ", 13, 10
    db "     ______                 __         ____  _____                ", 13, 10
    db "    / __  \\   ____ _ ____ _ / /_   ____ / __ \\/ ___/               ", 13, 10
    db "   / /_/  /  / __ `// __ `// __ \\ / __ \\ / / / \\__ \\               ", 13, 10
    db "  / _, _/  / /_/ // /_/ // /_/ // /_/ // /_/ /___/ /               ", 13, 10
    db " /_/ |_|   \\__,_/ \\__,_//_.___/ \\____//\\____//____/                ", 13, 10
    db "                                                                    ", 13, 10, 0
art_cat:
    db "        .--''''--.                                                 ", 13, 10
    db "       /  o    o  \\        in memory of Rambo                     ", 13, 10
    db "      (   \\____/   )       one tough, good cat.                   ", 13, 10
    db "       \\   ----   /        gone, but always on duty.              ", 13, 10
    db "        '.______.'                                                 ", 13, 10
    db "         /|    |\\          Semper Felix.                          ", 13, 10
    db "        ^ '----' ^                                                 ", 13, 10
    db "                                                                    ", 13, 10, 0

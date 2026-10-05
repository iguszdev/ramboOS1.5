RamboOS v1.5 "Semper Felix"
============================
Built in loving memory of Rambo - a tough, good cat.

A real, bootable 16-bit x86 operating system, written from scratch in
assembly. No Linux, no borrowed kernel - just a hand-written bootloader
and kernel, with a real mouse-driven graphical desktop and a way to
write your own programs for it.

FILE: ramboos.img  (1.44MB floppy disk image, MBR-bootable)

HOW TO RUN IT
-------------
Option A - QEMU (easiest, Win/Mac/Linux):
  1. Install QEMU: https://www.qemu.org/download/
  2. Run:  qemu-system-i386 -drive file=ramboos.img,format=raw,if=floppy

Option B - VirtualBox / VMware:
  1. New VM, "Other/Unknown" OS type, 16-32MB RAM is plenty
  2. IMPORTANT: make sure EFI is *disabled* (VirtualBox: Settings ->
     System -> uncheck "Enable EFI"). RamboOS is classic Legacy
     BIOS/MBR, not UEFI.
  3. Attach ramboos.img as a floppy disk (or IDE/SATA - both work)
  4. Enable a PS/2 mouse in the VM's settings if the GUI's mouse
     support doesn't respond (most VMs default to this already)
  5. Boot the VM

Option C - Real hardware:
  Write it to a USB stick (balenaEtcher works fine, or dd):
     sudo dd if=ramboos.img of=/dev/sdX bs=4M status=progress
  Then boot via your BIOS boot menu (F12/F9/Esc/Del depending on
  manufacturer) with Legacy Boot/CSM enabled and Secure Boot off.
  A real PS/2 or USB-emulating-PS/2 mouse is needed for GUI mouse
  support - the keyboard always works as a fallback either way.

WHAT'S NEW IN v1.5 - A BOOT MENU, GAMES, PANIC AND MEOWPAD
------------------------------------------------------------
  - Boot menu: choose [1] CLI or [2] GUI right at startup. Enter
    defaults to the CLI, same as before.
  - A "meow" plays on the PC speaker right after the boot banner.
  - rpg       - a short branching Rambo text adventure (4 endings).
  - dice      - dice game vs the CPU, best of 5 (3d6 per round).
  - meowpad   - a tiny text editor, up to 8 lines, prints them back.
  - panic     - a friendly fake "kernel panic" easter egg: blue
                screen, "Kotek zachorowal! :(", a sad meow, then
                reboots on a keypress. Nothing is actually broken.
  - The GUI taskbar now has a food-bowl "battery" meter next to the
    clock - the kibble drains and refills on a loop.
  - rambofetch (system info + ASCII cat) is unchanged and still the
    best way to see what RamboOS is running on.
  - Kernel is now ~19.9KB of its 20KB (40-sector) budget - almost full!

WHAT WAS NEW BEFORE - PONG, MATRIX, SNAKE, A DEBUGGER AND A MOUSE
---------------------------------------------------------------------
  - pong/matrix/pet/dump/bin, and earlier snake/roll/hex/stopwatch -
    see "commands" in the shell for the full, current list with a
    one-line description of everything RamboOS can do.
  - The "gui" desktop has a mouse driver written from scratch against
    the PS/2 controller (ports 0x60/0x64): hover/click icons, mouse in
    Paint mode, a live taskbar clock off the CMOS RTC, and a surprise
    when you click the clock. Keyboard still works side by side.

WHAT WAS NEW IN v1.3 - A REAL MOUSE, AND A SURPRISE
------------------------------------------------------
  The "gui" desktop has a mouse driver written from scratch against
  the PS/2 controller (ports 0x60/0x64): hover/click icons, mouse in
  Paint mode, a live taskbar clock off the CMOS RTC, and a surprise
  when you click the clock. Keyboard still works side by side.

COMMANDS
--------
System info:
  rambofetch  - full neofetch-style system summary (CPU, RAM, disk...)
  cpu / mem / disk / uptime - one rambofetch field on its own
  date / time - read live from the real CMOS RTC chip
  ver         - RamboOS version
  gui         - the real graphical desktop (mouse + keyboard)

Fun / Rambo stuff:
  beep / roar     - PC speaker sound
  growl           - flavour text
  rambofact / joke - random fact / joke (5 each)
  camo            - a message in cycling VGA colors
  dance           - a real PC-speaker tune with a dancing ASCII cat
  calc a op b     - a real calculator: + - * /, negative numbers
  orders          - ask Rambo the Oracle a yes/no question
  mission         - a 5-round recon reflex mini-game with a score
  numguess        - guess the number, 1-100, 10 tries
  snake           - classic Snake (arrows/WASD, ESC quits)
  roll [n]        - roll a die (d6, or d<n>)
  hex <n>         - decimal to hex
  stopwatch       - any key starts, any key stops
  pong            - Pong vs the CPU, first to 7
  matrix          - falling green code, any key stops
  pet             - pet Rambo, he purrs
  dump <hex>      - hex dump of memory, e.g. dump 7C00
  bin <n>         - number in binary
  dice            - NEW: dice game vs the CPU, best of 5 (3d6/round)
  rpg             - NEW: a short branching Rambo text adventure
  meowpad         - NEW: tiny text editor, up to 8 lines
  panic           - NEW: joke kernel-panic screen (totally safe)
  note <text>     - jot a note down (up to 5 per session)
  notes           - show your notes
  history         - show your last 5 commands
  secret / hello / sleep - more flavour text and an easter egg
  echo <text>     - prints text back
  tribute         - a short message about Rambo
  run             - load and execute YOUR OWN app from disk
                    (see APPDEV.txt)

System:
  logo / clear / cls  - reprint the banner / clear the screen
  about / credits     - about RamboOS
  help / commands     - list of all commands
  reboot              - reboot the machine
  shutdown            - halt the CPU (safe to power off)

WRITE YOUR OWN APP
-------------------
RamboOS ships with one pre-installed demo app (try "run" right after
booting) plus full source for it (demo-app.asm) and a step-by-step
guide in APPDEV.txt for writing, assembling, and installing your own.

WHAT'S IN THIS ZIP
-------------------
  ramboos.img     - the bootable disk image (this is the one to run)
  boot.asm        - stage 1 bootloader source (512-byte MBR)
  stage2.asm      - the kernel/shell/GUI/mouse-driver source
  demo-app.asm    - source for the pre-installed demo app
  build.sh        - rebuilds ramboos.img from the sources (needs nasm)
  APPDEV.txt      - guide to writing and installing your own app
  README.txt      - this file

Rambo was a tough, good cat, and this is his OS now. Semper Felix.

BUILDING FROM SOURCE
--------------------
  ./build.sh      (assembles boot.asm, stage2.asm, demo-app.asm with
                   NASM and lays them into a fresh 1.44MB ramboos.img:
                   sector 0 = boot, sectors 1-40 = kernel,
                   sector 41+ = the 'run' app slot)

#!/bin/sh
# Builds ramboos.img (1.44MB floppy image) from the sources. Needs: nasm, dd.
set -e
nasm -f bin boot.asm     -o boot.bin
nasm -f bin stage2.asm   -o stage2.bin
nasm -f bin demo-app.asm -o demo-app.bin

SIZE=$(wc -c < stage2.bin)
if [ "$SIZE" -gt 20480 ]; then
  echo "stage2.bin is $SIZE bytes - the kernel must fit in 40 sectors (20480 bytes)"
  exit 1
fi

dd if=/dev/zero    of=ramboos.img bs=512 count=2880 2>/dev/null
dd if=boot.bin     of=ramboos.img bs=512 seek=0  conv=notrunc 2>/dev/null
dd if=stage2.bin   of=ramboos.img bs=512 seek=1  conv=notrunc 2>/dev/null
dd if=demo-app.bin of=ramboos.img bs=512 seek=41 conv=notrunc 2>/dev/null
rm -f boot.bin stage2.bin demo-app.bin
echo "Built ramboos.img (kernel: $SIZE / 20480 bytes)"

https://github.com/zig-homebrew/zig-3ds/tree/master

```
env DEVKITARM=/opt/devkitpro/devkitARM env DEVKITPRO=/opt/devkitpro make
```

```
mkdir -p build romfs/gfx
/Applications/Xcode.app/Contents/Developer/usr/bin/make --no-print-directory -C build -f /Users/pfg/Dev/Node/3dsgame/Makefile
tex3ds -i /Users/pfg/Dev/Node/3dsgame/gfx/lenny.t3s -H lenny.h -d lenny.d -o lenny.t3x
Used lz11 for compression
arm-none-eabi-gcc -MMD -MP -MF /Users/pfg/Dev/Node/3dsgame/build/main.d  -g -Wall -O2 -mword-relocations -ffunction-sections -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft -I/Users/pfg/Dev/Node/3dsgame/include -I/opt/devkitpro/libctru/include -I/Users/pfg/Dev/Node/3dsgame/build -D__3DS__ -c /Users/pfg/Dev/Node/3dsgame/src/main.c -o main.o
arm-none-eabi-gcc -MMD -MP -MF /Users/pfg/Dev/Node/3dsgame/build/stereoscopic.d  -g -Wall -O2 -mword-relocations -ffunction-sections -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft -I/Users/pfg/Dev/Node/3dsgame/include -I/opt/devkitpro/libctru/include -I/Users/pfg/Dev/Node/3dsgame/build -D__3DS__ -c /Users/pfg/Dev/Node/3dsgame/src/stereoscopic.c -o stereoscopic.o
arm-none-eabi-gcc -specs=3dsx.specs -g -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft -Wl,-Map,3dsgame.map      main.o stereoscopic.o  -L/opt/devkitpro/libctru/lib -lcitro2d -lcitro3d -lctru -lm -o /Users/pfg/Dev/Node/3dsgame/3dsgame.elf
arm-none-eabi-gcc-nm -CSn /Users/pfg/Dev/Node/3dsgame/3dsgame.elf > 3dsgame.lst
smdhtool --create "3dsgame" "Built with devkitARM & libctru" "Unspecified Author" /opt/devkitpro/libctru/default_icon.png /Users/pfg/Dev/Node/3dsgame/3dsgame.smdh
3dsxtool /Users/pfg/Dev/Node/3dsgame/3dsgame.elf /Users/pfg/Dev/Node/3dsgame/3dsgame.3dsx --smdh=/Users/pfg/Dev/Node/3dsgame/3dsgame.smdh --romfs=/Users/pfg/Dev/Node/3dsgame/romfs
```

# Common set of macros to enable Linux versus Windows portability.
ifeq ($(OS),Windows_NT)
    OPHIS = "C:/Program Files (x86)/Ophis/ophis.exe"
    PY65MON = "%HOMEPATH%\AppData\Roaming\Python\Python36\Scripts\py65mon"
    PYTHON = python
    RM = del /f /q
    RMDIR = rmdir /s /q
    SHELL_EXT = bat
    TOUCH = type nul >
else
    OPHIS = ~/Ophis-2.1/ophis
    PY65MON = python 
    PYTHON = python
    RM = rm -f
    RMDIR = rm -rf
    SHELL_EXT = sh
    TOUCH = touch
endif

SOURCES =  \
	Tali-Forth.asm \
	macros.asm

APPLE_SOURCES = \
	$(SOURCES) \
	Tali-Main-L-Star.asm \
	Tali-Kernel-L-Star.asm

PY65MON_SOURCES = \
	$(SOURCES) \
	Tali-Main-Py65Mon.asm \
	Tali-Kernel-Py65Mon.asm

SBC27_SOURCES = \
	$(SOURCES) \
	Tali-Kernel.asm \
	Tali-Main-B001.asm \
	cbm_iec.asm \
	pckybd.asm \
	video.asm

py65mon.rom: clean $(SOURCES)
	$(OPHIS) --65c02 Tali-Main-Py65Mon.asm

tali-l-star.bin: $(APPLE_SOURCES)
	$(OPHIS) --65c02 Tali-Main-L-Star.asm
	"C:\Users\Martin\github\BinToMon\Release\BinToMon.exe" tali-l-star.bin > tali-l-star.txt

tali-sbc.bin: $(SBC27_SOURCES)
	$(OPHIS) --65c02 Tali-Main-B001.asm

debug: py65mon.rom
	$(PY65MON) -m 65C02 -r py65mon.rom

release: tali-l-star.bin tali-sbc.bin

clean:
	-$(RM) *.rom
	-$(RM) *.bin 

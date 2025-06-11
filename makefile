#!/usr/bin/make -f
#
# Based on the makefile for LoROM template
# Copyright 2014-2015 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the SFC program and the zip file.
title = platformer-example
version = 0.01

# Space-separated list of asm files without .s extension
# (use a backslash to continue on the next line)
objlist = \
  snesheader init main player memory common renderlevel \
  uploadppu graphics blockdata tad-audio_config audio_incbins audio_misc \
  scrolling playergraphics blockinteraction palettedata \
  actordata actorcode actorshared levelload leveldata \
  sincos_data math lz4 playerdraw playerprojectile

CC := gcc
AS65 := ca65
LD65 := ld65
CFLAGS65 = -g
TAD_COMPILER := audio/tad-compiler

objdir := obj/snes
audiodir := audio
srcdir := src
imgdirX := tilesetsX
imgdir4 := tilesets4
imgdir2 := tilesets2
bgdir := backgrounds

ifndef SNESEMU
SNESEMU := ./mesen-s
endif

lz4_flags    := -f -9

ifdef COMSPEC
PY := py.exe -3 
lz4_compress := tools/lz4
else
PY := python3
lz4_compress := lz4
endif

# Calculate the current directory as Wine applications would see it.
# yep, that's 8 backslashes.  Apparently, there are 3 layers of escaping:
# one for the shell that executes sed, one for sed, and one for the shell
# that executes wine
# TODO: convert to use winepath -w
wincwd := $(shell pwd | sed -e "s'/'\\\\\\\\'g")

# .PHONY means these targets aren't actual filenames
.PHONY: all run nocash-run spcrun dist clean

# When you type make without a target name, make will try
# to build the first target.  So unless you're trying to run
# NO$SNS in Wine, you should move run above nocash-run.
run: $(title).sfc
	$(SNESEMU) $<

# Special target for just the SPC700 image
spcrun: $(title).spc
	$(SPCPLAY) $<

all: $(title).sfc $(title).spc

clean:
	-rm $(objdir)/*.o $(objdir)/*.chr $(objdir)/*.ov53 $(objdir)/*.sav $(objdir)/*.pb53 $(objdir)/*.s

dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in all README.md $(objdir)/index.txt
	$(PY) tools/zipup.py $< $(title)-$(version) -o $@
	-advzip -z3 $@

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo zip.in >> $@
	echo $(title).sfc >> $@
	echo $(title).spc >> $@

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here. (This file's existence forces the unzip tool to create this folder.)" > $@

# Rules for ROM

objlisto = $(foreach o,$(objlist),$(objdir)/$(o).o)
chrXall := $(patsubst %.png,%.chr,$(wildcard tilesetsX/*.png))
chr4all := $(patsubst %.png,%.chrsfc,$(wildcard tilesets4/*.png))
chr2all := $(patsubst %.png,%.chrgb,$(wildcard tilesets2/*.png))
chr4_lz4 := $(patsubst %.png,%.chrsfc.lz4,$(wildcard tilesets4/lz4/*.png))
chr2_lz4 := $(patsubst %.png,%.chrgb.lz4,$(wildcard tilesets2/lz4/*.png))
palettes := $(wildcard palettes/*.png)
variable_palettes := $(wildcard palettes/variable/*.png)
levels_lz4 := $(patsubst %.tmx,%.lz4,$(wildcard levels/*.tmx))
levels_bin := $(patsubst %.tmx,%.bin,$(wildcard levels/*.tmx))

# Background conversion
# (nametable conversion is implied)
backgrounds := $(wildcard backgrounds/*.png)
chr4allbackground := $(patsubst %.png,%.chrsfc,$(wildcard backgrounds/*.png))

auto_linker.cfg: linker_template.cfg $(objlisto)
	$(PY) tools/uncle_fill.py hirom:16 auto_linker.cfg $^
map.txt $(title).sfc: auto_linker.cfg
	$(LD65) -o $(title).sfc -m map.txt --dbgfile $(title).dbg -C auto_linker.cfg $(objlisto)
	$(PY) tools/fixchecksum.py $(title).sfc

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/snes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/mktables.s: tools/mktables.py
	$< > $@

# Files that depend on enums
$(srcdir)/graphics.s: $(srcdir)/graphicsenum.s
$(objdir)/renderlevel.o: $(srcdir)/actorenum.s

$(objdir)/main.o: $(srcdir)/vblank.s $(srcdir)/audio_enum.inc
$(objdir)/blockdata.o: $(srcdir)/blockenum.s
$(objdir)/player.o: $(srcdir)/blockenum.s $(srcdir)/actorenum.s $(srcdir)/audio_enum.inc
$(objdir)/actorshared.o: $(srcdir)/blockenum.s
$(objdir)/levelload.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/blockenum.s
$(objdir)/leveldata.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/actorenum.s $(srcdir)/blockenum.s
$(objdir)/actordata.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s
$(objdir)/uploadppu.o: $(palettes) $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s
$(objdir)/blockinteraction.o: $(srcdir)/actorenum.s $(srcdir)/blockenum.s $(srcdir)/audio_enum.inc
$(srcdir)/actordata.s: $(srcdir)/actorenum.s
$(objdir)/actorcode.o: $(srcdir)/actorenum.s $(srcdir)/blockenum.s
$(objdir)/playerprojectile.o: $(srcdir)/actorenum.s $(srcdir)/blockenum.s $(srcdir)/audio_enum.inc

# Automatically insert graphics into the ROM
$(srcdir)/graphicsenum.s: $(chr2all) $(chr4all) $(chrXall) $(chr4allbackground) $(chr4_lz4) $(chr2_lz4) tools/gfxlist.txt tools/insertthegfx.py
	$(PY) tools/insertthegfx.py

# Automatically create the list of blocks from a description
$(srcdir)/blockdata.s: tools/blocks.txt tools/makeblocks.py
$(srcdir)/blockenum.s: tools/blocks.txt tools/makeblocks.py
	$(PY) tools/makeblocks.py


$(srcdir)/palettedata.s: $(palettes) $(variable_palettes)
$(srcdir)/paletteenum.s: $(palettes) $(variable_palettes) tools/encodepalettes.py
	$(PY) tools/encodepalettes.py
$(srcdir)/actorenum.s: tools/actors.txt tools/makeactor.py
	$(PY) tools/makeactor.py

$(srcdir)/leveldata.s: $(levels_lz4) $(levels_bin) tools/levelinsert.py tools/readtiled.py
	$(PY) tools/levelinsert.py
$(objdir)/leveldata.o: $(levels_lz4) $(levels_bin) $(srcdir)/leveldata.s $(srcdir)/actorenum.s
levels/%.lz4: levels/%.bin
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@
levels/%.bin: levels/%.tmx tools/levelconvert.py tools/blocks.txt
	$(PY) tools/levelconvert.py $< $@

$(srcdir)/sincos_data.s: tools/makesincos.py
	$(PY) tools/makesincos.py

# Rules for CHR data

# .chrgb (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
# Try generating it in the folder it's for
$(imgdir2)/%.chrgb: $(imgdir2)/%.png
	$(PY) tools/pilbmp2nes.py --planes=0,1 $< $@
$(imgdir2)/lz4/%.chrgb: $(imgdir2)/lz4/%.png
	$(PY) tools/pilbmp2nes.py --planes=0,1 $< $@
$(imgdir2)/lz4/%.chrgb.lz4: tilesets2/lz4/%.chrgb
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@

$(imgdir4)/%.chrsfc: $(imgdir4)/%.png
	$(PY) tools/pilbmp2nes.py "--planes=0,1;2,3" $< $@
$(imgdir4)/lz4/%.chrsfc: $(imgdir4)/lz4/%.png
	$(PY) tools/pilbmp2nes.py "--planes=0,1;2,3" $< $@
$(imgdir4)/lz4/%.chrsfc.lz4: tilesets4/lz4/%.chrsfc
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@

$(imgdirX)/%.chr: $(imgdirX)/%.txt $(imgdirX)/%.png
	$(PY) tools/pilbmp2nes.py "--flag-file" $^ $@
$(imgdirX)/lz4/%.chr: $(imgdirX)/%.txt $(imgdirX)/%.png
	$(PY) tools/pilbmp2nes.py "--flag-file" $^ $@
$(imgdirX)/lz4/%.chr.lz4: tilesetsX/lz4/%.chr
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@

# Rules for audio

$(srcdir)/audio_enum.inc: $(audiodir)/example-project.terrificaudio
	$(TAD_COMPILER) ca65-enums --output $@ $(audiodir)/example-project.terrificaudio

$(audiodir)/audio_common.bin: $(audiodir)/example-project.terrificaudio $(audiodir)/sound-effects.txt $(wildcard $(audiodir)/songs/*.mml)
	$(TAD_COMPILER) common --output $@ $(audiodir)/example-project.terrificaudio

$(patsubst %.mml,%.bin,$(wildcard $(audiodir)/songs/*.mml)): $(audiodir)/songs/*.mml
	$(TAD_COMPILER) song --output $@ $(audiodir)/example-project.terrificaudio $(patsubst %.bin,%.mml, $@)

$(objdir)/audio_incbins.o: $(audiodir)/audio_common.bin $(patsubst %.mml,%.bin,$(wildcard $(audiodir)/songs/*.mml))
$(srcdir)/audio_incbins.s: $(audiodir)/example-project.terrificaudio $(patsubst %.mml,%.bin,$(wildcard $(audiodir)/songs/*.mml))
	$(PY) tools/create_tad_incbins.py $< $@

$(objdir)/audio_misc.o: $(audiodir)/audio_common.bin

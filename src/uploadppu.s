; SNES platformer example
;
; Copyright (c) 2022 NovaSquirrel
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

.include "snes.inc"
.include "global.inc"
.include "graphicsenum.s"
.include "paletteenum.s"
.smart
.i16

.segment "CODE"
;;
; Clears 2048 bytes ($1000 words) of video memory to a constant
; value.  This can be one nametable, 128 2bpp tiles, 64 4bpp tiles,
; or 32 8bpp tiles.  Must be called during vertical or forced blank.
; @param X starting address of nametable in VRAM (16-bit)
; @param Y value to write (16-bit)
.proc ppu_clear_nt
  seta16
  sty $0000
  ldy #1024        ; number of bytes to clear
  
  ; Clear low bytes
  seta8
  stz PPUCTRL      ; +1 on PPUDATA low byte write
  lda #$00         ; point at low byte of Y
  jsl doonedma
  
  lda #INC_DATAHI  ; +1 on PPUDATA high byte write
  sta PPUCTRL
  lda #$01         ; point at high byte of Y
doonedma:
  stx PPUADDR
  sta DMAADDR
  ora #<PPUDATA
  sta DMAPPUREG
  lda #DMA_CONST|DMA_LINEAR
  sta DMAMODE
  sty DMALEN
  stz DMAADDRHI
  stz DMAADDRBANK
  lda #$01
  sta COPYSTART
  rtl
.endproc

;;
; Converts high OAM (sizes and X sign bits) to the packed format
; expected by the S-PPU.
.proc ppu_pack_oamhi
  setxy16
  ldx #0
  txy
packloop:
  ; pack four sprites' size+xhi bits from OAMHI
  sep #$20
  lda OAMHI+13,y
  asl a
  asl a
  ora OAMHI+9,y
  asl a
  asl a
  ora OAMHI+5,y
  asl a
  asl a
  ora OAMHI+1,y
  sta OAMHI,x
  rep #$21  ; seta16 + clc for following addition

  ; move to the next set of 4 OAM entries
  inx
  tya
  adc #16
  tay
  
  ; done yet?
  cpx #32  ; 128 sprites divided by 4 sprites per byte
  bcc packloop
  rtl
.endproc

;;
; Moves remaining entries in the CPU's local copy of OAM to
; (-128, 225) to get them offscreen.
; @param X index of first sprite in OAM (0-508)
.proc ppu_clear_oam
  setaxy16
lowoamloop:
  lda #(225 << 8) | <-128
  sta OAM,x
  lda #$0100  ; bit 8: offscreen
  sta OAMHI,x
  inx
  inx
  inx
  inx
  cpx #512  ; 128 sprites times 4 bytes per sprite
  bcc lowoamloop
  rtl
.endproc

;;
; Copies packed OAM data to the S-PPU using DMA channel 0.
.proc ppu_copy_oam
  setaxy16
  lda #DMAMODE_OAMDATA
  ldx #OAM
  ldy #544
  ; falls through to ppu_copy
.endproc

;;
; Copies data to the S-PPU using DMA channel 0.
; @param X source address
; @param DBR source bank
; @param Y number of bytes to copy
; @param A 15-8: destination PPU register; 7-0: DMA mode
;        useful constants:
; DMAMODE_PPUDATA, DMAMODE_CGDATA, DMAMODE_OAMDATA
.proc ppu_copy
  php
  setaxy16
  sta DMAMODE
  stx DMAADDR
  sty DMALEN
  seta8
  phb
  pla
  sta DMAADDRBANK
  lda #%00000001
  sta COPYSTART
  plp
  rtl
.endproc

;;
; Uploads a specific graphic asset to VRAM
; @param A graphic number (0-255)
.import GraphicsDirectory
.proc DoGraphicUpload
  phx
  php
  setaxy16
  ; Calculate the address
  and #255
  ; Multiply by 7 by subtracting the original value from value*8
  sta 0
  asl
  asl
  asl
  sub 0
  tax

  ; Now access the stuff from GraphicsDirectory:
  ; ppp dd ss - pointer, destination, size

  ; Destination address
  lda f:GraphicsDirectory+3,x
  sta PPUADDR

  ; Size can indicate that it's compressed
  lda f:GraphicsDirectory+5,x
  bmi Compressed
  sta DMALEN

  ; Upload to VRAM
  lda #DMAMODE_PPUDATA
  sta DMAMODE

  ; Source address
  lda f:GraphicsDirectory+0,x
  sta DMAADDR

  ; Source bank
  seta8
  lda f:GraphicsDirectory+2,x
  sta DMAADDRBANK

  ; Initiate the transfer
  lda #%00000001
  sta COPYSTART

  plp
  plx
  rtl

.a16
.i16
Compressed:
  phy ; This is trashed by the decompress routine

  lda f:GraphicsDirectory+0,x ; Source address
  pha
  lda f:GraphicsDirectory+2,x ; Source bank, don't care about high byte
  plx
  .import LZ4_DecompressToVRAM
  jsl LZ4_DecompressToVRAM

  ply
  plp
  plx
  rtl
.endproc

;;
; Uploads a specific palette asset to CGRAM
; locals: 0, 1
; @param A palette number (0-255)
; @param Y palette to upload to (0-15)
.import PaletteList
.proc DoPaletteUpload
  php
  setaxy16

  ; Calculate the address of the palette data
  and #255
  ; Multiply by 30
  sta 0
  asl
  asl
  asl
  asl
  sub 0
  asl
  add #PaletteList & $ffff
  ; Source address
  sta DMAADDR

  ; Upload to CGRAM
  lda #DMAMODE_CGDATA
  sta DMAMODE

  ; Size
  lda #15*2
  sta DMALEN

  ; Source bank
  seta8
  lda #^PaletteList
  sta DMAADDRBANK

  ; Destination address
  tya
  ; Multiply by 16 and add 1
  asl
  asl
  asl
  sec
  rol
  sta CGADDR

  ; Initiate the transfer
  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

; Upload level graphics and palettes,
; and also set PPU settings correctly for levels
.export UploadLevelGraphics
.proc UploadLevelGraphics
  seta8
  stz HDMASTART_Mirror
  stz HDMASTART

  ; Fix the background color
  stz CGADDR
  lda LevelBackgroundColor+0
  sta CGDATA
  lda LevelBackgroundColor+1
  sta CGDATA

  setaxy16
  ; Upload graphics
  lda #GraphicsUpload::SolidTiles
  jsl DoGraphicUpload

  lda #GraphicsUpload::GreenBrown
  jsl DoGraphicUpload

  lda #GraphicsUpload::YellowBlue
  jsl DoGraphicUpload

  lda #GraphicsUpload::Red
  jsl DoGraphicUpload

  lda #GraphicsUpload::Enemy
  jsl DoGraphicUpload

  lda #GraphicsUpload::Enemy2
  jsl DoGraphicUpload

  ; Upload palettes
  lda #Palette::GreenBrown
  ldy #0
  jsl DoPaletteUpload

  lda #Palette::YellowBlue
  ldy #1
  jsl DoPaletteUpload

  lda #Palette::Red
  ldy #2
  jsl DoPaletteUpload

  lda #Palette::Player
  ldy #8
  jsl DoPaletteUpload

  lda #Palette::Enemy1
  ldy #9
  jsl DoPaletteUpload

  lda #Palette::Enemy2
  ldy #10
  jsl DoPaletteUpload

  ; .------------------------------------.
  ; | Set up PPU registers for level use |
  ; '------------------------------------'
  seta8
  lda #1
  sta BGMODE       ; mode 1

  lda #(BG1CHRBase>>12)|((BG2CHRBase>>12)<<4)
  sta BGCHRADDR+0  ; bg plane 0 CHR at $0000, plane 1 CHR at $2000
  lda #BG3CHRBase>>12
  sta BGCHRADDR+1  ; bg plane 2 CHR at $2000

  lda #SpriteCHRBase >> 13
  sta OBSEL      ; sprite CHR at $6000, sprites are 8x8 and 16x16

  lda #1 | ((ForegroundBG >> 10)<<2)
  sta NTADDR+0   ; plane 0 nametable, 2 screens wide

  lda #1 | ((BackgroundBG >> 10)<<2)
  sta NTADDR+1   ; plane 1 nametable, 2 screens wide

  lda #0 | ((ExtraBG >> 10)<<2)
  sta NTADDR+2   ; plane 2 nametable, 1 screen

  stz PPURES

  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  stz BLENDSUB    ; disable subscreen

  lda #VBLANK_NMI|AUTOREAD  ; disable htime/vtime IRQ
  sta PPUNMI

  stz CGWSEL
  stz CGWSEL_Mirror
  stz CGADSUB
  stz CGADSUB_Mirror

  setaxy16
  jml RenderLevelScreens
.endproc

; Write increasing values to VRAM
.export WritePPUIncreasing
.proc WritePPUIncreasing
: sta PPUDATA
  ina
  dex
  bne :-
  rtl
.endproc

; Write the same value to VRAM repeatedly
.export WritePPURepeated
.proc WritePPURepeated
: sta PPUDATA
  dex
  bne :-
  rtl
.endproc

; Skip forward some amount of VRAM words
.export SkipPPUWords
.proc SkipPPUWords
: bit PPUDATARD
  dex
  bne :-
  rtl
.endproc

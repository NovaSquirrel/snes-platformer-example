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

; This file has the game's vblank handling code,
; and is included by main.s

VblankHandler:
  seta16

  ; Mark remaining sprites as offscreen
  ldx OamPtr
  jsl ppu_clear_oam

  ; Pack the second OAM table together into the format the PPU expects
  jsl ppu_pack_oamhi
  .a8 ; (does seta8)

  seta8
  jsl WaitVblank
  jsl ppu_copy_oam
  setaxy16

  ; Set up faster access to DMA registers
  lda #DMAMODE
  tcd
  ; Most DMAs here are DMAMODE_PPUDATA so set it up
  lda #DMAMODE_PPUDATA
  sta <DMAMODE+$00
  sta <DMAMODE+$10

  ; Player frame
  lda a:PlayerFrame
  and #255
  xba              ; *256
  asl              ; *512
  sta <DMAADDR+$00
  ora #256
  sta <DMAADDR+$10

  lda #32*8 ; 8 tiles for each DMA
  sta <DMALEN+$00
  sta <DMALEN+$10

  lda #SpriteCHRBase+($000>>1)
  sta PPUADDR
  seta8
  .import PlayerGraphics
  lda #^PlayerGraphics
  sta <DMAADDRBANK+$00
  sta <DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  ldx #SpriteCHRBase+($200>>1)
  stx PPUADDR
  lda #%00000010
  sta COPYSTART
  seta16

  ; Do row/column updates if required
  lda ColumnUpdateAddress
  beq :+
    stz ColumnUpdateAddress
    sta PPUADDR
    lda #.loword(ColumnUpdateBuffer)
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    lda #^ColumnUpdateBuffer
    sta <DMAADDRBANK
    lda #INC_DATAHI|VRAM_DOWN
    sta PPUCTRL
    lda #%00000001
    sta COPYSTART
    lda #INC_DATAHI
    sta PPUCTRL
    seta16
  :

  ldx RowUpdateAddress
  beq :+
    stz RowUpdateAddress
    ; --- First screen
    ; Set DMA parameters  
    stx PPUADDR
    lda #.loword(RowUpdateBuffer)
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    lda #^RowUpdateBuffer
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #.loword(RowUpdateBuffer+32*2)
    sta <DMAADDR
    sty <DMALEN

    seta8
    lda #%00000001
    sta COPYSTART
    seta16
  :

  .a16

  ; ----------------
  ; Do block updates (or any other tilemap updates that are needed)
  lda ScatterUpdateLength
  beq ScatterBufferEmpty
    sta <DMALEN

    lda #(<PPUADDR << 8) | DMA_0123 | DMA_FORWARD ; Alternate between writing to PPUADDR and PPUDATA
    sta <DMAMODE
    lda #.loword(ScatterUpdateBuffer)
    sta <DMAADDR

    seta8
    lda #^ScatterUpdateBuffer
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16
  ScatterBufferEmpty:

  lda #0
  tcd

EndOfVblank:

  ; Will seta8 afterward

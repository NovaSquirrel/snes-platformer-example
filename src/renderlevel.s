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

; This file contains code to draw the 16x16 blocks that levels are made up of.
; RenderLevelScreens will draw the whoel screen, and the other code handles updating
; the screen during scrolling.

.include "snes.inc"
.include "global.inc"
.include "actorenum.s"
.smart
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.import ActorSafeRemoveX

.segment "C_Player"

.a16
.i16
.proc RenderLevelScreens
  ; Calculate a new scroll position based on the player's current position
  lda PlayerPX
  sub #(8*256)
  bcs :+
    lda #0
: cmp ScrollXLimit
  bcc :+
    lda ScrollXLimit
  :
  sta ScrollX

  lda PlayerPY
  sub #(8*256)
  bcs :+
    lda #0
: cmp ScrollYLimit
  bcc :+
    lda ScrollYLimit
  :
  sta ScrollY

  ; If vertical scrolling is not enabled, lock to the bottom of the level
  lda VerticalScrollEnabled
  lsr
  bcs :+
    lda ScrollYLimit
    sta ScrollY
  :

  ; -------------------

  ; Try to spawn all actors that would be found on this screen, if this flag is set
  lda RerenderInitEntities
  and #255
  jeq NoInitEntities

  ; Init actors
  ldx #ActorStart
  ldy #ProjectileEnd-ActorStart
  jsl MemClear
DidPreserveEntities:

  seta8
  stz RerenderInitEntities
  seta16

  ; Init particles by clearing them out
  ldx #ParticleStart
  ldy #ParticleEnd-ParticleStart
  jsl MemClear

  seta8
  Low = 4
  High = 5
  ; Try to spawn actors.
  ; First find the minimum and maximum columns to check.
  lda ScrollX+1
  pha
  sub #4
  bcs :+
    tdc ; Clear accumulator
  :
  sta Low
  ; - get high column
  pla
  add #25
  bcc :+
    lda #255
  :
  sta High
  ; Now look through the list
  ldy #0
EnemyLoop:
  lda [LevelActorPointer],y
  cmp #255
  beq Exit
  cmp Low
  bcc Nope
  cmp High
  bcs Nope
  .import TryMakeActor
  jsl TryMakeActor
Nope:
  iny
  iny
  iny
  iny
  bne EnemyLoop
Exit:

NoInitEntities:
  seta16



  ; -------------------

BlockNum = 0
BlocksLeft = 2
YPos = 4
  ; Start rendering
  lda ScrollX+1 ; Get the column number in blocks
  and #$ff
  sub #4   ; Render out past the left side a bit
  sta BlockNum
  jsl GetLevelColumnPtr
  lda #26  ; Go 26 blocks forward
  sta BlocksLeft

  lda ScrollY
  xba
  and LevelColumnMask
  asl
  ora LevelBlockPtr
  sta YPos

Loop:
  ; Calculate the column address
  lda BlockNum
  and #15
  asl
  ora #ForegroundBG
  sta ColumnUpdateAddress

  ; Use the other nametable if necessary
  lda BlockNum
  and #16
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
  :

  ; Upload two columns
  ldx YPos
  jsl RenderLevelColumnLeft
  jsl RenderLevelColumnUpload
  inc ColumnUpdateAddress
  ldx YPos
  jsl RenderLevelColumnRight
  jsl RenderLevelColumnUpload

  ; Move onto the next block
  lda YPos
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1
  sta YPos
  inc BlockNum

  dec BlocksLeft
  bne Loop

  stz ColumnUpdateAddress

  rtl
.endproc

.proc RenderLevelColumnUpload
  php
  seta16

  ; Set DMA parameters  
  lda ColumnUpdateAddress
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #.loword(ColumnUpdateBuffer)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  lda #^ColumnUpdateBuffer
  sta DMAADDRBANK

  lda #INC_DATAHI|VRAM_DOWN
  sta PPUCTRL

  lda #%00000001
  sta COPYSTART

  lda #INC_DATAHI
  sta PPUCTRL
  plp
  rtl
.endproc

.proc RenderLevelRowUpload
  php

  ; .------------------
  ; | First screen
  ; '------------------
  seta16

  ; Set DMA parameters  
  lda RowUpdateAddress
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #.loword(RowUpdateBuffer)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  lda #^RowUpdateBuffer
  sta DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  ; .------------------
  ; | Second screen
  ; '------------------
  seta16

  ; Reset the counters. Don't need to do DMAMODE again I assume?
  lda RowUpdateAddress
  ora #2048>>1
  sta PPUADDR
  lda #.loword(RowUpdateBuffer+32*2)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8

  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

.segment "BlockGraphicData"
; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnLeft
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
: lda a:LevelBuf,x ; Get the next level tile
  inx
  inx
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopLeft,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  lda f:BlockBottomLeft,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  plx

  ; Wrap around in the buffer
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnRight
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
: lda a:LevelBuf,x ; Get the next level tile
  inx
  inx
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopRight,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  lda f:BlockBottomRight,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  plx

  ; Wrap around in the buffer
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rtl
.endproc

; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; Initialize X with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowTop
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  lda #20
  sta TempVal

: lda a:LevelBuf,x ; Get the next level tile
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopLeft,x
  sta RowUpdateBuffer,y
  iny
  iny
  lda f:BlockTopRight,x
  sta RowUpdateBuffer,y
  iny
  iny
  pla

  ; Next column
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  tax

  ; Wrap around in the buffer
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; Initialize X with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowBottom
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  lda #20
  sta TempVal

: lda a:LevelBuf,x ; Get the next level tile
  phx
  tax
  ; Write the two tiles in
  lda f:BlockBottomLeft,x
  sta RowUpdateBuffer,y
  iny
  iny
  lda f:BlockBottomRight,x
  sta RowUpdateBuffer,y
  iny
  iny
  pla

  ; Next column
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  tax

  ; Wrap around in the buffer
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc

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
.include "blockenum.s"
.smart
.import GameMainLoop, UploadLevelGraphics

.segment "C_LevelDecompress"

; Accumulator = level number
.a16
.i16
.export StartLevel, StartLevelFromDoor
.proc StartLevel
  setaxy16
::StartLevelFromDoor:
  ldx #$1ff
  txs ; Reset the stack pointer so no cleanup is needed
  jsr StartLevelCommon
  jsl UploadLevelGraphics
  jsl MakeCheckpoint
  jml GameMainLoop
.endproc

; Called both when starting a level normally and when making a checkpoint through other means
.export MakeCheckpoint
.proc MakeCheckpoint
  php

  seta8
  ; Y instead of X so an actor can call it easily
  ldy #GameStateSize-1
: lda GameStateStart,y
  sta CheckpointState,y
  dey
  bpl :-

  lda PlayerPX+1
  sta CheckpointX
  lda PlayerPY+1
  sta CheckpointY

  plp
  rtl
.endproc

; Stuff that's done whether a level is started from scratch or resumed
.proc StartLevelCommon
  jsl DecompressLevel
  phk ; Change the data bank back to something with the first 8KB of RAM visible
  plb
  inc RerenderInitEntities
  rts
.endproc

.a16
.i16
.export ResumeLevelFromCheckpoint
.proc ResumeLevelFromCheckpoint
  jsr StartLevelCommon

  ; Restore saved state
  seta8
  ldy #GameStateSize-1
: lda CheckpointState,y
  sta GameStateStart,y
  dey
  bpl :-

  lda CheckpointX
  sta PlayerPX+1
  lda CheckpointY
  sta PlayerPY+1

  ; Wait until here to do this, because it renders the screen and we're overriding the player start position
  jsl UploadLevelGraphics

  ; Don't need to restore register size because GameMainLoop does setaxy16
  jml GameMainLoop
.endproc

; .----------------------------------------------------------------------------
; | Header parsing
; '----------------------------------------------------------------------------
; Loads the level whose header is pointed to by LevelHeaderPointer
.a16
.i16
.export DecompressLevel
.proc DecompressLevel
  ; Clear out some buffers before the level loads stuff into them

  ; Don't clear any entities, that'll be done when rendering

  ; Clear level buffer
  ldx #.loword(LevelBuf)
  ldy #LevelBuf_End - LevelBuf
  jsl MemClear7F

  lda #32*2 ; 32 blocks tall
  sta LevelColumnSize
  dea
  sta LevelColumnMask

  lda #(15*16)*256 ; 15 screens of 16 tiles, each containing 256 subpixels
  sta ScrollXLimit
  lda #(16+2)*256  ; 1 screen of 16 tiles, each containing 256 subpixels. Add 2 tiles because (224 - 256) = 32 pixels.
  sta ScrollYLimit

  seta8
  ; ------------ Initialize variables ------------
  ; Clear a bunch of stuff in one go that's in contiguous space in memory
  ldx #LevelZeroWhenLoad_Start
  ldy #LevelZeroWhenLoad_End-LevelZeroWhenLoad_Start
  jsl MemClear

  ; Health
  lda #3
  sta PlayerHealth
  sta VerticalScrollEnabled

  ; Clear FirstActorOnScreen list too
  ldy #15
  lda #255
: sta FirstActorOnScreen,y
  dey
  bpl :-

  ; Set the high byte of the level pointer
  ; so later accesses work correctly.
  lda #^LevelBuf
  sta LevelBlockPtr+2

  ; Initialize variables related to optimizations
  .import level_demo
  lda #<level_demo
  sta LevelHeaderPointer+0
  lda #>level_demo
  sta LevelHeaderPointer+1
  lda #^level_demo
  sta LevelHeaderPointer+2

  ; -----------------------------------

  ; Parse the level header

  ; Music and starting player direction
  lda [LevelHeaderPointer]

  ldy #1
  ; Starting X position
  lda [LevelHeaderPointer],y
  sta PlayerPX+1
  stz PlayerPX+0

  iny ; Y = 2
  ; Starting Y position
  lda [LevelHeaderPointer],y
  sta PlayerPY+1
  stz PlayerPY+0

  ; Unused, a good place to put flags
  iny ; Y = 3
  lda [LevelHeaderPointer],y

  ; Background color
  iny ; Y = 4
  stz CGADDR
  lda [LevelHeaderPointer],y
  sta LevelBackgroundColor+0
  sta CGDATA
  iny ; Y = 5
  lda [LevelHeaderPointer],y
  sta LevelBackgroundColor+1
  sta CGDATA

  ; Actor data pointer
  iny ; Y = 6
  lda [LevelHeaderPointer],y
  sta LevelActorPointer+0
  iny ; Y = 7
  lda [LevelHeaderPointer],y
  sta LevelActorPointer+1

  ; Level data is at the end
  iny ; Y = 8
  lda [LevelHeaderPointer],y
  sta LevelDataPointer+0
  iny ; Y = 9
  lda [LevelHeaderPointer],y
  sta LevelDataPointer+1

  ; Copy over the bank number
  lda LevelHeaderPointer+2
  sta LevelActorPointer+2
  sta LevelDataPointer+2

  ; -----------------------------------
  jsr IndexActorList

  ; Decompress the data

  setaxy16
  .import SFX_LZ4_decompress
  ldx LevelDataPointer             ; Input address
  ldy #.loword(DecompressBuffer)   ; Output address
  lda LevelDataPointer+2           ; Input bank
  and #255
  ora #(^DecompressBuffer <<8)     ; Output bank
  jsl SFX_LZ4_decompress

  ; Point the data bank at bank $7F, where DecompressBuffer is
  ph2banks DecompressBuffer, DecompressBuffer
  plb
  plb

  ; Initialize the two indices
  ldx #0
  txy

  ; Expand the decompressed level out so that each block is two bytes
  ; and convert it to column major.
DecompressLoop:
  lda DecompressBuffer,y
  ; Move right one block in the decompressed data
  iny
  cpy #256*32        ; Went past the end of the decompressed data?
  bcs Exit
  and #255
  asl
  sta f:LevelBuf,x

  ; Move right one block in the destination
  txa
  add #32*2
  cmp #256*32*2      ; Went past the end?
  bcc :+
    sub #256*32*2-2  ; Go to the start of the next row
  :
  tax
  bra DecompressLoop
Exit:

  rtl
.endproc

.a8
.i16
.proc IndexActorList
  setaxy8
  ldy #0
@Loop:
  lda [LevelActorPointer],y
  cmp #255 ; 255 marks the end of the list
  beq @Exit
  ; Get screen number
  lsr
  lsr
  lsr
  lsr
  tax
  ; Write actor number to the list, if the
  ; screen doesn't already have an actor set for it
  lda FirstActorOnScreen,x
  cmp #255
  bne :+
  seta16
  tya
  ; Divide by 4 to fit a bigger range into 255 bytes
  lsr
  lsr
  seta8
  sta FirstActorOnScreen,x
:
  ; Actors entries are four bytes long
  iny
  iny
  iny
  iny
  bra @Loop
@Exit:
  setxy16
  rts
.endproc

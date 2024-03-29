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
.smart

.segment "C_Player"

.a16
.i16
.proc AdjustCamera
ScrollOldX = OldScrollX
ScrollOldY = OldScrollY
TargetX = 4
TargetY = 6

  ; If the player is below the target, player Y position is the new target
  lda PlayerPY
  cmp PlayerCameraTargetY
  bcc :+
    sta PlayerCameraTargetY
  :

  ; Start adjusting the camera target up if the player is too high up on the screen
  ; (which will happen if they use a spring)
  lda PlayerDrawY
  and #255
  cmp #48
  bcs :+
    lda PlayerCameraTargetY
    sub #64
    sta PlayerCameraTargetY
  :

  ; Save the old scroll positions
  lda ScrollX
  sta ScrollOldX
  lda ScrollY
  sta ScrollOldY

  ; Find the target scroll positions
  lda PlayerPX
  sub #8*256
  bcs :+
    lda #0
: cmp ScrollXLimit
  bcc :+
  lda ScrollXLimit
: sta TargetX

  ; For a horizontal level, going off of the top of the screen should not target upward
  lda PlayerCameraTargetY
  bpl :+
    stz PlayerCameraTargetY
  :

  lda PlayerCameraTargetY
  sub #8*256  ; Pull back to center vertically
  bcs :+
    lda #0
: cmp ScrollYLimit
  bcc :+
  lda ScrollYLimit
: sta TargetY


  ; Move only a fraction of that
  lda TargetY
  sub ScrollY
  php
  bpl :+
    neg
  :

  ; Calculate how fast to scroll vertically
  pha
  lsr ; / 128
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  and #255
  rsb #20
  beq @DontDivideByZero
  bpl :+
@DontDivideByZero:
    lda #1
  :
  tay
@DoDivision:
  pla
  sta CPUNUM
  seta8
  tya
  sta CPUDEN
  ; Wait 16 clock cycles
  seta16
  ; ---
  ; Do the X calculation while I'm waiting
  lda TargetX
  sub ScrollX
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  sta TargetX
  ; ---
  lda CPUQUOT
  plp
  bpl :+
    neg
  :
  sta TargetY


  .if 0
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  adc #0
  sta TargetY
  .endif

  ; Apply the scroll distance
  lda TargetX
  jsr SpeedLimit
  add ScrollX
  sta ScrollX

  lda TargetY
  jsr SpeedLimit
  add ScrollY
  sta ScrollY

  ; If vertical scrolling is not enabled, lock to the bottom of the level
  lda VerticalScrollEnabled
  lsr
  bcs :+
    lda ScrollYLimit
    sta ScrollY
  :

  ; -----------------------------------

  ; Is a column update required?
  lda ScrollX
  eor ScrollOldX
  and #$80
  beq NoUpdateColumn
    lda ScrollX
    cmp ScrollOldX
    jsr ToTiles
    bcs UpdateRight
  UpdateLeft:
    sub #2             ; Two tiles to the left
    jsr UpdateColumn
    bra NoUpdateColumn
  UpdateRight:
    add #34            ; Two tiles past the end of the screen on the right
    jsr UpdateColumn
  NoUpdateColumn:

  ; Is a row update required?
  lda ScrollY
  eor ScrollOldY
  and #$80
  beq NoUpdateRow
    lda ScrollY
    cmp ScrollOldY
    jsr ToTiles
    bcs UpdateDown
  UpdateUp:
    jsr UpdateRow
    bra NoUpdateRow
  UpdateDown:
    add #29            ; Just past the screen height
    jsr UpdateRow
  NoUpdateRow:

  rtl

; Convert a 12.4 scroll position to a number of tiles
ToTiles:
  php
  lsr ; \ shift out the subpixels
  lsr ;  \
  lsr ;  /
  lsr ; /

  lsr ; \
  lsr ;  | shift out 8 pixels
  lsr ; /
  plp
  rts

SpeedLimit:
  ; Take absolute value
  php
  bpl :+
    eor #$ffff
    inc a
  :
  ; Cap it at 8 pixels
  cmp #$0080
  bcc :+
    lda #$0080
  :
  ; Undo absolute value
  plp
  bpl :+
    eor #$ffff
    inc a
  :
  rts
.endproc

.a16
.proc UpdateRow
Temp = 4
YPos = 6
  sta Temp

  ; Calculate the address of the row
  ; (Always starts at the leftmost column
  ; and extends all the way to the right.)
  and #31
  asl ; Multiply by 32, the number of words per row in a screen
  asl
  asl
  asl
  asl
  ora #ForegroundBG
  sta RowUpdateAddress

  ; Get level pointer address
  ; (Always starts at the leftmost column of the screen)
  lda ScrollX
  xba
  dec a
  jsl GetLevelColumnPtr

  ; Get index for the buffer
  lda ScrollX
  xba
  dec a
  asl
  asl
  and #(64*2)-1
  tay

  ; Take the Y position, rounded to blocks,
  ; as the column of level data to read
  lda Temp
  and #.loword(~1)
  ora LevelBlockPtr
  tax

  ; Generate the top or the bottom as needed
  lda Temp
  lsr
  bcs :+
  jsl RenderLevelRowTop
  rts
:
  
  ; If it's the bottom row, also scan for actors to introduce into the level
  lda Temp
  pha ; Don't rely on this routine not overwriting this variable
  jsl RenderLevelRowBottom
  pla

  rts
.endproc

.a16
.proc UpdateColumn
Temp = 4
YPos = 6
  sta Temp

  ; Calculate address of the column
  and #31
  ora #ForegroundBG
  sta ColumnUpdateAddress

  ; Use the second screen if required
  lda Temp
  and #32
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
  :

  ; Get level pointer address
  lda Temp ; Get metatile count
  lsr
  jsl GetLevelColumnPtr

  ; Use the Y scroll position in blocks
  lda ScrollY
  xba
  asl
  and LevelColumnMask
  ora LevelBlockPtr
  tax

  ; Generate the left or right as needed
  lda Temp
  lsr
  bcc :+
  jsl RenderLevelColumnRight
  rts
:

  ; If it's the left column, also scan for actors to introduce into the level
  lda Temp
  pha ; Don't rely on this routine not overwriting this variable
  jsl RenderLevelColumnLeft
  pla
::ScanForActorsToMake:
CheckColumn = Temp + 0
CheckScreen = Temp + 1
  lsr
  setaxy8
  sta CheckColumn
  and #$f0
  sta CheckScreen
  lsr
  lsr
  lsr
  lsr ; Screen number
  tay
  lda FirstActorOnScreen,y
  cmp #255 ; No actors on screen
  beq Exit

  setaxy16
  and #$00ff ; Clear high byte
  asl        ; Multiply by 4
  asl
  tay

  seta8
Loop:
  lda [LevelActorPointer],y
  cmp #255
  beq Exit ; Exit since the actor data is over
  pha
  and #$f0
  cmp CheckScreen
  bne Exit_PLA ; Exit since the actor data is on a different screen now
  pla
  cmp CheckColumn
  bne :+
    jsl TryMakeActor
  :
  ; Next actor
  iny
  iny
  iny
  iny
  bra Loop

Exit_PLA:
  pla
Exit:
  setaxy16
  rts 
.endproc

; Try to make an actor from the level actor list
; inputs: Y (actor index)
; preserves Y
.a8
.i16
.export TryMakeActor
.proc TryMakeActor
Index = 0
  sty Index
  phy
  php
  setaxy16
  
  ; Ensure the actor has not already been spawned
  ldx #ActorStart
CheckExistsLoop:
  lda ActorType,x ; Ignore ActorIndexInLevel if there is no Actor there
  beq :+
    lda ActorIndexInLevel,x ; Already exists
    cmp Index
    beq Exit
  :
  ; Next actor
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne CheckExistsLoop

  ; -----------------------------------
  ; Spawn in the actor
  jsl FindFreeActorX
  bcc Exit

  ; X now points at a free slot
  stz ActorVX,x
  stz ActorVY,x
  stz ActorVarB,x
  stz ActorVarC,x
  stz ActorTimer,x
  stz ActorOnScreen,x ; also ActorDamage
  tya
  sta ActorIndexInLevel,x

  ; Actor list organized as XXXXXXXX D..YYYYY tttttttt abcdTTTT
  seta8
  lda [LevelActorPointer],y ; X position
  sta ActorPX+1,x
  lda #$80                   ; Center it
  sta ActorPX+0,x
  iny
  lda [LevelActorPointer],y ; Y position, and two unused bits
  asl
  php
  lsr
  and #31
  sta ActorPY+1,x
  lda #$ff
  sta ActorPY+0,x

  ; Copy the most significant bit of the Y position to the least significant bit of the direction
  plp
  .a8 ; plp restores it to 8-bit accumulator
  tdc ; Clear accumulator
  rol
  sta ActorDirection,x
  iny

  seta16
  lda [LevelActorPointer],y ; Actor type and flags
  and #$fff
  asl
  sta ActorType,x
  .import InitActorX
  jsl InitActorX

  ; Store the flags into Actor generic variable A
  lda [LevelActorPointer],y
  xba
  lsr
  lsr
  lsr
  lsr
  and #15
  sta ActorVarA,x

Exit:
  plp
  ply
  rtl
.endproc


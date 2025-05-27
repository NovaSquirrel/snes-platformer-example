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


; This file mostly contains generic routines for actors to build their behaviors out of

.include "snes.inc"
.include "global.inc"
.include "blockenum.s"
.import ActorRun, ActorDraw, ActorAfterRun, ActorFlags, ActorWidthTable, ActorHeightTable, ActorBank, ActorGraphic, ActorPalette
.import ActorGetShot
.smart

.segment "C_ActorCommon"

; Two comparisons to make to determine if something is a slope
SlopeBCC = Block::SlopeLeft
SlopeBCS = Block::SlopeRightBelow+1
.export SlopeBCC, SlopeBCS
SlopeY = 2

.export RunAllActors
.proc RunAllActors
  setaxy16

  ldx #ActorStart
ActorLoop:
  ; Don't do anything if it's an empty slot
  lda ActorType,x
  beq @SkipEntity
    jsr ProcessOneActor
@SkipEntity:
  ; Next actor
  txa
  add #ActorSize
  tax
  cpx #ProjectileEnd ; Do the projectiles too
  bcc ActorLoop

  ;------------------------------------

  jml RunAllParticles

; Call the Run and Draw routines on an actor
ProcessOneActor:
  ; Call the run and draw routines
  lda ActorType,x
  jsl CallRun
  lda ActorType,x
  jsl CallDraw
  rts

; Call the Actor run code
.a16
CallRun:
  phx
  tax
  seta8
  lda f:ActorBank+0,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorRun,x
  sta 0
  plx ; X now equals the Actor index base again

  ; Jump to it and return with an RTL
  jml [0]

; Call the Actor draw code
.a16
CallDraw:
  phx
  tax
  seta8
  lda f:ActorBank+1,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorDraw,x
  sta 0
  plx ; X now equals the Actor index base again

  ; Jump to the per-Actor routine and return with an RTL
  jml [0]
.endproc

.export SharedEnemyCommon, SharedRemoveIfFar
.a16
.i16
SharedEnemyCommon:
  jsl PlayerActorCollisionHurt
  jsl ActorGetShot
SharedRemoveIfFar:
  lda ActorPX,x
  sub ScrollX
  cmp #.loword(-24*256)
  bcs @Good
  cmp #(16+24)*256
  bcc @Good
  jsl ActorSafeRemoveX
@Good:
  rtl

.pushseg
.segment "C_ParticleCode"
.a16
.i16
.import ParticleRun, ParticleDraw
assert_same_banks RunAllParticles, ParticleRun
assert_same_banks RunAllParticles, ParticleDraw
.proc RunAllParticles
  phk
  plb

  ldx #ParticleStart
Loop:
  lda ParticleType,x
  beq SkipEntity   ; Skip if empty

  ; Call the run and draw routines
  asl
  pha
  pea :+ -1
    tay
    lda ParticleRun,y
    pha
    rts
  :
  pla
  pea :+ -1
    tay
    lda ParticleDraw,y
    pha
    rts
  :
SkipEntity:
  ; Next particle
  txa
  add #ParticleSize
  tax
  cpx #ParticleEnd
  bcc Loop

  rtl
.endproc
.popseg


.a16
.i16
.proc FindFreeActorX
  phy
  lda #ActorStart
  clc
Loop:
  tax
  ldy ActorType,x ; Don't care what gets loaded into Y, but it will set flags
  beq Found
  adc #ActorSize
  cmp #ActorEnd   ; Carry should always be clear at this point
  bcc Loop
NotFound:
  ply
  clc
  rtl
Found:
  ply

  ; Initialize certain variables on newly claimed actors to avoid causing problems
  lda #$ffff
  sta ActorIndexInLevel,x
  seta16
  sta ActorOnGround,x ; Also zeros ActorOnScreen
  sec
  rtl
.endproc

.a16
.i16
.proc FindFreeActorY
  phx
  lda #ActorStart
  clc
Loop:
  tay
  ldx ActorType,y ; Don't care what gets loaded into X, but it will set flags
  beq Found
  adc #ActorSize  ; Carry should always be clear at this point
  cmp #ActorEnd
  bcc Loop
NotFound:
  plx
  clc
  rtl
Found:
  plx

  ; Initialize certain variables on newly claimed actors to avoid causing problems
  lda #$ffff
  sta ActorIndexInLevel,y
  seta16
  tdc ; A = 0
  sta ActorOnGround,y ; Also zeros ActorOnScreen
  sec
  rtl
.endproc


.a16
.i16
.proc FindFreeParticleY
  phx
  lda #ParticleStart
  clc
Loop:
  tay
  ldx ParticleType,y ; Don't care what gets loaded into X, but it will set flags
  beq Found
  adc #ParticleSize  ; Carry should always be clear at this point
  cmp #ParticleEnd
  bcc Loop
NotFound:
  plx
  clc
  rtl
Found:
  plx

  lda #0
  sta ParticleTimer,y
  sta ParticleVX,y
  sta ParticleVY,y
  sec
  rtl
.endproc

; Just flip the LSB of ActorDirection
.export ActorTurnAround
.a16
.proc ActorTurnAround
  ; No harm in using it as a 16-bit value here, it's just written back
  lda ActorDirection,x
  eor #1
  sta ActorDirection,x
  rtl
.endproc

.export ActorLookAtPlayer
.a16
.proc ActorLookAtPlayer
  lda ActorPX,x
  cmp PlayerPX

  ; No harm in using it as a 16-bit value here, it's just written back
  lda ActorDirection,x
  and #$fffe
  adc #0
  sta ActorDirection,x

  rtl
.endproc

; Takes a speed in the accumulator, and negates it if Actor facing left
.a16
.export ActorNegIfLeft
.proc ActorNegIfLeft
  pha
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcs Left
Right:
  pla ; No change
  rtl
Left:
  pla ; Negate
  neg
  rtl
.endproc

.export ActorApplyVelocity, ActorApplyXVelocity, ActorApplyYVelocity
.proc ActorApplyVelocity
  lda ActorPX,x
  add ActorVX,x
  sta ActorPX,x
::ActorApplyYVelocity:
  lda ActorPY,x
  add ActorVY,x
  sta ActorPY,x
  rtl
.endproc

.proc ActorApplyXVelocity
  lda ActorPX,x
  add ActorVX,x
  sta ActorPX,x
  rtl
.endproc


; Walks forward, and turns around if walking farther
; would cause the Actor to fall off the edge of a platform
; input: A (walk speed), X (Actor slot)
.export ActorWalkOnPlatform
.proc ActorWalkOnPlatform
  jsl ActorWalk
  jsl ActorAutoBump
.endproc
; fallthrough
.a16
.export ActorStayOnPlatform
.proc ActorStayOnPlatform
  ; Check forward a bit
  ldy ActorPY,x
  lda #8*16
  jsl ActorNegIfLeft
  add ActorPX,x
  jsl ActorTryDownInteraction

  cmp #$4000 ; Test for solid on top
  bcs :+
    jsl ActorTurnAround
  :
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; Will try the second layer if the first is not solid
; A = X coordinate, Y = Y coordinate
.export ActorTryUpInteraction
.import BlockRunInteractionActorTopBottom
.proc ActorTryUpInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; Will try the second layer if the first is not solid or solid on top
; A = X coordinate, Y = Y coordinate
.export ActorTryDownInteraction
.proc ActorTryDownInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; A = X coordinate, Y = Y coordinate
.export ActorTrySideInteraction
.import BlockRunInteractionActorSide
.proc ActorTrySideInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorSide
  lda BlockFlag
  rtl
.endproc

.a16
.export ActorWalk
.proc ActorWalk
WalkDistance = 0
  jsl ActorNegIfLeft
  sta WalkDistance

  ; Look up if the wall is solid
  lda ActorPY,x
  sub #1<<7
  tay
  lda ActorPX,x
  add WalkDistance
  jsl ActorTrySideInteraction
  bpl NotSolid
  Solid:
     sec
     rtl
  NotSolid:

  ; Apply the walk
  lda ActorPX,x
  add WalkDistance
  sta ActorPX,x
  ; Fall into ActorDownhillFix
.endproc

.a16
.proc ActorDownhillFix
  ; Going downhill requires special help
  seta8
  lda ActorOnGround,x ; Need to have been on ground last frame
  beq NoSlopeDown
  lda ActorVY+1,x
  bmi NoSlopeDown
  seta16
    jsr ActorGetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorGetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta ActorPY,x
    stz ActorVY,x
  NoSlopeDown:
  seta16_clc

  ; Reset carry to indicate not bumping into something
  ; because ActorWalk falls into this
  ;clc
  rtl
.endproc

.a16
.export ActorGravity
.proc ActorGravity
  lda ActorVY,x
  bmi OK
  cmp #$60
  bcs Skip
OK:
  add #4
  sta ActorVY,x
Skip:
  jmp ActorApplyYVelocity
.endproc

; Calls ActorGravity and then fixes things if they land on a solid block
; input: X (Actor pointer)
; output: carry (standing on platform)
.a16
.export ActorFall, ActorFallOnlyGroundCheck
.proc ActorFall
  jsl ActorGravity
::ActorFallOnlyGroundCheck:
  ; Remove if too far off the bottom
  lda ActorPY,x
  bmi :+
    cmp #32*256
    bcc :+
    cmp #$ffff - 2*256
    bcs :+
      jml ActorSafeRemoveX
  :

  jmp ActorCheckStandingOnSolid
.endproc

.a16
.export ActorBumpAgainstCeiling
.proc ActorBumpAgainstCeiling
  lda ActorHeight,x
  ; Reverse subtraction
  eor #$ffff
  sec
  adc ActorPY,x
  tay
  lda ActorPX,x
  jsl ActorTryUpInteraction
  asl
  bcc :+
    lda #$ffff
    sta 0 ; Did hit the ceiling - communicate this a different way?
    lda #$20
    sta ActorVY,x
    clc
  :
  rtl
.endproc

; Checks if an Actor is on top of a solid block
; input: X (Actor slot)
; output: Zero flag (not zero if on top of a solid block)
; locals: 0, 1
; Currently 0 is set to $ffff if it bumps against the ceiling, but that's sort of flimsy
.a16
.export ActorCheckStandingOnSolid
.proc ActorCheckStandingOnSolid
  seta8
  stz ActorOnGround,x
  seta16

  ; If going upwards, bounce against ceilings
  lda ActorVY,x
  bmi ActorBumpAgainstCeiling

  ; Check for slope interaction
  jsr ActorGetSlopeYPos
  bcc :+
    lda SlopeY
    cmp ActorPY,x
    bcs :+
    sta ActorPY,x
    stz ActorVY,x

    seta8_sec
    inc ActorOnGround,x
    seta16
    ; Don't do the normal ground check
    ;sec - SEC above
    rtl
  :

  ; Maybe add checks for the sides
  ldy ActorPY,x
  lda ActorPX,x
  jsl ActorTryDownInteraction
  cmp #$4000
  lda #0
  rol
  seta8
  sta ActorOnGround,x
  ; React to touching the ground
  beq NotSnapToGround
    stz ActorPY,x ; Clear the low byte
    seta16
    stz ActorVY,x
    sec
    rtl
  NotSnapToGround:
  seta16_clc
  ;clc
  rtl
.endproc

; Get the Y position of the slope under the player's hotspot (SlopeY)
; and also return if they're on a slope at all (carry)
.a16
.proc ActorGetSlopeYPos
  phb
  ldy ActorPY,x
  lda ActorPX,x
  jsl GetLevelPtrXY
  jsr ActorIsSlope
  bcc NotSlope
    assert_same_banks ActorGetSlopeYPos, SlopeHeightTable
    phk
    plb
    lda ActorPY,x
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorIsSlope
      bcc :+
        lda ActorPY,x
        sbc #$0100 ; assert((PS & 1) == 1) Carry already set
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  plb
  rts
.endproc

.a16
; Similar but for checking one block below
.proc ActorGetSlopeYPosBelow
  phb
  jsr ActorIsSlope
  bcc NotSlope
    assert_same_banks ActorGetSlopeYPosBelow, SlopeHeightTable
    phk
    plb
    lda ActorPY,x
    add #$0100
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorIsSlope
      bcc :+
        lda ActorPY,x
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  plb
  rts
.endproc

.a16
.proc ActorIsSlope
  cmp #SlopeBCC
  bcc :+
  cmp #SlopeBCS
  bcs :+
  sub #SlopeBCC
  ; Now we have the block ID times 2

  ; Multiply by 16 to get the index into the slope table
  asl
  asl
  asl
  asl
  sta 0

  ; Select the column
  lda ActorPX,x
  and #$f0 ; Get the pixels within a block
  lsr
  lsr
  lsr
  ora 0
  tay

  sec ; Success
  rts
: clc ; Failure
  rts
.endproc

; Automatically turn around when bumping
; into something during ActorWalk
.a16
.export ActorAutoBump
.proc ActorAutoBump
  bcc NoBump
  jmp ActorTurnAround
NoBump:
  rtl
.endproc

; Calculate the position of the 16x16 Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition16x16
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  sub FGScrollXPixels
  sub #8
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  adc #0 ; Why do I need to round Y and not X?
  sub FGScrollYPixels
  sub #17
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; Calculate the position of the 8x8 Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition8x8
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  sub FGScrollXPixels
  sub #4
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  adc #0 ; Why do I need to round Y and not X?
  sub FGScrollYPixels
  sub #9
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; Calculate the position of the 8x8 Actor on-screen
; and whether it's visible in the first place
; Uses offsets from SpriteXYOffset
.a16
.proc ActorDrawPositionWithOffset8x8
  lda SpriteXYOffset
  and #255
  bit #128 ; Sign extend
  beq :+
    ora #$ff00
  :
  sta 0
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  add 0
  sub FGScrollXPixels
  sub #4
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda SpriteXYOffset+1
  and #255
  bit #128 ; Sign extend
  beq :+
    ora #$ff00
  :
  sta 2
  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  adc #0 ; Why do I need to round Y and not X?
  add 2
  sub FGScrollYPixels
  sub #9
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; A = tile to draw
.a16
.export DispActor16x16
.proc DispActor16x16
  sta 4

  ldy OamPtr

  jsr ActorDrawPosition16x16
  bcs :+
    seta8
    stz ActorOnScreen,x
    seta16
    rtl
  :  

  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  lda 4
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00000001
  lda #1 ; 16x16 sprites
  sta ActorOnScreen,x
  rol
  sta OAMHI+1,y
  seta16_clc

  tya
  adc #4 ; Carry cleared above
  sta OamPtr
  rtl
.endproc

; A = tile to draw
.a16
.export DispActor8x8
.proc DispActor8x8
  sta 4

  stz SpriteXYOffset
  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  jsr ActorDrawPosition8x8
  bcs :+
    rtl
  :
CustomOffset:
  ldy OamPtr

  lda 4
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00000001
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16_clc

  tya
  adc #4 ; CLC above
  sta OamPtr
  rtl
.endproc

; A = tile to draw
; SpriteXYOffset = X,Y offsets
.a16
.proc DispActor8x8WithOffset
  sta 4

  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda 4
    eor #OAM_XFLIP
    sta 4
    seta8 ; Flip X offset
    lda SpriteXYOffset
    eor #255
    ina
    sta SpriteXYOffset
    seta16
  :

  jsr ActorDrawPositionWithOffset8x8
  bcs :+
    rtl
  :
  bra DispActor8x8::CustomOffset
.endproc
.export DispActor8x8WithOffset

.a16
.proc ParticleDrawPosition
  lda ParticlePX,x
  sub ScrollX
  cmp #.loword(-1*256)
  bcs :+
  cmp #16*256
  bcs Invalid
: lsr
  lsr
  lsr
  lsr
  sub #4
  sta 0

  lda ParticlePY,x
  sub ScrollY
  cmp #15*256
  bcs Invalid
  lsr
  lsr
  lsr
  lsr
  sub #4
  sta 2

  sec
  rts
Invalid:
  clc
  rts
.endproc

; A = tile to draw
; Very similar to DispParticle8x8; maybe combine them somehow?
.a16
.export DispParticle16x16
.proc DispParticle16x16
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #1 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc


; A = tile to draw
.a16
.export DispParticle8x8
.proc DispParticle8x8
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc

.export SlopeHeightTable
.proc SlopeHeightTable
; SlopeLeft
.word $f0, $e0, $d0, $c0, $b0, $a0, $90, $80
.word $70, $60, $50, $40, $30, $20, $10, $00

; SlopeRight
.word $00, $10, $20, $30, $40, $50, $60, $70
.word $80, $90, $a0, $b0, $c0, $d0, $e0, $f0

;SlopeLeftBelow
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

;SlopeRightBelow
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00
.endproc

.pushseg
.segment "C_Player"
.export SlopeFlagTable
.proc SlopeFlagTable
Left  = $8000
Right = $0000
Gradual = 1
Medium  = 2
Steep   = 4

.word Left  ; MedSlopeL_DL
.word Right ; MedSlopeR_DR
.word Left  ; GradualSlopeL_D1
.word Left  ; GradualSlopeL_D2
.word Right ; GradualSlopeR_D3
.word Right ; GradualSlopeR_D4
.word Left  ; SteepSlopeL_D
.word Right ; SteepSlopeR_D
.repeat 2
.word Left  | Medium  ; MedSlopeL_UL
.word Left  | Medium  ; MedSlopeL_UR
.word Right | Medium  ; MedSlopeR_UL
.word Right | Medium  ; MedSlopeR_UR
.word Left  | Steep   ; SteepSlopeL_U
.word Right | Steep   ; SteepSlopeR_U
.word Left  | Gradual ; GradualSlopeL_U1
.word Left  | Gradual ; GradualSlopeL_U2
.word Left  | Gradual ; GradualSlopeL_U3
.word Left  | Gradual ; GradualSlopeL_U4
.word Right | Gradual ; GradualSlopeR_U1
.word Right | Gradual ; GradualSlopeR_U2
.word Right | Gradual ; GradualSlopeR_U3
.word Right | Gradual ; GradualSlopeR_U4
.endrep
.endproc
.popseg


; Tests if two actors overlap
; Inputs: Actor pointers X and Y
.export TwoActorCollision
.a16
.i16
.proc TwoActorCollision
AWidth   = TouchTemp+0
  ; Test Y positions

  ; Actor 1's top edge should not be below actor 2's bottom edge
  lda ActorPY,x
  sub ActorHeight,x
  cmp ActorPY,y
  bcs No

  ; Actor 2's top edge should not be below actor 1's bottom edge
  lda ActorPY,y
  sub ActorHeight,y
  cmp ActorPY,x
  bcs No

  ; Test X positions

  ; The two actors' widths are added together, so just do this math now
  lda ActorWidth,x
  adc ActorWidth,y ; Carry clear - guaranteed by the bcs above
  sta AWidth

  ; Assert that (abs(a.x - b.x) * 2 < (a.width + b.width))
  lda ActorPX,x
  sub ActorPX,y
  bpl :+       ; Take the absolute value
    eor #$ffff
    ina
  :
  asl
  cmp AWidth
  bcs No

  ; -----------------------------------

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc


.export PlayerActorCollision
.a16
.i16
.proc PlayerActorCollision
AWidth   = TouchTemp+0
  ; Actor's bottom edge should not be above player's top edge
  lda ActorPY,x
  cmp PlayerPYTop
  bcc No

  lda ActorWidth,x
  lsr
  sta AWidth

  ; Actor's left edge should not be more right than the player's right edge
  lda ActorPX,x
  sec
  sbc AWidth
  cmp PlayerPXRight
  bcs No

  ; Actor's right edge should not be more left than the player's left edge
  lda ActorPX,x
  sec
  adc AWidth
  cmp PlayerPXLeft
  bcc No

  ; Actor's top edge should not be below the player's bottom edge
  lda ActorPY,x
  sub ActorHeight,x
  cmp PlayerPY
  bcs No

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc

.export PlayerActorCollisionHurt
.a16
.i16
.proc PlayerActorCollisionHurt
  ; If touching the player, hurt them
  jsl PlayerActorCollision
  bcc :+
    .import HurtPlayer
    jml HurtPlayer
  :
Exit:
  rtl
.endproc

.export ActorClearX
.a16
.i16
.proc ActorClearX
  stz ActorVarA,x
  stz ActorVarB,x
  stz ActorVarC,x
  stz ActorVX,x
  stz ActorVY,x
  stz ActorTimer,x
  stz ActorDirection,x
  stz ActorOnGround,x
  rtl
.endproc

.export ActorClearY
.a16
.i16
.proc ActorClearY
  phx
  tyx
  jsl ActorClearX
  plx
  rtl
.endproc

; Counts the amount of a certain actor that currently exists
; inputs: A (actor type * 2)
; outputs: Y (count)
; locals: 0
.export CountActorAmount
.a16
.i16
.proc CountActorAmount
  phx
  sta 0  ; 0 = object num
  ldy #0 ; Y = counter for number of matching objects

  ldx #ActorStart
Loop:
  lda ActorType,x
  cmp 0
  bne :+
    iny
  :
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne Loop

  plx
  tya
  rtl
.endproc

; Counts the amount of a certain projectile actor that currently exists
; TODO: maybe measure the projectile type, instead of the actor type?
; inputs: A (actor type * 2)
; outputs: Y (count)
; locals: 0
.export CountProjectileAmount
.a16
.i16
.proc CountProjectileAmount
  phx
  sta 0  ; 0 = object num
  ldy #0 ; Y = counter for number of matching objects

  ldx #ProjectileStart
Loop:
  lda ActorType,x
  cmp 0
  bne :+
    iny
  :
  txa
  add #ActorSize
  tax
  cpx #ProjectileEnd
  bne Loop

  plx
  tya
  rtl
.endproc



.export ActorCopyPosXY
.a16
.i16
.proc ActorCopyPosXY
  lda ActorPX,x
  sta ActorPX,y
  lda ActorPY,x
  sta ActorPY,y
  rtl
.endproc

; Removes an actor, and does any cleanup required
.export ActorSafeRemoveX
.a16
.i16
.proc ActorSafeRemoveX
  ; Can put a deconstructor call here, or make it deallocate resources
  stz ActorType,x
  rtl
.endproc

.export ActorSafeRemoveY
.proc ActorSafeRemoveY
  phx
  tyx
  jsl ActorSafeRemoveX
  plx
  rtl
.endproc

.a16
.i16
.export InitActorX
.proc InitActorX
  ; You could insert something here that calls a constructor of some sort
  ; Fall into UpdateActorSizeX
.endproc
.export UpdateActorSizeX
.proc UpdateActorSizeX
  phx
  phy
  txy
  lda ActorType,x
  tax
  lda f:ActorWidthTable,x
  sta ActorWidth,y
  lda f:ActorHeightTable,x
  sta ActorHeight,y
  ply
  plx
  rtl
.endproc

.a16
.i16
.export InitActorY
.proc InitActorY
  ; You could insert something here that calls a constructor of some sort
  ; Fall into UpdateActorSizeY
.endproc
.export UpdateActorSizeY
.proc UpdateActorSizeY
  phx
  phy
  tyx
  lda ActorType,x
  tax
  lda f:ActorWidthTable,x
  sta ActorWidth,y
  lda f:ActorHeightTable,x
  sta ActorHeight,y
  ply
  plx
  rtl
.endproc

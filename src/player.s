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
.include "actorenum.s"
.include "../audio/gss_enum.s"
.smart

.import BlockRunInteractionAbove, BlockRunInteractionBelow
.import BlockRunInteractionSide,  BlockRunInteractionInsideHead
.import BlockRunInteractionInsideBody
.import InitActorX

.segment "ZEROPAGE"

.segment "C_Player"
.importzp SlopeBCC, SlopeBCS
.import SlopeHeightTable, SlopeFlagTable

PLAYER_WALK_SPEED = 2
PLAYER_RUN_SPEED = 3

.a16
.i16
.proc RunPlayer
Temp = 2
SideXPos = 8
BottomCmp = 8

SlopeY = 6
MaxSpeedLeft = 10
MaxSpeedRight = 12
  phk
  plb

  seta8
  countdown JumpGracePeriod
  countdown PlayerWantsToJump
  countdown PlayerWantsToAttack
  countdown PlayerJumpCancelLock
  countdown PlayerOnLadder
  countdown PlayerInvincible
  countdown PlayerWalkLock
  stz PlayerOnSlope

  lda keynew
  and #KEY_X|KEY_R
  beq :+
    lda #3
    sta PlayerWantsToAttack
  :

  ; Start off an attack
  lda PlayerWantsToAttack
  beq NoAttack
    stz PlayerWantsToAttack

    seta16
    jsl FindFreeProjectileX
    bcc :+
      lda #Actor::PlayerProjectile*2
      sta ActorType,x
      jsl InitActorX

      stz ActorProjectileType,x
      stz ActorTimer,x

      lda PlayerPX
      sta ActorPX,x
      lda PlayerPY
      sub #10*16
      sta ActorPY,x

      lda #$30
      jsl PlayerNegIfLeft
      sta ActorVX,x
    :
    seta8
  NoAttack:

  lda ForceControllerTime
  beq :+
     seta16
     lda ForceControllerBits
     tsb keydown
     seta8

     dec ForceControllerTime
     bne @NoCancelForce
       stz ForceControllerBits+0
       stz ForceControllerBits+1
     @NoCancelForce:
  :

  lda keydown+1
  and #>KEY_DOWN
  beq NotDown
    lda PlayerDownTimer
    cmp #60
    bcs YesDown
    inc PlayerDownTimer
    bne YesDown
  NotDown:
    stz PlayerDownTimer
  YesDown:

  lda keynew+1
  and #(KEY_B>>8)
  beq :+
    lda #3
    sta PlayerWantsToJump
  :

  ; Horizontal movement

  ; Calculate max speed from whether they're running or not
  ; (Updated only when on the ground)

  lda PlayerWasRunning ; nonzero = B button, only updated when on ground
  seta16
  beq :+
    lda #.loword(-(PLAYER_RUN_SPEED*16)-1)
    sta MaxSpeedLeft
    lda #PLAYER_RUN_SPEED*16
    sta MaxSpeedRight
    bra NotWalkSpeed
: lda #.loword(-(PLAYER_WALK_SPEED*16)-1)
  sta MaxSpeedLeft
  lda #PLAYER_WALK_SPEED*16
  sta MaxSpeedRight
NotWalkSpeed:

  ; Handle left and right
  lda keydown
  and #KEY_LEFT
  beq NotLeft
  lda ForceControllerBits
  and #KEY_RIGHT
  bne NotLeft
    seta8
    lda #1
    sta PlayerDir
    seta16
    lda PlayerVX
    bpl :+
    cmp MaxSpeedLeft ; can be either run speed or walk speed
    bcc NotLeft
    cmp #.lobyte(-PLAYER_RUN_SPEED*16-1)
    bcc NotLeft
:   sub #3 ; Acceleration speed
    sta PlayerVX
NotLeft:

  lda keydown
  and #KEY_RIGHT
  beq NotRight
  lda ForceControllerBits
  and #KEY_LEFT
  bne NotRight
    seta8
    stz PlayerDir
    seta16
    lda PlayerVX
    bmi :+
    cmp MaxSpeedRight ; can be either run speed or walk speed
    bcs NotRight
    cmp #PLAYER_RUN_SPEED*16
    bcs NotRight
:   add #3 ; Acceleration speed
    sta PlayerVX
NotRight:
NotWalk:

  ; Decelerate
  lda #4
  sta Temp

  ; Don't decelerate if pushing in the direction you're moving
  lda keydown
  and #KEY_LEFT
  beq :+
    lda PlayerVX
    bmi IsMoving
  :
  lda keydown
  and #KEY_RIGHT
  beq :+
    lda PlayerVX
    beq Stopped
    bpl IsMoving
  :
DecelerateAnyway:
  lda PlayerVX
  beq Stopped
    ; If negative, make positive
    php ; Save if it was negative
    bpl :+
      eor #$ffff
      ina
    :

    sub Temp ; Deceleration speed
    bpl :+
      tdc ; Clear accumulator
    :

    ; If negative, make negative again
    plp
    bpl :+
      eor #$ffff
      ina
    :

    sta PlayerVX
Stopped:
IsMoving:

   ; Another deceleration check; apply if you're moving faster than the max speed
   lda PlayerVX
   php
   bpl :+
     eor #$ffff
     ina
   :
   cmp MaxSpeedRight
   beq NoFixWalkSpeed ; If at or less than the max speed, don't fix
   bcc NoFixWalkSpeed
   sub #4
NoFixWalkSpeed:
   plp
   bpl :+
     eor #$ffff
     ina
   :
   sta PlayerVX


  ; Apply speed
  lda PlayerPX
  add PlayerVX
  sta PlayerPX


  ; Going downhill requires special help
  seta8
  lda PlayerOnGround ; Need to have been on ground last frame
  beq NoSlopeDown
  lda PlayerWantsToJump
  bne NoSlopeDown
  seta16
  lda PlayerVX     ; No compensation if not moving
  beq NoSlopeDown
    jsr GetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr GetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta PlayerPY
    stz PlayerVY
  NoSlopeDown:
  seta16

  ; Check for moving into a wall on the right
  lda PlayerVX
  bmi SkipRight
  lda PlayerPX
  add #3*16
  sta SideXPos

  ; Right middle
  lda PlayerPY
  sub #12*16
  tay
  lda SideXPos
  jsr TryRightInteraction
  ; Right head
  lda PlayerPY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TryRightInteraction
SkipRight:

  ; -------------------------

  lda PlayerVX
  beq :+
  bpl SkipLeft
:
  ; Check for moving into a wall on the left
  lda PlayerPX
  sub #4*16
  sta SideXPos

  ; Left middle
  lda PlayerPY
  sub #12*16
  tay
  lda SideXPos
  jsr TryLeftInteraction
  ; Left head
  lda PlayerPY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TryLeftInteraction
SkipLeft:

  ; -------------------  

  lda PlayerOnLadder
  and #255
  bne HandleLadder

  ; Vertical movement
  lda PlayerVY
  bmi GravityAddOK
  cmp #$60
  bcs SkipGravity
GravityAddOK:
  add #4
  sta PlayerVY
SkipGravity:
  add PlayerPY ; Apply the vertical speed
  sta PlayerPY
SkipApplyGravity:
  jmp PlayerIsntOnLadder

HandleLadder:
  stz PlayerVY
  jsr OfferJump
  lda keydown
  and #KEY_UP
  beq :+
    lda PlayerPY
    sub #$20
    sta PlayerPY
  :
  lda keydown
  and #KEY_DOWN
  beq :+
    lda PlayerPY
    add #$20
    sta PlayerPY
  :
  lda PlayerPY
  sta PlayerCameraTargetY
PlayerIsntOnLadder:


  ; Allow canceling a jump
  lda PlayerVY
  bpl :+
    seta8
    lda PlayerJumpCancel
    bne :+
    lda keydown+1
    and #(KEY_B>>8)
    bne :+
      lda PlayerJumpCancelLock ; Set by springs
      bne :+
        inc PlayerJumpCancel

        ; Reduce the jump to a small upward boost
        ; (unless the upward movement is already less than that)
        seta16
        lda PlayerVY
        cmp #.loword(-$20)
        bcs :+
        lda #.loword(-$20)
        sta PlayerVY
  :

  ; Cancel the jump cancel
  seta8
  lda PlayerOnGround
  sta PlayerOnGroundLast
  stz PlayerOnGround
  lda PlayerJumpCancel
  beq :+
    lda PlayerVY+1
    sta PlayerJumpCancel
  :
  seta16

  ; Collide with the ground
  ; (Determine if solid all must be set, or solid top)
  lda #$8000
  sta BottomCmp
  lda PlayerOnLadder ; On a ladder, one-way platforms are still solid below you
  and #255
  bne LadderDropThroughFix
  lda PlayerVY ; When not on a ladder, it's determined by the player's vertical speed
  bmi :+
    seta8
    stz PlayerJumping
    seta16
    lda PlayerPY
    and #$80
    bne :+
LadderDropThroughFix:
      lda #$4000
      sta BottomCmp
  :

  ; Slope interaction
  jsr GetSlopeYPos
  bcc NoSlopeInteraction
    lda SlopeY
    cmp PlayerPY
    bcs NoSlopeInteraction
    
    sta PlayerPY
    sta PlayerCameraTargetY
    stz PlayerVY

    ; Some unnecessary shifting, since this was previously shifted left
    ; and we're just undoing it, but the alternative is probably storing
    ; to PlayerSlopeType in every IsSlope call and I'd rather not.
    txa
    lsr
    lsr
    lsr
    lsr
    and #.loword(~1)
    sta PlayerSlopeType

    seta8
    inc PlayerOnSlope
    inc PlayerOnGround
    seta16

    ; Don't do the normal ground check
    bra SkipGroundCheck
  NoSlopeInteraction:

  lda PlayerVY
  bmi :+
  ; Left foot
  ldy PlayerPY
  lda PlayerPX
  sub #4*16
  jsr TryAboveInteraction
  ; Right foot
  ldy PlayerPY
  lda PlayerPX
  add #3*16
  jsr TryAboveInteraction
:
SkipGroundCheck:

  ; Above
  lda PlayerPY
  sub #PlayerHeight
  sta PlayerPYTop     ; Used in collision detection with enemies
  tay
  lda PlayerPX
  jsr TryBelowInteraction

  ; Inside
  lda PlayerPY
  sub #8*16
  tay
  lda PlayerPX
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionInsideBody

  ; ----------------------------------------
  ; Precompute collision detection variables
  lda PlayerPX
  sub #PlayerCollideWidth/2
  sta PlayerPXLeft
  lda PlayerPX
  add #PlayerCollideWidth/2
  sta PlayerPXRight

  ; -------------------
  
  ; Offer a jump if not on ground and the grace period is still active
  seta8
  lda PlayerOnGround
  bne :+
  lda JumpGracePeriod
  beq :+
    seta16
    jsr OfferJumpFromGracePeriod
  :
  seta16

  ; If on the ground, offer a jump
  seta8
  stz PlayerRidingSomething
  lda PlayerOnGround
  seta16
  beq @NotOnGround
    jsr OfferJump

    seta8
    lda keydown+1
    and #>KEY_Y
    sta PlayerWasRunning
    seta16
  @NotOnGround:
  rtl

TryBelowInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionBelow

  lda BlockFlag
  bpl @NotSolid
    lda PlayerVY
    bpl :+
      stz PlayerVY
    :

    lda PlayerPY
    and #$ff00
    ora #14*16
    sta PlayerPY
  @NotSolid:
  rts

TryAboveInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionAbove
  ; Solid?
  lda BlockFlag
  cmp BottomCmp
  bcc @NotSolidOnTop
    lda #$00ff
    trb PlayerPY
@HasGroundAfterAll:
    stz PlayerVY

    lda PlayerRidingSomething
    and #255
    cmp #RIDING_NO_PLATFORM_SNAP
    bne :+
      lda PlayerPY
      sta PlayerCameraTargetY
    :

    seta8
    inc PlayerOnGround
    stz PlayerOnLadder
    seta16
    rts
  @NotSolidOnTop:

  ; Riding on something forces it to act like you are standing on solid ground
  lda PlayerRidingSomething
  and #255
  bne @HasGroundAfterAll
  rts

TryLeftInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    ; Left
    lda PlayerPX
    sub PlayerVX ; Undo the horizontal movement
    and #$ff00   ; Snap to the block
    add #4*16    ; Add to the offset to press against the block
    sta PlayerPX
    stz PlayerVX ; Stop moving horizontally
  @NotSolid:
  rts

TryRightInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    ; Right
    lda PlayerPX
    sub PlayerVX  ; Undo the horizontal movement
    and #$ff00    ; Snap to the block
    add #12*16+12 ; Add the offset to press against the block
    sta PlayerPX
    stz PlayerVX  ; Stop moving horizontally
  @NotSolid:
  rts


.a16
; Get the Y position of the slope under the player's hotspot (SlopeY)
; and also return if they're on a slope at all (carry)
GetSlopeYPos:
  ldy PlayerPY
  lda PlayerPX
  jsl GetLevelPtrXY
  jsr IsSlope
  bcc NotSlope
    lda PlayerPY
    and #$ff00
    ora f:SlopeHeightTable,x
    sta SlopeY

    lda f:SlopeHeightTable,x
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr IsSlope
      bcc :+
        lda PlayerPY
        sbc #$0100 ; assert((PS & 1) == 1) Carry already set
        ora f:SlopeHeightTable,x
        sta SlopeY
    :
  sec
NotSlope:
  rts

.a16
; Similar but for checking one block below
GetSlopeYPosBelow:
  jsr IsSlope
  bcc NotSlope
    lda PlayerPY
    add #$0100
    and #$ff00
    ora f:SlopeHeightTable,x
    sta SlopeY

    lda f:SlopeHeightTable,x
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr IsSlope
      bcc :+
        lda PlayerPY
        ora f:SlopeHeightTable,x
        sta SlopeY
    :
  sec
  rts

.a16
; Determine if it's a slope (carry),
; but also determine the index into the height table (X)
IsSlope:
  cmp #SlopeBCC
  bcc :+
  cmp #SlopeBCS
  bcs :+
  sub #SlopeBCC
  ; Now we have the block ID times 2

  ; Multiply by 16 to get the index into the slope height table
  asl
  asl
  asl
  asl
  sta 0

  ; Select the column
  lda PlayerPX
  and #$f0 ; Get the pixels within a block
  lsr
  lsr
  lsr
  ora 0
  tax

  sec ; Success
  rts
: clc ; Failure
  rts

; Let the player jump if they press the button
.a16
OfferJump:
  seta8
  lda #7 ;JUMP_GRACE_PERIOD_LENGTH
  sta JumpGracePeriod
  seta16
OfferJumpFromGracePeriod:
  ; Newly pressed jump, either now or a few frames before
  lda PlayerWantsToJump
  and #255
  beq :+
  ; Still pressing the jump button
  lda keydown
  and #KEY_B
  beq :+
    seta8
    stz PlayerOnLadder
    stz JumpGracePeriod
    lda #1
    sta PlayerJumping

    ; Play the sound effect
    lda #255
    sta APU1 ; Volume
    lda #SoundEffect::jump
    sta APU2 ; Effect number
    lda #128
    sta APU3 ; Pan
    lda #GSS_Commands::SFX_PLAY|$70
    sta APU0

    seta16
    lda #.loword(-$60)
    sta PlayerVY
  :
  rts
.endproc

; Damages the player
.export HurtPlayer
.proc HurtPlayer
  php
  seta8
  lda PlayerHealth
  beq :+
  lda PlayerInvincible
  bne :+
    dec PlayerHealth
    lda #160
    sta PlayerInvincible


    ; Play the sound effect
    lda #255
    sta APU1 ; Volume
    lda #SoundEffect::hurt
    sta APU2 ; Effect number
    lda #128
    sta APU3 ; Pan
    lda #GSS_Commands::SFX_PLAY|$80
    sta APU0
  :
  plp
  rtl
.endproc

; Takes a speed in the accumulator, and negates it if player facing left
.a16
.export PlayerNegIfLeft
.proc PlayerNegIfLeft
  pha
  lda PlayerDir ; Ignore high byte
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

.a16
.i16
.export FindFreeProjectileX
.proc FindFreeProjectileX
  phy
  lda #ProjectileStart
  clc
Loop:
  tax
  ldy ActorType,x ; Don't care what gets loaded into Y, but it will set flags
  beq Found
  adc #ActorSize
  cmp #ProjectileEnd ; Carry should always be clear at this point
  bcc Loop
NotFound:
  ply
  clc
  rtl
Found:
  ply
  sec
  rtl
.endproc

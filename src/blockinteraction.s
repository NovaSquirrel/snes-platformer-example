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

; This file covers code to handle interacting with level blocks
; in different ways. These interactions are listed in blocks.txt

.include "snes.inc"
.include "global.inc"
.include "blockenum.s"
.include "actorenum.s"
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.segment "C_BlockInteraction"

.export BlockHeart, BlockSmallHeart
.export BlockMoney, BlockPrize, BlockBricks
.export BlockSpikes, BlockSpring, BlockLadder, BlockLadderTop
.export BlockFallthrough, BlockDoor

; Export the interaction runners
.export BlockRunInteractionAbove, BlockRunInteractionBelow
.export BlockRunInteractionSide, BlockRunInteractionInsideHead
.export BlockRunInteractionInsideBody, BlockRunInteractionActorInside
.export BlockRunInteractionActorTopBottom, BlockRunInteractionActorSide

; .-------------------------------------
; | Runners for interactions
; '-------------------------------------

.a16
.i16
.import BlockInteractionAbove
.proc BlockRunInteractionAbove
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionAbove),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionBelow
.proc BlockRunInteractionBelow
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionBelow),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionSide
.proc BlockRunInteractionSide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionSide),x)
  plb
Skip:
  rtl
.endproc


.a16
.i16
.import BlockInteractionInsideHead
.proc BlockRunInteractionInsideHead
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionInsideHead),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionInsideBody
.proc BlockRunInteractionInsideBody
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionInsideBody),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionActorInside
.proc BlockRunInteractionActorInside
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionActorInside),x)
  plb
Skip:
  rtl
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionActorTopBottom
.proc BlockRunInteractionActorTopBottom
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionActorTopBottom,y
  jsr Call
  plb
Skip:
  rtl

Call: ; Could use the RTS trick here instead
  sta TempVal
  jmp (TempVal)
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionActorSide
.proc BlockRunInteractionActorSide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionActorSide,y
  jsr BlockRunInteractionActorTopBottom::Call
  plb
Skip:
  rtl
.endproc




; -------------------------------------

.proc BlockAutoItem
  rts
.endproc

.proc BlockInventoryItem
  rts
.endproc

.proc BlockHeart
  seta8
  ; Play the sound effect
  lda #SFX::collect_item
  jsl PlaySoundEffect

  lda PlayerHealth
  cmp #4
  bcs Full
    lda #4
    sta PlayerHealth
    seta16
    lda #Block::Empty
    jsl ChangeBlock
  Full:
  seta16
  rts
.endproc

.proc BlockSmallHeart
  seta8
  ; Play the sound effect
  lda #SFX::collect_item
  jsl PlaySoundEffect

  lda PlayerHealth
  cmp #4
  bcs Full
    inc PlayerHealth
    seta16
    lda #Block::Empty
    jsl ChangeBlock
  Full:
  seta16
  rts
.endproc

.export GetOneCoin
.proc GetOneCoin
  ; Don't add coins if you have the maximum amount already
  seta8
  ; Play the sound effect
  lda #SFX::collect_coin
  jsl PlaySoundEffect

  lda MoneyAmount+2
  cmp #$09
  bcc OK
  lda #$99
  cmp MoneyAmount+1
  bne OK
  cmp MoneyAmount+0
  beq Skip
OK:
  sed
  lda MoneyAmount
  add #1
  sta MoneyAmount
  lda MoneyAmount+1
  adc #0
  sta MoneyAmount+1
  lda MoneyAmount+2
  adc #0
  sta MoneyAmount+2
  cld
Skip:
  seta16
  rtl
.endproc

.proc BlockMoney
  jsl GetOneCoin

  lda #Block::Empty
  jsl ChangeBlock

  rts
.endproc

.a16
.proc PoofAtBlock
  ; Need a free slot first
  jsl FindFreeParticleY
  bcs :+
    rts
  :
  lda #Particle::Poof
  sta ParticleType,y

  ; Position it where the block is
  jsl GetBlockXCoord
;  ora #$80 <-- was $80 for BlockPushForwardCleanup - why?
  ora #$40 ; <-- Cancels out offset in object.s ParticleDrawPosition - maybe just not have the offset?
  sta ParticlePX,y

  ; For a 16x16 particle
  jsl GetBlockYCoord
  ora #$40
  sta ParticlePY,y
  rts
.endproc


.a16
.proc BlockPrize
  jsl GetOneCoin

  lda #Block::PrizeAnimation
  jsl ChangeBlock

  lda #5
  sta BlockTemp
  lda #Block::UsedPrize
  jsl DelayChangeBlock

  jsl FindFreeParticleY
  bcc :+
    lda #Particle::PrizeParticle
    sta ParticleType,y
    lda #30
    sta ParticleTimer,y
    lda #.loword(-$30)
    sta ParticleVY,y

    jmp ParticleAtBlock
  :
  rts
.endproc

.proc BlockBricks
  seta8
  ; Play the sound effect
  lda #SFX::brick_break
  jsl PlaySoundEffect
  seta16

  lda #Block::Empty
  jsl ChangeBlock
  jsr PoofAtBlock
  rts
.endproc

.proc BlockSpikes
  .import HurtPlayer
  jsl HurtPlayer
  rts
.endproc

.proc BlockSpring
  ; Start sending the player upward
  lda #.loword(-$70)
  sta PlayerVY

  ; Move the player up a bit so that they're not stuck in the ground
  lda PlayerPY
  sub #4*16
  sta PlayerPY

  lda PlayerPY
  sub #4*256
  cmp PlayerCameraTargetY
  bcs :+
    sta PlayerCameraTargetY
  :

  seta8
  ; Play the sound effect
  lda #SFX::spring
  jsl PlaySoundEffect

  lda #30
  sta PlayerJumpCancelLock
  sta PlayerJumping
  seta16

  ; Animate the spring changing
  ; but only if the spring isn't scheduled to disappear before it'd pop back up
  jsr FindDelayedEditForBlock
  bcc :+
    lda DelayedBlockEditTime,x
    cmp #6
    bcc DontSpringUp
  :

  ; No problems? Go ahead and schedule it
  lda #5
  sta BlockTemp
  lda #Block::Spring
  jsl DelayChangeBlock

  lda #2
  sta BlockTemp
  lda #Block::SpringPressedHalf
  jsl DelayChangeBlock

DontSpringUp:

  lda #Block::SpringPressed
  jsl ChangeBlock

  stz BlockFlag
  rts
.endproc

.a16
.proc BlockLadder
  seta8
  lda PlayerOnLadder
  beq :+
    inc PlayerOnLadder
  :
  lda PlayerRidingSomething
  bne Exit
  seta16

  lda keydown
  and #KEY_UP|KEY_DOWN
  beq :+
GetOnLadder:
    ; Snap onto the ladder
    lda PlayerPX
    and #$ff00
    ora #$0080
    sta PlayerPX
    stz PlayerVX

    seta8
    lda #2
    sta PlayerOnLadder
Exit:
    seta16
  :
  rts
.endproc

.a16
.proc BlockLadderTop
  ; Make sure you're standing on it
  jsl GetBlockXCoord
  xba
  seta8
  cmp PlayerPX+1
  seta16
  beq :+
    rts
  :

  seta8
  lda PlayerDownTimer
  cmp #4
  bcc :+
    lda #2
    sta ForceControllerTime
    seta16
    lda #KEY_DOWN
    sta ForceControllerBits
    stz BlockFlag
    jmp BlockLadder::GetOnLadder
  :
  seta16
  rts
.endproc

.a16
.proc BlockFallthrough
  seta8
  lda PlayerDownTimer
  cmp #16
  bcc :+
    lda #2
    sta ForceControllerTime
    seta16
    lda #KEY_DOWN
    sta ForceControllerBits
    stz BlockFlag
  :
  seta16
  rts
.endproc

.a16
.proc ParticleAtBlock
  jsl GetBlockXCoord
  ora #$80
  sta ParticlePX,y

  jsl GetBlockYCoord
  ora #$80
  sta ParticlePY,y
  rts
.endproc

.a16
.export BlockRedKey
.proc BlockRedKey
  seta8
  inc RedKeys
  lda #SFX::collect_item
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.export BlockRedLock
.proc BlockRedLock
  lda RedKeys
  beq NoKeys
  seta8
  dec RedKeys
  lda #SFX::menu_select
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
NoKeys:
  rts
.endproc

.a16
.export BlockGreenKey
.proc BlockGreenKey
  seta8
  inc GreenKeys
  lda #SFX::collect_item
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.export BlockGreenLock
.proc BlockGreenLock
  lda GreenKeys
  beq NoKeys
  seta8
  dec GreenKeys
  lda #SFX::menu_select
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
NoKeys:
  rts
.endproc

.a16
.export BlockBlueKey
.proc BlockBlueKey
  seta8
  inc BlueKeys
  lda #SFX::collect_item
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.export BlockBlueLock
.proc BlockBlueLock
  lda BlueKeys
  beq NoKeys
  seta8
  dec BlueKeys
  lda #SFX::menu_select
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
NoKeys:
  rts
.endproc

.a16
.export BlockYellowKey
.proc BlockYellowKey
  seta8
  inc YellowKeys
  lda #SFX::collect_item
  jsl PlaySoundEffect
  seta16
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.export BlockYellowLock
.proc BlockYellowLock
  lda YellowKeys
  beq NoKeys
  seta8
  dec YellowKeys
  seta16
  lda #Block::Empty
  jsl ChangeBlock
NoKeys:
  rts
.endproc



.a16
.i16
.proc BlockDoor
.if 0
  lda keynew
  and #KEY_UP
  bne Up
  rts
Up:
  dec LevelBlockPtr
  dec LevelBlockPtr
  lda [LevelBlockPtr]
  cmp #Block::DoorExit
  beq DoorExit
DoorNormal:
  jsl GetBlockX
  bra TeleportAtColumn
DoorExit:
  .import ExitToOverworld
  jsr DoorFade
  jsl WaitVblank
  rts
;  jml ExitToOverworld
.endif
  rts
.endproc

.a16
.i16
.proc TeleportAtColumn
  rts
.if 0
  asl
  tax
  seta8
  lda f:ColumnWords+0,x
  cmp #$20
  beq LevelDoor
    sta PlayerPY+1
    lda f:ColumnWords+1,x
    sta PlayerPX+1
    lda #$80        ; Horizontally centered
    sta PlayerPX
    stz PlayerPY
    stz LevelFadeIn ; Start fading in after the transition

    jsr DoorFade

    lda #RERENDER_INIT_ENTITIES_TELEPORT
    sta RerenderInitEntities

    seta16

    jsl RenderLevelScreens
    rts
LevelDoor:
  lda f:ColumnWords+1,x
  pha
  jsr DoorFade
  pla

  ; Find the level header pointer
  setaxy16
  and #255 ; Multiply by 3
  sta 0
  asl
  adc 0 ; assert((PS & 1) == 0) Carry will be clear
  tax
  seta8
;  .import DoorLevelTeleportList
;  ; Use DoorLevelTeleportList to find the header
;  lda DoorLevelTeleportList+0,x
;  sta LevelHeaderPointer+0
;  lda DoorLevelTeleportList+1,x
;  sta LevelHeaderPointer+1
;  lda DoorLevelTeleportList+2,x
;  sta LevelHeaderPointer+2
  setaxy16

  .import StartLevelFromDoor
  jml StartLevelFromDoor
.endif
.endproc

.proc DoorFade
  seta8
  ; Fade the screen out and then disable rendering once it's black
  lda #$0e
  sta 15
FadeOut:
  inc framecount
  lda PlayerDrawX
  sta 0
  lda PlayerDrawY
  sub #16
  sta 1
  lda 15
  jsl WaitVblank
  seta8
  lda HDMASTART_Mirror
  sta HDMASTART

  lda 15
  sta PPUBRIGHT
  dec
  sta 15
  bne FadeOut

  lda #FORCEBLANK
  sta PPUBRIGHT
  rts
.endproc

.proc FindDelayedEditForBlock
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Only delayed blocks with nonzero timers are valid slots
  lda DelayedBlockEditTime,x
  beq :+
    ; Is it this block?
    lda DelayedBlockEditAddr,x
    cmp LevelBlockPtr
    beq Yes
: dex
  dex
  bpl DelayedBlockLoop
  clc
  rts
Yes:
  sec
  rts
.endproc


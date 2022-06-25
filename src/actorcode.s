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
.include "actorenum.s"
.include "blockenum.s"
.smart

.segment "C_ActorData"
CommonTileBase = $40

.import DispActor16x16, DispActor8x8, DispParticle8x8, DispActor8x8WithOffset
.import DispParticle16x16
.import DispActorMeta, DispActorMetaRight, DispActorMetaPriority2
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorAutoBump, ActorApplyXVelocity
.import ActorTurnAround, ActorSafeRemoveX, ActorWalkIgnoreState
.import ActorHover, ActorRoverMovement, CountActorAmount, ActorCopyPosXY, ActorClearY
.import PlayerActorCollision, TwoActorCollision, PlayerActorCollisionMultiRect
.import PlayerActorCollisionHurt, ActorLookAtPlayer
.import FindFreeProjectileY, ActorApplyVelocity, ActorGravity
.import ActorNegIfLeft, AllocateDynamicSpriteSlot, ActorAdvertiseMe, ActorCanBeCarried
.import GetAngle512
.import ActorTryUpInteraction, ActorTryDownInteraction, ActorBumpAgainstCeiling
.import InitActorX, UpdateActorSizeX, InitActorY, UpdateActorSizeY


.a16
.i16
.export DrawLedgeWalker
.proc DrawLedgeWalker
  lda framecount
  lsr
  lsr
  and #2
  add #(3*2)|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunLedgeWalker
.proc RunLedgeWalker
  lda #$10
  jsl ActorWalkOnPlatform
  jsl ActorFall
  jml PlayerActorCollisionHurt
.endproc

.i16
.export DrawMovingPlatform
.proc DrawMovingPlatform
  rtl
;  lda #$40|OAM_PRIORITY_2
;  sta SpriteTileBase
;  lda #.loword(Platform)
;  sta DecodePointer
;  jml DispActorMetaRight

;Platform:
;  Row8x8   -12,0,  $00, $10, $10, $01
;  EndMetasprite
.endproc

; Move a moving platform back and forth (or at least move ActorVX back and forth)
; with a smoothed turnaround at the end.
.a16
.proc MovingPlatformBackAndForth
  lda ActorDirection,x
  and #1
  asl
  tay

  ; Accelerate toward the desired speed if not already there
  lda ActorVX,x
  cmp Target,y
  beq Already
    add StepToTarget,y
    sta ActorVX,x
    rts
Already:
  ; Keep track of how many pixels have been traveled
  inc ActorTimer,x

  ; VarA = amount of blocks to travel before turning around
  lda ActorVarA,x
  ina
  asl
  asl
  asl
  asl
  cmp ActorTimer,x
  bne :+
    stz ActorTimer,x      ; Reset the timer
    lda ActorDirection,x  ; Flip around
    eor #1
    sta ActorDirection,x
  :
  rts

Target:
  .word $10, .loword(-$10)
StepToTarget:
  .word 1, .loword(-1)
.endproc

; Move a moving platform forward with a given offset (A=horizontal, Y=vertical)
.a16
.proc MoveMovingPlatform
  sta 0
  sty 2

  ; Calculate the new Y ahead of time
  lda ActorPY,x
  add 2
  sta 4

  ; Only move the player with the platform if they're standing on it
  lda PlayerPY
  cmp ActorPY,x
  bcs NoRide
  jsl CollideRide
  bcc NoRide
    lda PlayerPX
    add 0
    sta PlayerPX

    ; Put player on top and zero out vertical movement
    lda 4
    sub #$70
    sta PlayerPY
    stz PlayerVY

    seta8
    lda #RIDING_NO_PLATFORM_SNAP
    sta PlayerRidingSomething
    sta ActorVY,x ; Store something nonzero here to indicate the player has touched the platform
    seta16
  NoRide:

  ; Always move the platform
  lda ActorPX,x
  add 0
  sta ActorPX,x
  ;---
  lda 4
  sta ActorPY,x
  rts
.endproc

.a16
.export RunMovingPlatformHorizontal
.proc RunMovingPlatformHorizontal
  jsr MovingPlatformBackAndForth
  lda ActorVX,x
  ldy #0
  jsr MoveMovingPlatform
  rtl
.endproc

.a16
.export RunMovingPlatformVertical
.proc RunMovingPlatformVertical
  jsr MovingPlatformBackAndForth
  tdc ; Clear accumulator
  ldy ActorVX,x
  jsr MoveMovingPlatform
  rtl
.endproc

.a16
.i16
.export DrawWalker
.proc DrawWalker
  lda retraces
  lsr
  lsr
  and #2
  add #2*3
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunWalker
.proc RunWalker
  lda #20
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawJumper
.proc DrawJumper
  lda retraces
  lsr
  lsr
  and #2
  add #2*3
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunJumper
.proc RunJumper
  lda #20
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawShooter
.proc DrawShooter
  lda retraces
  lsr
  lsr
  and #2
  add #2*3
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunShooter
.proc RunShooter
  lda #20
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall

  jml PlayerActorCollisionHurt
.endproc


.a16
.i16
.export RunEnemyBullet
.proc RunEnemyBullet
  jsr ActorExpire
  jsl ActorApplyXVelocity  
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawEnemyBullet
.proc DrawEnemyBullet
  lda #12+OAM_PRIORITY_2
  jml DispActor8x8
.endproc

; -------------------------------------
; Maybe move particles to a separate file, though we don't have many yet
.pushseg
.segment "C_ParticleCode"
.a16
.i16
.export DrawPoofParticle
.proc DrawPoofParticle
  lda ParticleTimer,x
  lsr
  and #%110
  ora #CommonTileBase+$20+OAM_PRIORITY_2
  jsl DispParticle16x16
  rts
.endproc

.a16
.i16
.export RunPoofParticle
.proc RunPoofParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #4*3
  bne :+
    stz ParticleType,x
  :
  rts
.endproc


.a16
.i16
.export DrawLandingParticle
.proc DrawLandingParticle
  lda ParticleTimer,x
  lsr
  lsr
  lsr
  add #CommonTileBase+$38+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunLandingParticle
.proc RunLandingParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #8*2
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawPrizeParticle
.proc DrawPrizeParticle
  lda #CommonTileBase+$28+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunPrizeParticle
.proc RunPrizeParticle
  lda ParticlePX,x
  add ParticleVX,x
  sta ParticlePX,x

  lda ParticleVY,x
  add #4
  sta ParticleVY,x
  add ParticlePY,x
  sta ParticlePY,x

  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export RunParticleDisappear
.proc RunParticleDisappear
  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawSmokeParticle
.proc DrawSmokeParticle
  jsl RandomByte
  and #$11
  sta 0
  jsl RandomByte
  xba
  and #OAM_XFLIP|OAM_YFLIP
  ora 0
  ora #CommonTileBase+$26+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc



.a16
.i16
.export DrawBricksParticle
.proc DrawBricksParticle
  lda #CommonTileBase+$3c+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export DrawGrayBricksParticle
.proc DrawGrayBricksParticle
  lda #CommonTileBase+$3b+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunBricksParticle
.proc RunBricksParticle
  lda ParticlePX,x
  add ParticleVX,x
  sta ParticlePX,x

  lda ParticleVY,x
  add #4
  sta ParticleVY,x
  add ParticlePY,x
  sta ParticlePY,x
  cmp #256*32
  bcs Erase
  dec ParticleTimer,x
  bne :+
Erase:
    stz ParticleType,x
  :

.if 0
  lda ParticlePX,x
  ldy ParticlePY,x
  phx
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  plx  
  cmp #$4000
  bcc :+
    lda ParticleVY,x
    lsr
    eor #$ffff
    inc a
    sta ParticleVY,x
  :
.endif

  rts
.endproc
.popseg


; Check for collision with a rideable 16x16 thing
.a16
.i16
.export CollideRide
.proc CollideRide
  ; Check for collision with player
  lda PlayerVY
  bpl :+
  clc
  rtl
: jml PlayerActorCollision
.endproc

.export ActorExpire
.proc ActorExpire
  dec ActorTimer,x
  bne :+
    jsl ActorSafeRemoveX
  :
  rts
.endproc

.a16
.export ActorBecomePoof
.proc ActorBecomePoof
  jsl ActorSafeRemoveX
  jsl FindFreeParticleY
  bcc Exit
    lda #Particle::Poof
    sta ParticleType,y
    lda ActorWidth,x
    lsr
    rsb ActorPX,x
    add #4*16
    sta ParticlePX,y
    lda ActorPY,x
    sub ActorHeight,x
    add #4*16
    sta ParticlePY,y
Exit:
  rtl
.endproc

.a16
.proc ActorMakePoofAtOffset
  jsl FindFreeParticleY
  bcc Exit
    lda #Particle::Poof
    sta ParticleType,y
    lda ActorPX,x
    add 0
    sta ParticlePX,y
    lda ActorPY,x
    add 2
    sta ParticlePY,y
Exit:
  rtl
.endproc

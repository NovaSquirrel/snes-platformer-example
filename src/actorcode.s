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

; -----------------------------------------------------------------------------
; This file defines the "actors" in the game - which may be enemies, enemy projectiles
; or things like moving platforms. Each actor has a Run routine and a Draw routine and both
; are normally called every frame.

; This separation allows you to call the Draw routine by itself without causing the actor
; to run its logic. This can be useful if you want to run the Run and Draw routines at separate
; times, or if the game design calls for having an actor be drawn but paused - such as if the
; game allowed for picking up and grabbing enemies.

; Actors are defined in actors.txt and tables are automatically put in actordata.s
; via a Python script.

; Most of the actors mostly just call routines from actorshared.s and chain multiple
; simple behaviors together to get something more complicated.

.include "snes.inc"
.include "global.inc"
.include "actorenum.s"
.include "blockenum.s"
.smart

.segment "C_ActorData"

.import DispActor16x16, DispActor8x8, DispActor8x8WithOffset, DispParticle8x8, DispParticle16x16
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorGravity, ActorApplyXVelocity
.import ActorAutoBump, ActorLookAtPlayer, ActorTurnAround
.import PlayerActorCollision, PlayerActorCollisionHurt
.import FindFreeProjectileY, ActorApplyVelocity
.import ActorNegIfLeft
.import ActorTryUpInteraction, ActorTryDownInteraction
.import ActorCopyPosXY, InitActorY, ActorClearY
.import SharedEnemyCommon, SharedRemoveIfFar, ActorSafeRemoveX

.a16
.i16
.export DrawLedgeWalker
.proc DrawLedgeWalker
  lda framecount
  lsr
  lsr
  and #2
  add #($28)|OAM_PRIORITY_2|OAM_COLOR_1
  jml DispActor16x16
.endproc

.a16
.i16
.export RunLedgeWalker
.proc RunLedgeWalker
  lda #$10
  jsl ActorWalkOnPlatform
  jsl ActorFall
  jml SharedEnemyCommon
.endproc

.i16
.export DrawMovingPlatform
.proc DrawMovingPlatform
  ; This routine is hacky and works around not having a more generic actor drawer
  ; routine in the codebase by calling DispActor16x16 twice, with the actor's information
  ; temporarily changed for each call.

  ; Save the direction and change it
  lda ActorDirection,x
  pha
  and #$ff00           ; Clear the direction bit
  sta ActorDirection,x

  ; Save the X position and change it
  lda ActorPX,x
  pha
  sub #8*16
  sta ActorPX,x

  lda #($48)|OAM_PRIORITY_2|OAM_COLOR_1
  jsl DispActor16x16

  lda ActorPX,x
  add #16*16
  sta ActorPX,x

  inc ActorDirection,x ; Set the direction bit, causing a flip
  lda #($48)|OAM_PRIORITY_2|OAM_COLOR_1
  jsl DispActor16x16

  ; Restore the X position and direction
  pla
  sta ActorPX,x
  pla
  sta ActorDirection,x
  rtl
.endproc

; Move a moving platform back and forth with a smoothed turnaround at the end
; with the distance dictated by VarA. The moving platform's intended offset
; is in ActorVX and it can be added to the horizontal/vertical position.
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
  ; so compare ActorTimer to it, to see if it's time yet.
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

Target:       ; Desired speed
  .word $10, .loword(-$10)
StepToTarget: ; What to add to try to reach the target, if not already there
  .word 1, .loword(-1)
.endproc

; Move a moving platform forward with a given offset (A=horizontal, Y=vertical)
; Also handles moving the player along with the platform if they're riding it.
.a16
.proc MoveMovingPlatform
  ; Save the parameters that got passed in
  sta 0
  sty 2

  ; Calculate the new Y ahead of time
  lda ActorPY,x
  add 2
  sta 4

  jsl CollideRide  ; Test for riding on the platform
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
    seta16
  NoRide:

  ; Apply movement to the platform now
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
  ; Apply the back-and-forth movement to horizontal position
  lda ActorVX,x
  ldy #0
  jsr MoveMovingPlatform
  rtl
.endproc

.a16
.export RunMovingPlatformVertical
.proc RunMovingPlatformVertical
  jsr MovingPlatformBackAndForth
  ; Apply the back-and-forth movement to vertical position
  lda #0
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
  add #$20|OAM_PRIORITY_2|OAM_COLOR_1
  jml DispActor16x16
.endproc

.a16
.i16
.export RunWalker
.proc RunWalker
  ; This enemy walks forward, and automatically reverse when it bumps into a wall
  lda #20
  jsl ActorWalk     ; Carry is set if bumping into a wall
  jsl ActorAutoBump ; Turn around if carry is set

  jsl ActorFall

  jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawJumper
.proc DrawJumper
  lda retraces
  lsr
  lsr
  and #2
  add #$60|OAM_PRIORITY_2|OAM_COLOR_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunJumper
.proc RunJumper
  jsl ActorLookAtPlayer
  jsl ActorFall  ; Carry is set if the actor is currently on the ground
  bcc :+         ; and if they are, set the velocity negative to jump into the air!
    lda #.loword(-$50)
    sta ActorVY,x
  :

  jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawShooter
.proc DrawShooter
  lda retraces
  lsr
  lsr
  and #2
  add #$40|OAM_PRIORITY_2|OAM_COLOR_1
  jml DispActor16x16
.endproc

.a16
.i16
.export RunShooter
.proc RunShooter
  jsl ActorLookAtPlayer

  ; Every 64 frames, shoot a projectile
  lda framecount
  and #63
  bne NoShoot
      ; Try to create a new actor - first find a free slot to put it at
      jsl FindFreeActorY
      bcc NoShoot
        ; Place it at this actor's position
        jsl ActorClearY
        jsl ActorCopyPosXY

        ; Have the projectile move in the direction the enemy is facing
        lda #$20
        jsl ActorNegIfLeft
        sta ActorVX,y

        ; Use the bullet
        lda #Actor::EnemyBullet*2
        sta ActorType,y
        jsl InitActorY

        ; How long until the projectile disappears
        lda #32
        sta ActorTimer,y
NoShoot:

  jml SharedEnemyCommon
.endproc


.a16
.i16
.export RunEnemyBullet
.proc RunEnemyBullet
  ; Enemy bullets add the X velocity to their position, and hurt the player.
  ; They also disappear after a certain amount of time.
  jsr ActorExpire
  jsl ActorApplyXVelocity  
  jsl PlayerActorCollisionHurt
  jml SharedRemoveIfFar
.endproc

.a16
.i16
.export DrawEnemyBullet
.proc DrawEnemyBullet
  lda #$46|OAM_PRIORITY_2|OAM_COLOR_1
  jml DispActor8x8
.endproc

; Check for collision with a rideable actor - like a moving platform.
; This is like normal collision detection but it ignores collisions that
; occur when the player is moving upward or if they're below the actor.
.a16
.i16
.export CollideRide
.proc CollideRide
  lda PlayerPY
  cmp ActorPY,x
  bcs NoRide
  lda PlayerVY
  bpl :+
NoRide:
  clc
  rtl
: jml PlayerActorCollision
.endproc

; 
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

; -------------------------------------
; Particles! These are like actors but they don't have as many
; variables. They work the same way with a Run and Draw routine
; and they can call some of the Actor routines.
.pushseg
.segment "C_ParticleCode"
.a16
.i16
.export DrawPoofParticle
.proc DrawPoofParticle
  lda ParticleTimer,x
  lsr
  and #%110
  add #$4a|OAM_PRIORITY_2|OAM_COLOR_1
  jsl DispParticle16x16
  rts
.endproc

.a16
.i16
.export RunPoofParticle
.proc RunPoofParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #4*2
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawPrizeParticle
.proc DrawPrizeParticle
  lda ParticleTimer,x
  lsr
  lsr
  lsr
  and #3
  add #$66|OAM_PRIORITY_2|OAM_COLOR_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunPrizeParticle
.proc RunPrizeParticle
  lda ParticleVY,x
  add #2
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

.popseg

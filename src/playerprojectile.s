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
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.import ActorBecomePoof, ActorTurnAround, TwoActorCollision, DispActor8x8, DispActor8x8WithOffset, DispActor16x16, ActorExpire
.import PlayerActorCollision, ActorApplyVelocity, ActorApplyXVelocity, PlayerNegIfLeft
.import DispParticle8x8

.segment "C_ActorData"
CommonTileBase = $40

.a16
.i16
.export RunPlayerProjectile
.proc RunPlayerProjectile
  lda ActorProjectileType,x
  asl
  tay
  lda RunPlayerProjectileTable,y
  pha
  rts
.endproc

RunPlayerProjectileTable:
  .word .loword(RunProjectileBullet-1)
.a16
.i16
.export DrawPlayerProjectile
.proc DrawPlayerProjectile
  lda ActorProjectileType,x
  asl
  tay
  lda DrawPlayerProjectileTable,y
  pha
  rts
.endproc

DrawPlayerProjectileTable:
  .word .loword(DrawProjectileBullet-1)
.a16
.i16
.proc RunProjectileBullet
  jsl ActorApplyXVelocity

  inc ActorTimer,x
  lda ActorTimer,x
  cmp #50
  bne :+
    stz ActorType,x
  :
  rtl
.endproc

.a16
.i16
.proc DrawProjectileBullet
  lda #$56|OAM_PRIORITY_2|OAM_COLOR_1
  jml DispActor8x8
.endproc

; Check for a collision with a player projectile
; and run the default handler for it
.export ActorGetShot
.proc ActorGetShot
  jsl ActorGetShotTest
  bcc :+
  jsl ActorGotShot
: rtl
.endproc

.a16
.proc ActorGetShotTest
ProjectileIndex = TempVal
ProjectileType  = 0
  ldy #ProjectileStart
Loop:
  lda ActorType,y
  beq NotProjectile  

  jsl TwoActorCollision
  bcc :+
    lda ActorProjectileType,y
    sta ProjectileType
    sty ProjectileIndex
    sec ; Set = Actor was hit by projectile
    rtl
  :

NotProjectile:
  tya
  add #ActorSize
  tay
  cpy #ProjectileEnd
  bne Loop

  clc ; Clear = Actor was not hit by projectile
  rtl
.endproc

.proc ActorGotShot
ProjectileIndex = ActorGetShotTest::ProjectileIndex
ProjectileType  = ActorGetShotTest::ProjectileType
  phk
  plb
  lda ProjectileType
  asl
  tay
  lda HitProjectileResponse,y
  pha
  ldy ProjectileIndex
  rts

DefeatAndRemove:
  lda #0
  sta ActorType,y
Defeat:
  seta8
  ; Play the sound effect
  lda #SFX::menu_cursor
  jsl PlaySoundEffect
  seta16

  jml ActorBecomePoof

HitProjectileResponse:
  .word .loword(DefeatAndRemove-1)
.endproc

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

; Format for 16-bit X and Y positions and speeds:
; HHHHHHHH LLLLSSSS
; |||||||| ||||++++ - subpixels
; ++++++++ ++++------ actual pixels

.include "memory.inc"

.segment "ZEROPAGE"
  retraces: .res 2
  framecount: .res 2  ; Only increases every iteration of the main loop

  keydown:  .res 2
  keylast:  .res 2
  keynew:   .res 2

  ScrollX:  .res 2   ; Primary foreground
  ScrollY:  .res 2

  random1:  .res 2
  random2:  .res 2

  ; These hold the last value written to these registers, allowing you to get what value it was
  HDMASTART_Mirror: .res 1
  CGWSEL_Mirror: .res 1
  CGADSUB_Mirror: .res 1

  LevelBlockPtr: .res 3 ; Pointer to one block or a column of blocks. 00xxxxxxxxyyyyy0
  BlockFlag:     .res 2 ; Contains block class, solid flags, and interaction set
  BlockTemp:     .res 4 ; Temporary bytes for block interaction routines specifically

  PlayerPX:        .res 2 ; \ player X and Y positions
  PlayerPY:        .res 2 ; /

  PlayerVX:        .res 2 ; \
  PlayerVY:        .res 2 ; /
  PlayerFrame:     .res 1 ; Player animation frame

  ; Precomputed hitbox edges to speed up collision detection with the player
  PlayerPXLeft:    .res 2 ; 
  PlayerPXRight:   .res 2 ;
  PlayerPYTop:     .res 2 ; Y position for the top of the player

  ForceControllerBits: .res 2
  ForceControllerTime: .res 1

  PlayerWasRunning: .res 1     ; was the player running when they jumped?
  PlayerDir:        .res 1     ; currently facing left?
  PlayerJumping:    .res 1     ; true if jumping (not falling)
  PlayerOnGround:   .res 1     ; true if on ground
  PlayerOnGroundLast: .res 1   ; true if on ground last frame - used to display the landing particle
  PlayerWalkLock:   .res 1     ; timer for the player being unable to move left/right
  PlayerDownTimer:  .res 1     ; timer for how long the player has been holding down
                               ; (used for fallthrough platforms)
  PlayerHealth:     .res 1     ; current health, measured in half hearts

  OamPtr:           .res 2 ; Current index into OAM and OAMHI
  TempVal:          .res 4
  TouchTemp:        .res 8

  LevelColumnSize:  .res 2 ; for moving left and right in a level buffer
  LevelColumnMask:  .res 2 ; LevelColumnSize-1
  LevelHeaderPointer: .res 3 ; For starting the same level from a checkpoint, or other purposes
  LevelDataPointer:  .res 3 ; pointer to the actual level data
  LevelActorPointer: .res 3 ; actor pointer for this level

.segment "BSS" ; First 8KB of RAM
  ActorSize = 11*2+5
  ActorStart: .res ActorLen*ActorSize
  ActorEnd:
  ; Must be contiguous
  ProjectileStart: .res ProjectileLen*ActorSize
  ProjectileEnd:

  ActorType         = 0 ; Actor type ID
  ActorPX           = 2 ; Positions
  ActorPY           = 4 ;
  ActorVX           = 6 ; Speeds
  ActorVY           = 8 ;
  ActorTimer        = 10 ; General purpose
  ActorVarA         = 12 ; 
  ActorVarB         = 14 ; 
  ActorVarC         = 16 ; 
  ActorIndexInLevel = 18 ; Actor's index in level list, prevents Actor from being respawned until it's despawned
  ActorDirection    = 20 ; 0 (Right) or 1 (Left). Other bits may be used later. Good place for parameters from level?
  ActorOnGround     = 21 ; Nonzero means on ground
  ActorOnScreen     = 22 ; Nonzero means on screen - only maintained for 16x16 actors
  ActorWidth        = 23 ; Width in subpixels
  ActorHeight       = 25 ; Height in subpixels
  ActorProjectileType = ActorIndexInLevel ; Safe to reuse, since this is only checked on normal actor slots

  ; For less important, light entities
  ParticleSize = 7*2
  ParticleStart: .res ParticleLen*ParticleSize
  ParticleEnd:

  ParticleType       = 0
  ParticlePX         = 2
  ParticlePY         = 4
  ParticleVX         = 6
  ParticleVY         = 8
  ParticleTimer      = 10
  ParticleVariable   = 12

  NeedLevelRerender:     .res 1 ; If set, rerender the level again
  RerenderInitEntities:  .res 1 ; If set, init entity lists for next rerender;
                                ; if $80 (RERENDER_INIT_ENTITIES_TELEPORT), preserve certain entity types
  OAM:   .res 512
  OAMHI: .res 512
  ; OAMHI contains bit 8 of X (the horizontal position) and the size
  ; bit for each sprite.  It's a bit wasteful of memory, as the
  ; 512-byte OAMHI needs to be packed by software into 32 bytes before
  ; being sent to the PPU, but it makes sprite drawing code much
  ; simpler.

  ScrollXLimit: .res 2
  ScrollYLimit: .res 2

  JumpGracePeriod: .res 1
  PlayerJumpCancelLock: .res 1 ; timer for the player being unable to cancel a jump
  PlayerJumpCancel: .res 1
  PlayerWantsToJump: .res 1    ; true if player pressed the jump button
  PlayerWantsToAttack: .res 1  ; true if player pressed the attack button
  PlayerRidingSomething: .res 1 ; if 1, player is treated to be standing on a solid and can jump

  PlayerDrawX: .res 1
  PlayerDrawY: .res 1

  ; Mirrors, for effects
  FGScrollXPixels: .res 2
  FGScrollYPixels: .res 2
  BGScrollXPixels: .res 2
  BGScrollYPixels: .res 2

  LevelBackgroundColor:   .res 2 ; Palette entry
  LevelBackgroundId:      .res 1 ; Backgrounds specified in backgrounds.txt

  OldScrollX: .res 2
  OldScrollY: .res 2

  SpriteXYOffset: .res 2

; All of these are cleared in one go at the start of level decompression
LevelZeroWhenLoad_Start:
  ScreenFlags:            .res (16)*(16+1) ; 256*256

  VerticalScrollEnabled:  .res 1 ; Enable vertical scrolling
  LevelFadeIn:            .res 1 ; Timer for fading the level in

  PlayerOnLadder:      .res 1

  PlayerOnSlope:       .res 1 ; Nonzero if the player is on a slope
  PlayerSlopeType:     .res 2 ; Type of slope the player is on, if they are on one

  PlayerCameraTargetY: .res 2 ; Y position to target with the camera

  ; Video updates from scrolling
  ColumnUpdateAddress: .res 2     ; Address to upload to, or zero for none
  RowUpdateAddress:    .res 2     ; Address to upload to, or zero for none
  ; Found in bank 7F:
  ; ColumnUpdateBuffer:  .res 32*2  ; 32 tiles vertically
  ; RowUpdateBuffer:     .res 64*2  ; 64 tiles horizontally

  ; Second layer
  ColumnUpdateAddress2: .res 2     ; Address to upload to, or zero for none
  RowUpdateAddress2:    .res 2     ; Address to upload to, or zero for none

  ; List of tilemap changes to make in vblank (for ChangeBlock)
  ScatterUpdateLength: .res 2
  ScatterUpdateBuffer: .res SCATTER_BUFFER_LENGTH ; Alternates between 2 bytes for a VRAM address, 2 bytes for VRAM data

  ; Delayed ChangeBlock updates
  DelayedBlockEditType: .res MaxDelayedBlockEdits*2 ; Block type to put in
  DelayedBlockEditAddr: .res MaxDelayedBlockEdits*2 ; Address to put the block at
  DelayedBlockEditTime: .res MaxDelayedBlockEdits*2 ; Time left until the change

  PlayerInvincible: .res 1     ; timer for player invincibility

  ; Number of keys
  RedKeys:    .res 1
  GreenKeys:  .res 1
  BlueKeys:   .res 1
  YellowKeys: .res 1
LevelZeroWhenLoad_End:

  ; For speeding up actor spawning
  ; (keeps track of which actor index is the first one on a particular screen)
  ; Multiply by 4 to use it.
  FirstActorOnScreen:     .res 16

GameStateStart:
  YourInventory:    .res InventoryLen*2 ; Type, Amount pairs
  LevelInventory:   .res InventoryLen*2
  InventoryEnd:
GameStateEnd:
SaveDataStart:
  SavedGameState:   .res GameStateEnd-GameStateStart
  MoneyAmount:      .res 3   ; 5 BCD digits
SaveDataEnd:

CheckpointState:    .res GameStateEnd-GameStateStart
CheckpointX:        .res 1
CheckpointY:        .res 1

.segment "BSS7E"

.segment "BSS7F"
  LevelBuf:    .res 256*32*2 ; 16KB
  LevelBuf_End:

  DecompressBuffer: .res 8192

  ColumnUpdateBuffer:   .res 32*2  ; 32 tiles vertically
  RowUpdateBuffer:      .res 64*2  ; 64 tiles horizontally

.globalzp retraces
.globalzp framecount
.globalzp keydown
.globalzp keylast
.globalzp keynew
.globalzp ScrollX, ScrollY
.global   OldScrollX, OldScrollY
.globalzp LevelBlockPtr
.globalzp BlockFlag
.globalzp BlockRealX
.globalzp BlockRealY
.globalzp BlockTemp

.globalzp PlayerPX
.globalzp PlayerPXLeft
.globalzp PlayerPXRight
.globalzp PlayerPY
.globalzp PlayerPYTop
.globalzp PlayerVX
.globalzp PlayerVY
.globalzp PlayerFrame
.globalzp PlayerDir
.globalzp PlayerWasRunning
.global PlayerOnLadder, PlayerInWater
.global PlayerOnSlope
.global PlayerSlopeType
.global PlayerCameraTargetY
.globalzp PlayerOnGround
.globalzp PlayerOnGroundLast
.globalzp PlayerHealth
.global PlayerInvincible
.globalzp PlayerWalkLock
.globalzp PlayerDownTimer
.global PlayerDownRecently
.globalzp PlayerJumping
.globalzp OamPtr
.globalzp TempVal
.globalzp TouchTemp
.globalzp LevelDataPointer, LevelHeaderPointer
.globalzp ForceControllerBits
.globalzp ForceControllerTime

.global PlayerJumpCancel
.global PlayerJumpCancelLock
.global PlayerWantsToJump
.global PlayerWantsToAttack
.global PlayerAccelSpeed
.global PlayerDecelSpeed
.global JumpGracePeriod
.global PlayerRidingSomething
; 1 = Riding something normally, 2 = Don't update the PlayerCameraTargetY 
RIDING_NO_PLATFORM_SNAP = 2

.global PlayerDrawX
.global PlayerDrawY
.global PlayerOAMIndex
.global HighPriorityOAMIndex

.global ColumnUpdateAddress, ColumnUpdateAddress2
.global ColumnUpdateBuffer, ColumnUpdateBuffer2
.global RowUpdateAddress, RowUpdateAddress2
.global RowUpdateBuffer, RowUpdateBuffer2

BLOCK_UPDATE_COUNT = 8
.global BlockUpdateAddressTop
.global BlockUpdateAddressBottom
.global BlockUpdateDataTL
.global BlockUpdateDataTR
.global BlockUpdateDataBL
.global BlockUpdateDataBR
.global BlockUpdateDataEnd

MaxDelayedBlockEdits = 15
.global DelayedBlockEditType
.global DelayedBlockEditTime
.global DelayedBlockEditAddr

.globalzp LevelColumnSize, LevelColumnMask
.global ScrollXLimit, ScrollYLimit
.global LevelBuf
.global LevelBuf_End
.global LevelActorList
.global FirstActorOnScreen

.global OAM
.global OAMHI
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3

ActorLen = 32
ProjectileLen = 8
.global ActorStart
.globalzp ActorSize
.global ActorEnd
.globalzp ActorType
.globalzp ActorPX
.globalzp ActorPY
.globalzp ActorVX
.globalzp ActorVY
.globalzp ActorVarA
.globalzp ActorVarB
.globalzp ActorVarC
.globalzp ActorDirection
.globalzp ActorIndexInLevel
.globalzp ActorTimer
.globalzp ActorOnGround
.globalzp ActorOnScreen
.globalzp ActorProjectileType
.globalzp ActorWidth
.globalzp ActorHeight
.global ProjectileStart
.global ProjectileEnd

.enum PlayerProjectileType
  Bullet
.endenum

ParticleLen = 20
.global ParticleStart
.globalzp ParticleSize
.global ParticleEnd
.globalzp ParticleType
.globalzp ParticlePX
.globalzp ParticlePY
.globalzp ParticleVX
.globalzp ParticleVY
.globalzp ParticleTimer
.globalzp ParticleVariable

.global NeedLevelReload
.global NeedLevelRerender

RERENDER_INIT_ENTITIES_TELEPORT = $80
.global RerenderInitEntities

.global LevelZeroWhenLoad_Start
.global LevelZeroWhenLoad_End

.global LevelBackgroundColor
.global LevelBackgroundId
.global FGScrollXPixels, FGScrollYPixels, BGScrollXPixels, BGScrollYPixels
.globalzp LevelActorPointer
.global VerticalScrollEnabled
.global LevelFadeIn

.globalzp random1
.globalzp random2
.globalzp HDMASTART_Mirror, CGWSEL_Mirror, CGADSUB_Mirror

.global LevelActorBuffer

.global UseTapRun, TapReleaseTimer, TapReleaseButton, IsTapRun

; Save stuff
.global MoneyAmount

.global GameStateStart
.global GameStateEnd
GameStateSize = GameStateEnd-GameStateStart
InventoryLen = 25

.global YourInventory, LevelInventory, InventoryEnd

.global CheckpointState, CheckpointX, CheckpointY

.global CursorX
.global CursorY
.global AutoRepeatTimer

.global SpriteXYOffset

.global DecompressBuffer

.global RedKeys, GreenKeys, BlueKeys, YellowKeys

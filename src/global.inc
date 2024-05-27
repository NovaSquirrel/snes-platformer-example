; Probably use LevelColumnSize instead of these
LEVEL_WIDTH = 256
LEVEL_HEIGHT = 32
MAX_LEVEL_HEIGHT = 256
LEVEL_TILE_SIZE = 2

ForegroundBG  = $5800
BackgroundBG  = $5000
ExtraBG       = $4c00 ; Used for layer 3
ExtraBGWide   = $4800 ; Used for a bigger layer 3 background
SpriteCHRBase = $6000
BG1CHRBase    = $0000
BG2CHRBase    = $2000
BG3CHRBase    = $2000

PlayerHeight = 28*16
PlayerCollideWidth = 8*16

; ------------------------------------

; Include handy macros
.include "macros.s"
.include "memory.inc"

; main.s
.global main, nmi_handler, irq_handler

; uploadppu.s
.global ppu_copy_oam, ppu_pack_oamhi, ppu_clear_oam
.global ppu_copy, ppu_clear_nt, ppu_vsync, WaitVblank
.global DoGraphicUpload, DoPaletteUpload
.global WritePPUIncreasing, WritePPURepeated, SkipPPUWords

; Common
.global GetLevelColumnPtr, GetLevelPtrXY, GetBlockFlag
.global RenderLevelScreens
.global RenderLevelColumnUpload, RenderLevelColumnLeft, RenderLevelColumnRight
.global RenderLevelRowUpload, RenderLevelRowTop, RenderLevelRowBottom
.global PlayerFrameUpload
.global FadeIn, FadeOut, WaitKeysReady
.global MemClear, MemClear7F

.global RunPlayer, DrawPlayer, DrawPlayerStatus, AdjustCamera
.global BlockFlags

.global ChangeBlock, DelayChangeBlock
.global GetBlockX, GetBlockY, GetBlockXCoord, GetBlockYCoord

.global PlaySoundEffect

; Flags
.enum ActorFlag
  Priority      = %1100000000000000 ; Priority bits
  Essential     = %1000000000000000 
  Primary       = %0100000000000000
  Secondary     = %0000000000000000
.endenum

.global FindFreeActorX, FindFreeActorY, FindFreeParticleY

.global RandomByte, VelocityLeftOrRight

DirectionKeys = KEY_LEFT|KEY_DOWN|KEY_UP|KEY_RIGHT

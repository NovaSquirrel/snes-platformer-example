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
.include "../audio/gss_enum.s"
.smart
.export main, nmi_handler
.import RunAllActors, DrawPlayer, DrawPlayerStatus
.import StartLevel, ResumeLevelFromCheckpoint
.import GSS_SendCommand, GSS_SendCommandParamX, GSS_LoadSong

.segment "CODE"
;;
; Minimalist NMI handler that only acknowledges NMI and signals
; to the main thread that NMI has occurred.
.proc nmi_handler
  ; Because the INC and BIT instructions can't use 24-bit (f:)
  ; addresses, set the data bank to one that can access low RAM
  ; ($0000-$1FFF) and the PPU ($2100-$213F) with a 16-bit address.
  ; Only banks $00-$3F and $80-$BF can do this, not $40-$7D or
  ; $C0-$FF.  ($7E can access low RAM but not the PPU.)  But in a
  ; LoROM program no larger than 16 Mbit, the CODE segment is in a
  ; bank that can, so copy the data bank to the program bank.
  phb
  phk
  plb

  seta16
  inc a:retraces   ; Increase NMI count to notify main thread
  seta8
  bit a:NMISTATUS  ; Acknowledge NMI

  plb
  rti
.endproc


.segment "CODE"
; init.s sends us here
.proc main
  seta8
  setxy16
  phk
  plb

  ; Clear the first 512 of RAM bytes manually with a loop.
  ; This avoids the memory clear overwriting the return address on the stack!
  ldx #512-1
: stz 0, x
  dex
  bpl :-

  ; Clear the rest of the RAM
  ldx #512
  ldy #$10000 - 512
  jsl MemClear
  ldx #0
  txy ; 0 = 64KB
  jsl MemClear7F

  ; In the same way that the CPU of the Commodore 64 computer can
  ; interact with a floppy disk only through the CPU in the 1541 disk
  ; drive, the main CPU of the Super NES can interact with the audio
  ; hardware only through the sound CPU.  When the system turns on,
  ; the sound CPU is running the IPL (initial program load), which is
  ; designed to receive data from the main CPU through communication
  ; ports at $2140-$2143.  Load a program and start it running.
  jsl spc_boot_apu
  seta8
  lda #GSS_Commands::INITIALIZE
  jsl GSS_SendCommand

  lda #Music::test
  jsl GSS_LoadSong

  lda #GSS_Commands::MUSIC_START
  jsl GSS_SendCommand

  .a8
  ; Clear palette
  stz CGADDR
  ldx #256
: stz CGDATA ; Write twice
  stz CGDATA
  dex
  bne :-

  ; Clear VRAM too
  seta16
  stz PPUADDR
  ldx #$8000 ; 32K words
: stz PPUDATA
  dex
  bne :-

  setaxy16

  ; Initialize random generator
  lda #42069
  sta random1
  dec
  sta random2

  lda #0
 .import StartLevel

  jml StartLevel
.endproc

.export GameMainLoop
.proc GameMainLoop
  phk
  plb
  stz framecount
forever:
  ; Draw the player to a display list in main memory
  setaxy16
  inc framecount
  seta16

  ; Update keys
  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew

  lda keynew
  and #KEY_START
  beq :+
    ; TODO: Insert some sort of pause screen here!
  :

  seta16
  lda NeedLevelRerender
  lsr
  bcc :+
    jsl RenderLevelScreens
    seta8
    stz NeedLevelRerender
    seta16
  :

  ; Handle delayed block changes
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Count down the timer, if there is a timer
  lda DelayedBlockEditTime,x
  beq @NoBlock
    dec DelayedBlockEditTime,x
    bne @NoBlock
    ; Hit zero? Make the change
    lda DelayedBlockEditAddr,x
    sta LevelBlockPtr
    lda DelayedBlockEditType,x
    jsl ChangeBlock
  @NoBlock:
  dex
  dex
  bpl DelayedBlockLoop

  lda #5*4 ; Reserve 5 sprites at the start
  sta OamPtr

  jsl RunPlayer
  jsl AdjustCamera

  ; Calculate the scroll positions ahead of time so their integer values are ready
  lda ScrollX
  lsr
  lsr
  lsr
  lsr
  sta FGScrollXPixels
  lsr
  sta BGScrollXPixels
  ; ---
  lda ScrollY
  lsr
  lsr
  lsr
  lsr
  adc #0
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  sta FGScrollYPixels
  lsr
  add #128
  sta BGScrollYPixels

  .a16

  jsl DrawPlayerStatus

  jsl RunAllActors
  jsl DrawPlayer
  .a16
  .i16

  setaxy16

  ; Going past the bottom of the screen results in dying
  lda PlayerPY
  cmp #(512+32)*16
  bcs Die
    ; So does running out of health
    lda PlayerHealth
    and #255
    bne NotDie
  Die:
    ; Wait and turn off the screen
    jsl WaitVblank
    seta8
    lda #FORCEBLANK
    sta PPUBRIGHT
    seta16
    jml ResumeLevelFromCheckpoint
  NotDie:

  ; Include code for handling the vblank
  ; and updating PPU memory.
  .include "vblank.s"

  seta8
  ; Turn on rendering
  lda LevelFadeIn
  sta PPUBRIGHT
  cmp #$0f
  beq :+
    ina
  :
  sta LevelFadeIn

  ; Wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  ; Update scroll registers
  ; ---Primary foreground---
  seta8
  lda FGScrollXPixels+0
  sta BGSCROLLX
  lda FGScrollXPixels+1
  sta BGSCROLLX
  lda FGScrollYPixels+0
  sta BGSCROLLY
  lda FGScrollYPixels+1
  sta BGSCROLLY

  lda BGScrollXPixels+0
  sta BGSCROLLX+2
  lda BGScrollXPixels+1
  sta BGSCROLLX+2
  lda BGScrollYPixels+0
  sta BGSCROLLY+2
  lda BGScrollYPixels+1
  sta BGSCROLLY+2

  seta8
  lda HDMASTART_Mirror
  sta HDMASTART

  ; Now that we're done with vblank tasks, clean up after vblank
  seta16
  stz ScatterUpdateLength

  ; Go on with game logic again
  jmp forever
.endproc

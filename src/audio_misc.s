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
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.import SongDirectory
.importzp SONG_COUNT

.code

; input: A (song ID; 0=common, >0=song)
; output: Carry (song is valid), A (bank), X (address), Y (size)
.a8
.i16
.export LoadAudioData : far
.proc LoadAudioData
  cmp #0
  beq LoadCommon
  cmp #<SONG_COUNT
  bcs Invalid

  seta16

  ; Multiply by 5
  and #$00ff
  sta 0
  asl
  asl
  adc 0
  tax
  
  lda f:SongDirectory+3-5,x ; Size
  tay
  lda f:SongDirectory+0-5,x ; Address
  pha
  seta8
  lda f:SongDirectory+2-5,x ; Bank
  plx
  sec
  rtl

Invalid:
  clc
  rtl

LoadCommon:
  lda #^CommonAudioData_Bin
  ldx #.loword(CommonAudioData_Bin)
  ldy #CommonAudioData_SIZE
  sec
  rtl
.endproc

; input: A (sound effect)
.export PlaySoundEffect
.proc PlaySoundEffect
  php
  phk
  plb
  ; Assume .i16 and data bank == program bank
  seta8
  jsr Tad_QueueSoundEffect
  plp
  rtl
.endproc

; -----------------------------------------------

.segment "AudioDriver"

.export Tad_Loader_Bin, Tad_Loader_SIZE
.export Tad_AudioDriver_Bin, Tad_AudioDriver_SIZE
.export Tad_BlankSong_Bin, Tad_BlankSong_SIZE

CommonAudioData_Bin: .incbin "../audio/audio_common.bin"
CommonAudioData_SIZE = .sizeof(CommonAudioData_Bin) 

Tad_Loader_Bin: .incbin "../audio/driver/loader.bin"
Tad_Loader_SIZE = .sizeof(Tad_Loader_Bin)

Tad_AudioDriver_Bin: .incbin "../audio/driver/audio-driver.bin"
Tad_AudioDriver_SIZE = .sizeof(Tad_AudioDriver_Bin)

Tad_BlankSong_Bin: .incbin "../audio/driver/blank-song.bin"
Tad_BlankSong_SIZE = .sizeof(Tad_BlankSong_Bin)

.ifndef ENEMY_INC
ENEMY_INC = 1

.include "tiles.inc"
.include "globals.asm"
.include "sprite.asm"
.include "debug.asm"
.include "joystick.asm"
.include "tilelib.asm"
.include "timer.asm"

enemies_cleared: .byte 0

enemy_map: .byte 0,0,0,1,2,3

ENEMY1_INIT = $41
ENEMY2_INIT = $63
ENEMY3_INIT = $82
ENEMY4_INIT = $A2

; Enemy status:
;  Bits 7-5: sprite index
;  Bit 4: moving
;  Bit 3: vulnerable
;  Bit 2: eyes only
;  Bit 1-0: Direction (0:R,1:L,2:D,3:U)
enemies:
enemy1:  .byte ENEMY1_INIT
enemy2:  .byte ENEMY2_INIT
enemy3:  .byte ENEMY3_INIT
enemy4:  .byte ENEMY4_INIT
end_enemies:

ENEMY1_TGT_X = 18
ENEMY2_TGT_X = 1
ENEMY3_TGT_X = 19
ENEMY4_TGT_X = 0
ENEMY1_TGT_Y = 0
ENEMY2_TGT_Y = 0
ENEMY3_TGT_Y = 14
ENEMY4_TGT_Y = 14

BOX_X = 9
BOX_Y = 7

ENEMY_MIN_X  = 1
ENEMY_MIN_Y  = 3
ENEMY_MAX_X  = 19
ENEMY_MAX_Y  = 12

target_x:   .byte ENEMY1_TGT_X, ENEMY2_TGT_X, ENEMY3_TGT_X, ENEMY4_TGT_X
target_y:   .byte ENEMY1_TGT_Y, ENEMY2_TGT_Y, ENEMY3_TGT_Y, ENEMY4_TGT_Y

body_frames:   .byte  9, 11, 10, 12
vuln_frame:    .byte 13
eye_frames:    .byte 14, 14, 15, 15
eye_flips:     .byte $0, $1, $2, $0

reverse_dir:   .byte $1, $0, $3, $2

ticks_vuln_rem:   .word 0
chase:            .byte 0     ; 0=scatter mode, 1=chase mode
ticks_mode_rem:   .word 240   ; ticks remaining until switch between chase and scatter
scatter_time:     .word 240
chase_time:       .word 420

enemy_clear:
   lda #1
   sta enemies_cleared
   ldx #ENEMY1_idx
   jsr enemy_stop
   ldx #ENEMY2_idx
   jsr enemy_stop
   ldx #ENEMY3_idx
   jsr enemy_stop
   ldx #ENEMY4_idx
   jsr enemy_stop
   lda #ENEMY1_idx
   jsr sprite_disable
   lda #ENEMY2_idx
   jsr sprite_disable
   lda #ENEMY3_idx
   jsr sprite_disable
   lda #ENEMY4_idx
   jsr sprite_disable
   rts

enemy_reset:
   stz enemies_cleared
   stz ticks_vuln_rem
   stz ticks_vuln_rem+1
   lda #ENEMY1_INIT
   sta enemy1
   lda #ENEMY2_INIT
   sta enemy2
   lda #ENEMY3_INIT
   sta enemy3
   lda #ENEMY4_INIT
   sta enemy4
   jsr __enemy_scatter
   rts

__enemy_scatter:
   stz chase
   lda scatter_time
   sta ticks_mode_rem
   lda scatter_time+1
   sta ticks_mode_rem+1
   lda #ENEMY1_TGT_X
   sta target_x
   lda #ENEMY2_TGT_X
   sta target_x+1
   lda #ENEMY3_TGT_X
   sta target_x+2
   lda #ENEMY4_TGT_X
   sta target_x+3
   lda #ENEMY1_TGT_Y
   sta target_y
   lda #ENEMY2_TGT_Y
   sta target_y+1
   lda #ENEMY3_TGT_Y
   sta target_y+2
   lda #ENEMY4_TGT_Y
   sta target_y+3
   rts

enemy_set_mode_times:   ; Input:
                        ; A: scatter time, 15ths of seconds (0 to 17 seconds)
                        ; X/Y: chase time, ticks (0 to 1091-14/15 seconds)
   sta scatter_time
   asl scatter_time
   rol scatter_time+1
   asl scatter_time
   rol scatter_time+1
   stx chase_time
   sty chase_time+1
   rts

make_vulnerable: ; A: 15ths of seconds (0 to 17 seconds)
   sta ticks_vuln_rem
   asl ticks_vuln_rem
   rol ticks_vuln_rem+1
   asl ticks_vuln_rem
   rol ticks_vuln_rem+1
   ldx #0
@loop:
   lda enemies,x
   bit #$04
   bne @end_loop
   ora #$08
   sta enemies,x
@end_loop:
   inx
   cpx #(end_enemies-enemies)
   bne @loop
   jsr __enemy_scatter
   rts

enemy_tick:
   lda enemies_cleared
   cmp #0
   beq @start
   jmp @return
@start:
   lda ticks_vuln_rem+1
   cmp #0
   bne @dec_ticks
   lda ticks_vuln_rem
   beq @mode_tick
@dec_ticks:
   sec
   lda ticks_vuln_rem
   sbc #1
   sta ticks_vuln_rem
   lda ticks_vuln_rem+1
   sbc #0
   sta ticks_vuln_rem+1
   bra @check_eyes_mode
@enemy_temp: .byte 0
@sprite_idx: .byte 0
@mode_tick:
   jsr __enemy_mode_tick
   lda chase
   beq @check_eyes_mode
   jsr __enemy_chase_targets
@check_eyes_mode:
   jsr __enemy_eyes_targets
@start_loop:
   ldx #0
@loop:
   phx
   lda enemies,x
   sta @enemy_temp
   lsr
   lsr
   lsr
   lsr
   lsr
   sta @sprite_idx
   lda @enemy_temp
   bit #$10
   bne @move
   jmp @set_frame
@move:
   jsr __enemy_move
   plx
   lda enemies,x
   sta @enemy_temp
   phx
@set_frame:
   lda @enemy_temp
   bit #$08
   beq @check_eyes
   lda ticks_vuln_rem+1
   bne @check_ending
   lda ticks_vuln_rem
   bne @check_ending
   lda @enemy_temp
   and #$F7
   sta @enemy_temp
   bra @normal
@check_ending:
   lda ticks_vuln_rem+1
   bne @vulnerable
   lda ticks_vuln_rem
   cmp #90
   bcs @vulnerable
   bit #$08
   bne @normal    ; flash to normal frame every 8 ticks for last 1.5 seconds
@vulnerable:
   lda vuln_frame
   ldx @sprite_idx
   ldy #0
   jsr sprite_frame
   jmp @end_loop
@check_eyes:
   lda @enemy_temp
   bit #$04
   beq @normal
   and #$03
   tax
   lda eye_frames,x
   ldy eye_flips,x
   ldx @sprite_idx
   jsr sprite_frame
   jmp @end_loop
@normal:
   lda @enemy_temp
   and #$03
   tax
   lda body_frames,x
   ldx @sprite_idx
   ldy #0
   jsr sprite_frame
@end_loop:
   plx
   lda @enemy_temp
   sta enemies,x
   inx
   cpx #(end_enemies-enemies)
   beq @return
   jmp @loop
@return:
   rts

__enemy_mode_tick:
   lda ticks_mode_rem+1
   cmp #0
   bne @dec_ticks
   lda ticks_mode_rem
   beq @change_mode
@dec_ticks:
   sec
   lda ticks_mode_rem
   sbc #1
   sta ticks_mode_rem
   lda ticks_mode_rem+1
   sbc #0
   sta ticks_mode_rem+1
   bra @return
@change_mode:
   lda chase
   bne @scatter
   lda #1
   sta chase
   lda chase_time
   sta ticks_mode_rem
   lda chase_time+1
   sta ticks_mode_rem+1
   jsr __enemy_reverse
   bra @return
   nop
@scatter:
   jsr __enemy_scatter
   jsr __enemy_reverse
@return:
   rts

__enemy_chase_targets:
bra @start
@player_x:     .byte 0
@player_y:     .byte 0
@player_dir:   .byte 0
@ref_x:        .byte 0
@ref_y:        .byte 0
@start:
   lda #PLAYER_idx
   ldx #1
   jsr sprite_getpos
   stx @player_x
   sty @player_y
   lda #$0C
   and player
   lsr
   lsr
   sta @player_dir
   ; ENEMY1: target = player tile
   stx target_x
   sty target_y
   ; ENEMY2: target = 4 tiles ahead of player
   lda @player_dir
   cmp #DIR_RIGHT
   bne @e2_check_left
   lda @player_x
   clc
   adc #2
   sta target_x+2 ; Sneak in the start of enemy 3 targeting
   adc #2
   sta target_x+1
   lda @player_y
   sta target_y+1
   sta target_y+2
   jmp @enemy3
@e2_check_left:
   lda @player_dir
   cmp #DIR_LEFT
   bne @e2_check_down
   lda @player_x
   sec
   sbc #2
   sta target_x+2
   sbc #2
   bpl @e2_left_set_x
   lda #0
   sta target_x+2
@e2_left_set_x:
   sta target_x+1
   lda @player_y
   sta target_y+1
   sta target_y+2
   jmp @enemy3
@e2_check_down:
   lda @player_dir
   cmp #DIR_DOWN
   bne @e2_up
   lda @player_x
   sta target_x+1
   sta target_x+2
   lda @player_y
   clc
   adc #2
   sta target_y+2
   adc #2
   sta target_y+1
   jmp @enemy3
@e2_up:
   lda @player_x
   sta target_x+1
   sta target_x+2
   lda @player_y
   sec
   sbc #2
   sta target_y+2
   sbc #2
   bpl @e2_up_set_y
   lda #0
   sta target_y+2
@e2_up_set_y:
   sta target_y+1
   ; ENEMY 3 : double the vector to half the offset of enemy 2's target
@enemy3:
   lda #ENEMY1_idx
   ldx #1
   jsr sprite_getpos
   stx @ref_x
   sty @ref_y
   lda target_x+2
   sec
   sbc @ref_x
   sta target_x+2
   clc
   adc target_x+2
   clc
   adc @ref_x
   bpl @e3_set_x
   lda #0
@e3_set_x:
   sta target_x+2
   lda target_y+2
   sec
   sbc @ref_y
   sta target_y+2
   clc
   adc target_y+2
   clc
   adc @ref_y
   bpl @e3_set_y
   lda #0
@e3_set_y:
   sta target_y+2
   ; ENEMY 4: same as enemy 1 unless < 8 tiles away from player, then scatter
   lda #ENEMY4_idx
   ldx #1
   jsr sprite_getpos
   stx @ref_x
   sty @ref_y
   lda @player_x
   sec
   sbc @ref_x
   sta @ref_x
   bpl @e4_check_x
   lda #0
   sec
   sbc @ref_x
   sta @ref_x
@e4_check_x:
   cmp #8
   bmi @e4_calc_y
   jmp @e4_chase
@e4_calc_y:
   lda @player_y
   sec
   sbc @ref_y
   sta @ref_y
   bpl @e4_check_y
   lda #0
   sec
   sbc @ref_y
   sta @ref_y
@e4_check_y:
   cmp #8
   bmi @e4_calc_x2
   jmp @e4_chase
@e4_calc_x2:
   lda @ref_x
   tax
   clc
@e4_x2_loop:
   cpx #0
   beq @e4_calc_y2
   adc @ref_x
   dex
   bra @e4_x2_loop
@e4_calc_y2:
   sta @ref_x
   lda @ref_y
   tax
   clc
@e4_y2_loop:
   cpx #0
   beq @e4_calc_hyp
   adc @ref_y
   dex
   bra @e4_y2_loop
@e4_calc_hyp:
   adc @ref_x
   cmp #64
   bpl @e4_chase
   lda #ENEMY4_TGT_X
   sta target_x+3
   lda #ENEMY4_TGT_Y
   sta target_y+3
   bra @return
@e4_chase:
   lda target_x
   sta target_x+3
   lda target_y
   sta target_y+3
@return:
   rts

__enemy_eyes_targets:
   ldy #0
@loop:
   lda enemies,y
   bit #$04
   beq @next
   and #$E0
   lsr
   lsr
   lsr
   lsr
   lsr
   ldx #1
   phy
   jsr sprite_getpos
   tya
   ply
   cmp #BOX_Y
   bne @set_target
   cpx #BOX_X
   bne @set_target
   lda enemies,y
   and #$FB
   sta enemies,y
   bra @next
@set_target:
   lda #BOX_X
   sta target_x,y
   lda #BOX_Y
   sta target_y,y
@next:
   iny
   cpy #(end_enemies-enemies)
   bmi @loop
   rts

__enemy_reverse:
   ldx #0
@loop:
   lda enemies,x
   and #$03
   tay
   lda reverse_dir,y
   tay
   lda enemies,x
   and #$FC
   sta enemies,x
   tya
   ora enemies,x
   sta enemies,x
   inx
   cpx #(end_enemies-enemies)
   bne @loop
   rts

__enemy_move:  ; X: enemy offset (0-3)
   bra @start
@offset:    .byte 0
@enemy:     .byte 0
@last_x:    .byte 0
@last_y:    .byte 0
@target_x:  .byte 0
@target_y:  .byte 0
@diff_x:    .byte 0
@diff_y:    .byte 0
@index:     .byte 0
@last_dir:  .byte 0
@available: .byte 0,0,0,0
@rand:      .byte 0
@blocked:   .byte 0  ; bit 3: N, bit 2: S, bit 1: W, bit 0: E
@EAST_BLOCKED = $01
@WEST_BLOCKED = $02
@SOUTH_BLOCKED = $04
@NORTH_BLOCKED = $08
@start:
   stx @offset
   lda #<@move_right    ; copy jump table to zero page
   sta ZP_PTR_1
   lda #>@move_right
   sta ZP_PTR_1+1
   lda #<@move_left
   sta ZP_PTR_1+2
   lda #>@move_left
   sta ZP_PTR_1+3
   lda #<@move_down
   sta ZP_PTR_1+4
   lda #>@move_down
   sta ZP_PTR_1+5
   lda #<@move_up
   sta ZP_PTR_1+6
   lda #>@move_up
   sta ZP_PTR_1+7
   lda enemies,x
   sta @enemy
   and #$03
   sta @last_dir
   lda target_x,x
   sta @target_x
   lda target_y,x
   sta @target_y
   lda #$E0
   and @enemy
   lsr
   lsr
   lsr
   lsr
   lsr
   sta @index
   ldx #1
   jsr sprite_getpos
   stx @last_x
   sty @last_y
   cmp #0
   beq @check_east
   jmp @continue
@check_east:
   stz @blocked
   lda @last_dir
   cmp #DIR_LEFT
   beq @east_blocked
   ldx @last_x
   ldy @last_y
   cpx #ENEMY_MAX_X
   beq @east_blocked
   inx
   lda #1
   jsr get_tile
   cpx #HOME_FENCE
   beq @east_blocked
   cpx #BLANK
   beq @check_west
   cpx #PELLET
   bpl @check_west
@east_blocked:
   lda @blocked
   ora #@EAST_BLOCKED
   sta @blocked
@check_west:
   lda @last_dir
   cmp #DIR_RIGHT
   beq @west_blocked
   ldx @last_x
   cpx #ENEMY_MIN_X
   beq @west_blocked
   dex
   ldy @last_y
   lda #1
   jsr get_tile
   cpx #HOME_FENCE
   beq @west_blocked
   cpx #BLANK
   beq @check_south
   cpx #PELLET
   bpl @check_south
@west_blocked:
   lda @blocked
   ora #@WEST_BLOCKED
   sta @blocked
@check_south:
   lda @last_dir
   cmp #DIR_UP
   beq @south_blocked
   ldx @last_x
   ldy @last_y
   cpy #ENEMY_MAX_Y
   beq @south_blocked
   iny
   lda #1
   jsr get_tile
   cpx #BLANK
   beq @check_north
   cpx #HOME_FENCE
   beq @check_eyes_fence
   cpx #PELLET
   bpl @check_north
   bra @south_blocked
@check_eyes_fence:
   lda @enemy
   bit #$04
   bne @check_north
@south_blocked:
   lda @blocked
   ora #@SOUTH_BLOCKED
   sta @blocked
@check_north:
   lda @last_dir
   cmp #DIR_DOWN
   beq @north_blocked
   ldy @last_y
   cpy #ENEMY_MIN_Y
   beq @north_blocked
   dey
   ldx @last_x
   lda #1
   jsr get_tile
   cpx #BLANK
   beq @calc_dir
   cpx #PELLET
   bpl @calc_dir
@north_blocked:
   lda @blocked
   ora #@NORTH_BLOCKED
   sta @blocked
   bra @calc_dir
@continue:
   lda @last_dir  ; continue in last direction until fully into next tile
   asl
   tax
   lda @index
   jmp (ZP_PTR_1,x)
@calc_dir:
   sec
   lda @target_x
   sbc @last_x
   sta @diff_x
   sec
   lda @target_y
   sbc @last_y
   sta @diff_y
   bpl @check_sw
   jmp @north
@check_sw:
   lda @diff_x
   bpl @southeast
   jmp @southwest
@southeast:
   lda @blocked
   and #$05
   cmp #$05
   beq @se_check_north
   cmp @diff_y
   bmi @se_south
@se_east:
   lda @blocked
   bit #@EAST_BLOCKED
   bne @se_south
   jmp @set_right
@se_south:
   lda @blocked
   bit #@SOUTH_BLOCKED
   bne @se_east
   jmp @set_down
@se_check_north:
   jmp @nw_north
@southwest:
   lda @blocked
   and #$06
   cmp #$06
   beq @sw_check_north
   lda @diff_x
   bpl @sw_south
   sec
   lda #0
   sbc @diff_x
   cmp @diff_y
   bpl @sw_west
@sw_south:
   lda @blocked
   bit #@SOUTH_BLOCKED
   bne @sw_west
   jmp @set_down
@sw_west:
   lda @blocked
   bit #@WEST_BLOCKED
   bne @sw_south
   jmp @set_left
@sw_check_north:
   jmp @ne_north
@north:
   lda @diff_x
   bpl @northeast
   jmp @northwest
@northeast:
   lda @blocked
   and #$09
   cmp #$09
   beq @ne_check_west
   lda @diff_y
   bpl @ne_east
   sec
   lda #0
   sbc @diff_y
   cmp @diff_x
   bmi @ne_east
@ne_north:
   lda @blocked
   bit #@NORTH_BLOCKED
   bne @ne_east
   jmp @set_up
@ne_east:
   lda @blocked
   bit #@EAST_BLOCKED
   bne @ne_north
   jmp @set_right
@ne_check_west:
   jmp @sw_west
@northwest:
   lda @blocked
   and #$0A
   cmp #$0A
   beq @nw_check_south
   lda @diff_x
   cmp @diff_y
   bmi @nw_north
@nw_west:
   lda @blocked
   bit #@WEST_BLOCKED
   bne @nw_north
   jmp @set_left
@nw_north:
   lda @blocked
   bit #@NORTH_BLOCKED
   bne @nw_west
   jmp @set_up
@nw_check_south:
   jmp @se_south
@set_right:
   lda #0
   bra @set
@set_left:
   lda #1
   bra @set
@set_down:
   lda #2
   bra @set
@set_up:
   lda #3
@set:
   sta @last_dir
   lda @enemy
   and #$FC
   ora @last_dir
   ldx @offset
   sta enemies,x
   jmp @continue
@move_right:
   ldx #TICK_MOVEMENT
   jsr move_sprite_right
   bra @return
@move_left:
   ldx #TICK_MOVEMENT
   jsr move_sprite_left
   bra @return
@move_down:
   ldx #TICK_MOVEMENT
   jsr move_sprite_down
   bra @return
@move_up:
   ldx #TICK_MOVEMENT
   jsr move_sprite_up
@return:
   rts

enemy_check_vuln: ; Input: X: sprite index
                  ; Output: A: 0=not vulnerable, 1=vulnerable
   ldy enemy_map,x
   lda enemies,y
   and #$08
   lsr
   lsr
   lsr
   rts

enemy_check_eyes: ; Input: X: sprite index
                  ; Output: A: 0=full body, 1=eyes only
   ldy enemy_map,x
   lda enemies,y
   and #$04
   lsr
   lsr
   rts

enemy_release: ; X: sprite index
   ldy enemy_map,x
   lda enemies,y
   ora #$10
   sta enemies,y
   rts

enemy_stop:    ; X: sprite index
   ldy enemy_map,x
   lda enemies,y
   and #$EF
   sta enemies,y
   rts

enemy_eaten: ; X: sprite index
   ldy enemy_map,x
   lda enemies,y
   and #$F7
   ora #$04
   sta enemies,y
   rts

.endif

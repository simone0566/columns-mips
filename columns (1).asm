################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number (if applicable)
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       16
# - Unit height in pixels:      16
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
#
# IMPORTANT:
# The bitmap display uses screen coordinates:
#   (0,0) is the TOP-LEFT corner
#   x increases to the RIGHT
#   y increases DOWNWARD
#
# So a column drawn at:
#   (COL_X, COL_Y)
#   (COL_X, COL_Y + 1)
#   (COL_X, COL_Y + 2)
# is drawn from TOP to BOTTOM.
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL:
    .word 0x10008000
ADDR_KBRD:
    .word 0xffff0000
GRAVITY_SLEEP:  .word 200      # start speed (milliseconds)
LAND_COUNT:     .word 0    
PAUSED: .word 0   # 0 = running, 1 = paused
##############################################################################
# Mutable Data
##############################################################################
BG_COLOR:   .word 0x00000000    # black
GRID_COLOR: .word 0x00ffffff    # white
OUTLINE_COLOR: .word 0x00555555 # grey
TEXT_COLOR:      .word 0x00ff4444    # red for GAME OVER
OPTION_COLOR:    .word 0x0000ff00    # green for retry hint blocks

# 3x5 font rows, each word uses low 3 bits
# 1 bit = draw cell, 0 bit = skip
GLYPH_G: .word 7,4,5,5,7
GLYPH_A: .word 2,5,7,5,5
GLYPH_M: .word 5,7,7,5,5
GLYPH_E: .word 7,6,7,6,7
GLYPH_O: .word 7,5,5,5,7
GLYPH_V: .word 5,5,5,5,2
GLYPH_R: .word 6,5,6,5,5

GEM1:       .word 0x00ff0000    # top gem
GEM2:       .word 0x0000ff00    # middle gem
GEM3:       .word 0x000000ff    # bottom gem

COL_X:      .word 2
COL_Y:      .word 1

BOARD:      .space 1024         # 16 x 16 board, 4 bytes per cell
MARKS:      .space 1024
MELODY:
    .word 76,76,76,72,76,79,67,
          72,67,64,69,71,70,69,
          67,76,79,81,77,79,76,
          72,74,71,72,67,-1

DURATIONS:
    .word 150,150,150,150,150,300,300,
          200,200,200,200,200,200,200,
          200,150,150,150,200,200,300,
          200,200,200,200,300,0

MUSIC_INDEX: .word 0
MUSIC_WAIT:  .word 0

##############################################################################
# Code
##############################################################################
    .text
    .globl main
main:
    jal reset_state
    jal select_difficulty
    li   $v0, 31
    li   $a0, 60
    li   $a1, 1000
    li   $a2, 0
    li   $a3, 100
    syscall
    jal random_column

    li   $t0, 8
    sw   $t0, COL_X
    li   $t0, 1
    sw   $t0, COL_Y

    jal check_spawn_collision
    beq  $v0, $zero, main_start_draw

    # keep board visible if already blocked at top
    jal draw_grid
    jal draw_board
    jal play_game_over_sound
    jal draw_game_over_screen
    j   game_over_loop

main_start_draw:
    jal draw_grid
    jal draw_board
    jal draw_outline
    jal draw_column
    jal update_music 

game_loop:
    jal  handle_input

    lw   $t0, PAUSED
    bne  $t0, $zero, pause_loop

    jal  erase_column
    jal  check_collision_down
    bne  $v0, $zero, reached_bottom

    lw   $t0, COL_Y
    li   $t1, 12
    beq  $t0, $t1, reached_bottom

    addi $t0, $t0, 1
    sw   $t0, COL_Y

    jal  draw_grid
    jal  draw_board
    jal draw_outline
    jal  draw_column
    jal  update_music

    li   $v0, 32
    lw   $a0, GRAVITY_SLEEP
    syscall

    j    game_loop

pause_loop:
    jal  handle_input

    li   $v0, 32
    li   $a0, 100
    syscall

    lw   $t0, PAUSED
    bne  $t0, $zero, pause_loop

    j    game_loop

##############################################################################
reached_bottom:
    jal  lock_column
    jal  play_drop_sound
    jal  clear_matches_until_stable

    # count how many columns have landed
    lw   $t0, LAND_COUNT
    addi $t0, $t0, 1
    sw   $t0, LAND_COUNT

    # make gravity gradually faster
    lw   $t1, GRAVITY_SLEEP
    li   $t2, 60
    ble  $t1, $t2, speed_done

    addi $t1, $t1, -10
    sw   $t1, GRAVITY_SLEEP

speed_done:
    jal  random_column

    li   $t0, 8
    sw   $t0, COL_X
    li   $t0, 1
    sw   $t0, COL_Y

    jal  check_spawn_collision
    beq  $v0, $zero, spawn_ok

    jal  draw_grid
    jal  draw_board
    jal  play_game_over_sound
    jal  draw_game_over_screen
    j    game_over_loop

spawn_ok:
    jal  draw_grid
    jal  draw_board
    jal draw_outline
    jal  draw_column

    j    game_loop
##############################################################################
draw_cell:
    lw   $t0, ADDR_DSPL
    li   $t1, 16
    mult $a1, $t1
    mflo $t2

    add  $t2, $t2, $a0
    sll  $t2, $t2, 2
    add  $t0, $t0, $t2

    sw   $a2, 0($t0)
    jr   $ra

##############################################################################
draw_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $a0, COL_X
    lw   $a1, COL_Y
    lw   $a2, GEM1
    jal  draw_cell

    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 1
    lw   $a2, GEM2
    jal  draw_cell

    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 2
    lw   $a2, GEM3
    jal  draw_cell

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
erase_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t6, BG_COLOR

    lw   $a0, COL_X
    lw   $a1, COL_Y
    move $a2, $t6
    jal  draw_cell

    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 1
    move $a2, $t6
    jal  draw_cell

    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 2
    move $a2, $t6
    jal  draw_cell

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
draw_grid:
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    lw   $s1, GRID_COLOR

    # Left wall
    li   $s0, 0
left_loop:
    li   $a0, 0
    move $a1, $s0
    move $a2, $s1
    jal  draw_cell
    addi $s0, $s0, 1
    li   $t9, 16
    blt  $s0, $t9, left_loop

    # Right wall
    li   $s0, 0
right_loop:
    li   $a0, 15
    move $a1, $s0
    move $a2, $s1
    jal  draw_cell
    addi $s0, $s0, 1
    li   $t9, 16
    blt  $s0, $t9, right_loop

    # Top wall
    li   $s0, 0
top_loop:
    move $a0, $s0
    li   $a1, 0
    move $a2, $s1
    jal  draw_cell
    addi $s0, $s0, 1
    li   $t9, 16
    blt  $s0, $t9, top_loop

    # Bottom wall
    li   $s0, 0
bottom_loop:
    move $a0, $s0
    li   $a1, 15
    move $a2, $s1
    jal  draw_cell
    addi $s0, $s0, 1
    li   $t9, 16
    blt  $s0, $t9, bottom_loop

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
get_board_addr:
    # input:  a0 = x, a1 = y
    # output: v0 = address of BOARD[y][x]
    la   $t0, BOARD
    li   $t1, 16
    mul  $t2, $a1, $t1
    add  $t2, $t2, $a0
    sll  $t2, $t2, 2
    add  $v0, $t0, $t2
    jr   $ra

##############################################################################
get_mark_addr:
    # input: a0 = x, a1 = y
    # output: v0 = address of MARKS[y][x]
    la   $t0, MARKS
    li   $t1, 16
    mul  $t2, $a1, $t1
    add  $t2, $t2, $a0
    sll  $t2, $t2, 2
    add  $v0, $t0, $t2
    jr   $ra

##############################################################################
check_collision_down:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, COL_Y
    li   $t1, 12
    bge  $t0, $t1, collision_down_yes

    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 3
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_down_yes

    li   $v0, 0
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

collision_down_yes:
    li   $v0, 1
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
check_collision_left:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, COL_X
    li   $t1, 1
    ble  $t0, $t1, collision_left_yes

    addi $t0, $t0, -1

    move $a0, $t0
    lw   $a1, COL_Y
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_left_yes

    move $a0, $t0
    lw   $a1, COL_Y
    addi $a1, $a1, 1
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_left_yes

    move $a0, $t0
    lw   $a1, COL_Y
    addi $a1, $a1, 2
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_left_yes

    li   $v0, 0
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

collision_left_yes:
    li   $v0, 1
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
check_collision_right:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, COL_X
    li   $t1, 14
    bge  $t0, $t1, collision_right_yes

    addi $t0, $t0, 1

    move $a0, $t0
    lw   $a1, COL_Y
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_right_yes

    move $a0, $t0
    lw   $a1, COL_Y
    addi $a1, $a1, 1
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_right_yes

    move $a0, $t0
    lw   $a1, COL_Y
    addi $a1, $a1, 2
    jal  get_board_addr
    lw   $t2, 0($v0)
    bne  $t2, $zero, collision_right_yes

    li   $v0, 0
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

collision_right_yes:
    li   $v0, 1
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
check_spawn_collision:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $a0, COL_X

    li   $a1, 1
    jal  get_board_addr
    lw   $t0, 0($v0)
    bne  $t0, $zero, spawn_collision_yes

    lw   $a0, COL_X
    li   $a1, 2
    jal  get_board_addr
    lw   $t0, 0($v0)
    bne  $t0, $zero, spawn_collision_yes

    lw   $a0, COL_X
    li   $a1, 3
    jal  get_board_addr
    lw   $t0, 0($v0)
    bne  $t0, $zero, spawn_collision_yes

    li   $v0, 0
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

spawn_collision_yes:
    li   $v0, 1
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
lock_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # top gem
    lw   $a0, COL_X
    lw   $a1, COL_Y
    jal  get_board_addr
    lw   $t0, GEM1
    sw   $t0, 0($v0)

    # middle gem
    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 1
    jal  get_board_addr
    lw   $t0, GEM2
    sw   $t0, 0($v0)

    # bottom gem
    lw   $a0, COL_X
    lw   $a1, COL_Y
    addi $a1, $a1, 2
    jal  get_board_addr
    lw   $t0, GEM3
    sw   $t0, 0($v0)

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


##############################################################################
draw_board:
    addi $sp, $sp, -20
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)

    lw   $s3, BG_COLOR          # black for empty cells

    li   $s0, 1
board_row_loop:
    li   $s1, 1
board_col_loop:
    move $a0, $s1
    move $a1, $s0
    jal  get_board_addr
    lw   $s2, 0($v0)

    bne  $s2, $zero, draw_board_use_cell
    move $s2, $s3              

draw_board_use_cell:
    move $a0, $s1
    move $a1, $s0
    move $a2, $s2
    jal  draw_cell

    addi $s1, $s1, 1
    li   $t0, 15
    blt  $s1, $t0, board_col_loop

    addi $s0, $s0, 1
    li   $t0, 15
    blt  $s0, $t0, board_row_loop

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    addi $sp, $sp, 20
    jr   $ra

##############################################################################
random_color:
    li   $v0, 42
    li   $a0, 0
    li   $a1, 6
    syscall

    beq  $a0, 0, color_red
    beq  $a0, 1, color_green
    beq  $a0, 2, color_blue
    beq  $a0, 3, color_yellow
    beq  $a0, 4, color_purple
    beq  $a0, 5, color_orange
    jr   $ra

color_red:
    li   $v0, 0x00ff0000
    jr   $ra

color_green:
    li   $v0, 0x0000ff00
    jr   $ra

color_blue:
    li   $v0, 0x000000ff
    jr   $ra

color_yellow:
    li   $v0, 0x00ffff00
    jr   $ra

color_purple:
    li   $v0, 0x008800ff
    jr   $ra

color_orange:
    li   $v0, 0x00ff8800
    jr   $ra

##############################################################################
clear_matches_until_stable:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

clear_loop:
    jal  clear_marks
    jal  find_matches
    beq  $v0, $zero, clear_done
    
    jal  play_clear_sound
    jal  erase_marked_cells

gravity_repeat:
    jal  apply_gravity
    bne  $v0, $zero, gravity_repeat

    j    clear_loop

clear_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
##############################################################################
random_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  random_color
    sw   $v0, GEM1

    jal  random_color
    sw   $v0, GEM2

    jal  random_color
    sw   $v0, GEM3

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
handle_input:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, 1, no_key

    lw   $t2, 4($t0)

    li   $t3, 0x61           # 'a'
    beq  $t2, $t3, move_left

    li   $t3, 0x64           # 'd'
    beq  $t2, $t3, move_right

    li   $t3, 0x77           # 'w'
    beq  $t2, $t3, shuffle_column

    li   $t3, 0x73           # 's'
    beq  $t2, $t3, move_down

    li   $t3, 0x71           # 'q'
    beq  $t2, $t3, quit_game
    
    li   $t3, 0x70       # 'p'
    beq  $t2, $t3, toggle_pause

no_key:
    jr   $ra

##############################################################################
toggle_pause:
    lw   $t0, PAUSED
    xori $t0, $t0, 1     # flip 0 <-> 1
    sw   $t0, PAUSED
    jr   $ra
    
quit_game:
    li   $v0, 10
    syscall
    
game_over_loop:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, 1, game_over_wait

    lw   $t2, 4($t0)

    li   $t3, 0x72          # 'r' = retry
    beq  $t2, $t3, retry_game

    li   $t3, 0x71          # 'q' = quit
    beq  $t2, $t3, quit_game

game_over_wait:
    li   $v0, 32
    li   $a0, 100
    syscall
    j    game_over_loop

retry_game:
    j    main

move_left:
    lw   $t0, COL_X
    li   $t1, 1
    ble  $t0, $t1, left_done        # at left wall

    addi $t0, $t0, -1               # candidate x

    # check the three cells to the left
    la   $t3, BOARD
    li   $t4, 16

    lw   $t5, COL_Y
    mul  $t6, $t5, $t4
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t6, $t3, $t6
    lw   $t7, 0($t6)
    bne  $t7, $zero, left_done      # top gem blocked

    lw   $t5, COL_Y
    addi $t5, $t5, 1
    mul  $t6, $t5, $t4
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t6, $t3, $t6
    lw   $t7, 0($t6)
    bne  $t7, $zero, left_done      # middle gem blocked

    lw   $t5, COL_Y
    addi $t5, $t5, 2
    mul  $t6, $t5, $t4
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t6, $t3, $t6
    lw   $t7, 0($t6)
    bne  $t7, $zero, left_done      # bottom gem blocked

    sw   $t0, COL_X
left_done:
    jr   $ra

move_right:
    lw   $t0, COL_X
    li   $t1, 14
    bge  $t0, $t1, right_done       # at right wall

    addi $t0, $t0, 1                # candidate x

    # check the three cells to the right
    la   $t3, BOARD
    li   $t4, 16

    lw   $t5, COL_Y
    mul  $t6, $t5, $t4
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t6, $t3, $t6
    lw   $t7, 0($t6)
    bne  $t7, $zero, right_done     # top gem blocked

    lw   $t5, COL_Y
    addi $t5, $t5, 1
    mul  $t6, $t5, $t4
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t6, $t3, $t6
    lw   $t7, 0($t6)
    bne  $t7, $zero, right_done     # mid gem blocked

    lw   $t5, COL_Y
    addi $t5, $t5, 2
    mul  $t6, $t5, $t4
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t6, $t3, $t6
    lw   $t7, 0($t6)
    bne  $t7, $zero, right_done     # bot gem blocked

    sw   $t0, COL_X

right_done:
    jr   $ra

shuffle_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, GEM1
    lw   $t1, GEM2
    lw   $t2, GEM3

    sw   $t2, GEM1
    sw   $t0, GEM2
    sw   $t1, GEM3

    jal  play_shuffle_sound

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

move_down:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  check_collision_down
    bne  $v0, $zero, down_done

    lw   $t0, COL_Y
    li   $t1, 12
    bge  $t0, $t1, down_done

    addi $t0, $t0, 1
    sw   $t0, COL_Y

down_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
clear_marks:
    la   $t0, MARKS
    li   $t1, 256
    li   $t2, 0

clear_marks_loop:
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, 1
    blt  $t2, $t1, clear_marks_loop

    jr   $ra

##############################################################################
find_matches:
    addi $sp, $sp, -20
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)

    li   $s2, 0
    li   $s0, 1

find_row_loop:
    li   $s1, 1

find_col_loop:
    # horizontal
    li   $t0, 12
    bgt  $s1, $t0, skip_right
    move $a0, $s1
    move $a1, $s0
    jal  mark_run_right
    or   $s2, $s2, $v0

skip_right:
    # vertical
    li   $t0, 12
    bgt  $s0, $t0, skip_down
    move $a0, $s1
    move $a1, $s0
    jal  mark_run_down
    or   $s2, $s2, $v0

skip_down:
    # diagonal down-right
    li   $t0, 12
    bgt  $s1, $t0, skip_diag_dr
    bgt  $s0, $t0, skip_diag_dr
    move $a0, $s1
    move $a1, $s0
    jal  mark_run_diag_dr
    or   $s2, $s2, $v0

skip_diag_dr:
    # diagonal down-left
    li   $t0, 3
    blt  $s1, $t0, skip_diag_dl
    li   $t0, 12
    bgt  $s0, $t0, skip_diag_dl
    move $a0, $s1
    move $a1, $s0
    jal  mark_run_diag_dl
    or   $s2, $s2, $v0

skip_diag_dl:
    addi $s1, $s1, 1
    li   $t0, 15
    blt  $s1, $t0, find_col_loop

    addi $s0, $s0, 1
    li   $t0, 15
    blt  $s0, $t0, find_row_loop

    move $v0, $s2

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    addi $sp, $sp, 20
    jr   $ra

###############################################################################
# mark horizontal run starting at (x,y), but only if (x,y) is the FIRST cell
# in that horizontal run.
mark_run_right:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    move $t4, $a0          # start x
    move $t5, $a1          # start y

    # colour at (x,y)
    move $a0, $t4
    move $a1, $t5
    jal  get_board_addr
    lw   $s0, 0($v0)
    beq  $s0, $zero, mrr_no

    # if left neighbour has same colour, this is NOT the start of the run
    li   $t0, 1
    ble  $t4, $t0, mrr_count_start
    addi $a0, $t4, -1
    move $a1, $t5
    jal  get_board_addr
    lw   $t1, 0($v0)
    beq  $t1, $s0, mrr_no

mrr_count_start:
    move $t8, $t4          # scan x
    li   $t6, 0            # run length

mrr_scan:
    li   $t7, 15
    bge  $t8, $t7, mrr_done_scan

    move $a0, $t8
    move $a1, $t5
    jal  get_board_addr
    lw   $t1, 0($v0)
    bne  $t1, $s0, mrr_done_scan

    addi $t6, $t6, 1
    addi $t8, $t8, 1
    j    mrr_scan

mrr_done_scan:
    li   $t7, 3
    blt  $t6, $t7, mrr_no

    move $t8, $t4
mrr_mark:
    move $a0, $t8
    move $a1, $t5
    jal  get_mark_addr
    li   $t2, 1
    sw   $t2, 0($v0)

    addi $t8, $t8, 1
    addi $t6, $t6, -1
    bgtz $t6, mrr_mark

    li   $v0, 1
    j    mrr_end

mrr_no:
    li   $v0, 0

mrr_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# mark vertical run starting at (x,y), but only if (x,y) is the FIRST cell
# in that vertical run.
mark_run_down:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    move $t4, $a0          # x
    move $t5, $a1          # y

    # colour at (x,y)
    move $a0, $t4
    move $a1, $t5
    jal  get_board_addr
    lw   $s0, 0($v0)
    beq  $s0, $zero, mrd_no

    # if above neighbour has same colour, not the start
    li   $t0, 1
    ble  $t5, $t0, mrd_count_start
    move $a0, $t4
    addi $a1, $t5, -1
    jal  get_board_addr
    lw   $t1, 0($v0)
    beq  $t1, $s0, mrd_no

mrd_count_start:
    move $t8, $t5          # scan y
    li   $t6, 0

mrd_scan:
    li   $t7, 15
    bge  $t8, $t7, mrd_done_scan

    move $a0, $t4
    move $a1, $t8
    jal  get_board_addr
    lw   $t1, 0($v0)
    bne  $t1, $s0, mrd_done_scan

    addi $t6, $t6, 1
    addi $t8, $t8, 1
    j    mrd_scan

mrd_done_scan:
    li   $t7, 3
    blt  $t6, $t7, mrd_no

    move $t8, $t5
mrd_mark:
    move $a0, $t4
    move $a1, $t8
    jal  get_mark_addr
    li   $t2, 1
    sw   $t2, 0($v0)

    addi $t8, $t8, 1
    addi $t6, $t6, -1
    bgtz $t6, mrd_mark

    li   $v0, 1
    j    mrd_end

mrd_no:
    li   $v0, 0

mrd_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# mark diagonal down-right run starting at (x,y), only if first in run
mark_run_diag_dr:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    move $t4, $a0          # start x
    move $t5, $a1          # start y

    # colour at (x,y)
    move $a0, $t4
    move $a1, $t5
    jal  get_board_addr
    lw   $s0, 0($v0)
    beq  $s0, $zero, mrdr_no

    # if up-left neighbour has same colour, not the start
    li   $t0, 1
    ble  $t4, $t0, mrdr_count_start
    ble  $t5, $t0, mrdr_count_start
    addi $a0, $t4, -1
    addi $a1, $t5, -1
    jal  get_board_addr
    lw   $t1, 0($v0)
    beq  $t1, $s0, mrdr_no

mrdr_count_start:
    move $t8, $t4          # scan x
    move $t9, $t5          # scan y
    li   $t6, 0

mrdr_scan:
    li   $t7, 15
    bge  $t8, $t7, mrdr_done_scan
    bge  $t9, $t7, mrdr_done_scan

    move $a0, $t8
    move $a1, $t9
    jal  get_board_addr
    lw   $t1, 0($v0)
    bne  $t1, $s0, mrdr_done_scan

    addi $t6, $t6, 1
    addi $t8, $t8, 1
    addi $t9, $t9, 1
    j    mrdr_scan

mrdr_done_scan:
    li   $t7, 3
    blt  $t6, $t7, mrdr_no

    move $t8, $t4
    move $t9, $t5
mrdr_mark:
    move $a0, $t8
    move $a1, $t9
    jal  get_mark_addr
    li   $t2, 1
    sw   $t2, 0($v0)

    addi $t8, $t8, 1
    addi $t9, $t9, 1
    addi $t6, $t6, -1
    bgtz $t6, mrdr_mark

    li   $v0, 1
    j    mrdr_end

mrdr_no:
    li   $v0, 0

mrdr_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# mark diagonal down-left run starting at (x,y), only if first in run
mark_run_diag_dl:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    move $t4, $a0          # start x
    move $t5, $a1          # start y

    # colour at (x,y)
    move $a0, $t4
    move $a1, $t5
    jal  get_board_addr
    lw   $s0, 0($v0)
    beq  $s0, $zero, mrdl_no

    # if up-right neighbour has same colour, not the start
    li   $t0, 14
    bge  $t4, $t0, mrdl_count_start
    li   $t0, 1
    ble  $t5, $t0, mrdl_count_start
    addi $a0, $t4, 1
    addi $a1, $t5, -1
    jal  get_board_addr
    lw   $t1, 0($v0)
    beq  $t1, $s0, mrdl_no

mrdl_count_start:
    move $t8, $t4          # scan x
    move $t9, $t5          # scan y
    li   $t6, 0

mrdl_scan:
    li   $t7, 1
    blt  $t8, $t7, mrdl_done_scan
    li   $t7, 15
    bge  $t9, $t7, mrdl_done_scan

    move $a0, $t8
    move $a1, $t9
    jal  get_board_addr
    lw   $t1, 0($v0)
    bne  $t1, $s0, mrdl_done_scan

    addi $t6, $t6, 1
    addi $t8, $t8, -1
    addi $t9, $t9, 1
    j    mrdl_scan

mrdl_done_scan:
    li   $t7, 3
    blt  $t6, $t7, mrdl_no

    move $t8, $t4
    move $t9, $t5
mrdl_mark:
    move $a0, $t8
    move $a1, $t9
    jal  get_mark_addr
    li   $t2, 1
    sw   $t2, 0($v0)

    addi $t8, $t8, -1
    addi $t9, $t9, 1
    addi $t6, $t6, -1
    bgtz $t6, mrdl_mark

    li   $v0, 1
    j    mrdl_end

mrdl_no:
    li   $v0, 0

mrdl_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
erase_marked_cells:
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    li   $s0, 1
erase_row_loop:
    li   $s1, 1
erase_col_loop:
    move $a0, $s1
    move $a1, $s0
    jal  get_mark_addr
    lw   $t0, 0($v0)
    beq  $t0, $zero, erase_skip

    move $a0, $s1
    move $a1, $s0
    jal  get_board_addr
    sw   $zero, 0($v0)

erase_skip:
    addi $s1, $s1, 1
    li   $t1, 15
    blt  $s1, $t1, erase_col_loop

    addi $s0, $s0, 1
    li   $t1, 15
    blt  $s0, $t1, erase_row_loop

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
apply_gravity:
    addi $sp, $sp, -24
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)

    li   $s3, 0             
    li   $s0, 1           

gravity_col_loop:
    li   $s1, 14             # write row = bottom
    li   $s2, 14             # read row  = bottom

gravity_read_loop:
    li   $t0, 1
    blt  $s2, $t0, gravity_clear_top

    # read BOARD[x][read]
    move $a0, $s0
    move $a1, $s2
    jal  get_board_addr
    lw   $s4, 0($v0)         # use $s4, not $t1
    beq  $s4, $zero, gravity_next_read

    # if read != write, move gem downward
    beq  $s1, $s2, gravity_same_spot

    # write gem to BOARD[x][write]
    move $a0, $s0
    move $a1, $s1
    jal  get_board_addr
    sw   $s4, 0($v0)

    # clear old BOARD[x][read]
    move $a0, $s0
    move $a1, $s2
    jal  get_board_addr
    sw   $zero, 0($v0)

    li   $s3, 1

gravity_same_spot:
    addi $s1, $s1, -1

gravity_next_read:
    addi $s2, $s2, -1
    j    gravity_read_loop

gravity_clear_top:
    li   $t0, 1
    blt  $s1, $t0, gravity_next_col

    move $a0, $s0
    move $a1, $s1
    jal  get_board_addr
    sw   $zero, 0($v0)

    addi $s1, $s1, -1
    j    gravity_clear_top

gravity_next_col:
    addi $s0, $s0, 1
    li   $t0, 15
    blt  $s0, $t0, gravity_col_loop

    move $v0, $s3

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addi $sp, $sp, 24
    jr   $ra
    
update_music:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, MUSIC_INDEX

    # load pitch = MELODY[index]
    la   $t1, MELODY
    sll  $t2, $t0, 2
    add  $t3, $t1, $t2
    lw   $t4, 0($t3)

    # restart if end marker
    li   $t5, -1
    bne  $t4, $t5, music_have_pitch

    li   $t0, 0
    sw   $t0, MUSIC_INDEX

    la   $t1, MELODY
    lw   $t4, 0($t1)

music_have_pitch:
    # reload index in case we restarted
    lw   $t0, MUSIC_INDEX

    # duration = DURATIONS[index]
    la   $t1, DURATIONS
    sll  $t2, $t0, 2
    add  $t3, $t1, $t2
    lw   $t5, 0($t3)

    # play note
    li   $v0, 31
    move $a0, $t4
    move $a1, $t5
    li   $a2, 0
    li   $a3, 100
    syscall

    # move to next note
    addi $t0, $t0, 1
    sw   $t0, MUSIC_INDEX

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
music_store_wait:
    # use real time delay (independent of game loop)
    li   $v0, 32
    move $a0, $t5
    syscall

    li   $t6, 1
    sw   $t6, MUSIC_WAIT

    # index++
    addi $t0, $t0, 1
    sw   $t0, MUSIC_INDEX

music_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
select_difficulty:
select_loop:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, 1, select_wait

    lw   $t2, 4($t0)

    li   $t3, 0x31          # '1' → Easy
    beq  $t2, $t3, set_easy

    li   $t3, 0x32          # '2' → Medium
    beq  $t2, $t3, set_medium

    li   $t3, 0x33          # '3' → Hard
    beq  $t2, $t3, set_hard

select_wait:
    li   $v0, 32
    li   $a0, 100
    syscall
    j    select_loop

set_easy:
    li   $t4, 500
    sw   $t4, GRAVITY_SLEEP
    jr   $ra

set_medium:
    li   $t4, 300
    sw   $t4, GRAVITY_SLEEP
    jr   $ra

set_hard:
    li   $t4, 150
    sw   $t4, GRAVITY_SLEEP
    jr   $ra
    
play_drop_sound:
    li   $v0, 31
    li   $a0, 50      # pitch
    li   $a1, 120     # duration
    li   $a2, 0       # instrument
    li   $a3, 100     # volume
    syscall
    jr   $ra

play_clear_sound:
    li   $v0, 31
    li   $a0, 80
    li   $a1, 150
    li   $a2, 0
    li   $a3, 100
    syscall
    jr   $ra

play_game_over_sound:
    li   $v0, 31
    li   $a0, 35
    li   $a1, 400
    li   $a2, 0
    li   $a3, 100
    syscall
    jr   $ra
    
play_shuffle_sound:
    li   $v0, 31
    li   $a0, 65
    li   $a1, 100
    li   $a2, 0
    li   $a3, 100
    syscall
    jr   $ra
    

get_outline_y:
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    lw   $s0, COL_Y      # candidate y
    lw   $s1, COL_X      # x

outline_fall_loop:
    li   $t2, 12
    bge  $s0, $t2, outline_done

    move $a0, $s1
    addi $a1, $s0, 3
    jal  get_board_addr
    lw   $t3, 0($v0)
    bne  $t3, $zero, outline_done

    addi $s0, $s0, 1
    j    outline_fall_loop

outline_done:
    move $v0, $s0

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 12
    jr   $ra
##############################################################################
draw_outline:
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    jal  get_outline_y
    move $s0, $v0              # outline top y

    lw   $s1, OUTLINE_COLOR    # save color in s1

    lw   $a0, COL_X
    move $a1, $s0
    move $a2, $s1
    jal  draw_cell

    lw   $a0, COL_X
    addi $a1, $s0, 1
    move $a2, $s1
    jal  draw_cell

    lw   $a0, COL_X
    addi $a1, $s0, 2
    move $a2, $s1
    jal  draw_cell

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 12
    jr   $ra
    
    ##############################################################################
reset_state:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # clear BOARD
    la   $t0, BOARD
    li   $t1, 256
reset_board_loop:
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, reset_board_loop

    # clear MARKS
    la   $t0, MARKS
    li   $t1, 256
reset_marks_loop:
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, reset_marks_loop

    # reset state vars
    sw   $zero, LAND_COUNT
    sw   $zero, PAUSED
    sw   $zero, MUSIC_INDEX
    sw   $zero, MUSIC_WAIT

    li   $t0, 8
    sw   $t0, COL_X
    li   $t0, 1
    sw   $t0, COL_Y
    
    jal  clear_screen

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
    ##############################################################################
clear_screen:
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)

    lw   $s2, BG_COLOR
    li   $s0, 0                # y

clear_screen_row:
    li   $s1, 0                # x

clear_screen_col:
    move $a0, $s1   # x
    move $a1, $s0   # y
    move $a2, $s2   # BG_COLOR
    jal  draw_cell

    addi $s1, $s1, 1
    li   $t0, 16
    blt  $s1, $t0, clear_screen_col

    addi $s0, $s0, 1
    li   $t0, 16
    blt  $s0, $t0, clear_screen_row

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    addi $sp, $sp, 16
    jr   $ra
    
    
    ##############################################################################
draw_glyph_3x5:
    addi $sp, $sp, -28
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    move $s0, $a0          # base x
    move $s1, $a1          # base y
    move $s2, $a2          # glyph addr
    move $s3, $a3          # color

    li   $s4, 0            # row = 0

glyph_row_loop:
    li   $t0, 5
    bge  $s4, $t0, glyph_done

    sll  $t1, $s4, 2
    add  $t2, $s2, $t1
    lw   $s5, 0($t2)      
    li   $t3, 0            # col = 0

glyph_col_loop:
    li   $t4, 3
    bge  $t3, $t4, glyph_next_row

    li   $t5, 2
    sub  $t5, $t5, $t3     # bit index = 2-col
    srlv $t6, $s5, $t5
    andi $t6, $t6, 1
    beq  $t6, $zero, glyph_skip_pixel

    add  $a0, $s0, $t3
    add  $a1, $s1, $s4
    move $a2, $s3
    jal  draw_cell

glyph_skip_pixel:
    addi $t3, $t3, 1
    j    glyph_col_loop

glyph_next_row:
    addi $s4, $s4, 1
    j    glyph_row_loop

glyph_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 28
    jr   $ra
    
    ##############################################################################
draw_game_over_screen:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    jal  clear_screen

    lw   $s0, TEXT_COLOR

    # Row 1: GAME  (y = 2)
    li   $a0, 0
    li   $a1, 2
    la   $a2, GLYPH_G
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 4
    li   $a1, 2
    la   $a2, GLYPH_A
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 8
    li   $a1, 2
    la   $a2, GLYPH_M
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 12
    li   $a1, 2
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5

    # Row 2: OVER  (y = 8)
    li   $a0, 0
    li   $a1, 8
    la   $a2, GLYPH_O
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 4
    li   $a1, 8
    la   $a2, GLYPH_V
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 8
    li   $a1, 8
    la   $a2, GLYPH_E
    move $a3, $s0
    jal  draw_glyph_3x5

    li   $a0, 12
    li   $a1, 8
    la   $a2, GLYPH_R
    move $a3, $s0
    jal  draw_glyph_3x5

    # small option markers near bottom
    # left green block = retry
    lw   $t0, OPTION_COLOR
    li   $a0, 3
    li   $a1, 14
    move $a2, $t0
    jal  draw_cell


    # right red block = quit
    lw   $t1, TEXT_COLOR
    li   $a0, 11
    li   $a1, 14
    move $a2, $t1
    jal  draw_cell

    li   $a0, 12
    li   $a1, 14
    move $a2, $t1
    jal  draw_cell

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

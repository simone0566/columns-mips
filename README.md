# columns-mips
A Columns puzzle game built in MIPS assembly, featuring bitmap graphics, keyboard controls, and sound effects.
# Columns in MIPS Assembly

A falling-block puzzle game implemented in MIPS assembly for CSC258 at the University of Toronto.

Move falling columns of coloured gems and arrange matching colours horizontally, vertically, or diagonally to clear them.

## Features

- Bitmap graphics and keyboard controls
- Gem colour cycling
- Horizontal, vertical, and diagonal match detection
- Cascading clears and gravity
- Three difficulty levels
- Increasing falling speed
- Pause, restart, and game-over screen
- Background music and sound effects

## Running the Game

Use the MARS MIPS simulator.

1. Open `columns.asm`.
2. Open **Tools → Bitmap Display** and configure:
   - Unit width: 16 pixels
   - Unit height: 16 pixels
   - Display width: 256 pixels
   - Display height: 256 pixels
   - Base address: `0x10008000` (`$gp`)
3. Connect the Bitmap Display to MIPS.
4. Open **Tools → Keyboard and Display MMIO Simulator**
   and connect it to MIPS.
5. Assemble and run the program.
6. Use the keyboard simulator to select a difficulty:
   `1` for Easy, `2` for Medium, or `3` for Hard.

## Controls

| Key | Action |
| --- | --- |
| A | Move left |
| D | Move right |
| W | Cycle gem colours |
| S | Move down |
| P | Pause / resume |
| Q | Quit |
| R | Restart after game over |

## Project Structure

- `columns.asm` — game source code
- `README.md` — project overview and setup instructions

## Credits

Developed by Shimeng Wang.

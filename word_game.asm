# ================================================================
# EECE321 - Computer Organization Project
# RISC-V Word Guessing Game
# Simulator: RARS
# ================================================================
# Description:
#   A word-guessing game where the player is shown a word with
#   some letters masked as '-'. The player must guess the full
#   word within a limited number of attempts. Difficulty levels
#   control how many letters are hidden and how many attempts
#   are allowed.
#
# Registers used (saved across the game loop):
#   s0  = current word index
#   s1  = base score (correct guesses)
#   s2  = difficulty level (1, 2, or 3)
#   s3  = total number of words
#   s4  = max attempts per word (depends on difficulty)
#   s5  = base address of the word-pointer array
#   s6  = bonus score (sum of remaining attempts on correct)
#   s7  = pointer to the current word string
#   s8  = length of the current word
#   s9  = number of letters to mask for the current word
#   s10 = remaining attempts for the current word
# ================================================================

# ========================  DATA SEGMENT  ========================
.data

# ---- Word bank (at least 5 words, variable lengths) -----------
word0:  .asciz "university"      # length 10
word1:  .asciz "assembly"        # length 8
word2:  .asciz "computer"        # length 8
word3:  .asciz "processor"       # length 9
word4:  .asciz "register"        # length 8
word5:  .asciz "memory"          # length 6
word6:  .asciz "keyboard"        # length 8

# Pointer table: each entry holds the address of a word string
words:      .word word0, word1, word2, word3, word4, word5, word6

# Corresponding lengths (must match the order above)
word_lens:  .word 10, 8, 8, 9, 8, 6, 8

# Total number of words in the bank
num_words:  .word 7

# ---- Buffers ---------------------------------------------------
display_buf:  .space 64          # holds the masked word for display
input_buf:    .space 64          # holds the player's typed guess
mask_array:   .space 64          # per-character flag: 1=hidden, 0=shown
enter_buf:    .space 8           # small buffer to consume Enter key

# ---- UI / prompt strings --------------------------------------
welcome:      .asciz "\n============================================\n     WELCOME TO THE WORD GUESSING GAME\n============================================\n\nPress ENTER to start... "
diff_prompt:  .asciz "\n\nSelect difficulty level:\n  1 - Easy   (few hidden letters, 5 attempts)\n  2 - Medium (more hidden letters, 4 attempts)\n  3 - Hard   (most hidden letters, 3 attempts)\n\nYour choice: "
invalid_diff: .asciz "\nInvalid choice. Please enter 1, 2, or 3.\n"
word_hdr1:    .asciz "\n----- Word "
word_hdr2:    .asciz " of "
word_hdr3:    .asciz " -----\n"
clue_label:   .asciz "  Clue:            "
attempts_lbl: .asciz "  Attempts left:   "
guess_prompt: .asciz "  Your guess:      "
correct_msg:  .asciz "  >> Correct! +1 point\n"
wrong_msg:    .asciz "  >> Wrong!\n"
no_attempts:  .asciz "  >> No attempts left!\n"
reveal_lbl:   .asciz "  The word was:    "
score_hdr:    .asciz "\n============================================\n              GAME OVER\n============================================\n"
score_lbl:    .asciz "  Correct guesses:      "
score_of:     .asciz " / "
bonus_lbl:    .asciz "\n  Bonus (left-over attempts): +"
total_lbl:    .asciz "\n  ---- TOTAL SCORE:     "
total_end:    .asciz " ----"
thanks_msg:   .asciz "\n\nThank you for playing!\n"
newline:      .asciz "\n"

# ========================  TEXT SEGMENT  ========================
.text
.globl main

# ================================================================
# MAIN
# ================================================================
main:
    # ---- Seed the pseudo-random number generator ---------------
    # Syscall 30: returns current time (low bits in a0).
    # Syscall 40: seeds generator 0 with the value in a1.
    li    a7, 30               # time
    ecall
    mv    a1, a0               # a1 = seed
    li    a0, 0                # generator id = 0
    li    a7, 40               # set seed
    ecall

    # ---- Print welcome banner ----------------------------------
    la    a0, welcome
    li    a7, 4                # print string
    ecall

    # ---- Wait for user to press Enter --------------------------
    la    a0, enter_buf
    li    a1, 4
    li    a7, 8                # read string (consumes the Enter)
    ecall

# ---- Ask for difficulty level (loop until valid) ---------------
get_difficulty:
    la    a0, diff_prompt
    li    a7, 4
    ecall

    # Read the player's choice as a short string
    la    a0, input_buf
    li    a1, 10
    li    a7, 8
    ecall

    # Parse the first character of the input
    la    t0, input_buf
    lb    a0, 0(t0)
    addi  a0, a0, -48         # ASCII '0'=48, so '1'->1, '2'->2 ...

    li    t0, 1
    blt   a0, t0, bad_diff
    li    t0, 3
    bgt   a0, t0, bad_diff
    mv    s2, a0               # s2 = difficulty (1, 2, or 3)
    j     init_game

bad_diff:
    la    a0, invalid_diff
    li    a7, 4
    ecall
    j     get_difficulty

# ---- Initialise game state -------------------------------------
init_game:
    li    s0, 0                # word index
    li    s1, 0                # base score
    li    s6, 0                # bonus score
    lw    s3, num_words        # total words (pseudo-instruction)
    la    s5, words            # pointer-table base

    # Set max attempts per difficulty
    li    t0, 1
    beq   s2, t0, att_easy
    li    t0, 2
    beq   s2, t0, att_med
    li    s4, 3                # Hard  -> 3 attempts
    j     game_loop
att_easy:
    li    s4, 5                # Easy  -> 5 attempts
    j     game_loop
att_med:
    li    s4, 4                # Medium-> 4 attempts

# ================================================================
# GAME LOOP  –  iterate over every word in the bank
# ================================================================
game_loop:
    bge   s0, s3, end_game     # all words done?

    # ---- Print header "--- Word X of Y ---" --------------------
    la    a0, word_hdr1
    li    a7, 4
    ecall
    addi  a0, s0, 1            # 1-based index
    li    a7, 1                # print int
    ecall
    la    a0, word_hdr2
    li    a7, 4
    ecall
    mv    a0, s3
    li    a7, 1
    ecall
    la    a0, word_hdr3
    li    a7, 4
    ecall

    # ---- Fetch current word pointer and length -----------------
    slli  t0, s0, 2            # offset = index * 4
    add   t1, s5, t0
    lw    s7, 0(t1)            # s7 -> current word string

    la    t2, word_lens
    add   t2, t2, t0
    lw    s8, 0(t2)            # s8 = word length

    # ---- Calculate how many letters to mask --------------------
    # Level 1 ≈ 30 %, Level 2 ≈ 50 %, Level 3 ≈ 70 %
    mv    a0, s8
    mv    a1, s2
    jal   ra, calc_mask_count  # returns count in a0
    mv    s9, a0

    # ---- Clear the mask array (all zeros) ----------------------
    la    t0, mask_array
    mv    t1, s8
clr_mask:
    beqz  t1, clr_done
    sb    zero, 0(t0)
    addi  t0, t0, 1
    addi  t1, t1, -1
    j     clr_mask
clr_done:

    # ---- Randomly choose which positions to mask ---------------
    mv    a0, s9               # how many to mask
    mv    a1, s8               # word length
    jal   ra, set_random_mask

    # ---- Build the display string  (e.g. "u-iv-r----") ---------
    la    t0, mask_array
    mv    t1, s7               # source word
    la    t2, display_buf
    mv    t3, s8
build_disp:
    beqz  t3, build_end
    lb    t4, 0(t0)            # mask flag
    lb    t5, 0(t1)            # original letter
    bnez  t4, put_dash
    sb    t5, 0(t2)            # visible letter
    j     next_ch
put_dash:
    li    t5, 45               # '-' (ASCII 45)
    sb    t5, 0(t2)
next_ch:
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    addi  t3, t3, -1
    j     build_disp
build_end:
    sb    zero, 0(t2)          # null-terminate

    # ---- Guessing loop for the current word --------------------
    mv    s10, s4              # reset remaining attempts

guess_loop:
    beqz  s10, word_fail       # out of attempts?

    # Show the clue
    la    a0, clue_label
    li    a7, 4
    ecall
    la    a0, display_buf
    li    a7, 4
    ecall
    la    a0, newline
    li    a7, 4
    ecall

    # Show remaining attempts
    la    a0, attempts_lbl
    li    a7, 4
    ecall
    mv    a0, s10
    li    a7, 1
    ecall
    la    a0, newline
    li    a7, 4
    ecall

    # Prompt for input
    la    a0, guess_prompt
    li    a7, 4
    ecall

    # Read the guess (syscall 8: read string into buffer)
    la    a0, input_buf
    li    a1, 60
    li    a7, 8
    ecall

    # ---- Strip trailing newline / carriage-return ---------------
    la    t0, input_buf
strip_nl:
    lb    t1, 0(t0)
    beqz  t1, do_lower         # reached null terminator
    li    t2, 10               # '\n'
    beq   t1, t2, cut_nl
    li    t2, 13               # '\r'
    beq   t1, t2, cut_nl
    addi  t0, t0, 1
    j     strip_nl
cut_nl:
    sb    zero, 0(t0)          # replace with null

    # ---- Convert input to lowercase for case-insensitive match -
do_lower:
    la    t0, input_buf
lower_loop:
    lb    t1, 0(t0)
    beqz  t1, do_compare
    li    t2, 65               # 'A'
    blt   t1, t2, lower_next
    li    t2, 90               # 'Z'
    bgt   t1, t2, lower_next
    addi  t1, t1, 32           # to lowercase
    sb    t1, 0(t0)
lower_next:
    addi  t0, t0, 1
    j     lower_loop

    # ---- Compare the guess with the actual word ----------------
do_compare:
    la    a0, input_buf
    mv    a1, s7
    jal   ra, strcmp            # a0 = 0 if strings match

    beqz  a0, word_ok

    # Wrong guess
    addi  s10, s10, -1
    la    a0, wrong_msg
    li    a7, 4
    ecall
    j     guess_loop

    # ---- Correct guess -----------------------------------------
word_ok:
    la    a0, correct_msg
    li    a7, 4
    ecall
    addi  s1, s1, 1            # +1 base score
    add   s6, s6, s10          # bonus = leftover attempts
    j     next_word

    # ---- Failed to guess the word ------------------------------
word_fail:
    la    a0, no_attempts
    li    a7, 4
    ecall
    la    a0, reveal_lbl
    li    a7, 4
    ecall
    mv    a0, s7
    li    a7, 4
    ecall
    la    a0, newline
    li    a7, 4
    ecall

next_word:
    addi  s0, s0, 1
    j     game_loop

# ================================================================
# END GAME  –  display score summary and exit
# ================================================================
end_game:
    la    a0, score_hdr
    li    a7, 4
    ecall

    # Correct guesses X / Y
    la    a0, score_lbl
    li    a7, 4
    ecall
    mv    a0, s1
    li    a7, 1
    ecall
    la    a0, score_of
    li    a7, 4
    ecall
    mv    a0, s3
    li    a7, 1
    ecall

    # Bonus
    la    a0, bonus_lbl
    li    a7, 4
    ecall
    mv    a0, s6
    li    a7, 1
    ecall

    # Total
    la    a0, total_lbl
    li    a7, 4
    ecall
    add   a0, s1, s6
    li    a7, 1
    ecall
    la    a0, total_end
    li    a7, 4
    ecall

    la    a0, thanks_msg
    li    a7, 4
    ecall

    # ---- Terminate program -------------------------------------
    li    a7, 10               # exit
    ecall

# ================================================================
# FUNCTION: calc_mask_count
# ----------------------------------------------------------------
# Calculates how many letters to hide based on word length and
# difficulty level.
#   Level 1 -> ~30 %    Level 2 -> ~50 %    Level 3 -> ~70 %
#
# Inputs :  a0 = word length,  a1 = difficulty (1–3)
# Output :  a0 = number of letters to mask (>= 1)
# Clobbers: t0, t1
# ================================================================
calc_mask_count:
    li    t0, 1
    beq   a1, t0, pct30
    li    t0, 2
    beq   a1, t0, pct50
    # Level 3 -> 70 %
    li    t1, 7
    j     do_pct
pct30:
    li    t1, 3
    j     do_pct
pct50:
    li    t1, 5
do_pct:
    mul   a0, a0, t1           # length * percentage_numerator
    li    t1, 10
    div   a0, a0, t1           # / 10
    # Guarantee at least 1 letter masked
    li    t0, 1
    bge   a0, t0, pct_ok
    li    a0, 1
pct_ok:
    ret

# ================================================================
# FUNCTION: set_random_mask
# ----------------------------------------------------------------
# Randomly selects 'a0' distinct positions in [0 .. a1-1] and
# sets the corresponding bytes in mask_array to 1.
#
# Inputs :  a0 = count to mask,  a1 = word length (upper bound)
# Clobbers: t0, t1, s11  (s11 is saved/restored)
# ================================================================
set_random_mask:
    addi  sp, sp, -16
    sw    ra,  12(sp)
    sw    s11,  8(sp)
    sw    a1,   4(sp)          # preserve word length
    mv    s11, a0              # s11 = remaining positions to mask

rand_loop:
    beqz  s11, rand_done

    # Syscall 42: random int in [0, a1)
    lw    a1, 4(sp)            # upper bound = word length
    li    a0, 0                # generator id
    li    a7, 42
    ecall                      # a0 = random position

    # If this position is already masked, try again
    la    t0, mask_array
    add   t0, t0, a0
    lb    t1, 0(t0)
    bnez  t1, rand_loop

    # Mark position as masked
    li    t1, 1
    sb    t1, 0(t0)
    addi  s11, s11, -1
    j     rand_loop

rand_done:
    lw    ra,  12(sp)
    lw    s11,  8(sp)
    addi  sp, sp, 16
    ret

# ================================================================
# FUNCTION: strcmp
# ----------------------------------------------------------------
# Compares two null-terminated strings byte-by-byte.
#
# Inputs :  a0 = pointer to string 1,  a1 = pointer to string 2
# Output :  a0 = 0 if equal, 1 if not equal
# Clobbers: t0, t1
# ================================================================
strcmp:
    lb    t0, 0(a0)
    lb    t1, 0(a1)
    bne   t0, t1, str_neq
    beqz  t0, str_eq           # both reached null -> equal
    addi  a0, a0, 1
    addi  a1, a1, 1
    j     strcmp
str_eq:
    li    a0, 0
    ret
str_neq:
    li    a0, 1
    ret

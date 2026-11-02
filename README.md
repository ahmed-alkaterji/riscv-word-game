<div align="center">

# 🔤 RISC-V Word Guessing Game

**A complete word-guessing game written in pure RISC-V assembly.**

![RISC-V](https://img.shields.io/badge/RISC--V-283272?style=for-the-badge&logo=riscv&logoColor=white)
![Assembly](https://img.shields.io/badge/Assembly-654FF0?style=for-the-badge)
![RARS](https://img.shields.io/badge/Simulator-RARS-lightgrey?style=for-the-badge)

</div>

---

## 🎮 Gameplay

The player sees a word with some letters masked as `-` and must guess the full word before running out of attempts.

- **3 difficulty levels** control how many letters are hidden and how many attempts you get.
- **Scoring**: a base point per correct word, plus a bonus equal to your unused attempts.
- A word bank of variable-length words.

## 🧠 Under the hood

Game state lives in saved registers across the main loop:

| Register | Purpose |
|----------|---------|
| `s0` | current word index |
| `s1` / `s6` | base score / bonus score |
| `s2` | difficulty (1–3) |
| `s4` / `s10` | max / remaining attempts |
| `s5` / `s7` | word-pointer array / current word |
| `s8` / `s9` | word length / letters to mask |

## 🚀 Run it

1. Download [RARS](https://github.com/TheThirdOne/rars).
2. Open `word_game.asm`, then **Assemble** → **Run**.

---

<sub>EECE 321 (Computer Organization) project, American University of Beirut.</sub>

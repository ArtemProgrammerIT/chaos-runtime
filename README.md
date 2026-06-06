# CHAOS.ch (v0.1)

> *"If the code runs — that doesn't mean you understand it"*

---

## Requirements

- [Zig](https://ziglang.org/) **0.13.0** or newer
- Windows 10/11, Linux or macOS

---

## Installing Zig

### Windows

**Method 1: Via winget (recommended)**

```powershell
winget install zig.zig
```

**Method 2: Via scoop**

```powershell
scoop install zig
```

**Method 3: Manually (portable)**

1. Download the archive from [ziglang.org/download](https://ziglang.org/download)
2. Extract to `C:\zig` (or any folder)
3. Add to **PATH**:
   - `Win + R` → `sysdm.cpl` → Advanced → Environment Variables
   - Add `C:\zig` to the **Path** variable
   - Click OK, restart the terminal

**Verification:**

```powershell
zig version
# Should output: 0.13.0
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install zig
# or
sudo snap install zig --classic --beta
```

### macOS

```bash
brew install zig
```

---

## Installing CHAOS Runtime

1. Download and extract the `chaos-runtime.zip` archive
2. Open a terminal in the project folder:

```bash
cd chaos-runtime
```

---

## Building

```bash
zig build
```

The executable will appear in:
- **Windows:** `zig-out\bin\chaos.exe`
- **Linux/macOS:** `zig-out/bin/chaos`

---

## Running

### Windows (PowerShell / CMD)

```powershell
# Run with random seed (JIT shuffling)
.\zig-out\bin\chaos.exe examples\hello.chaos

# Reproducible chaos with fixed seed
.\zig-out\bin\chaos.exe examples\hello.chaos --jit-seed=42
```

### Linux / macOS

```bash
# Run with random seed
./zig-out/bin/chaos examples/hello.chaos

# Reproducible chaos
./zig-out/bin/chaos examples/hello.chaos --jit-seed=42
```

---

## Troubleshooting

### `zig: command not found` / `'zig' is not recognized`

Zig is not in PATH. Check:
- **Windows:** `echo %PATH%` — should contain the folder with `zig.exe`
- **Linux/macOS:** `which zig` — should output the path

### Build error

Make sure Zig version ≥ 0.13.0:
```bash
zig version
```

---

## 1. Syntax

CHAOS uses a **hybrid syntax**:

- **Square brackets `[ ]`** — for blocks, function calls, control constructs
- **Parentheses `( )`** — only for arithmetic operations inside expressions
- **Curly braces `{ }`** — for grouping inside a block
- **Symbol prefixes** — `$` for variables, `?` for special values

```lisp
[defun add (a b) { 
    $result = (a + b) 
    return $result
}]
```

| Element | Syntax | Example |
|---------|--------|---------|
| Function / command call | `[ ... ]` | `[print "hello"]` |
| Arithmetic | `( ... )` | `(5 + 3)` |
| Block body | `{ ... }` | `{ $x = 5; return $x }` |
| Variable | `$name` | `$result` |
| Random number | `[$?]` | `[$?]` → 1..100 |
| Comment | `;;` | `;; this is a comment` |

### Mandatory rules:
- Every function/command call starts with `[` and ends with `]`
- Arithmetic only inside `( )` with the operator **between** operands: `(a + b)`, not `(+ a b)`
- Variables always with `$`
- Each command may return a **different type** on each call

---

## 2. Typing — maximally weak and volatile

The type of an operation's result is determined **at runtime** by three factors:
1. Type of the left operand (20% weight)
2. Type of the right operand (20%)
3. **Hash of the current function's name** (60%)

```lisp
[defun weird_add (a b) {
    $result = (a + b)
    return $result
}]

[weird_add "5" 3]   ;; in this run → 8 (number)
;; next run without any code change → "53" (string)
;; program restart → again 8 or "53", but never an error
```

### Possible results for `("5" + 3)`:

| Function hash `weird_add % 3` | Result |
|-------------------------------|--------|
| 0 | `8` (number, addition) |
| 1 | `"53"` (string, concatenation) |
| 2 | `"8"` (string from number) |

**There are no errors ever.** Everything is coerced into something meaningful.

---

## 3. Paradigm — functional with chaotic side effects

- Functions are first-class objects (can be passed around)
- No loops (only recursion)
- Variables are immutable after `[let $x = ...]`
- But the result of a function with the same arguments can **change** between calls

```lisp
[defun double (x) {
    $r = (x * 2)
    return $r
}]

[double 5]   ;; could be 10, "55", or 7 (if * acted as +)
```

---

## 4. Execution — JIT compilation with reassembly

- Code → bytecode → JIT
- JIT **shuffles type coercion rules** before each run
- Each function call may be recompiled

```bash
chaos --jit-seed=random script.chaos   ;; for reproducibility: --jit-seed=42
```

---

## 5. Memory management — manual

```lisp
[let $buf = [alloc 100]]
[write $buf 0 "hello"]
[free $buf]
[read $buf 0]   ;; returns "world", 42 or "" — not an error
```

---

## 6. Ecosystem

| Item | Value |
|------|-------|
| Application | systems + web |
| Platform | native (machine code via JIT) |
| Package manager | none |
| Tools | only `chaos doc` (documentation changes) |
| License | Open Source (WTFPL) |

---

## 7. Security — maximally unsafe

- No bounds checking
- No stack protection
- Pointer arithmetic
- Reading from `NULL` → `0` or `""` (not an error)

---

# CHAOS LANGUAGE COMMANDS v0.1

**Comment:** `;;` to end of line

---

## 1. Assignment and variables

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| `let` | `[let $x = 5]` | `$x` will be 5 (number) or `"5"` (string) randomly on each program run |
| `let` with expression | `[let $sum = (5 + 3)]` | `$sum` could be `8` (number), `"53"` (string concatenation), or `"8"` (stringified number) |

---

## 2. Arithmetic operations

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| Addition | `("5" + 3)` | `8` (numeric addition) **or** `"53"` (string concatenation) **or** `"8"` (number to string) |
| Multiplication | `(5 * 2)` | `10` **or** `"55"` **or** `7` (if it acted as addition) |
| Subtraction | `(10 - 4)` | `6` **or** `"104"` **or** `14` (if it acted as addition) |
| Division | `(10 / 2)` | `5` **or** `"102"` **or** `12` (if it acted as addition) |

---

## 3. Functions

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| Function definition | `[defun add (a b) { return (a + b) }]` | function created; but each call of `(a + b)` will yield a random result |
| Function call | `[add "5" 3]` | `8`, `"53"`, or `"8"` — randomly on each **call**, not only on program start |
| Return | `return $result` | returns `$result` with whatever type it has at the call moment |

---

## 4. CHAOS special commands

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| `chaos` | `[chaos $x]` | shuffles local rules for the next operation on `$x` |
| `$?` | `[$?]` | returns a random number from 1 to 100; **the same** within a single function call |
| `maybe` | `[maybe 1 0]` | returns `1` or `0` randomly (50/50) |
| `maybe` with strings | `[maybe "hello" "world"]` | returns `"hello"` or `"world"` randomly |
| `fuzzy-match` | `[fuzzy-match "abc" "abc"]` | `true` with 50% probability (even if strings are identical) |
| `unstable-equal` | `[unstable-equal $x $y]` | compares `$x` and `$y`, but may return `true` or `false` randomly |
| `until-chaos` | `[until-chaos { print "x" }]` | executes the body until the result no longer matches the previous one |

---

## 5. Memory operations

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| `alloc` | `[alloc $buf 100]` | allocates 100 bytes; `$buf` gets a pointer (number) |
| `write` | `[write $buf 0 "hello"]` | writes `"hello"` at address `$buf + 0`; may write incompletely |
| `read` | `[read $buf 0]` | reads from memory; may return `"hello"`, `"world"`, `42`, or `""` |
| `free` | `[free $buf]` | frees memory; after this `$buf` can still be read |
| `read` after `free` | `[read $buf 0]` | `"world"`, `42`, `""` — but not an error |

---

## 6. Control flow

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| `if` | `[if ([$?] > 50) { print "yes" }]` | condition is evaluated randomly due to `[$?]` |
| `if` with `else` | `[if ($x) { print "true" } { print "false" }]` | `$x` may be `true` even if `$x` = `0` or `""` |
| `print` | `[print $x]` | prints `$x` as a number or string — randomly |

---

## 7. I/O and Web

| Command | Syntax (example) | Possible results |
|---------|------------------|------------------|
| `http` | `[http GET "https://rand.org/num"]` | may return the number `42` or the string `"42"` — randomly |
| `load` | `[load "std.chaos"]` | loads a file; may load a **different** file (if the path's hash is a multiple of 3) |
| `load` (unsuccessful) | `[load "nonexistent.chaos"]` | not an error! may load `"std.chaos"` instead |

---

## 8. Complete program example

```lisp
;; comment
[load "std.chaos"]   ;; will load std.chaos or another — depending on luck

[defun add_web (a b) {
    [chaos (a + b)]   ;; shuffle rules for this operation
    $num = [http GET "https://rand.org/num"]   ;; number or string
    return [maybe $num a]   ;; returns $num or a randomly
}]

[let $x = [add_web "5" 3]]
[print $x]   ;; may output: 8, "53", "8", 5, "5", 42, "42" — but not an error
```

---

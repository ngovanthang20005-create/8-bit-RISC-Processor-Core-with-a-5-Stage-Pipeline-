8-Bit 5-Stage Pipelined RISC Processor Core
![Language](https://en.wikipedia.org/wiki/Verilog)
![Toolchain](https://www.xilinx.com/products/design-tools/vivado.html)
![Verification Status](#verification-and-results)
![License](LICENSE)
A fully synthesizable 8-bit RISC processor core with a classic 5-stage pipeline (IF, ID, EX, MEM, WB) written in Verilog-2001. Designed, synthesized, and verified in Xilinx Vivado 2026.1, this processor features comprehensive hardware hazard resolution including data forwarding, a register-file bypass, load-use stall insertion, and control-branch flushes.
---
📌 Table of Contents
Architecture Overview
Instruction Set Architecture (ISA)
Pipeline & Hazard Handling
Project Structure
Verification and Results
Synthesis & FPGA Implementation
How to Run Simulation & Synthesis
Author
---
🏗 Architecture Overview
The core utilizes a Harvard Memory Architecture (separate instruction and data memories) to eliminate structural hazards during simultaneous instruction fetching and data memory access.
Data Width: 8-bit registers, ALU, and data RAM.
Instruction Width: Fixed 16-bit instructions.
Registers: 8 general-purpose 8-bit registers (`R0` – `R7`).
Instruction ROM: $256 \times 16$-bit ($256$ instructions).
Data RAM: $256 \times 8$-bit ($256$ bytes).
Flags: Zero (`Z`) and Carry/Borrow (`C`).
Target FPGA: Xilinx Virtex-7 (`xc7vx485tffg1157-1`) or generic Artix-7 series.
```
       +---------------------------------------------------------------+
       |                      risc8\_5stage\_core                        |
       |                                                               |
       |   +--------+      +--------------+      +--------------+      |
  clk ---->|  imem  |----->| Pipeline Reg |----->|     alu      |      |
  rst ---->|  (IF)  |      |   \& Control  |      |     (EX)     |      |
       |   +--------+      +--------------+      +--------------+      |
       |                          |                     |              |
       |                   +--------------+      +--------------+      |
       |                   |   regfile    |      |     dmem     |      |
       |                   |  (ID / WB)   |      |    (MEM)     |      |
       |                   +--------------+      +--------------+      |
       |                          ^                     |              |
       |                          +-- Forwarding Bus ---+              |
       +---------------------------------------------------------------+
```
---
📜 Instruction Set Architecture (ISA)
The processor supports 16 instructions with a fixed 16-bit word length divided into 4 formats:
```
R-type   | \[15:12 Opcode] | \[11:9 rd] | \[8:6 rs1] | \[5:3 rs2] | \[2:0 000]
R1-type  | \[15:12 Opcode] | \[11:9 rd] | \[8:6 rs1] | \[5:0 000000]
I-type   | \[15:12 Opcode] | \[11:9 rd] | \[8 0]     | \[7:0 imm8]
J-type   | \[15:12 Opcode] | \[11:8 0000]           | \[7:0 addr8]
```
Instruction Table
Opcode	Mnemonic	Operation	Flags	Format	Description
`0x0`	NOP	None	-	-	No operation
`0x1`	ADD `rd, rs1, rs2`	$rd \leftarrow rs1 + rs2$	Z, C	R	Arithmetic Addition
`0x2`	SUB `rd, rs1, rs2`	$rd \leftarrow rs1 - rs2$	Z, C	R	Arithmetic Subtraction
`0x3`	AND `rd, rs1, rs2`	$rd \leftarrow rs1 \text{ AND } rs2$	Z	R	Bitwise AND
`0x4`	OR `rd, rs1, rs2`	$rd \leftarrow rs1 \text{ OR } rs2$	Z	R	Bitwise OR
`0x5`	XOR `rd, rs1, rs2`	$rd \leftarrow rs1 \text{ XOR } rs2$	Z	R	Bitwise XOR
`0x6`	SHL `rd, rs1`	$rd \leftarrow rs1 \ll 1$	Z, C	R1	Shift Left (Multiply by 2)
`0x7`	SHR `rd, rs1`	$rd \leftarrow rs1 \gg 1$	Z, C	R1	Shift Right (Logical)
`0x8`	LDI `rd, imm8`	$rd \leftarrow imm8$	-	I	Load Immediate
`0x9`	ADDI `rd, imm8`	$rd \leftarrow rd + imm8$	Z, C	I	Add Immediate
`0xA`	LD `rd, \[rs1]`	$rd \leftarrow RAM[rs1]$	-	R1	Load from Data Memory
`0xB`	ST `rd, \[rs1]`	$RAM[rs1] \leftarrow rd$	-	R1	Store to Data Memory
`0xC`	JMP `addr8`	$PC \leftarrow addr8$	-	J	Unconditional Jump
`0xD`	BZ `addr8`	if $Z=1$, $PC \leftarrow addr8$	-	J	Branch if Zero
`0xE`	BNZ `addr8`	if $Z=0$, $PC \leftarrow addr8$	-	J	Branch if Not Zero
`0xF`	HLT	Freeze execution	-	-	Halt Processor
---
⚡ Pipeline & Hazard Handling
The 5 stages are IF (Instruction Fetch), ID (Instruction Decode), EX (Execute), MEM (Memory Access), and WB (Write-Back).
To maintain continuous execution without corrupting register or memory state, hardware mechanisms resolve hazards automatically:
Structural Hazards: Eliminated via separate Harvard memories and dual-port Register File read operations.
Data Hazards (RAW):
Forwarding Unit: Supplies data directly from `EX/MEM` or `MEM/WB` pipeline registers back to the ALU in `EX` stage ($0$-cycle penalty).
Register File Bypass: Resolves distance-3 dependency if same register is read in `ID` while written in `WB`.
Load-Use Stall: A dependent instruction immediately following a `LD` instruction automatically triggers a 1-cycle hardware stall bubble.
Control Hazards:
Branch conditions (`BZ`, `BNZ`, `JMP`) are evaluated during the `EX` stage using up-to-date ALU flags.
Taken branches perform a 2-cycle pipeline flush, converting wrong-path instructions in `IF/ID` and `ID/EX` into bubbles.
---
📁 Project Structure
```text
├── rtl/
│   ├── alu.v                # Arithmetic Logic Unit \& Flag generation
│   ├── control\_unit.v       # Combinational opcode decoder \& signal generator
│   ├── dmem.v               # 256x8-bit Data RAM module
│   ├── hazard\_unit.v        # Forwarding logic \& stall control unit
│   ├── imem.v               # 256x16-bit Instruction ROM with preloaded program
│   ├── regfile.v            # 8x8-bit Register File with internal bypass logic
│   └── risc8\_5stage\_core.v  # Core Top-Level: Pipeline registers \& datapath wiring
├── sim/
│   └── tb\_risc8\_5stage.v    # Self-checking testbench with trace \& performance logging
├── constraints/
│   └── risc8.xdc            # Vivado timing constraint file (100 MHz clock)
└── README.md
```
---
🧪 Verification and Results
The design was verified using a self-checking testbench (`tb\_risc8\_5stage.v`) running a 34-instruction test program incorporating all instruction classes, load-use dependencies, forward paths, and taken/not-taken branch conditions.
Test Execution Metrics
Total Execution Cycles: 51 cycles
Executed Instructions: 34 instructions
Average CPI: 1.50
Stalls Inserted: 1 load-use stall cycle
Flushes Executed: 6 taken branches ($12$ flush cycles)
Operands Forwarded: 12 instances
Verification Status: `ALL TESTS PASSED` (0 Errors)
```text
============================================================
                   EXECUTION RESULTS SUMMARY                 
============================================================
 \[CHECK] Register R1 = 0x00                     --> PASS
 \[CHECK] Register R2 = 0x0F                     --> PASS
 \[CHECK] Register R3 = 0x01                     --> PASS
 \[CHECK] Register R4 = 0x20                     --> PASS
 \[CHECK] Register R5 = 0x00                     --> PASS
 \[CHECK] Register R6 = 0x66                     --> PASS
 \[CHECK] Register R7 = 0x00                     --> PASS
 \[CHECK] RAM\[0x20]   = 0x0F                     --> PASS
 \[CHECK] Flags \[Z,C] = 2'b11                    --> PASS
------------------------------------------------------------
 \* ALL TESTS PASSED WITH ZERO ERRORS \*
============================================================
```
---
⚙ Synthesis & FPGA Implementation
Synthesis & P&R Tool: Xilinx Vivado 2026.1
Device Target: `xc7vx485tffg1157-1` (Virtex-7)
Clock Frequency: $100\text{ MHz}$ ($10\text{ ns}$ target period)
Code Cleanliness: $0$ Latch warnings, $0$ Critical warnings (fully synthesizable Verilog-2001)
Post-implementation netlist optimization leaves control flow registers (PC, valid bits) intact while constant-folding unused ROM paths.
---
🚀 How to Run Simulation & Synthesis
1. Using Xilinx Vivado (GUI)
Open Vivado and create a new RTL Project named `8bit`.
Select target FPGA device: `xc7vx485tffg1157-1` (or your preferred Artix-7/Basys-3 board).
Import design sources from `rtl/` and set `risc8\_5stage\_core.v` as Top.
Import simulation file `sim/tb\_risc8\_5stage.v`.
Import constraints `constraints/risc8.xdc`.
Run Behavioral Simulation (completes at 545 ns with `ALL TESTS PASSED`).
Click Run Synthesis $\rightarrow$ Run Implementation $\rightarrow$ Generate Bitstream.
2. Using Icarus Verilog & GTKWave (CLI)
```bash
# Compile design and testbench
iverilog -g2001 -o processor\_tb rtl/\*.v sim/tb\_risc8\_5stage.v

# Execute simulation
vvp processor\_tb
```
---
👤 Author
Student Name: NGÔ VĂN THẮNG
Student ID: SS190566
Project Date: October 2026

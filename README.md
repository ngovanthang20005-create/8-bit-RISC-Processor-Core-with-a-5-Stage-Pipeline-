8-bit RISC Processor Core with 5-Stage Pipeline (Verilog HDL)
![Verilog](https://img.shields.io/badge/Language-Verilog--2001-blue.svg)
![Tool](https://img.shields.io/badge/Tool-Xilinx%20Vivado%202026.1-orange.svg)
[![Verification](https://img.shields.io/badge/Verification-100%25%20Passed-brightgreen.svg)]()
![License](https://img.shields.io/badge/License-MIT-green.svg)
An 8-bit RISC processor core featuring a classic 5-stage pipeline (IF, ID, EX, MEM, WB), written in synthesizable Verilog-2001. The design includes dynamic hazard handling (data forwarding, load-use stalls, branch flushes) and a Harvard memory architecture. Verified using Xilinx Vivado 2026.1 with a self-checking testbench.
---
📌 Features
Architecture: Harvard memory setup (256 × 16-bit ROM for Instructions, 256 × 8-bit RAM for Data).
Pipeline Stages: 5-Stage classic pipeline (`IF` -> `ID` -> `EX` -> `MEM` -> `WB`).
Register File: 8 general-purpose 8-bit registers (`R0`–`R7`) with dual read ports and internal write-bypass.
Instruction Set: 16 instructions (4-bit opcode, fixed 16-bit instruction length).
Hazard Resolution:
Data Hazards: Register-file bypass and 3-way result forwarding (EX/MEM -> EX, MEM/WB -> EX).
Load-Use Stall: 1-cycle pipeline freeze via Hazard Unit.
Control Hazards: 2-cycle branch flush on taken branches/jumps.
Flags: Zero ($Z$) and Carry ($C$) flags updated by arithmetic, logic, and shift operations.
Synthesis Quality: Clean, latch-free code; targets Xilinx Virtex-7 / Artix-7 FPGAs.
---
🏗️ Block Diagram & Datapath
The core consists of 6 modular components tied together by a central 5-stage pipeline top level:
```
                  +-------------------------------------------------------+
                  |                 risc8_5stage_core                     |
                  |                                                       |
  +---------+     |  +----------+    +--------------+    +-------------+  |
  |  imem   |---->|  |   IF/ID  |--->| control_unit |--->|    ID/EX    |  |
  |  (ROM)  |     |  +----------+    +--------------+    +-------------+  |
  +---------+     |                         |                   |         |
                  |                         v                   v         |
  +---------+     |                  +--------------+    +-------------+  |
  | regfile |<----+----------------->| hazard_unit  |--->|     alu     |  |
  +---------+     |                  +--------------+    +-------------+  |
                  |                                             |         |
  +---------+     |                                             v         |
  |  dmem   |<----+------------------------------------->+-------------+  |
  |  (RAM)  |     |                                      |   EX/MEM    |  |
  +---------+     |                                      +-------------+  |
                  |                                             |         |
                  |                                             v         |
                  |                                      +-------------+  |
                  |                                      |   MEM/WB    |  |
                  |                                      +-------------+  |
                  +-------------------------------------------------------+
```
---
📑 Instruction Set Architecture (ISA)
All instructions are fixed 16 bits in width:
Format	Bit 15..12	Bit 11..9	Bit 8..6	Bit 5..3	Bit 2..0	Instructions
R-type	`opcode`	`rd`	`rs1`	`rs2`	`000`	`ADD`, `SUB`, `AND`, `OR`, `XOR`
R1-type	`opcode`	`rd`	`rs1`	`000000`		`SHL`, `SHR`, `LD`, `ST`
I-type	`opcode`	`rd`	`0`	`imm8` (7..0)		`LDI`, `ADDI`
J-type	`opcode`	`0000`	`addr8` (7..0)			`JMP`, `BZ`, `BNZ`
Instruction Table
Opcode (Hex)	Mnemonic	Format	Operation	Flags
`0x0`	`NOP`	-	No operation	-
`0x1`	`ADD rd, rs1, rs2`	R	$rd \leftarrow rs1 + rs2$	$Z, C$
`0x2`	`SUB rd, rs1, rs2`	R	$rd \leftarrow rs1 - rs2$	$Z, C$
`0x3`	`AND rd, rs1, rs2`	R	$rd \leftarrow rs1 \text{ AND } rs2$	$Z$
`0x4`	`OR rd, rs1, rs2`	R	$rd \leftarrow rs1 \text{ OR } rs2$	$Z$
`0x5`	`XOR rd, rs1, rs2`	R	$rd \leftarrow rs1 \text{ XOR } rs2$	$Z$
`0x6`	`SHL rd, rs1`	R1	$rd \leftarrow rs1 \ll 1$	$Z, C$
`0x7`	`SHR rd, rs1`	R1	$rd \leftarrow rs1 \gg 1$	$Z, C$
`0x8`	`LDI rd, imm8`	I	$rd \leftarrow imm8$	-
`0x9`	`ADDI rd, imm8`	I	$rd \leftarrow rd + imm8$	$Z, C$
`0xA`	`LD rd, [rs1]`	R1	$rd \leftarrow \text{RAM}[rs1]$	-
`0xB`	`ST rd, [rs1]`	R1	$\text{RAM}[rs1] \leftarrow rd$	-
`0xC`	`JMP addr8`	J	$PC \leftarrow addr8$	-
`0xD`	`BZ addr8`	J	if $Z == 1$, $PC \leftarrow addr8$	-
`0xE`	`BNZ addr8`	J	if $Z == 0$, $PC \leftarrow addr8$	-
`0xF`	`HLT`	-	Stop execution	-
---
📁 Repository Structure
```
├── rtl/
│   ├── alu.v                 # 8-bit ALU (Arithmetic, Logic, Shifts, Flags)
│   ├── control_unit.v        # Combinational Instruction Decoder
│   ├── dmem.v                # 256x8-bit Synchronous/Asynchronous Data RAM
│   ├── hazard_unit.v         # Forwarding Unit and Stall Logic
│   ├── imem.v                # 256x16-bit Instruction ROM (Preloaded)
│   ├── regfile.v             # 8x8-bit Register File with Internal Bypass
│   └── risc8_5stage_core.v   # Top-Level Core Pipeline Module
├── tb/
│   └── tb_risc8_5stage.v     # Self-Checking Verification Testbench
├── constraints/
│   └── risc8.xdc             # Timing and Clock Constraints (100 MHz)
├── docs/
│   └── RISC8_5Stage_Pipeline_Report.pdf  # Full Project Design & Verification Report
├── LICENSE                   # MIT License
└── README.md                 # Project Overview
```
---
⚡ Verification & Results
A test program consisting of 34 instructions (covering arithmetic loops, memory transfers, load-use dependencies, conditional branching, and flushing) was executed on the self-checking testbench.
Simulation Output Metrics
```text
============================================================
                   SIMULATION COMPLETE
============================================================
Total Cycles        : 51
Retired Instructions: 34
Measured CPI        : 1.50
Load-Use Stalls     : 1
Branch Flushes      : 6 (12 cycles wasted)
Forwarded Operands  : 12
Error Count         : 0
Status              : *** ALL TESTS PASSED ***
============================================================
```
Resource & Timing Summary (Vivado 2026.1)
Target Device: `xc7vx485tffg1157-1` (Virtex-7) / compatible with `xc7a35t` (Artix-7).
Synthesis: Completely clean; 0 Warnings, 0 Unintended Latches.
Post-Implementation Cells: 36 logic cells / flip-flops (Control path retained under optimizations).
Timing Constraint: Met target clock frequency of 100 MHz ($T_{clk} = 10\text{ ns}$).
---
🚀 How to Run (Xilinx Vivado)
Clone Repository:
```bash
   git clone https://github.com/your-username/risc8-5stage-pipeline.git
   cd risc8-5stage-pipeline
   ```
Create Vivado Project:
Open Xilinx Vivado.
Create an RTL Project named `8bit`.
Add all `.v` files from the `rtl/` directory as Design Sources.
Add `tb/tb_risc8_5stage.v` as a Simulation Source.
Add `constraints/risc8.xdc` as a Constraint File.
Set `risc8_5stage_core` as the top module.
Run Behavioral Simulation:
Navigate to Flow Navigator -> Simulation -> Run Behavioral Simulation.
Observe the Tcl Console; verify that it prints `*** ALL TESTS PASSED ***` at time `545 ns`.
Run Synthesis & Implementation:
Click Run Synthesis and check for zero latch warnings.
Click Run Implementation and view Report Timing Summary (ensure $WNS \ge 0$).
---
👤 Author
Name: Ngô Văn Thắng
Student ID: SS190566
Tool Standard: Xilinx Vivado 2026.1 / Verilog-2001
---
📜 License
This project is released under the MIT License.

# RISC-V 5-Stage Pipeline — UVM Verification Testbench

A complete UVM-based verification environment for a 5-stage pipelined RISC-V processor, implementing the RV32I base integer instruction set. Built to verify correct pipeline behavior under hazard conditions, data forwarding, and branch flush scenarios.

---

## Project Overview

| Item | Detail |
|---|---|
| **Architecture** | 5-stage pipeline: IF → ID → EX → MEM → WB |
| **ISA** | RISC-V RV32I (R-type, I-type, Branch) |
| **Verification methodology** | UVM 1.2 |
| **Simulators supported** | Synopsys VCS, Cadence Xcelium |
| **Waveform debug** | Synopsys Verdi (.fsdb) |
| **Coverage achieved** | >95% code and functional coverage |
| **Language** | SystemVerilog |

---

## Repository Structure

```
riscv-uvm-verification/
├── rtl/
│   └── riscv_pipeline.sv        # 5-stage RISC-V pipeline RTL
├── tb/
│   ├── tb_top.sv                # Testbench top module
│   ├── riscv_interface.sv       # Interface with clocking blocks
│   ├── riscv_transaction.sv     # UVM sequence item
│   ├── riscv_sequence.sv        # Random, hazard & directed sequences
│   ├── riscv_driver.sv          # UVM driver
│   ├── riscv_monitor.sv         # UVM monitor with analysis port
│   ├── riscv_scoreboard.sv      # Self-checking reference model
│   ├── riscv_agent.sv           # UVM agent (active/passive)
│   └── riscv_env.sv             # Environment + test classes
└── scripts/
    └── run_sim.tcl              # VCS/Xcelium compile & sim script
```

---

## UVM Testbench Architecture

```
+---------------------------+
|        UVM Test           |
|  riscv_random_test        |
|  riscv_hazard_test        |
+----------+----------------+
           |
+----------v----------------+
|        UVM Env            |
|  +--------+  +---------+  |
|  | Agent  |  |Scoreboard|  |
|  |        |  |         |  |
|  |Seq'cer |  |Ref Model|  |
|  |Driver  |  |Pass/Fail|  |
|  |Monitor +-->         |  |
|  +---+----+  +---------+  |
+------|--------------------+
       |
+------v-------+
|  Interface   |  ← clocking blocks
+------+-------+
       |
+------v-------+
|     DUT      |
| riscv_pipeline|
+--------------+
```

---

## Features Verified

### Hazard Detection & Resolution
- **RAW (Read After Write)** data hazards — back-to-back dependent instructions
- **Load-use hazards** — stall insertion when load result needed immediately
- **Control hazards** — pipeline flush on branch instructions

### Data Forwarding
- EX/MEM → EX forwarding path
- MEM/WB → EX forwarding path
- Correct operand selection via forwarding mux

### Instruction Coverage
- R-type: ADD, SUB, AND, OR, XOR, SLL, SRL
- I-type: ADDI, ANDI, ORI, XORI
- Branch: BEQ with flush verification

### Corner Cases
- Write to x0 register (must always read back 0)
- Maximum immediate value (12-bit sign-extended)
- Self-dependent operations (rs1 == rs2 == rd)

---

## Test Suite

| Test | Description | Transactions |
|---|---|---|
| `riscv_random_test` | Fully constrained-random stimulus | 100 |
| `riscv_hazard_test` | RAW hazards + branch flush + corner cases | ~35 |

---

## How to Run

### Synopsys VCS
```bash
cd scripts

# Compile
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -debug_access+all -cm line+cond+fsm+branch+tgl \
    +incdir+../tb ../rtl/riscv_pipeline.sv ../tb/tb_top.sv -o simv

# Run random test
./simv +UVM_TESTNAME=riscv_random_test +UVM_VERBOSITY=UVM_MEDIUM

# Run hazard test
./simv +UVM_TESTNAME=riscv_hazard_test +UVM_VERBOSITY=UVM_MEDIUM

# Coverage report
urg -dir coverage.vdb -format both -report coverage_report
```

### Cadence Xcelium
```bash
xrun -64bit -sv -uvm -timescale 1ns/1ps -access +rwc \
     +incdir+../tb ../rtl/riscv_pipeline.sv ../tb/tb_top.sv \
     +UVM_TESTNAME=riscv_random_test
```

### View Waveforms (Verdi)
```bash
verdi -ssf riscv_pipeline.fsdb &
```

---

## Scoreboard Output Example

```
[SCOREBOARD] ============================================
[SCOREBOARD]           SCOREBOARD FINAL REPORT
[SCOREBOARD] ============================================
[SCOREBOARD]   Total transactions : 100
[SCOREBOARD]   PASSED            : 100
[SCOREBOARD]   FAILED            : 0
[SCOREBOARD] ============================================
[SCOREBOARD]   RESULT: ** ALL TESTS PASSED **
```

---

## Skills Demonstrated

- UVM layered testbench architecture (transaction, sequence, driver, monitor, scoreboard, agent, env)
- Constrained-random stimulus generation with functional coverage
- SystemVerilog assertions and clocking blocks
- Hazard detection and forwarding verification
- Coverage-driven regression flow (VCS + URG)
- Waveform debug with Synopsys Verdi
- Tcl/automation scripting for simulation flow

---

## Author

**Charan Gowda Devaraja**  
MS Computer Engineering — University of Texas at Dallas  
[LinkedIn](https://linkedin.com/in/charan-gowda-devaraja-a57b31217)
# ============================================================
# run_sim.tcl
# Simulation run script for RISC-V UVM Testbench
# Supports Synopsys VCS and Cadence Xcelium
# Usage:
#   VCS:     vcs -f run_sim.tcl +UVM_TESTNAME=riscv_random_test
#   Xcelium: xrun -f run_sim.tcl +UVM_TESTNAME=riscv_hazard_test
# ============================================================

# -------------------------------------------------------
# Source file list
# -------------------------------------------------------
set RTL_FILES {
  ../rtl/riscv_pipeline.sv
}

set TB_FILES {
  ../tb/riscv_transaction.sv
  ../tb/riscv_interface.sv
  ../tb/riscv_sequence.sv
  ../tb/riscv_driver.sv
  ../tb/riscv_monitor.sv
  ../tb/riscv_scoreboard.sv
  ../tb/riscv_agent.sv
  ../tb/riscv_env.sv
  ../tb/tb_top.sv
}

# -------------------------------------------------------
# Compilation flags
# -------------------------------------------------------
set VCS_FLAGS {
  -full64
  -sverilog
  -ntb_opts uvm-1.2
  -timescale=1ns/1ps
  -debug_access+all
  -cm line+cond+fsm+branch+tgl
  +define+UVM_NO_DEPRECATED
  +incdir+../tb
  -o simv
}

set XCELIUM_FLAGS {
  -64bit
  -sv
  -uvm
  -timescale 1ns/1ps
  -access +rwc
  -coverage all
  +incdir+../tb
}

# -------------------------------------------------------
# Simulation flags
# -------------------------------------------------------
set SIM_FLAGS {
  +UVM_VERBOSITY=UVM_MEDIUM
  +UVM_TIMEOUT=10000000
  -cm_dir coverage.vdb
}

# -------------------------------------------------------
# Available tests
# -------------------------------------------------------
# +UVM_TESTNAME=riscv_random_test   → 100 random instructions
# +UVM_TESTNAME=riscv_hazard_test   → RAW + branch + corner cases

# -------------------------------------------------------
# Coverage goals
# -------------------------------------------------------
# Target: >95% line, condition, FSM, branch, toggle coverage
# Run coverage regression:
#   urg -dir coverage.vdb -report coverage_report

# -------------------------------------------------------
# Waveform viewing (Synopsys Verdi)
# -------------------------------------------------------
# verdi -ssf riscv_pipeline.fsdb &

# -------------------------------------------------------
# Example full run commands
# -------------------------------------------------------
# Random test:
#   vcs [VCS_FLAGS] [RTL_FILES] [TB_FILES]
#   ./simv [SIM_FLAGS] +UVM_TESTNAME=riscv_random_test
#
# Hazard test:
#   ./simv [SIM_FLAGS] +UVM_TESTNAME=riscv_hazard_test
#
# Coverage report:
#   urg -dir coverage.vdb -format both -report coverage_report

puts "============================================"
puts "  RISC-V UVM Verification Run Script"
puts "  Available tests:"
puts "    riscv_random_test  - constrained random"
puts "    riscv_hazard_test  - hazard + corner cases"
puts "============================================"

// ============================================================
// tb_top.sv
// Testbench Top Module - instantiates DUT, interface,
// and kicks off UVM test
// ============================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// Include all testbench files
`include "riscv_transaction.sv"
`include "riscv_interface.sv"
`include "riscv_sequence.sv"
`include "riscv_driver.sv"
`include "riscv_monitor.sv"
`include "riscv_scoreboard.sv"
`include "riscv_agent.sv"
`include "riscv_env.sv"

module tb_top;

  // -------------------------------------------------------
  // Clock and reset generation
  // -------------------------------------------------------
  logic clk;
  logic rst_n;

  // 10ns clock period (100MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // Reset: assert for 5 cycles then deassert
  initial begin
    rst_n = 1'b0;
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    `uvm_info("TB_TOP", "Reset deasserted", UVM_MEDIUM)
  end

  // -------------------------------------------------------
  // Interface instantiation
  // -------------------------------------------------------
  riscv_interface dut_if(.clk(clk), .rst_n(rst_n));

  // -------------------------------------------------------
  // DUT instantiation
  // -------------------------------------------------------
  riscv_pipeline dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .instr_in  (dut_if.instr_in),
    .pc_in     (dut_if.pc_in),
    .stall     (dut_if.stall),
    .flush     (dut_if.flush),
    .result_out(dut_if.result_out),
    .rd_out    (dut_if.rd_out),
    .valid_out (dut_if.valid_out),
    .data_hazard(dut_if.data_hazard),
    .ctrl_hazard(dut_if.ctrl_hazard)
  );

  // -------------------------------------------------------
  // Pass interface to UVM config DB
  // so all components can access it
  // -------------------------------------------------------
  initial begin
    uvm_config_db #(virtual riscv_interface)::set(
      null, "uvm_test_top.*", "vif", dut_if
    );
  end

  // -------------------------------------------------------
  // Start UVM test
  // Test name passed via +UVM_TESTNAME on command line:
  //   +UVM_TESTNAME=riscv_random_test
  //   +UVM_TESTNAME=riscv_hazard_test
  // -------------------------------------------------------
  initial begin
    run_test();
  end

  // -------------------------------------------------------
  // Timeout watchdog - kill sim if it hangs
  // -------------------------------------------------------
  initial begin
    #1_000_000;
    `uvm_fatal("TB_TOP", "SIMULATION TIMEOUT - check for deadlock")
  end

  // -------------------------------------------------------
  // Waveform dump for Synopsys Verdi / DVE
  // -------------------------------------------------------
  initial begin
    $fsdbDumpfile("riscv_pipeline.fsdb");
    $fsdbDumpvars(0, tb_top);
  end

endmodule

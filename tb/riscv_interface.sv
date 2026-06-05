// ============================================================
// riscv_interface.sv
// Interface connecting DUT to UVM testbench
// ============================================================

interface riscv_interface(input logic clk, input logic rst_n);

  // -------------------------------------------------------
  // Instruction fetch signals
  // -------------------------------------------------------
  logic [31:0] instr_in;       // Instruction fed into pipeline
  logic [31:0] pc_in;          // Program counter input

  // -------------------------------------------------------
  // Pipeline control signals
  // -------------------------------------------------------
  logic        stall;          // Stall the pipeline
  logic        flush;          // Flush pipeline (branch mispredict)

  // -------------------------------------------------------
  // Write-back / output signals
  // -------------------------------------------------------
  logic [31:0] result_out;     // Result from execute stage
  logic [4:0]  rd_out;         // Destination register
  logic        valid_out;      // Output is valid this cycle

  // -------------------------------------------------------
  // Hazard detection signals
  // -------------------------------------------------------
  logic        data_hazard;    // Data hazard detected
  logic        ctrl_hazard;    // Control hazard detected

  // -------------------------------------------------------
  // Clocking block - Driver uses this to drive inputs
  // synchronously with the clock
  // -------------------------------------------------------
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output instr_in;
    output pc_in;
    output stall;
    output flush;
  endclocking

  // -------------------------------------------------------
  // Clocking block - Monitor uses this to sample outputs
  // -------------------------------------------------------
  clocking monitor_cb @(posedge clk);
    default input #1;
    input result_out;
    input rd_out;
    input valid_out;
    input data_hazard;
    input ctrl_hazard;
  endclocking

  // -------------------------------------------------------
  // Modports
  // -------------------------------------------------------
  modport driver_mp  (clocking driver_cb,  input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);

endinterface

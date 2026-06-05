// ============================================================
// riscv_scoreboard.sv
// UVM Scoreboard - self-checking component that compares
// DUT output against a reference model
// ============================================================

class riscv_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(riscv_scoreboard)

  // Analysis export - receives transactions from monitor
  uvm_analysis_imp #(riscv_transaction, riscv_scoreboard) analysis_export;

  // -------------------------------------------------------
  // Counters for summary report
  // -------------------------------------------------------
  int unsigned pass_count;
  int unsigned fail_count;
  int unsigned total_count;

  // Reference register file (32 x 32-bit registers)
  logic [31:0] ref_regfile [32];

  // -------------------------------------------------------
  // Constructor
  // -------------------------------------------------------
  function new(string name = "riscv_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    pass_count  = 0;
    fail_count  = 0;
    total_count = 0;
  endfunction

  // -------------------------------------------------------
  // Build phase
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    // Initialize reference register file to 0
    foreach (ref_regfile[i]) ref_regfile[i] = 32'h0;
  endfunction

  // -------------------------------------------------------
  // Write - called automatically when monitor broadcasts
  // -------------------------------------------------------
  function void write(riscv_transaction txn);
    logic [31:0] expected;

    total_count++;

    // Compute expected result from reference model
    expected = compute_expected(txn);

    // Compare DUT output vs reference
    if (txn.result === expected) begin
      pass_count++;
      `uvm_info("SCOREBOARD",
        $sformatf("PASS [%0d] rd=x%0d | expected=0x%0h | got=0x%0h",
          total_count, txn.rd, expected, txn.result),
        UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SCOREBOARD",
        $sformatf("FAIL [%0d] rd=x%0d | expected=0x%0h | got=0x%0h",
          total_count, txn.rd, expected, txn.result))
    end

    // Update reference register file with result
    if (txn.rd != 0) // x0 is always 0 in RISC-V
      ref_regfile[txn.rd] = txn.result;

  endfunction

  // -------------------------------------------------------
  // Reference model - computes expected output
  // -------------------------------------------------------
  function logic [31:0] compute_expected(riscv_transaction txn);
    case (txn.opcode)
      7'b0110011: begin // R-type
        case (txn.instruction[14:12]) // funct3
          3'b000: return (txn.instruction[30]) ?
                    ref_regfile[txn.rs1] - ref_regfile[txn.rs2] : // SUB
                    ref_regfile[txn.rs1] + ref_regfile[txn.rs2];  // ADD
          3'b111: return ref_regfile[txn.rs1] & ref_regfile[txn.rs2]; // AND
          3'b110: return ref_regfile[txn.rs1] | ref_regfile[txn.rs2]; // OR
          3'b100: return ref_regfile[txn.rs1] ^ ref_regfile[txn.rs2]; // XOR
          default: return 32'hx;
        endcase
      end
      7'b0010011: begin // I-type
        case (txn.instruction[14:12])
          3'b000: return ref_regfile[txn.rs1] + txn.imm; // ADDI
          3'b111: return ref_regfile[txn.rs1] & txn.imm; // ANDI
          3'b110: return ref_regfile[txn.rs1] | txn.imm; // ORI
          default: return 32'hx;
        endcase
      end
      default: return 32'hx;
    endcase
  endfunction

  // -------------------------------------------------------
  // Report phase - print final summary
  // -------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
    `uvm_info("SCOREBOARD", "          SCOREBOARD FINAL REPORT           ", UVM_NONE)
    `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf("  Total transactions : %0d", total_count), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf("  PASSED            : %0d", pass_count),   UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf("  FAILED            : %0d", fail_count),   UVM_NONE)
    `uvm_info("SCOREBOARD", "============================================", UVM_NONE)

    if (fail_count == 0)
      `uvm_info("SCOREBOARD", "  RESULT: ** ALL TESTS PASSED **", UVM_NONE)
    else
      `uvm_error("SCOREBOARD", $sformatf("  RESULT: ** %0d TESTS FAILED **", fail_count))
  endfunction

endclass

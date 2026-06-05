// ============================================================
// riscv_sequence.sv
// UVM Sequences - generates streams of transactions
// Includes base, random, hazard, and directed sequences
// ============================================================

// -------------------------------------------------------
// Base sequence - all sequences extend from this
// -------------------------------------------------------
class riscv_base_sequence extends uvm_sequence #(riscv_transaction);

  `uvm_object_utils(riscv_base_sequence)

  function new(string name = "riscv_base_sequence");
    super.new(name);
  endfunction

endclass


// -------------------------------------------------------
// Random sequence - fully constrained-random instructions
// Used for coverage-driven verification
// -------------------------------------------------------
class riscv_random_sequence extends riscv_base_sequence;

  `uvm_object_utils(riscv_random_sequence)

  int unsigned num_transactions = 50;

  function new(string name = "riscv_random_sequence");
    super.new(name);
  endfunction

  task body();
    riscv_transaction txn;
    `uvm_info("SEQ", $sformatf("Starting random sequence (%0d transactions)", num_transactions), UVM_MEDIUM)

    repeat(num_transactions) begin
      txn = riscv_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask

endclass


// -------------------------------------------------------
// R-type sequence - targets ADD, SUB, AND, OR, XOR
// -------------------------------------------------------
class riscv_rtype_sequence extends riscv_base_sequence;

  `uvm_object_utils(riscv_rtype_sequence)

  function new(string name = "riscv_rtype_sequence");
    super.new(name);
  endfunction

  task body();
    riscv_transaction txn;
    `uvm_info("SEQ", "Starting R-type directed sequence", UVM_MEDIUM)

    repeat(20) begin
      txn = riscv_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with {
        opcode == 7'b0110011; // Force R-type only
      })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask

endclass


// -------------------------------------------------------
// Hazard sequence - back-to-back instructions that
// create data hazards (RAW - Read After Write)
// -------------------------------------------------------
class riscv_hazard_sequence extends riscv_base_sequence;

  `uvm_object_utils(riscv_hazard_sequence)

  function new(string name = "riscv_hazard_sequence");
    super.new(name);
  endfunction

  task body();
    riscv_transaction txn1, txn2, txn3;
    `uvm_info("SEQ", "Starting RAW hazard sequence", UVM_MEDIUM)

    // Generate RAW hazard: txn1 writes to rd=x5,
    // txn2 immediately reads from rs1=x5
    repeat(10) begin
      // Instruction 1: writes to x5
      txn1 = riscv_transaction::type_id::create("txn1");
      start_item(txn1);
      if (!txn1.randomize() with {
        opcode == 7'b0110011;
        rd == 5'd5;
      })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn1);

      // Instruction 2: reads x5 immediately (RAW hazard)
      txn2 = riscv_transaction::type_id::create("txn2");
      start_item(txn2);
      if (!txn2.randomize() with {
        opcode == 7'b0110011;
        rs1 == 5'd5; // Depends on txn1 result
      })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn2);
    end
    `uvm_info("SEQ", "RAW hazard sequence complete", UVM_MEDIUM)
  endtask

endclass


// -------------------------------------------------------
// Branch sequence - tests control hazards and
// pipeline flush behavior
// -------------------------------------------------------
class riscv_branch_sequence extends riscv_base_sequence;

  `uvm_object_utils(riscv_branch_sequence)

  function new(string name = "riscv_branch_sequence");
    super.new(name);
  endfunction

  task body();
    riscv_transaction txn;
    `uvm_info("SEQ", "Starting branch/control hazard sequence", UVM_MEDIUM)

    repeat(15) begin
      txn = riscv_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with {
        opcode == 7'b1100011; // Branch instructions only
      })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask

endclass


// -------------------------------------------------------
// Corner case sequence - targets edge conditions:
// x0 register writes, max immediate values, self-dependent ops
// -------------------------------------------------------
class riscv_corner_sequence extends riscv_base_sequence;

  `uvm_object_utils(riscv_corner_sequence)

  function new(string name = "riscv_corner_sequence");
    super.new(name);
  endfunction

  task body();
    riscv_transaction txn;
    `uvm_info("SEQ", "Starting corner case sequence", UVM_MEDIUM)

    // Test 1: Write to x0 (should always read back as 0)
    txn = riscv_transaction::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with { rd == 5'd0; })
      `uvm_fatal("SEQ", "Randomization failed")
    finish_item(txn);

    // Test 2: Max immediate value
    txn = riscv_transaction::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      opcode == 7'b0010011;
      imm == 32'hFFF;
    })
      `uvm_fatal("SEQ", "Randomization failed")
    finish_item(txn);

    // Test 3: rs1 == rs2 == rd (self-dependent operation)
    txn = riscv_transaction::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      opcode == 7'b0110011;
      rd == rs1;
      rs1 == rs2;
    })
      `uvm_fatal("SEQ", "Randomization failed")
    finish_item(txn);

    `uvm_info("SEQ", "Corner case sequence complete", UVM_MEDIUM)
  endtask

endclass

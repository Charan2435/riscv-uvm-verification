// ============================================================
// riscv_env.sv
// UVM Environment - top-level verification container
// Instantiates agent, scoreboard, and coverage collector
// ============================================================

class riscv_env extends uvm_env;

  `uvm_component_utils(riscv_env)

  // -------------------------------------------------------
  // Environment sub-components
  // -------------------------------------------------------
  riscv_agent      agent;
  riscv_scoreboard scoreboard;

  // -------------------------------------------------------
  // Constructor
  // -------------------------------------------------------
  function new(string name = "riscv_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------
  // Build phase - create all sub-components
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = riscv_agent::type_id::create("agent", this);
    scoreboard = riscv_scoreboard::type_id::create("scoreboard", this);
    `uvm_info("ENV", "Environment built: agent + scoreboard", UVM_MEDIUM)
  endfunction

  // -------------------------------------------------------
  // Connect phase - wire monitor output to scoreboard
  // -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.ap.connect(scoreboard.analysis_export);
    `uvm_info("ENV", "Monitor analysis port connected to scoreboard", UVM_MEDIUM)
  endfunction

endclass


// ============================================================
// riscv_base_test.sv
// Base test - all tests extend from this
// Sets up env and provides helper tasks
// ============================================================

class riscv_base_test extends uvm_test;

  `uvm_component_utils(riscv_base_test)

  riscv_env env;

  function new(string name = "riscv_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = riscv_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "Base test run phase - override in derived tests", UVM_MEDIUM)
    phase.drop_objection(this);
  endtask

endclass


// ============================================================
// Random test - runs fully constrained-random stimulus
// ============================================================

class riscv_random_test extends riscv_base_test;

  `uvm_component_utils(riscv_random_test)

  function new(string name = "riscv_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    riscv_random_sequence seq;
    phase.raise_objection(this);

    seq = riscv_random_sequence::type_id::create("seq");
    seq.num_transactions = 100;
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask

endclass


// ============================================================
// Hazard test - targets RAW data hazards specifically
// ============================================================

class riscv_hazard_test extends riscv_base_test;

  `uvm_component_utils(riscv_hazard_test)

  function new(string name = "riscv_hazard_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    riscv_hazard_sequence   hazard_seq;
    riscv_branch_sequence   branch_seq;
    riscv_corner_sequence   corner_seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Running hazard test suite", UVM_MEDIUM)

    // Run RAW hazard sequence
    hazard_seq = riscv_hazard_sequence::type_id::create("hazard_seq");
    hazard_seq.start(env.agent.sequencer);

    // Run branch/control hazard sequence
    branch_seq = riscv_branch_sequence::type_id::create("branch_seq");
    branch_seq.start(env.agent.sequencer);

    // Run corner cases
    corner_seq = riscv_corner_sequence::type_id::create("corner_seq");
    corner_seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask

endclass

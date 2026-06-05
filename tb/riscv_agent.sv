// ============================================================
// riscv_agent.sv
// UVM Agent - bundles driver, monitor, and sequencer
// together into a reusable verification component
// ============================================================

class riscv_agent extends uvm_agent;

  `uvm_component_utils(riscv_agent)

  // -------------------------------------------------------
  // Agent sub-components
  // -------------------------------------------------------
  riscv_driver                    driver;
  riscv_monitor                   monitor;
  uvm_sequencer #(riscv_transaction) sequencer;

  // Analysis port - forwards monitor output up to env
  uvm_analysis_port #(riscv_transaction) ap;

  // -------------------------------------------------------
  // Constructor
  // -------------------------------------------------------
  function new(string name = "riscv_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------
  // Build phase - create sub-components
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    monitor   = riscv_monitor::type_id::create("monitor", this);
    ap        = new("ap", this);

    // Only create driver and sequencer for active agent
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = riscv_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer #(riscv_transaction)::type_id::create("sequencer", this);
      `uvm_info("AGENT", "Active agent: driver + sequencer created", UVM_MEDIUM)
    end else begin
      `uvm_info("AGENT", "Passive agent: monitor only", UVM_MEDIUM)
    end
  endfunction

  // -------------------------------------------------------
  // Connect phase - wire up TLM ports
  // -------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    // Connect monitor analysis port up to env level
    monitor.ap.connect(ap);

    // Connect driver to sequencer (active only)
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass

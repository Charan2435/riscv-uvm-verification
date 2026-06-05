// ============================================================
// riscv_monitor.sv
// UVM Monitor - observes pipeline outputs and broadcasts
// transactions to scoreboard via analysis port
// ============================================================

class riscv_monitor extends uvm_monitor;

  `uvm_component_utils(riscv_monitor)

  // Virtual interface handle
  virtual riscv_interface.monitor_mp vif;

  // Analysis port - broadcasts observed transactions
  // to scoreboard and coverage collector
  uvm_analysis_port #(riscv_transaction) ap;

  // -------------------------------------------------------
  // Constructor
  // -------------------------------------------------------
  function new(string name = "riscv_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------
  // Build phase
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual riscv_interface)::get(this, "", "vif", vif))
      `uvm_fatal("MONITOR", "Could not get virtual interface from config DB")
  endfunction

  // -------------------------------------------------------
  // Run phase - continuously samples interface outputs
  // -------------------------------------------------------
  task run_phase(uvm_phase phase);
    riscv_transaction txn;

    // Wait for reset
    @(posedge vif.clk iff vif.rst_n === 1'b1);
    `uvm_info("MONITOR", "Reset deasserted, starting to monitor", UVM_MEDIUM)

    forever begin
      @(vif.monitor_cb);

      // Only capture when output is valid
      if (vif.monitor_cb.valid_out) begin
        txn = riscv_transaction::type_id::create("txn");

        // Sample output signals
        txn.result   = vif.monitor_cb.result_out;
        txn.rd       = vif.monitor_cb.rd_out;
        txn.valid    = vif.monitor_cb.valid_out;

        // Log hazard conditions
        if (vif.monitor_cb.data_hazard)
          `uvm_info("MONITOR", "Data hazard detected", UVM_MEDIUM)

        if (vif.monitor_cb.ctrl_hazard)
          `uvm_info("MONITOR", "Control hazard detected", UVM_MEDIUM)

        `uvm_info("MONITOR",
          $sformatf("Observed: rd=x%0d result=0x%0h valid=%0b",
            txn.rd, txn.result, txn.valid),
          UVM_HIGH)

        // Broadcast to scoreboard and coverage
        ap.write(txn);
      end
    end
  endtask

endclass

// ============================================================
// riscv_driver.sv
// UVM Driver - drives instructions into the RISC-V pipeline
// ============================================================

class riscv_driver extends uvm_driver #(riscv_transaction);

  `uvm_component_utils(riscv_driver)

  // Virtual interface handle
  virtual riscv_interface.driver_mp vif;

  // -------------------------------------------------------
  // Constructor
  // -------------------------------------------------------
  function new(string name = "riscv_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------
  // Build phase - get interface from config DB
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual riscv_interface)::get(this, "", "vif", vif))
      `uvm_fatal("DRIVER", "Could not get virtual interface from config DB")
  endfunction

  // -------------------------------------------------------
  // Run phase - main driver loop
  // Continuously fetches transactions from sequencer
  // and drives them onto the interface
  // -------------------------------------------------------
  task run_phase(uvm_phase phase);
    riscv_transaction txn;

    // Hold reset
    vif.driver_cb.instr_in <= 32'h0;
    vif.driver_cb.pc_in    <= 32'h0;
    vif.driver_cb.stall    <= 1'b0;
    vif.driver_cb.flush    <= 1'b0;

    // Wait for reset to deassert
    @(posedge vif.clk iff vif.rst_n === 1'b1);
    `uvm_info("DRIVER", "Reset deasserted, starting to drive transactions", UVM_MEDIUM)

    forever begin
      // Get next transaction from sequencer
      seq_item_port.get_next_item(txn);

      // Drive signals onto interface
      drive_transaction(txn);

      // Signal done to sequencer
      seq_item_port.item_done();
    end
  endtask

  // -------------------------------------------------------
  // Drive a single transaction onto the interface
  // -------------------------------------------------------
  task drive_transaction(riscv_transaction txn);
    @(vif.driver_cb);

    vif.driver_cb.instr_in <= txn.instruction;
    vif.driver_cb.pc_in    <= txn.pc;

    `uvm_info("DRIVER",
      $sformatf("Driving: %s", txn.convert2string()),
      UVM_HIGH)

    // Hold for one cycle then clear
    @(vif.driver_cb);
    vif.driver_cb.instr_in <= 32'h13; // NOP (ADDI x0, x0, 0)

  endtask

  // -------------------------------------------------------
  // Inject a pipeline stall (used by directed tests)
  // -------------------------------------------------------
  task inject_stall(int cycles = 1);
    repeat(cycles) begin
      @(vif.driver_cb);
      vif.driver_cb.stall <= 1'b1;
    end
    @(vif.driver_cb);
    vif.driver_cb.stall <= 1'b0;
    `uvm_info("DRIVER", $sformatf("Injected stall for %0d cycles", cycles), UVM_MEDIUM)
  endtask

  // -------------------------------------------------------
  // Inject a pipeline flush (used for branch tests)
  // -------------------------------------------------------
  task inject_flush();
    @(vif.driver_cb);
    vif.driver_cb.flush <= 1'b1;
    @(vif.driver_cb);
    vif.driver_cb.flush <= 1'b0;
    `uvm_info("DRIVER", "Injected pipeline flush", UVM_MEDIUM)
  endtask

endclass

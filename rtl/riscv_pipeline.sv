// ============================================================
// riscv_pipeline.sv
// 5-Stage RISC-V Pipelined Processor RTL
// Stages: IF → ID → EX → MEM → WB
// Features: hazard detection, data forwarding, pipeline flush
// ============================================================

module riscv_pipeline (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction input (from testbench)
  input  logic [31:0] instr_in,
  input  logic [31:0] pc_in,
  input  logic        stall,
  input  logic        flush,

  // Outputs to testbench
  output logic [31:0] result_out,
  output logic [4:0]  rd_out,
  output logic        valid_out,
  output logic        data_hazard,
  output logic        ctrl_hazard
);

  // -------------------------------------------------------
  // Register File (32 x 32-bit)
  // -------------------------------------------------------
  logic [31:0] regfile [32];

  // -------------------------------------------------------
  // Pipeline Stage Registers
  // -------------------------------------------------------

  // IF/ID
  logic [31:0] ifid_instr, ifid_pc;

  // ID/EX
  logic [31:0] idex_pc, idex_rs1_val, idex_rs2_val, idex_imm;
  logic [4:0]  idex_rd, idex_rs1, idex_rs2;
  logic [6:0]  idex_opcode;
  logic [2:0]  idex_funct3;
  logic        idex_funct7;

  // EX/MEM
  logic [31:0] exmem_result, exmem_rs2_val;
  logic [4:0]  exmem_rd;
  logic [6:0]  exmem_opcode;
  logic        exmem_valid;

  // MEM/WB
  logic [31:0] memwb_result;
  logic [4:0]  memwb_rd;
  logic        memwb_valid;
  logic        memwb_reg_write;

  // -------------------------------------------------------
  // Forwarding & Hazard signals
  // -------------------------------------------------------
  logic [1:0] fwd_a, fwd_b;   // Forwarding mux selects
  logic       raw_hazard;      // RAW data hazard detected
  logic       branch_taken;    // Branch outcome

  // -------------------------------------------------------
  // Stage 1: Instruction Fetch (IF)
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ifid_instr <= 32'h13; // NOP
      ifid_pc    <= 32'h0;
    end else if (flush) begin
      ifid_instr <= 32'h13; // Flush: insert NOP
      ifid_pc    <= 32'h0;
      ctrl_hazard <= 1'b1;
    end else if (!stall && !raw_hazard) begin
      ifid_instr  <= instr_in;
      ifid_pc     <= pc_in;
      ctrl_hazard <= 1'b0;
    end
  end

  // -------------------------------------------------------
  // Stage 2: Instruction Decode (ID)
  // -------------------------------------------------------
  logic [6:0]  id_opcode;
  logic [4:0]  id_rd, id_rs1, id_rs2;
  logic [2:0]  id_funct3;
  logic        id_funct7;
  logic [31:0] id_imm;

  // Decode instruction fields
  assign id_opcode = ifid_instr[6:0];
  assign id_rd     = ifid_instr[11:7];
  assign id_rs1    = ifid_instr[19:15];
  assign id_rs2    = ifid_instr[24:20];
  assign id_funct3 = ifid_instr[14:12];
  assign id_funct7 = ifid_instr[30];

  // Immediate generation
  always_comb begin
    case (id_opcode)
      7'b0010011: id_imm = {{20{ifid_instr[31]}}, ifid_instr[31:20]}; // I-type
      7'b0100011: id_imm = {{20{ifid_instr[31]}}, ifid_instr[31:25], ifid_instr[11:7]}; // S-type
      7'b1100011: id_imm = {{19{ifid_instr[31]}}, ifid_instr[31], ifid_instr[7],
                             ifid_instr[30:25], ifid_instr[11:8], 1'b0}; // B-type
      default:    id_imm = 32'h0;
    endcase
  end

  // RAW Hazard Detection
  always_comb begin
    raw_hazard = 1'b0;
    if (idex_opcode == 7'b0000011) begin // Load-use hazard
      if ((idex_rd == id_rs1) || (idex_rd == id_rs2))
        raw_hazard = 1'b1;
    end
  end
  assign data_hazard = raw_hazard;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      idex_opcode  <= 7'h0;
      idex_rd      <= 5'h0;
      idex_rs1     <= 5'h0;
      idex_rs2     <= 5'h0;
      idex_funct3  <= 3'h0;
      idex_funct7  <= 1'b0;
      idex_imm     <= 32'h0;
      idex_rs1_val <= 32'h0;
      idex_rs2_val <= 32'h0;
      idex_pc      <= 32'h0;
    end else if (!stall && !raw_hazard) begin
      idex_opcode  <= id_opcode;
      idex_rd      <= id_rd;
      idex_rs1     <= id_rs1;
      idex_rs2     <= id_rs2;
      idex_funct3  <= id_funct3;
      idex_funct7  <= id_funct7;
      idex_imm     <= id_imm;
      idex_rs1_val <= regfile[id_rs1];
      idex_rs2_val <= regfile[id_rs2];
      idex_pc      <= ifid_pc;
    end
  end

  // -------------------------------------------------------
  // Stage 3: Execute (EX)
  // -------------------------------------------------------
  logic [31:0] ex_opa, ex_opb, ex_result;

  // Forwarding mux logic
  always_comb begin
    // Forward A
    if (exmem_valid && exmem_rd != 0 && exmem_rd == idex_rs1)
      fwd_a = 2'b10; // Forward from EX/MEM
    else if (memwb_valid && memwb_rd != 0 && memwb_rd == idex_rs1)
      fwd_a = 2'b01; // Forward from MEM/WB
    else
      fwd_a = 2'b00; // No forwarding

    // Forward B
    if (exmem_valid && exmem_rd != 0 && exmem_rd == idex_rs2)
      fwd_b = 2'b10;
    else if (memwb_valid && memwb_rd != 0 && memwb_rd == idex_rs2)
      fwd_b = 2'b01;
    else
      fwd_b = 2'b00;
  end

  // Operand muxes with forwarding
  always_comb begin
    case (fwd_a)
      2'b10:   ex_opa = exmem_result;
      2'b01:   ex_opa = memwb_result;
      default: ex_opa = idex_rs1_val;
    endcase

    case (fwd_b)
      2'b10:   ex_opb = exmem_result;
      2'b01:   ex_opb = memwb_result;
      default: ex_opb = idex_rs2_val;
    endcase
  end

  // ALU
  always_comb begin
    ex_result = 32'h0;
    case (idex_opcode)
      7'b0110011: begin // R-type
        case (idex_funct3)
          3'b000: ex_result = idex_funct7 ? ex_opa - ex_opb : ex_opa + ex_opb; // ADD/SUB
          3'b111: ex_result = ex_opa & ex_opb; // AND
          3'b110: ex_result = ex_opa | ex_opb; // OR
          3'b100: ex_result = ex_opa ^ ex_opb; // XOR
          3'b001: ex_result = ex_opa << ex_opb[4:0]; // SLL
          3'b101: ex_result = ex_opa >> ex_opb[4:0]; // SRL
          default: ex_result = 32'h0;
        endcase
      end
      7'b0010011: begin // I-type
        case (idex_funct3)
          3'b000: ex_result = ex_opa + idex_imm; // ADDI
          3'b111: ex_result = ex_opa & idex_imm; // ANDI
          3'b110: ex_result = ex_opa | idex_imm; // ORI
          3'b100: ex_result = ex_opa ^ idex_imm; // XORI
          default: ex_result = 32'h0;
        endcase
      end
      7'b1100011: begin // Branch
        branch_taken = (ex_opa == ex_opb); // BEQ
        ex_result    = idex_pc + idex_imm; // Branch target
      end
      default: ex_result = 32'h0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      exmem_result  <= 32'h0;
      exmem_rd      <= 5'h0;
      exmem_opcode  <= 7'h0;
      exmem_rs2_val <= 32'h0;
      exmem_valid   <= 1'b0;
    end else begin
      exmem_result  <= ex_result;
      exmem_rd      <= idex_rd;
      exmem_opcode  <= idex_opcode;
      exmem_rs2_val <= ex_opb;
      exmem_valid   <= (idex_opcode != 7'h0);
    end
  end

  // -------------------------------------------------------
  // Stage 4: Memory (MEM) - pass-through for non-load/store
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      memwb_result    <= 32'h0;
      memwb_rd        <= 5'h0;
      memwb_valid     <= 1'b0;
      memwb_reg_write <= 1'b0;
    end else begin
      memwb_result    <= exmem_result;
      memwb_rd        <= exmem_rd;
      memwb_valid     <= exmem_valid;
      memwb_reg_write <= (exmem_opcode == 7'b0110011 ||
                          exmem_opcode == 7'b0010011);
    end
  end

  // -------------------------------------------------------
  // Stage 5: Write Back (WB)
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      integer i;
      for (i = 0; i < 32; i++) regfile[i] <= 32'h0;
    end else if (memwb_reg_write && memwb_rd != 5'h0) begin
      regfile[memwb_rd] <= memwb_result;
    end
  end

  // -------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------
  assign result_out = memwb_result;
  assign rd_out     = memwb_rd;
  assign valid_out  = memwb_valid;

endmodule

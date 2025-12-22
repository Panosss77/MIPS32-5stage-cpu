/***********************************************************************************************/
/*********************************  MIPS 5-stage pipeline implementation ***********************/
/***********************************************************************************************/

module cpu(input clock, input reset);
 reg [31:0] PC; 
 reg [31:0] IFID_PCplus4;
 reg [31:0] IFID_instr;
 wire IFID_Write, PC_Write, Stall_Select;//<--------------- Used for Stalling.
 reg [31:0] IDEX_rdA, IDEX_rdB, IDEX_signExtend;
 reg [4:0]  IDEX_instr_rt, IDEX_instr_rs, IDEX_instr_rd;                            
 reg [4:0]  IDEX_shamt;//<--------------- Used for sll(v).
 reg [31:0] IDEX_PCplus4;
 reg        IDEX_RegDst, IDEX_ALUSrc;
 reg [1:0]  IDEX_ALUcntrl;
 reg        IDEX_Branch, IDEX_MemRead, IDEX_MemWrite; 
 reg        IDEX_MemToReg, IDEX_RegWrite, IDEX_Jump, IDEX_invZero;                
 reg [4:0]  EXMEM_RegWriteAddr, EXMEM_instr_rd; 
 reg [31:0] EXMEM_ALUOut;
 reg        EXMEM_Zero;
 reg [31:0] EXMEM_MemWriteData;
 reg [31:0] EXMEM_PCplus4,EXMEM_signExtend;
 reg        EXMEM_Branch, EXMEM_MemRead, EXMEM_MemWrite, EXMEM_RegWrite, EXMEM_MemToReg, EXMEM_invZero;
 reg [31:0] MEMWB_DMemOut;
 reg [4:0]  MEMWB_RegWriteAddr, MEMWB_instr_rd; 
 reg [31:0] MEMWB_ALUOut;
 reg [31:0] ALU_INB_FORWARD, ALUInA;//<------------ Used for multiplexing for Forwarding and sll(v).
 reg        MEMWB_MemToReg, MEMWB_RegWrite;               
 wire [31:0] instr, ALUInB, ALUOut, rdA, rdB, signExtend, DMemOut, wRegData, PCIncr;
 wire Zero, RegDst, MemRead, MemWrite, MemToReg, ALUSrc, RegWrite, Branch, Jump, invZero;
 wire [5:0] opcode, func;
 wire [4:0] instr_rs, instr_rt, instr_rd, RegWriteAddr;
 wire [3:0] ALUOp;
 wire [1:0] ALUcntrl;
 wire [15:0] imm;
 wire [1:0] forwardA,forwardB;//<--------------- Used for Forwarding.
 wire [31:0] jump_target;
 wire PCSrc,bubble_idex, Flush;//<-------------- Used for branching/stalling
 
 assign bubble_idex = ~Stall_Select;

always @(posedge clock or negedge reset)
begin 
  if (reset == 1'b0)begin
    PC <= 0;
  end
  else if (PC_Write) begin
    PC <= (PCSrc) ? (EXMEM_PCplus4 + (EXMEM_signExtend << 2)) : (Jump)? jump_target : PC+4;
  end
end
  
assign jump_target = {IFID_PCplus4[31:28], IFID_instr[25:0], 2'b00};
assign PCSrc = EXMEM_Branch & (EXMEM_Zero ^ EXMEM_invZero);
assign Flush = PCSrc | Jump;
  
  // IFID pipeline register
 always @(posedge clock or negedge reset)
begin 
  if (!reset) begin
    IFID_PCplus4 <= 32'b0;
    IFID_instr   <= 32'b0;
  end 
  else begin
    if (Flush) begin
      IFID_instr <= 32'b0;
    end
    else if (IFID_Write) begin
      IFID_PCplus4 <= PC + 32'd4;
      IFID_instr   <= instr;
    end
  end
end

 // Instruction Memory
Memory cpu_IMem(.clock(clock), .reset(reset), .ren(1'b1), .wen(1'b0), .addr(PC >> 2), .din(32'bx), .dout(instr));//Does the job
  

/***************** Instruction Decode Unit (ID)  ****************/
assign opcode = IFID_instr[31:26];
assign func = IFID_instr[5:0];
assign instr_rs = IFID_instr[25:21];
assign instr_rt = IFID_instr[20:16];
assign instr_rd = IFID_instr[15:11];
assign imm = IFID_instr[15:0];
assign signExtend = {{16{imm[15]}}, imm};

// Register file
RegFile cpu_regs(clock, reset, instr_rs, instr_rt, MEMWB_RegWriteAddr, MEMWB_RegWrite, wRegData, rdA, rdB);

  // IDEX pipeline register
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0)
      begin
       IDEX_rdA <= 32'b0;    
       IDEX_rdB <= 32'b0;
       IDEX_signExtend <= 32'b0;
       IDEX_instr_rd <= 5'b0;
       IDEX_instr_rs <= 5'b0;
       IDEX_instr_rt <= 5'b0;
       IDEX_shamt <= 5'b0;
       IDEX_Branch <= 1'b0;
       IDEX_MemRead <= 1'b0;
       IDEX_MemWrite <= 1'b0;
       IDEX_MemToReg <= 1'b0;                  
       IDEX_RegWrite <= 1'b0;
       IDEX_RegDst <= 1'b0;
       IDEX_ALUcntrl <= 2'b0;
       IDEX_ALUSrc <= 1'b0;
       IDEX_Jump <= 1'b0;
       IDEX_invZero <= 1'b0;
    end 
    else 
      begin
       if (IFID_Write) begin//<---------------- Inserted if in case for stall, to freeze IDEX.
         IDEX_rdA <= rdA;
         IDEX_rdB <= rdB;
         IDEX_signExtend <= signExtend;
         IDEX_instr_rd <= instr_rd;
         IDEX_instr_rs <= instr_rs;
         IDEX_instr_rt <= instr_rt;
         IDEX_shamt <= IFID_instr[10:6];//<--------- Passing new shamt around.
         IDEX_PCplus4 <= IFID_PCplus4;
       end

       if (Stall_Select && !PCSrc) begin//<---------------- Inserted if in case for stall, to freeze Control Unit signals for IDEX. (Active Low).
        IDEX_Branch <= Branch;
        IDEX_MemRead <= MemRead;
        IDEX_MemWrite <= MemWrite;
        IDEX_MemToReg <= MemToReg;                  
        IDEX_RegWrite <= RegWrite;
        IDEX_RegDst <= RegDst;
        IDEX_ALUcntrl <= ALUcntrl;
        IDEX_ALUSrc <= ALUSrc;
        IDEX_Jump <= Jump;
        IDEX_invZero <= invZero;
       end
       else begin
        IDEX_Branch <= 1'b0;
        IDEX_MemRead <= 1'b0;
        IDEX_MemWrite <= 1'b0;
        IDEX_MemToReg <= 1'b0;                  
        IDEX_RegWrite <= 1'b0;
        IDEX_RegDst <= 1'b0;
        IDEX_ALUcntrl <= 2'b0;
        IDEX_ALUSrc <= 1'b0;
        IDEX_Jump <= 1'b0;
        IDEX_invZero <= 1'b0;
       end
    end
  end

// Main Control Unit 
control_main control_main (RegDst,Branch,MemRead,MemWrite,MemToReg,ALUSrc,RegWrite,ALUcntrl,invZero,Jump,opcode);
                  
// Control Unit that generates stalls.
Hazard_Unit cpu_hazard(.PC_Write(PC_Write),         .IFID_Write(IFID_Write), 
                       .Stall_Select(Stall_Select), .IFID_RegisterRS(instr_rs),//<------ Wiring it all together.
                       .IFID_RegisterRT(instr_rt),  .IDEX_RegisterRT(IDEX_instr_rt), 
                       .IDEX_MemRead(IDEX_MemRead));

/***************** Execution Unit (EX)  ****************/
always @(*) begin

  case (forwardA)
      2'b10: ALUInA <= (ALUOp == 4'b1001) ? IDEX_shamt : EXMEM_ALUOut;
      2'b01: ALUInA <= (ALUOp == 4'b1001) ? IDEX_shamt : wRegData;//<------- Bringing correct value for 2nd operand either from WriteBack or EXMEM
      2'b00: ALUInA <= (ALUOp == 4'b1001) ? IDEX_shamt : IDEX_rdA;//         in case of forwarding, or rdB, normally, if neither is needed.
      default: ALUInA <= 32'bx;//                                            If sll Operation is executed, first operand gets shamt value from IDEX.
  endcase//                                                                  In case of sllv, its fine as it is. (Rs or shamt)
                    //<------- Forwarding logic based on Forwarding signals.
  case (forwardB)
    2'b10: ALU_INB_FORWARD <= EXMEM_ALUOut;
    2'b01: ALU_INB_FORWARD <= wRegData;//<------- Bringing correct value for 2nd operand either from WriteBack or EXMEM
    2'b00: ALU_INB_FORWARD <= IDEX_rdB;//           in case of forwarding, or rdB, normally, if neither is needed.(Rt)
    default: ALU_INB_FORWARD <= 32'bx;
  endcase
end

assign ALUInB = (IDEX_ALUSrc == 1'b0) ? ALU_INB_FORWARD : IDEX_signExtend; //<------- Pre-existing multiplexer for immediate in ALU.

//  ALU
ALU  #(32) cpu_alu(ALUOut, Zero, ALUInA, ALUInB, ALUOp);

assign RegWriteAddr = (IDEX_RegDst==1'b0) ? IDEX_instr_rt : IDEX_instr_rd;

 // EXMEM pipeline register
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0 | PCSrc)//Extra logic for flashing EXMEM when branching.
      begin
       EXMEM_ALUOut <= 32'b0;    
       EXMEM_RegWriteAddr <= 5'b0;
       EXMEM_MemWriteData <= 32'b0;
       EXMEM_Zero <= 1'b0;
       EXMEM_Branch <= 1'b0; 
       EXMEM_MemRead <= 1'b0;
       EXMEM_MemWrite <= 1'b0;
       EXMEM_MemToReg <= 1'b0;                  
       EXMEM_RegWrite <= 1'b0;
       EXMEM_instr_rd<=5'b0;
       EXMEM_invZero <= 1'b0;
       EXMEM_signExtend <= 32'b0;
      end 
    else 
      begin
       EXMEM_ALUOut <= ALUOut;    
       EXMEM_RegWriteAddr <= RegWriteAddr;
       EXMEM_MemWriteData <= ALU_INB_FORWARD;
       EXMEM_Zero <= Zero; 
       EXMEM_Branch <= IDEX_Branch;
       EXMEM_MemRead <= IDEX_MemRead;
       EXMEM_MemWrite <= IDEX_MemWrite;
       EXMEM_MemToReg <= IDEX_MemToReg;                  
       EXMEM_RegWrite <= IDEX_RegWrite;
       EXMEM_instr_rd<=IDEX_instr_rd;
       EXMEM_invZero <= IDEX_invZero;
       EXMEM_PCplus4 <= IDEX_PCplus4;
       EXMEM_signExtend <= IDEX_signExtend;
      end
  end
  
  // ALU control
  control_alu control_alu(ALUOp, IDEX_ALUcntrl, IDEX_signExtend[5:0]);
  
  // Control logic for Forwarding 
  Forward_unit bypass(.ForwardA(forwardA),               .ForwardB(forwardB),
                      .IDEX_RegisterRT(IDEX_instr_rt),   .IDEX_RegisterRS(IDEX_instr_rs),
                      .EXMEM_RegisterRD(EXMEM_RegWriteAddr), .EXMEM_RegWrite(EXMEM_RegWrite),//<------- Works like a charm
                      .MEMWB_RegisterRD(MEMWB_RegWriteAddr), .MEMWB_RegWrite(MEMWB_RegWrite));
  
/***************** Memory Unit (MEM)  ****************/  
// Data memory 1KB
// Instantiate the Data Memory here 
Memory cpu_DMem(.clock(clock), .reset(reset), .ren(EXMEM_MemRead), .wen(EXMEM_MemWrite), .addr(EXMEM_ALUOut), .din(EXMEM_MemWriteData), .dout(DMemOut));

// MEMWB pipeline register
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0)     
      begin
       MEMWB_DMemOut <= 32'b0;    
       MEMWB_ALUOut <= 32'b0;
       MEMWB_RegWriteAddr <= 5'b0;
       MEMWB_MemToReg <= 1'b0;                  
       MEMWB_RegWrite <= 1'b0;
       MEMWB_instr_rd<=5'b0;
      end 
    else 
      begin
       MEMWB_DMemOut <= DMemOut;
       MEMWB_ALUOut <= EXMEM_ALUOut;
       MEMWB_RegWriteAddr <= EXMEM_RegWriteAddr;
       MEMWB_MemToReg <= EXMEM_MemToReg;                  
       MEMWB_RegWrite <= EXMEM_RegWrite;
       MEMWB_instr_rd<=EXMEM_instr_rd;
      end
  end

/***************** WriteBack Unit (WB)  ****************/  
// Write Back logic 
assign wRegData = (MEMWB_MemToReg)?MEMWB_DMemOut:MEMWB_ALUOut;  //<--- Executing writeback from pipeline registers from MEMWB. (Multiplexer)


endmodule
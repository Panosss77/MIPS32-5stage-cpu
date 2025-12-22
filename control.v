`include "constants.h"

/************** Main control in ID pipe stage  *************/
module control_main(output reg RegDst,
                output reg Branch,  
                output reg MemRead,
                output reg MemWrite,  
                output reg MemToReg,  
                output reg ALUSrc,  
                output reg RegWrite,
                output reg [1:0] ALUcntrl,
                output reg invZero,
                output reg Jump,
                input [5:0] opcode);

  always @(*)
   begin
     case (opcode)
      `R_FORMAT:     
          begin 
            RegWrite=1'b1;
            RegDst=1'b1;
            ALUSrc=1'b0;
            Branch=1'b0;
            MemWrite=1'b0;
            MemToReg=1'b0;
            ALUcntrl = 2'b10;
            MemRead=1'b0;
            invZero = 1'b0;
            Jump = 1'b0;        
          end
       `LW :   
           begin 
            RegWrite=1'b1;
            RegDst=1'b0;
            ALUSrc=1'b1;
            Branch=1'b0;
            MemWrite=1'b0;
            MemToReg=1'b1;
            ALUcntrl = 2'b00;
            MemRead=1'b1;
            invZero = 1'b0;
            Jump = 1'b0;
           end
        `SW :   
           begin 
            RegWrite=1'b0;
            RegDst=1'bx;
            ALUSrc=1'b1;
            Branch=1'b0;
            MemWrite=1'b1;
            MemToReg=1'bx;
            ALUcntrl = 2'b00;
            MemRead=1'b0;
            invZero = 1'b0;
            Jump = 1'b0;
           end
       `BEQ:  
           begin 
            RegWrite=0;
            RegDst=1'bx;
            ALUSrc=1'b0;
            Branch=1'b1;
            MemWrite=1'b0;
            MemToReg=1'bx;
            ALUcntrl = 2'b01;
            MemRead=1'b0;
            invZero = 1'b0;
            Jump = 1'b0;
           end
        `BNE:  
           begin 
            RegWrite=0;
            RegDst=1'bx;
            ALUSrc=1'b0;
            Branch=1'b1;
            MemWrite=1'b0;
            MemToReg=1'bx;
            ALUcntrl = 2'b01;
            MemRead=1'b0;
            invZero = 1'b1;
            Jump = 1'b0;
           end
        `ADDI:  
           begin 
            RegWrite=1'b1;
            RegDst=1'b0;
            ALUSrc=1'b1;
            Branch=1'b0;
            MemWrite=1'b0;
            MemToReg=1'b0;
            ALUcntrl = 2'b00;
            MemRead=1'b0;
            invZero = 1'b0;
            Jump = 1'b0;
           end
        `J:  
           begin 
            RegWrite=1'b0;
            RegDst=1'b0;
            ALUSrc=1'b0;
            Branch=1'b0;
            MemWrite=1'b0;
            MemToReg=1'b0;
            ALUcntrl = 2'b00;
            MemRead=1'b0;
            invZero = 1'b0;
            Jump = 1'b1;
           end
       default:
           begin
            RegWrite=1'bx;
            RegDst=1'bx;
            ALUSrc=1'bx;
            Branch=1'bx;
            MemWrite=1'bx;
            MemToReg=1'bx;
            ALUcntrl = 2'bxx;
            MemRead=1'bx;
            invZero = 1'bx;
            Jump = 1'bx;
           end
      endcase
    end // always
endmodule


/**************** Module for Bypass Detection in EX pipe stage   *********/
module Forward_unit(ForwardA,ForwardB,IDEX_RegisterRT,IDEX_RegisterRS,EXMEM_RegisterRD,EXMEM_RegWrite,MEMWB_RegisterRD,MEMWB_RegWrite);

  output reg [1:0] ForwardA,ForwardB;
  input  [4:0] IDEX_RegisterRT,IDEX_RegisterRS,EXMEM_RegisterRD,MEMWB_RegisterRD;
  input EXMEM_RegWrite,MEMWB_RegWrite;

  always @(*) begin
   
    ForwardA = 2'b00;     //Set default values for forwarding control signals.
    ForwardB = 2'b00;

    
    if (EXMEM_RegWrite && (EXMEM_RegisterRD )) begin  //Check 1st case with exmem - idex clash.
      if (EXMEM_RegisterRD == IDEX_RegisterRS)
        ForwardA = 2'b10;
      if (EXMEM_RegisterRD == IDEX_RegisterRT)
        ForwardB = 2'b10;
    end

    if (MEMWB_RegWrite && (MEMWB_RegisterRD )) begin  //Check 2nd case with memwb - idex clash. (Don't forward if first case applies.)
      if ((MEMWB_RegisterRD == IDEX_RegisterRS) && !((EXMEM_RegWrite) && (EXMEM_RegisterRD == IDEX_RegisterRS)))
        ForwardA = 2'b01;
      if ((MEMWB_RegisterRD == IDEX_RegisterRT) && !((EXMEM_RegWrite) && (EXMEM_RegisterRD == IDEX_RegisterRT)))
        ForwardB = 2'b01;
    end
  end
endmodule
                       

/**************** Module for Stall Detection in ID pipe stage   *********/
module Hazard_Unit(PC_Write,IFID_Write,Stall_Select,IFID_RegisterRS,IFID_RegisterRT,IDEX_RegisterRT,IDEX_MemRead);
  input [4:0] IFID_RegisterRS,IFID_RegisterRT,IDEX_RegisterRT;
  input IDEX_MemRead;
  output reg PC_Write;
  output reg Stall_Select;
  output reg IFID_Write;

  always @(*) begin
   
    PC_Write    = 1'b1;
    IFID_Write  = 1'b1;     //Set default values for stall control signals.
    Stall_Select= 1'b1; 

    if (IDEX_MemRead && ((IDEX_RegisterRT == IFID_RegisterRS) || (IDEX_RegisterRT == IFID_RegisterRT))) begin
      PC_Write     = 1'b0; 
      IFID_Write   = 1'b0;  //Check whether stalling should happen. If so do it.
      Stall_Select = 1'b0; 
    end
  end
endmodule

                       
/************** control for ALU control in EX pipe stage  *************/
module control_alu(output reg [3:0] ALUOp,                  
               input [1:0] ALUcntrl,
               input [5:0] func);

  always @(*)
    begin
      case (ALUcntrl)
        2'b10: 
           begin
             case (func)
              `ADD: ALUOp  = 4'b0010; 
              `SUB: ALUOp = 4'b0110; 
              `AND: ALUOp = 4'b0000; 
              `OR: ALUOp = 4'b0001; 
              `NOR: ALUOp = 4'b1100; 
              `SLT: ALUOp = 4'b0111; //Added ALUOps for sll(v).
              `SLL: ALUOp = 4'b1001;
              `SLLV: ALUOp = 4'b1000;
              `XOR: ALUOp = 4'b1101;//Added ALUOp for xor.
              default: ALUOp = 4'b0000;       
             endcase 
          end   
        2'b00: 
              ALUOp  = 4'b0010; 
        2'b01: 
              ALUOp = 4'b0110;
        default:
              ALUOp = 4'b0000;
     endcase
    end
endmodule
This project is a 32-bit MIPS processor written in Verilog. It implements a 5-stage pipeline with Instruction Fetch, Instruction Decode, Execute, Memory Access, and Write Back stages. The processor is designed for learning and experimentation.

Features:
The processor implements a standard 5-stage pipeline and supports a subset of the MIPS32 instruction set. It handles data hazards with forwarding and load-use stalls, and control hazards from branches and jumps using pipeline flushing. The processor has a 32-register file, an ALU capable of arithmetic and logical operations, and separate instruction and data memory modules. It also includes a hazard detection unit and a forwarding unit to manage pipeline dependencies.
The supported instructions include:
R-type: add, sub, and, or, nor, slt, sll, sllv, xor
I-type: lw, sw, addi, beq, bne
J-type: j, jal

The ALU control logic interprets the function codes for R-type instructions, while the main control module interprets opcodes to generate control signals for the pipeline.

Pipeline Architecture:
The processor has IF, ID, EX, MEM, and WB stages with pipeline registers between each stage. Data hazards are handled with forwarding from EX/MEM and MEM/WB stages. Load-use hazards are detected by the hazard unit and resolved by stalling the pipeline. Branch and jump instructions trigger pipeline flushes when taken to ensure correct control flow.

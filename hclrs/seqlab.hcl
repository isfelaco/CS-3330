# registers
register pP {  
	pc: 64 = 0; # 64-bits wide; 0 is its default value.
} 
pc = P_pc;

# wires
wire opcode:8, icode:4, ifun:4, rA:4, rB:4, valC:64, conditionsMet:1;
opcode = i10bytes[0..8];
icode = opcode[4..8];
ifun = opcode[0..4];
rA = i10bytes[12..16];
rB = i10bytes[8..12];

reg_srcA = rA;
reg_srcB = rB;

# constant
valC = [
    icode == IRMOVQ || icode == RMMOVQ   :   i10bytes[16..80];
    icode == JXX : i10bytes[8..72];
    1 : 0;
];

# selecting values to move and performing ALU operations
reg_inputE = [
    icode == IRMOVQ :   valC;  # if irmovq, move a constant
    icode == RRMOVQ || icode == RMMOVQ  :   reg_outputA;   # if rrmovq, move the value from first register
    icode == OPQ && ifun == ADDQ    :   reg_outputA + reg_outputB;
    icode == OPQ && ifun == SUBQ    :   reg_outputB - reg_outputA;
    icode == OPQ && ifun == ANDQ    :   reg_outputA & reg_outputB;
    icode == OPQ && ifun == XORQ    :   reg_outputA ^ reg_outputB;
    1   :   0;
];

# setting condition codes
register cC {
    SF:1 = 0;
    ZF:1 = 1;
}
c_ZF = [
    icode == OPQ    :   (reg_inputE == 0);
    1   :   C_ZF;
];
c_SF = [
    icode == OPQ    :   (reg_inputE >= 0x8000000000000000);
    1   :   C_SF;
];

conditionsMet = [
    ifun == ALWAYS :   1;
    ifun == LE  :   C_SF || C_ZF;
    ifun == 2   :   C_SF && !C_ZF; # L, negative and not zero
    ifun == 3   :   C_ZF;  # E, diff equal to zero
    ifun == NE  :   !C_ZF;
    ifun == GE  :   !C_SF || C_ZF; # not negative and not zero
    ifun == 6   :   !C_SF && !C_ZF;
    1   :   1;
];

# destination of instruction
reg_dstE = [
    !conditionsMet && icode == CMOVXX   :   REG_NONE;
    icode == IRMOVQ || icode == RRMOVQ || icode == RMMOVQ || icode == OPQ  :   rB;
    1 : REG_NONE;
];

mem_addr = valC + reg_outputB;
mem_input = reg_inputE;
mem_readbit = 0;
mem_writebit = [
    icode == RMMOVQ :   1;
    1   :   0;
];

const TOO_BIG = 0xC; # the first unused icode in Y86-64

# update stat code
Stat = [
    icode == HALT               : STAT_HLT;
    icode >= TOO_BIG            : STAT_INS; # icode > 11 -> unused opcode
	1                           : STAT_AOK;
];

# update the pc
p_pc = [
    icode == NOP    :   P_pc + 1;
    icode == RRMOVQ || icode == OPQ || icode == PUSHQ || icode == POPQ  :   P_pc + 2;
    icode >= 0x3 && icode <= 0x5    :   P_pc + 0xa;
    icode == JXX    :   valC;
    1   : P_pc;
];
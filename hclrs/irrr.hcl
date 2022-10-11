register pP {  
	pc: 64 = 0; # 64-bits wide; 0 is its default value.
} 
pc = P_pc;

wire opcode:8, icode:4, rA:4, rB:4, valC: 64;

opcode = i10bytes[0..8];
icode = opcode[4..8];
rA = i10bytes[12..16];
rB = i10bytes[8..12];
valC = [
    icode == 3 : i10bytes[16..80];
    icode == JXX : i10bytes[8..72];
    1 : 0;
];
reg_srcA = rA;
reg_srcB = rB;
reg_dstE = [
    icode == 2 || icode == 3 : rB;  # rB is destination register for movs
    1 : REG_NONE;
];
reg_inputE = [
    icode == IRMOVQ : valC;  # if irmovq, move a constant
    icode == RRMOVQ : reg_outputA;   # if rrmovq, move the value from first register
    1 : 0;
];

const TOO_BIG = 0xC; # the first unused icode in Y86-64

Stat = [
    icode == HALT               : STAT_HLT;
    icode >= TOO_BIG            : STAT_INS; # icode > 11 -> unused opcode
	1                           : STAT_AOK;
];

p_pc = [
    icode == NOP                                                    : P_pc + 1;
    icode == 0x2 || icode == 0x6 || icode == 0xa || icode == 0xb    : P_pc + 2;
    icode >= 0x3 && icode <= 0x5                                    : P_pc + 0xa;
    icode == JXX                                                    : valC;
    1                                                               : P_pc;
];
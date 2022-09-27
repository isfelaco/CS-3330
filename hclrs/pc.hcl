register pP {  
	pc:64 = 0; # 64-bits wide; 0 is its default value.
} 

pc = P_pc;

wire opcode:8, icode:4;

opcode = i10bytes[0..8];
icode = opcode[4..8];

const TOO_BIG = 0xC; # the first unused icode in Y86-64

Stat = [
	icode == HALT               : STAT_HLT;
    icode >= TOO_BIG            : STAT_INS; # icode > 11 -> unused opcode
    0x7 <= icode && icode < 0xa : STAT_INS; # if there is a jXX, call, or ret icode
	1                           : STAT_AOK;
];

p_pc = [
    icode == 0x0 || icode == 0x1 || icode == 0x9                    : P_pc + 0x1;
    icode == 0x2 || icode == 0x6 || icode == 0xa || icode == 0xb    : P_pc + 0x2;
    icode >= 0x3 && icode <= 0x5                                    : P_pc + 0xa;
    icode == 0x7 || icode == 0x8                                    : P_pc + 0x9;
    1                                                               : P_pc + 0;
];
## SEQLAB solution for HCL3
# Please do not consult this unless you've turned in HCL2 and HCL3.

########## the PC and condition codes registers #############
register fF { 
	pc:64 = 0; 
}

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}


########## Fetch #############
pc = F_pc;

wire icode:4, ifun:4, rA:4, rB:4, valC:64;

icode = i10bytes[4..8];
ifun = i10bytes[0..4];
rA = i10bytes[12..16];
rB = i10bytes[8..12];

valC = [
	icode in { JXX } : i10bytes[8..72];
	1 : i10bytes[16..80];
];

wire offset:64, valP:64;
offset = [
	icode in { HALT, NOP, RET } : 1;
	icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	icode in { JXX, CALL } : 9;
	1 : 10;
];
valP = F_pc + offset;


########## Decode #############

reg_srcA = [
	icode in {RRMOVQ, RMMOVQ, OPQ} : rA;
	1 : REG_NONE;
];
reg_srcB = [
	icode in {OPQ, RMMOVQ} : rB;
	1 : REG_NONE;
];


########## Execute #############


wire conditionsMet:1;
conditionsMet = [
	ifun == ALWAYS : true;
	ifun == LE : C_SF || C_ZF;
	ifun == LT : C_SF;
	ifun == EQ : C_ZF;
	ifun == NE : !C_ZF;
	ifun == GE : !C_SF;
	ifun == GT : !C_SF && !C_ZF;
	1 : false;
];

wire valE:64;
valE = [
	icode == OPQ && ifun == ADDQ : reg_outputA + reg_outputB;
	icode == OPQ && ifun == SUBQ : reg_outputB - reg_outputA;
	icode == OPQ && ifun == ANDQ : reg_outputA & reg_outputB;
	icode == OPQ && ifun == XORQ : reg_outputA ^ reg_outputB;
	icode in { RMMOVQ } : valC + reg_outputB;
	1 : 0;
];

### simplified condition codes
c_ZF = valE == 0;
c_SF = valE >= 0x8000000000000000;
stall_C = icode != OPQ;



########## Memory #############

mem_readbit = false;
mem_writebit = icode in { RMMOVQ };
mem_addr = valE;
mem_input = reg_outputA;


########## Writeback #############

reg_dstE = [
	icode == RRMOVQ && conditionsMet : rB;
	icode in {IRMOVQ, OPQ} : rB;
	1 : REG_NONE;
];


reg_inputE = [
	icode == RRMOVQ : reg_outputA;
	icode == OPQ : valE;
	icode in {IRMOVQ} : valC;
	1 : 0xbadbadbadbad;
];

Stat = [
	icode == HALT : STAT_HLT;
	icode > 0xb : STAT_INS;
	1 : STAT_AOK;
];



########## PC Update #############

f_pc = [
	icode == JXX : valC;
	1 : valP;
];


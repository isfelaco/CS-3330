########## the PC and condition codes registers #############

register pP { 
    predPC : 64 = 0;
    misprediction : 1 = 0;
    valP : 64 = 0;
}
register cC {
	SF:1 = 0;
	ZF:1 = 1;
}
########################################################################################


########## Fetch #############
pc = [
    P_misprediction : P_valP;
    # other conditions ?
    1               : P_predPC;
];

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];

f_rA = [
	f_icode in { RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, PUSHQ, POPQ }  : i10bytes[12..16];  # note that IRMOVQ does not actually need rA
	1                                                   : REG_NONE;
];
f_rB = [
	f_icode in { RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ }  : i10bytes[8..12];
    f_icode in { PUSHQ, POPQ }                          : REG_RSP;
	1                                                   : REG_NONE;
];
f_valC = [
	f_icode in { IRMOVQ, RMMOVQ, MRMOVQ } : i10bytes[16..80];     # value or displacement
	f_icode in { JXX }                    : i10bytes[8..72];      # destination
	1                                     : 0;
];

# new PC (assuming there is no jump)
f_valP = [
	f_icode in { IRMOVQ, RMMOVQ, MRMOVQ }   : pc + 10;
	f_icode in { JXX }                      : pc + 9;
    f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : pc + 2;
    f_icode == HALT                         : pc;
	1                                       : pc + 1;
];

# pc register update (to fetch immediately on next cycle)
p_predPC = [
    f_icode in { JXX }    : f_valC; # always take the jump
    1       : f_valP;
];

f_Stat = [
	f_icode == HALT                                         : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ, JXX, PUSHQ, POPQ }   : STAT_AOK;
    #icode > 0xb : STAT_INS;
	#1 : STAT_AOK;
	1                                                       : STAT_INS;
];


########################################################################################
register fD {
  Stat : 3 = STAT_AOK;
  icode : 4 = NOP;
  ifun : 4 = NOP;
  rA : 4 = REG_NONE;
  rB : 4 = REG_NONE;
  valC : 64 = 0;
  valP : 64 = 0;
}
########################################################################################


########## Decode #############
# source selection
reg_srcA = [
	D_icode in { RRMOVQ, RMMOVQ, MRMOVQ, OPQ, PUSHQ, POPQ }  : D_rA;
	1                                           : REG_NONE;
];
reg_srcB = [
	D_icode in { RMMOVQ, MRMOVQ, OPQ, PUSHQ, POPQ }  : D_rB;
	1 : REG_NONE;
];

wire loadUse : 1;
loadUse = E_icode == MRMOVQ && reg_srcB == e_dstM;  # MRMOVQ is moving to a register
stall_P = f_Stat != STAT_AOK || loadUse;            # keep the PC the same next cycle
stall_D = loadUse;                                  # keep same instruction in decode next cycle
#bubble_E = loadUse;                                 # send nop to execute next cycle
# had to comment this out, but probably will effect other stuff


d_valA = [
    reg_srcA == REG_NONE : 0;

	reg_srcA == e_dstE : e_valE;    # instruction is in execute
    reg_srcA == m_dstE : m_valE;    # instruction is in memory
	reg_srcA == W_dstE : W_valE;    # instruction is in writeback

    reg_srcA == m_dstM : m_valM;    # instruction is in memory
    reg_srcA == W_dstM : W_valM;    # instruction is in writeback

    1 : reg_outputA;
];
d_valB = [
    reg_srcB == REG_NONE : 0;

	reg_srcB == e_dstE : e_valE;    # instruction is in execute
    reg_srcB == m_dstE : m_valE;    # instruction is in memory
	reg_srcB == W_dstE : W_valE;    # instruction is in writeback

    reg_srcB == m_dstM : m_valM;    # instruction is in memory
    reg_srcB == W_dstM : W_valM;    # instruction is in writeback

    1 : reg_outputB;
];

# destination selection
d_dstE = [
	D_icode in { IRMOVQ, RRMOVQ, OPQ, PUSHQ, POPQ }  : D_rB;
	1                                   : REG_NONE;
];
d_dstM = [
    D_icode in { MRMOVQ, POPQ }           : D_rA;
    1                               : REG_NONE;
];


########################################################################################
d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;
d_valP = D_valP;
register dE {
  Stat : 3 = STAT_AOK;
  icode : 4 = NOP;
  ifun : 4 = NOP;
  valA : 64 = 0;
  valB : 64 = 0;
  valC : 64 = 0;
  valP : 64 = 0;
  dstE : 4 = REG_NONE;
  dstM : 4 = REG_NONE;
}
########################################################################################


########## Execute #############
e_Cnd = [
  E_ifun == ALWAYS  : true;
  E_ifun == LE      : C_SF || C_ZF;
  E_ifun == LT      : C_SF;
  E_ifun == EQ      : C_ZF;
  E_ifun == NE      : !C_ZF;
  E_ifun == GE      : !C_SF;
  E_ifun == GT      : !C_SF && !C_ZF;
  1                 : false;
];

e_dstE = [
  E_icode == CMOVXX && !e_Cnd   : REG_NONE;
  1                             : E_dstE;
];

wire operand1:64, operand2:64;
operand1 = [
    E_icode in { RRMOVQ, OPQ }      : E_valA;
	E_icode in { RMMOVQ, MRMOVQ }   : E_valC;
    E_icode in { PUSHQ, POPQ }      : 8;
	1                               : 0;
];
operand2 = [
	E_icode in { RMMOVQ, MRMOVQ, OPQ, PUSHQ, POPQ }  : E_valB;
	1                                   : 0;
];

e_valE = [
	E_icode in { RMMOVQ, MRMOVQ }       : operand1 + operand2;
    E_icode in { RRMOVQ }               : operand1;
	E_icode in { IRMOVQ }               : E_valC;

    E_icode == OPQ && E_ifun == ADDQ    : operand1 + operand2 ;
    E_icode == OPQ && E_ifun == SUBQ    : operand2 - operand1 ;
    E_icode == OPQ && E_ifun == ANDQ    : operand1 & operand2 ;
    E_icode == OPQ && E_ifun == XORQ    : operand1 ^ operand2 ;

    E_icode in { PUSHQ }          : operand2 - operand1;
    E_icode in { POPQ }           : operand1 + operand2;

	1                                   : 0;
];

### set condition codes
c_ZF = e_valE == 0;
c_SF = e_valE >= 0x8000000000000000;
stall_C = E_icode != OPQ;

p_misprediction = E_icode in { JXX } && !e_Cnd;
p_valP = E_valP;
bubble_E = p_misprediction;
bubble_D = p_misprediction;

########################################################################################
e_Stat = E_Stat;
e_icode = E_icode;
e_valA = E_valA;
e_valB = E_valB;
e_valC = E_valC;
e_valP = E_valP;
e_dstM = E_dstM;
register eM {
  Stat : 3 = STAT_AOK;
  icode : 4 = NOP;
  valA : 64 = 0;
  valB : 64 = 0;
  valC : 64 = 0;
  valP : 64 = 0;
  valE : 64 = 0;
  dstE : 4 = REG_NONE;
  dstM : 4 = REG_NONE;
  Cnd : 1 = true;
}
########################################################################################


########## Memory #############
mem_readbit = M_icode in { MRMOVQ, POPQ };
mem_writebit = M_icode in { RMMOVQ, PUSHQ };
mem_addr = [
	M_icode in { MRMOVQ, RMMOVQ }   : M_valE;
    M_icode in { POPQ }        : M_valB;
    1                               : 0xBADBADBAD;
];
mem_input = [
	M_icode in { RMMOVQ }   : M_valA;
    1                       : 0xBADBADBAD;
];
m_valM = mem_output;


########################################################################################
m_Stat = M_Stat;
m_icode = M_icode;
m_valA = M_valA;
m_valC = M_valC;
m_valE = M_valE;
m_dstE = M_dstE;
m_dstM = M_dstM;
register mW {
  Stat : 3 = STAT_AOK;
  icode : 4 = NOP;
  valA : 64 = 0;
  valC : 64 = 0;
  valE : 64 = 0;
  dstE : 4 = REG_NONE;
  valM : 64 = 0;
  dstM : 4 = REG_NONE;
}
########################################################################################


########## Writeback #############
reg_inputE = [
    W_icode in { RRMOVQ, IRMOVQ, OPQ, PUSHQ, POPQ }  : W_valE;
    1                                   : 0xBADBADBAD;
];
reg_inputM = [
	W_icode in { MRMOVQ, POPQ }   : W_valM;
    1                       : 0xBADBADBAD;
];

reg_dstE = W_dstE;
reg_dstM = W_dstM;

########## PC and Status updates #############

Stat = W_Stat;
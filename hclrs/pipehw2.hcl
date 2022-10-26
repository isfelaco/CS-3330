########## the PC and condition codes registers #############
register fF { pc : 64 = 0; }
register cC {
	SF:1 = 0;
	ZF:1 = 1;
}
########################################################################################


########## Fetch #############
pc = F_pc;

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];

wire need_regs:1, need_immediate:1;

need_regs = f_icode in { RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ };
need_immediate = f_icode in { IRMOVQ, RMMOVQ, MRMOVQ };         # will add JXX, CALL, RET

f_rA = [
	need_regs   : i10bytes[12..16];        # note that IRMOVQ does not actually need rA
	1           : REG_NONE;
];
f_rB = [
	need_regs   : i10bytes[8..12];
	1           : REG_NONE;
];
f_valC = [
	need_immediate && need_regs : i10bytes[16..80];     # value or displacement
	need_immediate              : i10bytes[8..72];      # destination
	1                           : 0;
];

# new PC (assuming there is no jump)
wire valP:64;
valP = [
	need_immediate && need_regs : pc + 10;
	need_immediate              : pc + 9;
    need_regs                   : pc + 2;
    f_icode == HALT             : pc;
	1                           : pc + 1;
];

# pc register update (to fetch immediately on next cycle)
f_pc = valP;

f_Stat = [
	f_icode == HALT                                         : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ}   : STAT_AOK;
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
  #valP : 64 = 0;
}
########################################################################################


########## Decode #############
# source selection
reg_srcA = [
	D_icode in { RRMOVQ, RMMOVQ, MRMOVQ, OPQ }  : D_rA;
	1                                           : REG_NONE;
];
reg_srcB = [
	D_icode in { RMMOVQ, MRMOVQ, OPQ }  : D_rB;
	1                                   : REG_NONE;
];

wire loadUse : 1;
loadUse = E_icode == MRMOVQ && reg_srcB == e_dstM;  # MRMOVQ is moving to a register
stall_F = f_Stat != STAT_AOK || loadUse;            # keep the PC the same next cycle
stall_D = loadUse;                                  # keep same instruction in decode next cycle
bubble_E = loadUse;                                 # send nop to execute next cycle


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
	D_icode in { IRMOVQ, RRMOVQ, OPQ }  : D_rB;
	1                                   : REG_NONE;
];
d_dstM = [
    D_icode in { MRMOVQ }   : D_rA;
    1                       : REG_NONE;
];


########################################################################################
d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;
register dE {
  Stat : 3 = STAT_AOK;
  icode : 4 = NOP;
  ifun : 4 = NOP;
  valA : 64 = 0;
  valB : 64 = 0;
  valC : 64 = 0;
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
	1                               : 0;
];
operand2 = [
	E_icode in { RMMOVQ, MRMOVQ, OPQ }  : E_valB;
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

	1                                   : 0;
];

### set condition codes
c_ZF = e_valE == 0;
c_SF = e_valE >= 0x8000000000000000;
stall_C = E_icode != OPQ;


########################################################################################
e_Stat = E_Stat;
e_icode = E_icode;
e_valA = E_valA;
e_valC = E_valC;
e_dstM = E_dstM;
register eM {
  Stat : 3 = STAT_AOK;
  icode : 4 = NOP;
  valA : 64 = 0;
  valC : 64 = 0;
  valE : 64 = 0;
  dstE : 4 = REG_NONE;
  dstM : 4 = REG_NONE;
  Cnd : 1 = true;
}
########################################################################################


########## Memory #############
mem_readbit = M_icode in { MRMOVQ };
mem_writebit = M_icode in { RMMOVQ };
mem_addr = [
	M_icode in { MRMOVQ, RMMOVQ }   : M_valE;
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
m_valE = M_valE; # valE is value from ALU
m_dstE = M_dstE;
m_dstM = M_dstM;
register mW {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  valA : 64 = 0 ;
  valC : 64 = 0 ;
  valE : 64 = 0 ;
  dstE : 4 = REG_NONE ;
  valM : 64 = 0 ;
  dstM : 4 = REG_NONE ;
}
########################################################################################


########## Writeback #############
reg_inputE = [
    W_icode in { RRMOVQ, IRMOVQ, OPQ }  : W_valE;
    1                                   : 0xBADBADBAD;
];
reg_inputM = [
	W_icode in { MRMOVQ }   : W_valM;
    1                       : 0xBADBADBAD;
];

reg_dstE = W_dstE;
reg_dstM = W_dstM;


########## PC and Status updates #############

Stat = W_Stat;
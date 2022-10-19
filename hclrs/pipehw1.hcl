### definition of values
# valA = reg_outputA -> read from reg_srcA -> rA
# valB = reg_outputB -> read from reg_srcB -> rB
# valC = constant (for movs) or destination (for jxx, call)
# valP = new PC (assuming there's no jump)
# 

########## the PC and condition codes registers #############
register fF { 
  pc : 64 = 0 ; 
}

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}


########## Fetch #############
pc = F_pc;

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];

wire need_regs:1, need_immediate:1;

need_regs = f_icode in {RRMOVQ, IRMOVQ, OPQ};
need_immediate = f_icode in {IRMOVQ};

f_rA = [
	need_regs: i10bytes[12..16];
  #  note that IRMOVQ does not need rA
	1: REG_NONE;
];
f_rB = [
	need_regs: i10bytes[8..12];
	1: REG_NONE;
];
f_valC = [
	need_immediate && need_regs : i10bytes[16..80]; # f_icode in { IRMOVQ } : i10bytes[16..80]; # 
	f_icode in {  } : i10bytes[8..72]; # need_immediate : i10bytes[8..72]; # RRMOVQ needs displacement
	1 : 0;
];

# new PC (assuming there is no jump)
wire valP:64;
valP = [
	need_immediate && need_regs : pc + 10;
	need_immediate : pc + 9;
  f_icode in { RRMOVQ, OPQ } : pc + 2; # need_regs : pc + 2;
  f_icode == HALT : pc; // so we see the same PC as the yis tool
	1 : pc + 1;
];

# pc register update (to fetch immediately on next cycle)
f_pc = [
	1 : valP;
];
f_Stat = [
	f_icode == HALT : STAT_HLT;
	f_icode in {NOP, RRMOVQ, IRMOVQ, OPQ} : STAT_AOK;
	1 : STAT_INS;
];
stall_F = f_Stat != STAT_AOK;

########################################################################################
register fD {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  ifun : 4 = NOP ;
  rA : 4 = REG_NONE ;
  rB : 4 = REG_NONE ;
  valC : 64 = 0 ;
  #valP : 64 = 0 ;
}
########################################################################################



########## Decode #############

# source selection
reg_srcA = [
	D_icode in {RRMOVQ, OPQ} : D_rA; # rA that was just got on last fetch
	1 : REG_NONE;
];
reg_srcB = [
	D_icode in {OPQ} : D_rB; # rA that was just got on last fetch
	1 : REG_NONE;
];

d_valA = [
	reg_srcA == e_dstE && reg_srcA != REG_NONE : e_valE;        # instruction is in execute
    # d_dstE that was set on the last cycle
    # e_valE was the last value in ALU that will be written to a register
  reg_srcA == m_dstE && reg_srcA != REG_NONE : m_valE;        # instruction is in memory
	reg_srcA == reg_dstE && reg_srcA != REG_NONE : reg_inputE;  # instruction is in writeback

  1 : reg_outputA; # output of reg_srcA
];
d_valB = [
	reg_srcB == e_dstE && reg_srcB != REG_NONE : e_valE;        # instruction is in execute
    # d_dstE that was set on the last cycle
    # e_valE was the last value in ALU that will be written to a register
  reg_srcB == m_dstE && reg_srcB != REG_NONE : m_valE;        # instruction is in memory
	reg_srcB == reg_dstE && reg_srcB != REG_NONE : reg_inputE;  # instruction is in writeback

  1 : reg_outputB; # output of reg_srcB
];

# destination selection
d_dstE = [
	D_icode in {IRMOVQ, RRMOVQ, OPQ} : D_rB; # rB that was just got on last fetch
	1 : REG_NONE;
];



########################################################################################
d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;
register dE {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  ifun : 4 = NOP ;
  valA : 64 = 0 ;
  valB : 64 = 0 ;
  valC : 64 = 0 ;
  dstE : 4 = REG_NONE ;
}
########################################################################################

########## Execute #############

e_Cnd = [
  E_ifun == ALWAYS : true ;
  E_ifun == LE : C_SF || C_ZF ;
  E_ifun == LT : C_SF ;
  E_ifun == EQ : C_ZF ;
  E_ifun == NE : !C_ZF ;
  E_ifun == GE : !C_SF ;
  E_ifun == GT : !C_SF && !C_ZF ;
  1 : false ;
] ;

e_dstE = [
  E_icode == CMOVXX && !e_Cnd : REG_NONE;
  1 : E_dstE;
];

e_valE = [
  E_icode in {RRMOVQ} : E_valA;
	E_icode in {IRMOVQ} : E_valC;

  E_icode == OPQ && E_ifun == ADDQ : E_valA + E_valB ;
  E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA ;
  E_icode == OPQ && E_ifun == ANDQ : E_valA & E_valB ;
  E_icode == OPQ && E_ifun == XORQ : E_valA ^ E_valB ;

  # all other instructions will perform operations here
  1 : 0 ;
];

### set condition codes
c_ZF    = e_valE == 0;
c_SF    = e_valE >= 0x8000000000000000;
stall_C = E_icode != OPQ ;


########################################################################################
e_Stat = E_Stat;
e_icode = E_icode;
e_valA = E_valA;
e_valC = E_valC;
register eM {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  valA : 64 = 0 ;
  valC : 64 = 0 ;
  valE : 64 = 0 ;
  dstE : 4 = REG_NONE ;
  Cnd : 1 = true ;
}
########################################################################################

########## Memory #############


########################################################################################
m_Stat = M_Stat;
m_icode = M_icode;
m_valA = M_valA;
m_valC = M_valC;
m_valE = M_valE; # valE is value from ALU
m_dstE = M_dstE;
register mW {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  valA : 64 = 0 ;
  valC : 64 = 0 ;
  valE : 64 = 0 ;
  dstE : 4 = REG_NONE ;
}
########################################################################################

########## Writeback #############


reg_inputE = [ # unlike book, we handle the "forwarding" actions (something + 0) here
	#W_icode in {RRMOVQ} : W_valA;
	#W_icode in {IRMOVQ} : W_valC;
  W_icode in {RRMOVQ, IRMOVQ, OPQ} : W_valE;
  1: 0xBADBADBAD;
];

reg_dstE = W_dstE;


########## PC and Status updates #############

Stat = W_Stat;
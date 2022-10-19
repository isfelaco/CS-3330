########## the PC and condition codes registers #############

register fF { pc : 64 = 0 ; }

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}


########## FETCH #############

pc = F_pc ;

# from Instruction Memory
f_icode = i10bytes[4..8] ;
f_ifun = i10bytes[0..4] ;

wire need_regs : 1, need_immediate : 1 ;
need_regs = d_icode in { RRMOVQ, IRMOVQ } ;
need_immediate = d_icode in { IRMOVQ } ;

f_rA = [
  need_regs : i10bytes[12..16] ;
  1 : REG_NONE ;
] ;
f_rB = [
  need_regs : i10bytes[8..12] ;
  1 : REG_NONE ;
] ;

f_valC = [
  need_immediate && need_regs : i10bytes[16..80] ; # displacement
  need_immediate : i10bytes[8..72] ; # destination of jump/call
  1 : 0 ;
] ;

wire offset : 64 ;
offset = [
  f_icode in { HALT, NOP } : 1 ;
  f_icode in { RRMOVQ, OPQ} : 2 ;
  1 : 10 ;
] ;
f_valP = F_pc + offset ; # next instruction

f_Stat = [
  f_icode == HALT : STAT_HLT ;
  f_icode > 0xb : STAT_INS ;
  1 : STAT_AOK ;
] ;


########################################################################################
register fD {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  ifun : 4 = NOP ;
  rA : 4 = REG_NONE ;
  rB : 4 = REG_NONE ;
  valC : 64 = 0 ;
  valP : 64 = 0 ;
}
########################################################################################



########## DECODE #############

# use D_valP to determine if there's a hazard in the next instruction ?
reg_srcA = [
  D_icode in { RRMOVQ, OPQ } : D_rA;
  1 : REG_NONE ;
] ;
reg_srcB = [
  D_icode in { OPQ, RMMOVQ } : D_rB;
  1 : REG_NONE ;
] ;

d_valA = [
  (reg_srcA == W_dstE) && (reg_srcA != REG_NONE) : W_valE ; # prev dest equals reg to use
                                              # then previous calculation is the new value
  # add more conditions
  (reg_srcA == W_dstM) && (reg_srcA != REG_NONE) : W_valM ;
  1 : reg_outputA ;
] ;
d_valB = [
  (reg_srcB == W_dstE) && (reg_srcB != REG_NONE) : W_valE ; # prev dest equals reg to use
                                            # then previous calculation is the new value
  # add more conditions
  ((reg_srcB == W_dstM) && (reg_srcB != REG_NONE)) : W_valM ;
  # maybe use m_dstM, W_valM
  1 : reg_outputB ;
] ;

# set dstE and dstM, forward dstE then re-evaluate based on conditionsMet 
d_dstE = [
	D_icode in { IRMOVQ, RRMOVQ, OPQ} : D_rB;
	1 : REG_NONE;
];
d_dstM = [
  1 : REG_NONE;
];



########################################################################################
d_Stat = D_Stat ;
d_icode = D_icode ;
d_ifun = D_ifun ;
d_valC = D_valC ;
register dE {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  ifun : 4 = NOP ;
  valC : 64 = 0 ;
  valA : 64 = 0 ;
  valB : 64 = 0 ;
  dstE : 4  = REG_NONE ;
  dstM : 4 = REG_NONE ;
}
########################################################################################


########## EXECUTE #############

# use E_valC in ALU to compute e_valE

# set the condition codes and pass to e_Cnd
e_Cnd = [
	E_ifun == ALWAYS : true;
	E_ifun == LE : C_SF || C_ZF;
	E_ifun == LT : C_SF;
	E_ifun == EQ : C_ZF;
	E_ifun == NE : !C_ZF;
	E_ifun == GE : !C_SF;
	E_ifun == GT : !C_SF && !C_ZF;
	1 : false;
];

# set valE, result of ALU
e_valE = [
  # icodes that perform arithmetic
	E_icode == OPQ && E_ifun == ADDQ : E_valA + E_valB ;
	E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA ;
	E_icode == OPQ && E_ifun == ANDQ : E_valA & E_valB ;
	E_icode == OPQ && E_ifun == XORQ : E_valA ^ E_valB ;
  
  E_icode == RRMOVQ : E_valA ; # so valA doesn't have to be passed down

  # icodes that use valC
  E_icode in { IRMOVQ } : E_valC ; # use valC as destination

	1 : 0 ;
];

# update condition codes for next instruction
c_ZF = e_valE == 0;
c_SF = e_valE >= 0x8000000000000000;

e_dstE = [
  E_icode == RRMOVQ && !e_Cnd : REG_NONE ;
  1 : E_dstE ;
];

########################################################################################
e_Stat = E_Stat ; 
e_icode = E_icode ;
e_valA = E_valA ;
e_valB = E_valB ;
e_dstM = E_dstM ;

register eM {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  Cnd : 1 = 0 ;
  valE : 64 = 0 ;
  valA : 64 = 0 ;
  valB : 64 = 0 ;
  dstE : 4  = REG_NONE ;
  dstM : 4  = REG_NONE ;
}
########################################################################################



########## MEMORY #############

# update Stat using M_Stat and data memory

mem_readbit = false ;
mem_writebit = false ;
mem_addr = [ 
    1 : M_valE ; # address calculated in ALU
];
mem_input = [
    1 : M_valA ;
];

m_valM = [ 
  1 : mem_output ;
];


########################################################################################
m_Stat = M_Stat ;
m_icode = M_icode ;
m_valE = M_valE ;
m_dstE = M_dstE ;
m_dstM = M_dstM ;

register mW {
  Stat : 3 = STAT_AOK ;
  icode : 4 = NOP ;
  valE : 64 = 0 ;
  valM : 64 = 0 ;
  dstE : 4  = REG_NONE ;
  dstM : 4 = REG_NONE ;
}
########################################################################################



########## WRITEBACK #############

# destination selection

reg_dstE = W_dstE ;
reg_dstM = W_dstM ;

reg_inputE = [ # get value to forward to next decode
	W_icode in { RRMOVQ, IRMOVQ, OPQ } : W_valE ;
	1 : 0xbadbadbadbad ;
];
reg_inputM = [
  1 : 0;
];


########## PC and Status updates #############

Stat = W_Stat ;


f_pc = [
  1 : W_valE ; # fetch new instruction, shouldn't need valP
] ;
stall_F =  Stat != STAT_AOK; # so that we see the same final PC as the yis tool

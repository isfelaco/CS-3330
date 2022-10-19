########## the PC and condition codes registers #############
register fF {
  pc : 64 = 0 ;
}

register cC {
  SF : 1 = 0 ;
  ZF : 1 = 1 ;
}

########## Fetch #############
pc = F_pc ;

f_icode = i10bytes[4..8] ;
f_ifun  = i10bytes[0..4] ;
f_rA  = i10bytes[12..16] ;
f_rB  = i10bytes[8..12] ;
f_valC = [
  f_icode in { JXX, CALL } : i10bytes[8..72] ;
  1 : i10bytes[16..80] ;
] ;

wire offset : 64 ;
offset = [
  f_icode in { HALT, NOP, RET } : 1 ;
  f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2 ;
  f_icode in { JXX, CALL } : 9 ;
  1 : 10 ;
] ;
f_valP = F_pc + offset ;

########## Pipeline Register fD ##########

register fD {
  icode : 4 = NOP ;
  ifun : 4  = NOP ;
  rA : 4 = 0 ;
  rB : 4 = 0 ;
  valC : 64 = 0 ;
  valP : 64 = 0 ;
}

########## Decode #############

reg_srcA = [
  D_icode in { RRMOVQ, RMMOVQ, MRMOVQ, OPQ, PUSHQ, POPQ } : D_rA ;
  1 : REG_NONE ;
] ;
reg_srcB = [
  D_icode in { OPQ, RMMOVQ, MRMOVQ } : D_rB ;
  D_icode in { PUSHQ, POPQ, CALL, RET } : REG_RSP ;
  1 : REG_NONE ;
] ;

d_icode = D_icode ;
d_ifun  = D_ifun ;

d_valA = [
  reg_srcA == m_dstE : m_valE ;
  W_dstE == reg_srcA && W_dstE != REG_NONE : reg_inputE ;
  1 : reg_outputA ;
] ;
# add more conditions for forwarding
d_valB = [
  reg_srcB == m_dstE : m_valE ;
  W_dstE == reg_srcB && W_dstE != REG_NONE : reg_inputE ;
  1 : reg_outputB ;
] ;

d_dstE = [
  d_icode in { IRMOVQ, RRMOVQ } : D_rB ;
  1 : REG_NONE ;
] ;

d_valC = D_valC ;
d_valP = D_valP ;
d_rA = D_rA ;
d_rB = D_rB ;

########## Pipeline Register dE ##########

register dE {
  icode : 4 = NOP ;
  ifun : 4  = NOP ;
  rA : 4 = 0 ;
  rB : 4 = 0 ;
  valA : 64 = 0 ;
  valB : 64 = 0 ;
  valC : 64 = 0 ;
  dstE : 4 = REG_NONE;
  valP : 64 = 0 ;
}

########## Execute #############
wire conditionsMet : 1 ;
conditionsMet = [
  E_ifun == ALWAYS : true ;
  E_ifun == LE : C_SF || C_ZF ;
  E_ifun == LT : C_SF ;
  E_ifun == EQ : C_ZF ;
  E_ifun == NE : !C_ZF ;
  E_ifun == GE : !C_SF ;
  E_ifun == GT : !C_SF && !C_ZF ;
  1 : false ;
] ;

e_valE = [
  E_icode == OPQ && E_ifun == ADDQ : reg_outputA + reg_outputB ;
  E_icode == OPQ && E_ifun == SUBQ : reg_outputB - reg_outputA ;
  E_icode == OPQ && E_ifun == ANDQ : reg_outputA & reg_outputB ;
  E_icode == OPQ && E_ifun == XORQ : reg_outputA ^ reg_outputB ;
  E_icode in { RMMOVQ, MRMOVQ } : E_valC + reg_outputB ;
  E_icode in { PUSHQ, CALL } : reg_outputB - 8 ;
  E_icode in { POPQ, RET } : reg_outputB + 8 ;
  1 : 0 ;
] ;

### simplified condition codes
c_ZF    = e_valE == 0 ;
c_SF    = e_valE >= 0x8000000000000000 ;
stall_C = E_icode != OPQ ;

e_icode = E_icode ;
e_rA = E_rA ;
e_rB = E_rB ;
e_valA  = E_valA ;
e_valB  = E_valB ;
e_valC  = E_valC ;
e_valP  = E_valP ;

########## Pipeline Register eM ##########

register eM {
  icode : 4 = NOP ;
  rA : 4 = REG_NONE;
  rB : 4 = REG_NONE;
  valA : 64 = 0 ;
  valB : 64 = 0 ;
  valC : 64 = 0 ;
  valE : 64 = 0 ;
  valP : 64 = 0 ;
}

########## Memory #############
mem_readbit  = M_icode in { MRMOVQ, POPQ, RET } ;
mem_writebit = M_icode in { RMMOVQ, PUSHQ, CALL } ;
mem_addr = [
  M_icode in { POPQ, RET } : reg_outputB ;
  1 : M_valE ;
] ;
mem_input = [
  M_icode == CALL : M_valP ;
  1 : reg_outputA ;
] ;


m_dstE = [
  M_icode in { RRMOVQ } && conditionsMet : M_rB ;
  M_icode in { IRMOVQ, OPQ } : M_rB ;
  M_icode == MRMOVQ : M_rA ;
  M_icode in { PUSHQ, POPQ, CALL, RET } : REG_RSP ;
  1 : REG_NONE ;
] ;
m_dstM = [
  W_icode == POPQ : M_rA;
  1 : REG_NONE ;
] ;

m_icode = M_icode ;
m_valA  = M_valA ;
m_valB  = M_valB ;
m_valC  = M_valC ;
m_valE  = M_valE ;
m_valP  = M_valP ;
########## Pipeline Register mW ##########

register mW {
  icode : 4 = NOP ;
  valA : 64 = 0 ;
  valB : 64 = 0 ;
  valC : 64 = 0 ;
  valE : 64 = 0 ;
  dstE : 4  = REG_NONE ;
  dstM : 4  = REG_NONE ;
  valP : 64 = 0 ;
}

########## Writeback #############
reg_dstE = W_dstE ;
reg_dstM = W_dstM ;

reg_inputE = [
  W_icode == RRMOVQ : reg_outputA ;
  W_icode == MRMOVQ : mem_output ;
  W_icode in { OPQ, PUSHQ, POPQ, CALL, RET } : W_valE ;
  W_icode == IRMOVQ : W_valC ;
  1 : 0xbadbadbadbad ;
] ;
reg_inputM = [
  W_icode == POPQ : mem_output ;
  1 : 0 ;
] ;

Stat = [
  W_icode == HALT : STAT_HLT ;
  W_icode > 0xb : STAT_INS ;
  1 : STAT_AOK ;
] ;

########## PC Update #############
f_pc = [
  W_icode == JXX && conditionsMet : W_valC ;
  W_icode == CALL : W_valC ;
  W_icode == RET : mem_output ;
  Stat != STAT_AOK : F_pc ; # stalling for halt
  1 : W_valP ;
] ;


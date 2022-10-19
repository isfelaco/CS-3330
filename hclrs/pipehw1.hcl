########## the PC and condition codes registers #############

register fF { pc : 64 = 0 ; }


########## Fetch #############

pc = F_pc ;

wire rA : 4, rB : 4 ;

d_icode = i10bytes[4..8] ;
rA      = i10bytes[12..16] ;
rB      = i10bytes[8..12] ;

d_valC = [
  d_icode in { JXX } : i10bytes[8..72] ;
  1 : i10bytes[16..80] ;
] ;

wire offset : 64, valP : 64 ;
offset = [
  d_icode in { HALT, NOP, RET } : 1 ;
  d_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2 ;
  d_icode in { JXX, CALL } : 9 ;
  1 : 10 ;
] ;
valP = F_pc + offset ;

########## Pipeline Register Bank ##########
register fD {

}
############################################
########## Decode #############

# source selection
reg_srcA = [
  d_icode in { RRMOVQ } : rA ;
  1 : REG_NONE ;
] ;

d_valA = [
  W_dstE == reg_srcA && W_dstE != REG_NONE : reg_inputE ; # previous destination equals current rA
  1 : reg_outputA ;
] ;

d_dstE = [
  d_icode in { IRMOVQ, RRMOVQ } : rB ;
  1 : REG_NONE ;
] ;

d_Stat = [
  d_icode == HALT : STAT_HLT ;
  d_icode > 0xb : STAT_INS ;
  1 : STAT_AOK ;
] ;


########## Pipeline Register Bank ##########
register dW {
  icode : 4 = NOP ;
  valC : 64 = 0 ;
  valA : 64 = 0 ;
  dstE : 4  = REG_NONE ;
  Stat : 3  = STAT_AOK ;
}
############################################
########## Execute #############



########## Pipeline Register Bank ##########
register eM {

}
############################################
########## Memory #############



########## Pipeline Register Bank ##########
register mW {

}
############################################
########## Writeback #############

# destination selection

reg_dstE = W_dstE ;

reg_inputE = [ # unlike book, we handle the "forwarding" actions (something + 0) here
  W_icode == RRMOVQ : W_valA ;
  W_icode in { IRMOVQ } : W_valC ;
  1 : 0xBADBADBAD ;
] ;


########## PC and Status updates #############

Stat = W_Stat ;

f_pc = valP ;
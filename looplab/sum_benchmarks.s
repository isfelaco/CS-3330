	.file	"sum_benchmarks.c"
	.text
	.p2align 4
	.globl	sum_C
	.type	sum_C, @function
sum_C:
.LFB5278:
	.cfi_startproc
	endbr64
	testq	%rdi, %rdi
	jle	.L4
	leaq	(%rsi,%rdi,2), %rdx
	xorl	%eax, %eax
	.p2align 4,,10
	.p2align 3
.L3:
	addw	(%rsi), %ax
	addq	$2, %rsi
	cmpq	%rdx, %rsi
	jne	.L3
	ret
	.p2align 4,,10
	.p2align 3
.L4:
	xorl	%eax, %eax
	ret
	.cfi_endproc
.LFE5278:
	.size	sum_C, .-sum_C
	.p2align 4
	.globl	sum_multiple_accum_C
	.type	sum_multiple_accum_C, @function
sum_multiple_accum_C:
.LFB5279:
	.cfi_startproc
	endbr64
	testq	%rdi, %rdi
	jle	.L11
	leaq	-2(%rdi,%rdi), %rax
	xorl	%edx, %edx
	andq	$-4, %rax
	leaq	4(%rsi,%rax), %rcx
	xorl	%eax, %eax
	.p2align 4,,10
	.p2align 3
.L10:
	addw	(%rsi), %ax
	addw	2(%rsi), %dx
	addq	$4, %rsi
	cmpq	%rsi, %rcx
	jne	.L10
	addl	%edx, %eax
	ret
	.p2align 4,,10
	.p2align 3
.L11:
	xorl	%eax, %eax
	ret
	.cfi_endproc
.LFE5279:
	.size	sum_multiple_accum_C, .-sum_multiple_accum_C
	.globl	functions
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC0:
	.string	"sum_clang6_O: simple C compiled with clang 6 -O -mavx2"
	.align 8
.LC1:
	.string	"sum_gcc7_O3: simple C compiled with GCC7 -O3 -mavx2"
	.align 8
.LC2:
	.string	"sum_C: simple C compiled on this machine with settings in Makefile"
	.align 8
.LC3:
	.string	"sum_simple: simple ASM implementation"
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC4:
	.string	"sum_unrolled2"
.LC5:
	.string	"sum_unrolled4"
.LC6:
	.string	"sum_multiple_accum"
.LC7:
	.string	"sum_multiple_accum_C"
	.section	.data.rel,"aw"
	.align 32
	.type	functions, @object
	.size	functions, 144
functions:
	.quad	sum_clang6_O
	.quad	.LC0
	.quad	sum_gcc7_O3
	.quad	.LC1
	.quad	sum_C
	.quad	.LC2
	.quad	sum_simple
	.quad	.LC3
	.quad	sum_unrolled2
	.quad	.LC4
	.quad	sum_unrolled4
	.quad	.LC5
	.quad	sum_multiple_accum
	.quad	.LC6
	.quad	sum_multiple_accum_C
	.quad	.LC7
	.quad	0
	.quad	0
	.ident	"GCC: (Ubuntu 9.4.0-1ubuntu1~20.04.1) 9.4.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	 1f - 0f
	.long	 4f - 1f
	.long	 5
0:
	.string	 "GNU"
1:
	.align 8
	.long	 0xc0000002
	.long	 3f - 2f
2:
	.long	 0x3
3:
	.align 8
4:

/*
 * Copyright (c) 2016-2017, ARM Limited and Contributors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Neither the name of ARM nor the names of its contributors may be used
 * to endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef __ASM_MACROS_S__
#define __ASM_MACROS_S__

#include <arch.h>
#include <asm_macros_common.S>
#include <spinlock.h>

#define WORD_SIZE	4

	/*
	 * Co processor register accessors
	 */
	.macro ldcopr reg, coproc, opc1, CRn, CRm, opc2
	mrc	\coproc, \opc1, \reg, \CRn, \CRm, \opc2
	.endm

	.macro ldcopr16 reg1, reg2, coproc, opc1, CRm
	mrrc	\coproc, \opc1, \reg1, \reg2, \CRm
	.endm

	.macro stcopr reg, coproc, opc1, CRn, CRm, opc2
	mcr	\coproc, \opc1, \reg, \CRn, \CRm, \opc2
	.endm

	.macro stcopr16 reg1, reg2, coproc, opc1, CRm
	mcrr	\coproc, \opc1, \reg1, \reg2, \CRm
	.endm

	/* Cache line size helpers */
	.macro	dcache_line_size  reg, tmp
	ldcopr	\tmp, CTR
	ubfx	\tmp, \tmp, #CTR_DMINLINE_SHIFT, #CTR_DMINLINE_WIDTH
	mov	\reg, #WORD_SIZE
	lsl	\reg, \reg, \tmp
	.endm

	.macro	icache_line_size  reg, tmp
	ldcopr	\tmp, CTR
	and	\tmp, \tmp, #CTR_IMINLINE_MASK
	mov	\reg, #WORD_SIZE
	lsl	\reg, \reg, \tmp
	.endm

	/*
	 * Declare the exception vector table, enforcing it is aligned on a
	 * 32 byte boundary.
	 */
	.macro vector_base  label
	.section .vectors, "ax"
	.align 5
	\label:
	.endm

	/*
	 * This macro calculates the base address of the current CPU's multi
	 * processor(MP) stack using the plat_my_core_pos() index, the name of
	 * the stack storage and the size of each stack.
	 * Out: r0 = physical address of stack base
	 * Clobber: r14, r1, r2
	 */
	.macro get_my_mp_stack _name, _size
	bl  plat_my_core_pos
	ldr r2, =(\_name + \_size)
	mov r1, #\_size
	mla r0, r0, r1, r2
	.endm

	/*
	 * This macro calculates the base address of a uniprocessor(UP) stack
	 * using the name of the stack storage and the size of the stack
	 * Out: r0 = physical address of stack base
	 */
	.macro get_up_stack _name, _size
	ldr r0, =(\_name + \_size)
	.endm

	/*
	 * Macro to mark instances where we're jumping to a function and don't
	 * expect a return. To provide the function being jumped to with
	 * additional information, we use 'bl' instruction to jump rather than
	 * 'b'.
         *
	 * Debuggers infer the location of a call from where LR points to, which
	 * is usually the instruction after 'bl'. If this macro expansion
	 * happens to be the last location in a function, that'll cause the LR
	 * to point a location beyond the function, thereby misleading debugger
	 * back trace. We therefore insert a 'nop' after the function call for
	 * debug builds, unless 'skip_nop' parameter is non-zero.
	 */
	.macro no_ret _func:req, skip_nop=0
	bl	\_func
#if DEBUG
	.ifeq \skip_nop
	nop
	.endif
#endif
	.endm

	/*
	 * Reserve space for a spin lock in assembly file.
	 */
	.macro define_asm_spinlock _name:req
	.align	SPINLOCK_ASM_ALIGN
	\_name:
	.space	SPINLOCK_ASM_SIZE
	.endm

	/*
	 * Helper macro to OR the bottom 32 bits of `_val` into `_reg_l`
	 * and the top 32 bits of `_val` into `_reg_h`.  If either the bottom
	 * or top word of `_val` is zero, the corresponding OR operation
	 * is skipped.
	 */
	.macro orr64_imm _reg_l, _reg_h, _val
		.if (\_val >> 32)
			orr \_reg_h, \_reg_h, #(\_val >> 32)
		.endif
		.if (\_val & 0xffffffff)
			orr \_reg_l, \_reg_l, #(\_val & 0xffffffff)
		.endif
	.endm

	/*
	 * Helper macro to bitwise-clear bits in `_reg_l` and
	 * `_reg_h` given a 64 bit immediate `_val`.  The set bits
	 * in the bottom word of `_val` dictate which bits from
	 * `_reg_l` should be cleared.  Similarly, the set bits in
	 * the top word of `_val` dictate which bits from `_reg_h`
	 * should be cleared.  If either the bottom or top word of
	 * `_val` is zero, the corresponding BIC operation is skipped.
	 */
	.macro bic64_imm _reg_l, _reg_h, _val
		.if (\_val >> 32)
			bic \_reg_h, \_reg_h, #(\_val >> 32)
		.endif
		.if (\_val & 0xffffffff)
			bic \_reg_l, \_reg_l, #(\_val & 0xffffffff)
		.endif
	.endm

#endif /* __ASM_MACROS_S__ */

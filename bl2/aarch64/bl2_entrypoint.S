/*
 * Copyright (c) 2013-2017, ARM Limited and Contributors. All rights reserved.
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

#include <arch.h>
#include <asm_macros.S>
#include <bl_common.h>


	.globl	bl2_entrypoint



func bl2_entrypoint
	/*---------------------------------------------
	 * Save from x1 the extents of the tzram
	 * available to BL2 for future use.
	 * x0 is not currently used.
	 * ---------------------------------------------
	 */
	mov	x20, x1

	/* ---------------------------------------------
	 * Set the exception vector to something sane.
	 * ---------------------------------------------
	 */
	adr	x0, early_exceptions
	msr	vbar_el1, x0
	isb

	/* ---------------------------------------------
	 * Enable the SError interrupt now that the
	 * exception vectors have been setup.
	 * ---------------------------------------------
	 */
	msr	daifclr, #DAIF_ABT_BIT

	/* ---------------------------------------------
	 * Enable the instruction cache, stack pointer
	 * and data access alignment checks
	 * ---------------------------------------------
	 */
	mov	x1, #(SCTLR_I_BIT | SCTLR_A_BIT | SCTLR_SA_BIT)
	mrs	x0, sctlr_el1
	orr	x0, x0, x1
	msr	sctlr_el1, x0
	isb

	/* ---------------------------------------------
	 * Invalidate the RW memory used by the BL2
	 * image. This includes the data and NOBITS
	 * sections. This is done to safeguard against
	 * possible corruption of this memory by dirty
	 * cache lines in a system cache as a result of
	 * use by an earlier boot loader stage.
	 * ---------------------------------------------
	 */
	adr	x0, __RW_START__
	adr	x1, __RW_END__
	sub	x1, x1, x0
	bl	inv_dcache_range

	/* ---------------------------------------------
	 * Zero out NOBITS sections. There are 2 of them:
	 *   - the .bss section;
	 *   - the coherent memory section.
	 * ---------------------------------------------
	 */
	ldr	x0, =__BSS_START__
	ldr	x1, =__BSS_SIZE__
	bl	zeromem

#if USE_COHERENT_MEM
	ldr	x0, =__COHERENT_RAM_START__
	ldr	x1, =__COHERENT_RAM_UNALIGNED_SIZE__
	bl	zeromem
#endif

	/* --------------------------------------------
	 * Allocate a stack whose memory will be marked
	 * as Normal-IS-WBWA when the MMU is enabled.
	 * There is no risk of reading stale stack
	 * memory after enabling the MMU as only the
	 * primary cpu is running at the moment.
	 * --------------------------------------------
	 */
	bl	plat_set_my_stack

	/* ---------------------------------------------
	 * Initialize the stack protector canary before
	 * any C code is called.
	 * ---------------------------------------------
	 */
#if STACK_PROTECTOR_ENABLED
	bl	update_stack_protector_canary
#endif

	/* ---------------------------------------------
	 * Perform early platform setup & platform
	 * specific early arch. setup e.g. mmu setup
	 * ---------------------------------------------
	 */
	mov	x0, x20
	bl	bl2_early_platform_setup
	bl	bl2_plat_arch_setup

	/* ---------------------------------------------
	 * Jump to main function.
	 * ---------------------------------------------
	 */
	bl	bl2_main

	/* ---------------------------------------------
	 * Should never reach this point.
	 * ---------------------------------------------
	 */
	no_ret	plat_panic_handler

endfunc bl2_entrypoint

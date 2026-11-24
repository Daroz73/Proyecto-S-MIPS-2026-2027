# t7_extremos_alu.asm -- casos extremos y peculiares de la ALU y de $zero.
# Instrucciones: add, sub, and, or, slt, slti, sll, srl, addi, andi, ori, lui, lw, lb, lbu,
#   addiu (li), addu (move), syscall (11 y 10).
# Casos de la tabla de casos que cubre (ademas de t1/t2):
#   add/sub : operandos positivos y negativos en los limites de 32 bits sin desbordamiento.
#   and/or  : operandos con unos en los 16 bits altos (0xaaaaaaaa, 0x55555555, 0xffff0000).
#   slt/slti: resultados 1 y 0 con negativos (-1 < 0 da 1 con signo y 0 sin signo).
#   sll/srl : shamt = 31 y 1; srl sobre negativos (entran ceros).
#   addi    : inmediatos -32768, 0 y 32767 sobre $zero.
#   addiu/addu: li 0, li -1, move.
#   andi/ori/lui: inmediatos con el bit 15 a 1 (0xffff).
#   $zero   : se escribe con add, sub, and, or, slt, slti, sll, srl, addi, andi, ori, lui,
#             lw, lb, lbu y move; despues sigue valiendo 0.
# Extremos: acarreo que recorre los 32 bits (0x7fffffff + 0x80000001 = 0), acarreo del bit 15
#   al 16, INT_MIN + INT_MAX, 0 - INT_MAX, -1 - INT_MIN; slt con valores contiguos
#   (-1/0, INT_MIN/-1), slt de un registro consigo mismo, slti con 0 y en el limite 32767;
#   1 << 31, INT_MIN >> 31, -1 >> 1; destino = origen en sll/srl/and/or; patrones alternos.
# Salida: 7 lineas de 5 valores hex de 32 bits.

        .data
dato:   .word 0x12345678
bff:    .word 0xffffffff

        .text
main:
        li   $s0, 0x7fffffff        # INT_MAX
        lui  $s1, 0x8000            # INT_MIN
        li   $s2, -1
# ---- linea 1: acarreos y limites de 32 bits ----
        li   $t4, 0x80000001
        add  $a0, $s0, $t4          # acarreo por los 32 bits: 0x00000000
        jal  ph
        li   $t4, 0x0000ffff
        addi $a0, $t4, 1            # acarreo del bit 15 al 16: 0x00010000
        jal  ph
        sub  $a0, $zero, $s0        # 0 - INT_MAX: 0x80000001
        jal  ph
        sub  $a0, $s2, $s1          # -1 - INT_MIN: 0x7fffffff
        jal  ph
        add  $a0, $s1, $s0          # INT_MIN + INT_MAX: 0xffffffff
        jal  ph
        jal  nl
# ---- linea 2: addi/li en los limites ----
        addi $a0, $zero, 32767      # 0x00007fff
        jal  ph
        addi $a0, $zero, -32768     # 0xffff8000
        jal  ph
        la   $t4, dato
        lw   $t4, 0($t4)
        addi $a0, $t4, 0            # inmediato 0: copia 0x12345678
        jal  ph
        li   $a0, 0                 # 0x00000000
        jal  ph
        li   $a0, -1                # 0xffffffff
        jal  ph
        jal  nl
# ---- linea 3: slt con valores contiguos ----
        slt  $a0, $s2, $zero        # -1 < 0 -> 1 (sin signo: 0)
        jal  ph
        slt  $a0, $zero, $s2        # 0 < -1 -> 0 (sin signo: 1)
        jal  ph
        slt  $a0, $s2, $s2          # registro consigo mismo -> 0
        jal  ph
        slt  $a0, $s1, $s2          # INT_MIN < -1 -> 1
        jal  ph
        slt  $a0, $s0, $zero        # INT_MAX < 0 -> 0
        jal  ph
        jal  nl
# ---- linea 4: slti en los limites ----
        slti $a0, $s2, 0            # -1 < 0 -> 1
        jal  ph
        slti $a0, $zero, 0          # 0 < 0 -> 0
        jal  ph
        slti $a0, $s1, 0            # INT_MIN < 0 -> 1
        jal  ph
        li   $t4, 32767
        slti $a0, $t4, 32767        # 32767 < 32767 -> 0
        jal  ph
        li   $t4, 32766
        slti $a0, $t4, 32767        # 32766 < 32767 -> 1
        jal  ph
        jal  nl
# ---- linea 5: desplazamientos extremos y destino = origen ----
        li   $t4, 1
        sll  $a0, $t4, 31           # 0x80000000
        jal  ph
        srl  $a0, $s1, 31           # INT_MIN >> 31: 0x00000001
        jal  ph
        srl  $a0, $s2, 1            # -1 >> 1: 0x7fffffff
        jal  ph
        li   $t4, 3
        sll  $t4, $t4, 30           # rd = rt: 0xc0000000
        srl  $t4, $t4, 29           # rd = rt: 0x00000006
        move $a0, $t4
        jal  ph
        srl  $a0, $t4, 3            # todo se pierde: 0x00000000
        jal  ph
        jal  nl
# ---- linea 6: and/or/andi/ori con patrones alternos ----
        li   $t4, 0xaaaaaaaa
        li   $t5, 0x55555555
        and  $a0, $t4, $t5          # 0x00000000
        jal  ph
        or   $a0, $t4, $t5          # 0xffffffff
        jal  ph
        and  $t6, $t4, $t4          # rd = rs = rt: 0xaaaaaaaa
        or   $t6, $t6, $t6
        move $a0, $t6
        jal  ph
        lui  $t6, 0xffff
        ori  $a0, $t6, 0xffff       # 0xffffffff
        jal  ph
        andi $a0, $t5, 0xffff       # 0x00005555
        jal  ph
        jal  nl
# ---- linea 7: escrituras en $zero con todos los tipos de instruccion ----
        li   $s7, 0                 # acumula $zero tras cada escritura
        add  $zero, $s2, $s0         # -1 + INT_MAX (sin desbordamiento)
        or   $s7, $s7, $zero
        sub  $zero, $s2, $s0
        or   $s7, $s7, $zero
        and  $zero, $s2, $s2
        or   $s7, $s7, $zero
        or   $zero, $s2, $s2
        or   $s7, $s7, $zero
        slt  $zero, $s2, $s0
        or   $s7, $s7, $zero
        slti $zero, $s2, 5
        or   $s7, $s7, $zero
        sll  $zero, $s2, 4
        or   $s7, $s7, $zero
        srl  $zero, $s2, 4
        or   $s7, $s7, $zero
        addi $zero, $zero, -1
        or   $s7, $s7, $zero
        andi $zero, $s2, 0xffff
        or   $s7, $s7, $zero
        ori  $zero, $zero, 0xffff
        or   $s7, $s7, $zero
        lui  $zero, 0xffff
        or   $s7, $s7, $zero
        la   $t4, bff
        lw   $zero, 0($t4)
        or   $s7, $s7, $zero
        lb   $zero, 0($t4)
        or   $s7, $s7, $zero
        lbu  $zero, 1($t4)
        or   $s7, $s7, $zero
        move $zero, $s2
        or   $s7, $s7, $zero
        move $a0, $s7               # OR de $zero tras cada escritura: 0
        jal  ph
        move $a0, $zero             # 0
        jal  ph
        addi $a0, $zero, 1          # $zero como operando: 1
        jal  ph
        lw   $a0, 0($t4)            # la escritura en $zero no toco la memoria: 0xffffffff
        jal  ph
        sub  $a0, $zero, $s2        # 0 - (-1) = 1
        jal  ph
        jal  nl

        li   $v0, 10
        syscall

# ---------- rutinas de impresion (solo syscall 11); usan $t0-$t3, $a0, $v0 ----------
ph:     move $t0, $a0               # imprime $a0 en hex (8 digitos) y un espacio
        li   $t1, 8
ph_b:   srl  $t2, $t0, 28
        slti $t3, $t2, 10
        beq  $t3, $zero, ph_l
        addi $a0, $t2, 48           # '0'..'9'
        j    ph_p
ph_l:   addi $a0, $t2, 87           # 'a'..'f'
ph_p:   li   $v0, 11
        syscall
        sll  $t0, $t0, 4
        addi $t1, $t1, -1
        bne  $t1, $zero, ph_b
        li   $a0, 32
        li   $v0, 11
        syscall
        jr   $ra
nl:     li   $a0, 10                # salto de linea
        li   $v0, 11
        syscall
        jr   $ra

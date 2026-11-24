# t3_memoria.asm -- acceso a memoria (little-endian).
# Instrucciones: lw, sw, lb, lbu, sb, lui, ori, addi, addiu (li), addu (move), la, syscall (11 y 10).
# Casos de la tabla de casos que cubre:
#   lw/sw  : desplazamiento positivo (4, 8, 32764) y negativo (-4, -8, -12, -32768).
#   lb/lbu : bytes con bit 7 a 1 en las cuatro posiciones de la palabra (d[1:0] = 0, 1, 2, 3).
#   sb     : en las cuatro posiciones de una misma palabra; tras cada sb se lee con lw
#            y se comprueba que los otros tres bytes no cambiaron.
# Extremos extra: $gp y $sp iniciales (R6), lb/lbu de bytes con bit 7 a 0 (0x7f, 0x01),
#   desplazamientos negativos en lb/lbu/sb, sb de un registro con bits altos a 1 (solo
#   se escribe el byte bajo), palabras vecinas intactas tras sb, desplazamientos extremos
#   -32768 y 32764 (base fuera de la memoria), primera palabra de .data (0x2000),
#   ultima palabra de la memoria (0x3ffc), pila con desplazamientos negativos.
# Salida: 8 lineas de 5 valores hex de 32 bits.

        .data
w0:     .word 0x8899aabb            # bytes bb aa 99 88: los cuatro con bit 7 a 1
w1:     .word 0x017f80ff            # bytes ff 80 7f 01
buf:    .space 16

        .text
main:
# ---- linea 1: valores iniciales y lb con bit 7 = 1 en las cuatro posiciones ----
        move $a0, $gp               # 0x00001800
        jal  ph
        move $a0, $sp               # 0x00003ffc
        jal  ph
        la   $s0, w0                # 0x2000
        lb   $a0, 0($s0)            # 0xffffffbb
        jal  ph
        lb   $a0, 1($s0)            # 0xffffffaa
        jal  ph
        lb   $a0, 2($s0)            # 0xffffff99
        jal  ph
        jal  nl
# ---- linea 2: lb byte 3, lbu en las cuatro posiciones ----
        lb   $a0, 3($s0)            # 0xffffff88
        jal  ph
        lbu  $a0, 0($s0)            # 0x000000bb
        jal  ph
        lbu  $a0, 1($s0)            # 0x000000aa
        jal  ph
        lbu  $a0, 2($s0)            # 0x00000099
        jal  ph
        lbu  $a0, 3($s0)            # 0x00000088
        jal  ph
        jal  nl
# ---- linea 3: lb/lbu con bit 7 = 0 y desplazamientos negativos ----
        la   $s1, w1
        lb   $a0, 2($s1)            # 0x7f -> 0x0000007f
        jal  ph
        lb   $a0, 3($s1)            # 0x01 -> 0x00000001
        jal  ph
        lb   $a0, 1($s1)            # 0x80 -> 0xffffff80
        jal  ph
        lb   $a0, -1($s1)           # byte 3 de w0: 0xffffff88
        jal  ph
        lbu  $a0, -4($s1)           # byte 0 de w0: 0x000000bb
        jal  ph
        jal  nl
# ---- linea 4: sb en las cuatro posiciones de una palabra, lw tras cada uno ----
        la   $s2, buf
        li   $t4, 0x11223344
        sw   $t4, 0($s2)
        lw   $a0, 0($s2)            # 0x11223344
        jal  ph
        li   $t4, -86               # 0xffffffaa: solo se escribe 0xaa
        sb   $t4, 0($s2)
        lw   $a0, 0($s2)            # 0x112233aa
        jal  ph
        li   $t4, 0x7fffffbb        # solo se escribe 0xbb
        sb   $t4, 1($s2)
        lw   $a0, 0($s2)            # 0x1122bbaa
        jal  ph
        li   $t4, 0xcc
        sb   $t4, 2($s2)
        lw   $a0, 0($s2)            # 0x11ccbbaa
        jal  ph
        li   $t4, 0xdd
        sb   $t4, 3($s2)
        lw   $a0, 0($s2)            # 0xddccbbaa
        jal  ph
        jal  nl
# ---- linea 5: sb con desplazamiento negativo y palabras vecinas intactas ----
        li   $t4, 0x55555555
        sw   $t4, 4($s2)
        sw   $t4, 8($s2)
        addi $s3, $s2, 8            # s3 = buf+8
        li   $t4, 0x80
        sb   $t4, -1($s3)           # byte 3 de buf+4
        li   $t4, 0x01
        sb   $t4, -4($s3)           # byte 0 de buf+4
        lw   $a0, -4($s3)           # 0x80555501
        jal  ph
        lw   $a0, 0($s2)            # vecina de abajo intacta: 0xddccbbaa
        jal  ph
        lw   $a0, 0($s3)            # vecina de arriba intacta: 0x55555555
        jal  ph
        lb   $a0, -1($s3)           # lb del byte escrito: 0xffffff80
        jal  ph
        lbu  $a0, -4($s3)           # 0x00000001
        jal  ph
        jal  nl
# ---- linea 6: lw/sw con desplazamiento positivo y negativo ----
        li   $t4, 0xcafe0001
        sw   $t4, 12($s2)           # positivo
        lw   $a0, 12($s2)           # 0xcafe0001
        jal  ph
        addi $s4, $s2, 16           # s4 = buf+16
        lw   $a0, -4($s4)           # negativo, misma palabra: 0xcafe0001
        jal  ph
        li   $t4, 0x0badf00d
        sw   $t4, -12($s4)          # escribe buf+4
        lw   $a0, 4($s2)            # 0x0badf00d
        jal  ph
        lw   $a0, -16($s4)          # buf+0: 0xddccbbaa
        jal  ph
        lw   $a0, 8($s0)            # w0+8 = buf+0: 0xddccbbaa
        jal  ph
        jal  nl
# ---- linea 7: desplazamientos extremos y limites de la memoria ----
        lui  $t4, 0x0000
        ori  $s5, $t4, 0xa000       # base 0xa000 (fuera de la memoria)
        lw   $a0, -32768($s5)       # 0xa000-0x8000 = 0x2000 (w0): 0x8899aabb
        jal  ph
        li   $s6, 0xffffa004        # base 0x2000-32764 (negativa)
        lw   $a0, 32764($s6)        # 0x2000 (w0): 0x8899aabb
        jal  ph
        li   $t4, 0x13579bdf
        sw   $t4, -32768($s5)       # escribe en w0 con desplazamiento -32768
        lw   $a0, 0($s0)            # 0x13579bdf
        jal  ph
        li   $t4, 0x2468ace0
        sw   $t4, 32764($s6)        # escribe en w0 con desplazamiento 32764
        lw   $a0, 0($s0)            # 0x2468ace0
        jal  ph
        li   $t4, 0x3ffc3ffc
        li   $s7, 0x3ffc
        sw   $t4, 0($s7)            # ultima palabra de la memoria
        lw   $a0, 0($s7)            # 0x3ffc3ffc
        jal  ph
        jal  nl
# ---- linea 8: pila (sw/lw con desplazamiento negativo respecto al tope previo) ----
        addi $sp, $sp, -12
        li   $t4, 0x00000111
        sw   $t4, 8($sp)
        li   $t4, 0x00000222
        sw   $t4, 4($sp)
        li   $t4, 0x00000333
        sw   $t4, 0($sp)
        addi $s7, $sp, 12           # tope anterior
        lw   $a0, -12($s7)          # 0x00000333
        jal  ph
        lw   $a0, -8($s7)           # 0x00000222
        jal  ph
        lw   $a0, -4($s7)           # 0x00000111
        jal  ph
        addi $sp, $sp, 12
        move $a0, $sp               # 0x00003ffc
        jal  ph
        lb   $a0, 0($sp)            # byte 0 de 0x3ffc3ffc: 0xfffffffc
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

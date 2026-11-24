# t2_inmediatos.asm -- desplazamientos e instrucciones con inmediato.
# Instrucciones: sll, srl, slti, andi, ori, lui, addiu (li), addu (move), syscall (11 y 10).
# Casos de la tabla de casos que cubre:
#   sll/srl : shamt = 0 y shamt != 0 (1, 4, 28, 31); srl sobre negativos (entran ceros).
#   slti    : resultado 1 y 0; -7<3 (=1, sin signo 0) y 3<-5 (=0, sin signo 1).
#   andi/ori: inmediatos con el bit 15 a 1 (0x8001, 0xffff, 0x8000, 0x8888, 0xf0f0, 0xf000).
#   lui     : inmediatos con el bit 15 a 1 (0x8001, 0xffff, 0x8000, 0xdead).
# Extremos extra: sll que saca bits por arriba, srl 31 de -1, slti con -32768 y 32767,
#   slti con iguales, andi/ori con 0 y con $zero, lui que pisa un valor previo, lui 0.
# Salida: 7 lineas de 5 valores hex de 32 bits.

        .text
main:
        li   $s0, 0x80000001        # negativo con bits en ambos extremos
        li   $s1, 0x12345678
        li   $s2, -1                # 0xffffffff
# ---- linea 1: sll ----
        sll  $a0, $s1, 0            # 0x12345678
        jal  ph
        sll  $a0, $s1, 4            # 0x23456780
        jal  ph
        sll  $a0, $s0, 31           # 0x80000000
        jal  ph
        sll  $a0, $s0, 1            # 0x00000002 (se pierde el bit 31)
        jal  ph
        sll  $a0, $s2, 28           # 0xf0000000
        jal  ph
        jal  nl
# ---- linea 2: srl (entran ceros) ----
        srl  $a0, $s0, 0            # 0x80000001
        jal  ph
        srl  $a0, $s0, 1            # 0x40000000
        jal  ph
        srl  $a0, $s0, 31           # 0x00000001
        jal  ph
        srl  $a0, $s2, 28           # 0x0000000f
        jal  ph
        srl  $a0, $s1, 4            # 0x01234567
        jal  ph
        jal  nl
# ---- linea 3: slti ----
        li   $s3, -7
        li   $s4, 3
        slti $a0, $s3, 3            # -7 < 3  -> 1 (sin signo: 0)
        jal  ph
        slti $a0, $s4, -5           # 3 < -5  -> 0 (sin signo: 1)
        jal  ph
        slti $a0, $s4, 3            # iguales -> 0
        jal  ph
        lui  $s5, 0x8000            # INT_MIN
        slti $a0, $s5, -32768       # INT_MIN < -32768 -> 1
        jal  ph
        li   $s6, 0x7fffffff        # INT_MAX
        slti $a0, $s6, 32767        # INT_MAX < 32767 -> 0
        jal  ph
        jal  nl
# ---- linea 4: andi (extension con ceros) ----
        andi $a0, $s2, 0x8001       # 0x00008001 (no 0xffff8001)
        jal  ph
        andi $a0, $s2, 0xffff       # 0x0000ffff
        jal  ph
        andi $a0, $s1, 0xf0f0       # 0x00005070
        jal  ph
        andi $a0, $s0, 0x8000       # 0
        jal  ph
        andi $a0, $s2, 0            # 0
        jal  ph
        jal  nl
# ---- linea 5: ori (extension con ceros) ----
        ori  $a0, $zero, 0x8000     # 0x00008000 (no 0xffff8000)
        jal  ph
        ori  $a0, $zero, 0xffff     # 0x0000ffff
        jal  ph
        ori  $a0, $s1, 0x8888       # 0x1234def8
        jal  ph
        ori  $a0, $s0, 0xf000       # 0x8000f001
        jal  ph
        ori  $a0, $s1, 0            # 0x12345678
        jal  ph
        jal  nl
# ---- linea 6: lui ----
        lui  $a0, 0x8001            # 0x80010000
        jal  ph
        lui  $a0, 0xffff            # 0xffff0000
        jal  ph
        move $t4, $s2
        lui  $t4, 0x1234            # pisa los 16 bits bajos: 0x12340000
        move $a0, $t4
        jal  ph
        lui  $a0, 0                 # 0
        jal  ph
        lui  $a0, 0x8000            # 0x80000000
        jal  ph
        jal  nl
# ---- linea 7: combinaciones ----
        lui  $t4, 0xdead
        ori  $a0, $t4, 0xbeef       # 0xdeadbeef
        jal  ph
        lui  $t4, 0xdead
        ori  $t4, $t4, 0xbeef
        srl  $t4, $t4, 16
        sll  $a0, $t4, 16           # 0xdead0000
        jal  ph
        lui  $t4, 0xdead
        ori  $t4, $t4, 0xbeef
        andi $a0, $t4, 0xffff       # 0x0000beef
        jal  ph
        sll  $t4, $s2, 16
        srl  $a0, $t4, 16           # 0x0000ffff
        jal  ph
        lui  $t4, 0x8000
        slti $a0, $t4, 0            # INT_MIN < 0 -> 1
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

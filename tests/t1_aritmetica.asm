# t1_aritmetica.asm -- aritmetica y logica con registros.
# Instrucciones: add, sub, and, or, slt, addi, addu (move), addiu (li), syscall (11 y 10), nop.
# Casos de la tabla de casos que cubre:
#   add/sub     : operandos positivos (pos+pos, pos-pos) y con negativos (pos+neg, neg+neg, neg-pos, 0-neg).
#   and/or      : operandos con unos en los 16 bits altos (0xf0f0ff00, 0xff00f0f0, 0xffff8000).
#   slt         : resultado 1 y 0; -7<1000 (=1, sin signo daria 0) y 1000<-7 (=0, sin signo daria 1).
#   addi        : inmediatos negativos (-1, -1000, -32768).
#   addiu/addu  : li con 32767, -32768, 1000, -7 (limites de 16 bits) y move.
#   $zero       : add, addi y move con destino $zero; despues $zero sigue valiendo 0.
# Extremos extra: resultado 0 de sub, rd = rs = rt, slt con iguales, slt INT_MIN/INT_MAX,
#   and/or con $zero, inmediato 32767 en addi, nop.
# Salida: 7 lineas de 5 valores hex de 32 bits.

        .text
main:
# ---- linea 1: li (addiu) en los limites de 16 bits y move (addu) ----
        li   $s0, 32767             # 0x00007fff
        li   $s1, -32768            # 0xffff8000
        li   $s2, 1000              # 0x000003e8
        li   $s3, -7                # 0xfffffff9
        move $a0, $s0
        jal  ph
        move $a0, $s1
        jal  ph
        move $a0, $s2
        jal  ph
        move $a0, $s3
        jal  ph
        move $t4, $s3               # move de un negativo
        move $a0, $t4
        jal  ph
        jal  nl
# ---- linea 2: add ----
        add  $a0, $s2, $s2          # pos+pos   = 0x000007d0
        jal  ph
        add  $a0, $s2, $s3          # pos+neg   = 993 = 0x000003e1
        jal  ph
        add  $a0, $s3, $s3          # neg+neg   = -14 = 0xfffffff2
        jal  ph
        add  $a0, $s1, $s0          # -32768+32767 = 0xffffffff
        jal  ph
        add  $t4, $s2, $zero
        add  $t4, $t4, $t4          # rd = rs = rt: 2000 = 0x000007d0
        move $a0, $t4
        jal  ph
        jal  nl
# ---- linea 3: sub ----
        sub  $a0, $s2, $s3          # 1000-(-7) = 0x000003ef
        jal  ph
        sub  $a0, $s3, $s2          # -7-1000   = 0xfffffc11
        jal  ph
        sub  $a0, $s3, $s3          # 0
        jal  ph
        sub  $a0, $s1, $s0          # -65535    = 0xffff0001
        jal  ph
        sub  $a0, $zero, $s1        # 0-(-32768) = 0x00008000
        jal  ph
        jal  nl
# ---- linea 4: and / or con unos en la mitad alta ----
        li   $s4, 0xf0f0ff00
        li   $s5, 0xff00f0f0
        and  $a0, $s4, $s5          # 0xf000f000
        jal  ph
        or   $a0, $s4, $s5          # 0xfff0fff0
        jal  ph
        and  $a0, $s4, $s1          # 0xf0f08000
        jal  ph
        or   $a0, $s3, $s1          # 0xfffffff9
        jal  ph
        and  $t4, $s4, $zero        # 0
        or   $a0, $t4, $zero        # 0
        jal  ph
        jal  nl
# ---- linea 5: slt ----
        slt  $a0, $s3, $s2          # -7 < 1000 -> 1 (sin signo: 0)
        jal  ph
        slt  $a0, $s2, $s3          # 1000 < -7 -> 0 (sin signo: 1)
        jal  ph
        slt  $a0, $s2, $s2          # iguales -> 0
        jal  ph
        lui  $s6, 0x8000            # INT_MIN
        li   $s7, 0x7fffffff        # INT_MAX
        slt  $a0, $s6, $s7          # INT_MIN < INT_MAX -> 1
        jal  ph
        slt  $a0, $s7, $s6          # INT_MAX < INT_MIN -> 0
        jal  ph
        jal  nl
# ---- linea 6: addi con inmediatos negativos ----
        addi $a0, $s2, -1000        # 0
        jal  ph
        addi $a0, $s2, -32768       # 1000-32768 = 0xffff83e8
        jal  ph
        addi $a0, $s3, -1           # 0xfffffff8
        jal  ph
        addi $a0, $s0, 1            # 0x00008000
        jal  ph
        addi $a0, $s1, 32767        # -1 = 0xffffffff
        jal  ph
        jal  nl
# ---- linea 7: escrituras en $zero ----
        add  $zero, $s2, $s2
        addi $zero, $zero, 5
        move $zero, $s3
        nop
        move $a0, $zero             # 0
        jal  ph
        add  $a0, $zero, $s2        # $zero como operando: 0x000003e8
        jal  ph
        addi $a0, $zero, -1         # 0xffffffff
        jal  ph
        sub  $a0, $zero, $zero      # 0
        jal  ph
        slt  $a0, $zero, $s2        # 0 < 1000 -> 1
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

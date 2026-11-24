# t4_control.asm -- control de flujo, procedimientos y syscall.
# Instrucciones: beq, bne, j, jal, jr, syscall (11 y 10), lw, sw, addi, add, sub, sll, slt,
#   addiu (li), addu (move), la, blt/bge/bgt/ble (pseudo: slt + beq/bne).
# Casos de la tabla de casos que cubre:
#   beq/bne : cada uno tomado y no tomado; saltos hacia atras (bucles con bne y con beq).
#   j       : hacia delante y hacia atras.
#   jal/jr  : procedimientos no hoja (f1 -> f2 -> f3, recursion rsum y fib) que guardan
#             $ra en la pila y retornan correctamente.
#   syscall : servicio 11 (toda la salida) y 10 (al final; lo que sigue no se ejecuta).
# Extremos extra: beq con negativos iguales, beq $zero,$zero, bne con valores que solo
#   difieren en el bit 31 y beq que solo difieren en el bit 0 (la comparacion usa los 32
#   bits), pseudo blt/bge/bgt/ble con negativos, $ra = direccion siguiente al jal,
#   jr con un registro distinto de $ra (tabla de saltos en .data), $sp restaurado.
# Salida: linea 1 letras T (tomado) / N (no tomado); lineas 2-4 valores hex.

        .data
tabla:  .word caso0, caso1, caso2

        .text
main:
# ---- linea 1: beq/bne tomados y no tomados (esperado: TNTNTTTNTNTN) ----
        li   $s0, 5
        li   $s1, 5
        li   $s2, 6
        beq  $s0, $s1, b1           # 5 == 5: tomado
        jal  pN
        j    b1f
b1:     jal  pT
b1f:    beq  $s0, $s2, b2           # 5 == 6: no tomado
        jal  pN
        j    b2f
b2:     jal  pT
b2f:    bne  $s0, $s2, b3           # 5 != 6: tomado
        jal  pN
        j    b3f
b3:     jal  pT
b3f:    bne  $s0, $s1, b4           # 5 != 5: no tomado
        jal  pN
        j    b4f
b4:     jal  pT
b4f:    li   $s3, -1
        li   $s4, 0xffffffff
        beq  $s3, $s4, b5           # -1 == 0xffffffff: tomado
        jal  pN
        j    b5f
b5:     jal  pT
b5f:    beq  $zero, $zero, b6       # siempre tomado
        jal  pN
        j    b6f
b6:     jal  pT
b6f:    lui  $s5, 0x8000
        bne  $s5, $zero, b7         # solo difieren en el bit 31: tomado
        jal  pN
        j    b7f
b7:     jal  pT
b7f:    li   $s6, 1
        beq  $s6, $zero, b8         # solo difieren en el bit 0: no tomado
        jal  pN
        j    b8f
b8:     jal  pT
b8f:    li   $s7, -3
        blt  $s7, $s6, b9           # -3 < 1: tomado
        jal  pN
        j    b9f
b9:     jal  pT
b9f:    bge  $s7, $s6, b10          # -3 >= 1: no tomado
        jal  pN
        j    b10f
b10:    jal  pT
b10f:   bgt  $s6, $s7, b11          # 1 > -3: tomado
        jal  pN
        j    b11f
b11:    jal  pT
b11f:   ble  $s6, $s7, b12          # 1 <= -3: no tomado
        jal  pN
        j    b12f
b12:    jal  pT
b12f:   jal  nl
# ---- linea 2: bucles con saltos hacia atras ----
        li   $s0, 0                 # suma
        li   $s1, 10                # i = 10..1
lazo1:  add  $s0, $s0, $s1
        addi $s1, $s1, -1
        bne  $s1, $zero, lazo1      # bne hacia atras
        move $a0, $s0               # 55 = 0x00000037
        jal  ph
        li   $s0, 0                 # cuenta
        li   $s1, 8
        li   $s2, 1
lazo2:  addi $s0, $s0, 1
        addi $s1, $s1, -1
        slt  $t4, $zero, $s1        # 1 mientras s1 > 0
        beq  $t4, $s2, lazo2        # beq hacia atras
        move $a0, $s0               # 8 = 0x00000008
        jal  ph
        li   $s0, 0
        li   $s1, -5
lazo3:  addi $s0, $s0, 1
        addi $s1, $s1, 1
        blt  $s1, 5, lazo3          # de -5 a 4: 10 vueltas
        move $a0, $s0               # 0x0000000a
        jal  ph
        li   $s0, 0
        li   $s1, 0
lazo4:  slti $t4, $s1, 6
        beq  $t4, $zero, fin4       # sale cuando s1 = 6
        add  $s0, $s0, $s1          # 0+1+2+3+4+5
        addi $s1, $s1, 1
        j    lazo4                  # j hacia atras
fin4:   move $a0, $s0               # 15 = 0x0000000f
        jal  ph
        jal  getra                  # $ra = direccion de 'tras'
tras:   la   $t4, tras
        sub  $a0, $v1, $t4          # 0
        jal  ph
        jal  nl
# ---- linea 3: procedimientos no hoja y recursion ----
        li   $a0, 5
        jal  f1                     # f1(5) = f2(5) + f3(5) = 12 + 6 = 18
        move $a0, $v0               # 0x00000012
        jal  ph
        li   $a0, 10
        jal  rsum                   # 10+9+...+1 = 55
        move $a0, $v0               # 0x00000037
        jal  ph
        li   $a0, 8
        jal  fib                    # fib(8) = 21
        move $a0, $v0               # 0x00000015
        jal  ph
        li   $a0, 0
        jal  rsum                   # caso base directo: 0
        move $a0, $v0
        jal  ph
        move $a0, $sp               # pila restaurada: 0x00003ffc
        jal  ph
        jal  nl
# ---- linea 4: jr con un registro distinto de $ra (tabla de saltos) ----
        li   $s0, 0                 # indice
        li   $s1, 3
lazo5:  la   $t4, tabla
        sll  $t5, $s0, 2
        add  $t4, $t4, $t5
        lw   $t6, 0($t4)            # direccion del caso
        jr   $t6
caso0:  li   $a0, 0xc0
        j    tras_caso
caso1:  li   $a0, 0xc1
        j    tras_caso
caso2:  li   $a0, 0xc2
tras_caso:
        add  $a0, $a0, $s0          # 0xc0, 0xc2, 0xc4
        jal  ph
        addi $s0, $s0, 1
        bne  $s0, $s1, lazo5
        la   $t6, ultimo
        jr   $t6                    # salto indirecto hacia delante
        li   $a0, 0xbad             # no se ejecuta
        jal  ph
ultimo: move $a0, $s0               # 0x00000003
        jal  ph
        jal  nl

        li   $v0, 10
        syscall
        li   $a0, 88                # 'X': no debe aparecer (la CPU ya se detuvo)
        li   $v0, 11
        syscall

# ---------- procedimientos ----------
getra:  move $v1, $ra               # hoja: devuelve su propio $ra en $v1
        jr   $ra

f3:     addi $v0, $a0, 1            # hoja: x + 1
        jr   $ra

f2:     addi $sp, $sp, -4           # no hoja: f3(x) * 2
        sw   $ra, 0($sp)
        jal  f3
        sll  $v0, $v0, 1
        lw   $ra, 0($sp)
        addi $sp, $sp, 4
        jr   $ra

f1:     addi $sp, $sp, -12          # no hoja: f2(x) + f3(x)
        sw   $ra, 8($sp)
        sw   $s0, 4($sp)
        sw   $a0, 0($sp)
        jal  f2
        move $s0, $v0
        lw   $a0, 0($sp)
        jal  f3
        add  $v0, $s0, $v0
        lw   $s0, 4($sp)
        lw   $ra, 8($sp)
        addi $sp, $sp, 12
        jr   $ra

rsum:   bne  $a0, $zero, rs_rec     # rsum(n) = n + rsum(n-1), rsum(0) = 0
        li   $v0, 0
        jr   $ra
rs_rec: addi $sp, $sp, -8
        sw   $ra, 4($sp)
        sw   $a0, 0($sp)
        addi $a0, $a0, -1
        jal  rsum
        lw   $a0, 0($sp)
        add  $v0, $v0, $a0
        lw   $ra, 4($sp)
        addi $sp, $sp, 8
        jr   $ra

fib:    slti $t4, $a0, 2            # fib(n) = n si n < 2; si no fib(n-1) + fib(n-2)
        beq  $t4, $zero, fb_rec
        move $v0, $a0
        jr   $ra
fb_rec: addi $sp, $sp, -12
        sw   $ra, 8($sp)
        sw   $s0, 4($sp)
        sw   $a0, 0($sp)
        addi $a0, $a0, -1
        jal  fib
        move $s0, $v0
        lw   $a0, 0($sp)
        addi $a0, $a0, -2
        jal  fib
        add  $v0, $s0, $v0
        lw   $a0, 0($sp)
        lw   $s0, 4($sp)
        lw   $ra, 8($sp)
        addi $sp, $sp, 12
        jr   $ra

# ---------- rutinas de impresion (solo syscall 11); usan $t0-$t3, $a0, $v0 ----------
pT:     li   $a0, 84                # 'T'
        li   $v0, 11
        syscall
        jr   $ra
pN:     li   $a0, 78                # 'N'
        li   $v0, 11
        syscall
        jr   $ra
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

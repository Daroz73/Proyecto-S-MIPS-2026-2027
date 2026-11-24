# t8_extremos_mem_saltos.asm -- casos extremos de memoria, saltos, reset y TTY.
# Instrucciones: or, lw, sw, lb, lbu, sb, beq, bne, j, jal, jr, addi, sll, srl, slti, lui, ori,
#   addiu (li), addu (move), la, nop, syscall (11 y 10).
# Casos de la tabla de casos que cubre (ademas de t3/t4):
#   lw/sw   : desplazamiento 0, positivo (+4) y negativo (-4); rt = rs.
#   lb/lbu  : bytes 0x00, 0xff, 0x7f y 0x80 (bit 7 a 1 en las posiciones 1 y 3).
#   sb      : posiciones 0..3 de una palabra 0xffffffff, con lw tras cada sb.
#   beq/bne : tomados y no tomados con el mismo registro; saltos lejanos hacia delante y
#             hacia atras (mas de 256 instrucciones).
#   j, jal/jr: a un procedimiento lejano que llama a otro (no hoja) y retorna.
#   syscall : 11 (mismo caracter varias veces seguidas) y 10.
# Extremos: registros a 0 tras el reset (R6) aunque el programa anterior los dejara
#   distintos de 0 (run_tests ejecuta todos los programas seguidos en la misma placa);
#   lw con rt = rs (la carga pisa su propia base); sw de un registro en la direccion que
#   contiene; sb del byte bajo de su propia base; sb de 0x00 sobre 0xff; lb/lbu de las
#   fronteras 0x7f/0x80 y 0x00/0xff; desplazamiento de salto con los bits 8 y 9 a 1;
#   TTY_WE un solo flanco por caracter (R4).
# Salida: 5 lineas.

        .data
w:      .word 0xcafebabe
bytes:  .word 0x807fff00            # bytes 00 ff 7f 80
unos:   .word 0xffffffff
buf:    .space 8

        .text
main:
# ---- R6: todos los registros salvo $gp y $sp valen 0 al empezar ----
        or   $26, $26, $1
        or   $26, $26, $2
        or   $26, $26, $3
        or   $26, $26, $4
        or   $26, $26, $5
        or   $26, $26, $6
        or   $26, $26, $7
        or   $26, $26, $8
        or   $26, $26, $9
        or   $26, $26, $10
        or   $26, $26, $11
        or   $26, $26, $12
        or   $26, $26, $13
        or   $26, $26, $14
        or   $26, $26, $15
        or   $26, $26, $16
        or   $26, $26, $17
        or   $26, $26, $18
        or   $26, $26, $19
        or   $26, $26, $20
        or   $26, $26, $21
        or   $26, $26, $22
        or   $26, $26, $23
        or   $26, $26, $24
        or   $26, $26, $25
        or   $26, $26, $27
        or   $26, $26, $30
        or   $26, $26, $31
# ---- linea 1: reset, lw con rt = rs, sw de su propia direccion, offsets 0/+4/-4 ----
        move $a0, $26               # OR de $1..$31 salvo $gp, $sp: 0x00000000
        jal  ph
        la   $t4, w
        lw   $t4, 0($t4)            # rt = rs: 0xcafebabe
        move $a0, $t4
        jal  ph
        la   $t5, buf
        sw   $t5, 0($t5)            # guarda su propia direccion (0x2000c)
        lw   $a0, 0($t5)            # 0x0000200c
        jal  ph
        sw   $t4, 4($t5)
        addi $t6, $t5, 8
        lw   $a0, -4($t6)           # 0xcafebabe
        jal  ph
        lw   $a0, -4($t5)           # palabra anterior (unos): 0xffffffff
        jal  ph
        jal  nl
# ---- linea 2: lb/lbu en las fronteras 0x00, 0xff, 0x7f, 0x80 ----
        la   $s0, bytes
        lb   $a0, 0($s0)            # 0x00 -> 0x00000000
        jal  ph
        lb   $a0, 1($s0)            # 0xff -> 0xffffffff
        jal  ph
        lbu  $a0, 1($s0)            # 0xff -> 0x000000ff
        jal  ph
        lb   $a0, 2($s0)            # 0x7f -> 0x0000007f
        jal  ph
        lb   $a0, 3($s0)            # 0x80 -> 0xffffff80
        jal  ph
        jal  nl
# ---- linea 3: sb de 0x00 y de su propia base sobre una palabra de unos ----
        la   $s1, unos
        sb   $zero, 1($s1)
        lw   $a0, 0($s1)            # 0xffff00ff
        jal  ph
        sb   $zero, 3($s1)
        lw   $a0, 0($s1)            # 0x00ff00ff
        jal  ph
        li   $t4, 0x80
        sb   $t4, 0($s1)
        lw   $a0, 0($s1)            # 0x00ff0080
        jal  ph
        sb   $s1, 2($s1)            # byte bajo de la base (0x08)
        lw   $a0, 0($s1)            # 0x00080080
        jal  ph
        lb   $a0, 0($s1)            # 0x80 -> 0xffffff80
        jal  ph
        jal  nl
# ---- linea 4: mismo caracter seguido, saltos con el mismo registro y saltos lejanos ----
        li   $a0, 65                # 'A' tres veces: TTY_WE un flanco por caracter
        li   $v0, 11
        syscall
        syscall
        syscall
        li   $s2, 7
        beq  $s2, $s2, b1           # mismo registro: tomado
        jal  pN
        j    b1f
b1:     jal  pT
b1f:    bne  $s2, $s2, b2           # mismo registro: no tomado
        jal  pN
        j    b2f
b2:     jal  pT
b2f:    li   $s3, 1
        beq  $zero, $zero, lejos    # salto hacia delante de mas de 300 instrucciones
        li   $a0, 88                # 'X': no se ejecuta
        li   $v0, 11
        syscall
cerca:  li   $a0, 66                # 'B': llegada del salto lejano hacia atras
        li   $v0, 11
        syscall
        j    tras_lejos
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
lejos:  li   $a0, 70                # 'F': llegada del salto lejano hacia delante
        li   $v0, 11
        syscall
        bne  $s3, $zero, cerca      # salto hacia atras de mas de 300 instrucciones
        li   $a0, 88                # 'X': no se ejecuta
        li   $v0, 11
        syscall
tras_lejos:
        jal  nl
# ---- linea 5: jal a un procedimiento lejano (no hoja) ----
        li   $a0, 0x1234
        jal  lejano                 # devuelve (a0 << 4) + 1 = 0x12341
        move $a0, $v0
        jal  ph
        move $a0, $sp               # pila restaurada: 0x00003ffc
        jal  ph
        jal  nl

        li   $v0, 10
        syscall

# ---------- procedimientos ----------
lejano: addi $sp, $sp, -4           # no hoja: guarda $ra y llama a uno
        sw   $ra, 0($sp)
        sll  $a0, $a0, 4
        jal  uno
        lw   $ra, 0($sp)
        addi $sp, $sp, 4
        jr   $ra
uno:    addi $v0, $a0, 1            # hoja
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

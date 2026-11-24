# t5_registros.asm -- banco de registros: los 32 registros guardan valores independientes.
# Instrucciones: lui, ori, addiu (li), sw, lw, addi, bne, jal, jr, syscall (11 y 10).
# Casos de la tabla de casos que cubre:
#   $zero   : li $zero (escritura con lui/ori a traves de $at) y despues vale 0.
#   sw/lw   : desplazamiento positivo grande desde $zero (0x2100..0x217c).
#   syscall : servicios 11 y 10.
# Extremos extra: escribe un valor distinto en $1..$31 (incluidos $at, $gp, $sp, $fp y $ra)
#   y comprueba despues que ninguna escritura piso a otro registro (fallo tipico del
#   decodificador de WRITE_REG o del multiplexor de lectura). El valor de $i es
#   i*0x01010101, con los cuatro bytes iguales, asi que un bit atascado tambien se ve.
# Salida: 7 lineas con el contenido de $0..$31 en hex (5 por linea).

        .text
main:
        li   $2,  0x02020202        # $at se escribe al final: li lo usa como temporal
        li   $3,  0x03030303
        li   $4,  0x04040404
        li   $5,  0x05050505
        li   $6,  0x06060606
        li   $7,  0x07070707
        li   $8,  0x08080808
        li   $9,  0x09090909
        li   $10, 0x0a0a0a0a
        li   $11, 0x0b0b0b0b
        li   $12, 0x0c0c0c0c
        li   $13, 0x0d0d0d0d
        li   $14, 0x0e0e0e0e
        li   $15, 0x0f0f0f0f
        li   $16, 0x10101010
        li   $17, 0x11111111
        li   $18, 0x12121212
        li   $19, 0x13131313
        li   $20, 0x14141414
        li   $21, 0x15151515
        li   $22, 0x16161616
        li   $23, 0x17171717
        li   $24, 0x18181818
        li   $25, 0x19191919
        li   $26, 0x1a1a1a1a
        li   $27, 0x1b1b1b1b
        li   $28, 0x1c1c1c1c
        li   $29, 0x1d1d1d1d
        li   $30, 0x1e1e1e1e
        li   $31, 0x1f1f1f1f
        li   $0,  0x5a5a5a5a        # escritura en $zero: no tiene efecto
        li   $1,  0x01010101
# guarda los 32 registros en 0x2100..0x217c sin usar ningun otro registro
        sw   $0,  0x2100($zero)
        sw   $1,  0x2104($zero)
        sw   $2,  0x2108($zero)
        sw   $3,  0x210c($zero)
        sw   $4,  0x2110($zero)
        sw   $5,  0x2114($zero)
        sw   $6,  0x2118($zero)
        sw   $7,  0x211c($zero)
        sw   $8,  0x2120($zero)
        sw   $9,  0x2124($zero)
        sw   $10, 0x2128($zero)
        sw   $11, 0x212c($zero)
        sw   $12, 0x2130($zero)
        sw   $13, 0x2134($zero)
        sw   $14, 0x2138($zero)
        sw   $15, 0x213c($zero)
        sw   $16, 0x2140($zero)
        sw   $17, 0x2144($zero)
        sw   $18, 0x2148($zero)
        sw   $19, 0x214c($zero)
        sw   $20, 0x2150($zero)
        sw   $21, 0x2154($zero)
        sw   $22, 0x2158($zero)
        sw   $23, 0x215c($zero)
        sw   $24, 0x2160($zero)
        sw   $25, 0x2164($zero)
        sw   $26, 0x2168($zero)
        sw   $27, 0x216c($zero)
        sw   $28, 0x2170($zero)
        sw   $29, 0x2174($zero)
        sw   $30, 0x2178($zero)
        sw   $31, 0x217c($zero)
# imprime las 32 palabras, 5 por linea
        li   $s0, 0x2100            # puntero
        li   $s1, 0x2180            # fin
        li   $s2, 5                 # valores que quedan en la linea
imp:    lw   $a0, 0($s0)
        jal  ph
        addi $s0, $s0, 4
        addi $s2, $s2, -1
        bne  $s2, $zero, sigue
        jal  nl
        li   $s2, 5
sigue:  bne  $s0, $s1, imp
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

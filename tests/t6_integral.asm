# t6_integral.asm -- prueba integral: ordenacion y busqueda binaria sobre enteros con signo.
# Instrucciones: lw, sw, add, sub, addi, slt, sll, srl, beq, bne, j, jal, jr, la,
#   addiu (li), addu (move), blt/bge (pseudo), syscall (11 y 10).
# Casos de la tabla de casos que cubre:
#   slt     : resultado 1 y 0 con negativos donde con y sin signo difieren (ordenacion).
#   sll/srl : sll 2 para indexar y srl 1 para el punto medio (shamt != 0).
#   lw/sw   : desplazamiento positivo (4) y negativo (-4) al intercambiar vecinos.
#   beq/bne : tomados y no tomados, saltos hacia atras (bucles anidados).
#   jal/jr  : main -> imprimir_entero (no hoja: guarda $ra y llama a imprimir_digito).
#   add/sub : con operandos negativos (negacion para imprimir en decimal).
# Extremos extra: arreglo con -2147483647, 2147483647, -32768, 32767, 0 y valores
#   repetidos; busqueda de un valor que existe, del primero y de otro que no; ordenacion con
#   iguales; impresion en decimal de los extremos de 32 bits.
# Salida: 6 lineas en decimal.

        .data
arr:    .word 7, -1, 32767, -2147483647, 0, 2147483647, -32768, 1, -1
n:      .word 9
pot:    .word 1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1, 0

        .text
main:
        la   $s0, arr
        la   $t4, n
        lw   $s1, 0($t4)            # n = 9
# ---- ordenacion por burbuja (con signo) ----
        addi $s2, $s1, -1           # pasadas
ext:    beq  $s2, $zero, ordenado
        move $s3, $s0               # puntero al par (a[i], a[i+1])
        move $s4, $s2               # comparaciones en esta pasada
int:    lw   $t4, 0($s3)
        lw   $t5, 4($s3)
        slt  $t6, $t5, $t4          # a[i+1] < a[i] ?
        beq  $t6, $zero, noint
        addi $s3, $s3, 4            # intercambio: s3 apunta ahora a a[i+1]
        sw   $t4, 0($s3)            # a[i+1] <- a[i]
        sw   $t5, -4($s3)           # a[i] <- a[i+1] (desplazamiento negativo)
        j    sig
noint:  addi $s3, $s3, 4
sig:    addi $s4, $s4, -1
        bne  $s4, $zero, int        # bne hacia atras
        addi $s2, $s2, -1
        j    ext                    # j hacia atras
ordenado:
# ---- lineas 1-3: arreglo ordenado, 3 por linea ----
        li   $s2, 0                 # i
        li   $s5, 3                 # quedan en la linea
imp:    sll  $t4, $s2, 2
        add  $t4, $s0, $t4
        lw   $a0, 0($t4)
        jal  imprimir_entero
        addi $s5, $s5, -1
        bne  $s5, $zero, esp
        jal  nl
        li   $s5, 3
        j    cont
esp:    jal  sp1
cont:   addi $s2, $s2, 1
        blt  $s2, $s1, imp
# ---- linea 4: minimo y maximo ----
        lw   $a0, 0($s0)            # -2147483647
        jal  imprimir_entero
        jal  sp1
        sll  $t4, $s1, 2
        add  $t4, $s0, $t4
        lw   $a0, -4($t4)           # 2147483647
        jal  imprimir_entero
        jal  nl
# ---- linea 5: cuantos negativos y cuantos positivos ----
        li   $s2, 0                 # i
        li   $s3, 0                 # negativos
        li   $s4, 0                 # positivos
cnt:    sll  $t4, $s2, 2
        add  $t4, $s0, $t4
        lw   $t5, 0($t4)
        slt  $t6, $t5, $zero
        add  $s3, $s3, $t6
        slt  $t6, $zero, $t5
        add  $s4, $s4, $t6
        addi $s2, $s2, 1
        bne  $s2, $s1, cnt
        move $a0, $s3               # 4
        jal  imprimir_entero
        jal  sp1
        move $a0, $s4               # 4
        jal  imprimir_entero
        jal  nl
# ---- linea 6: busqueda binaria de 32767 (indice 7) y de 5 (no esta: -1) ----
        li   $a1, 32767
        jal  buscar
        move $a0, $v0
        jal  imprimir_entero
        jal  sp1
        li   $a1, 5
        jal  buscar
        move $a0, $v0
        jal  imprimir_entero
        jal  sp1
        li   $a1, -2147483647
        jal  buscar
        move $a0, $v0               # 0
        jal  imprimir_entero
        jal  nl

        li   $v0, 10
        syscall

# buscar: indice de $a1 en arr[0..n-1] (ordenado) o -1. Hoja; usa $t4-$t9.
buscar: li   $t4, 0                 # lo
        addi $t5, $s1, -1           # hi
bb:     slt  $t6, $t5, $t4          # hi < lo -> no esta
        bne  $t6, $zero, bb_no
        add  $t7, $t4, $t5
        srl  $t7, $t7, 1            # mid
        sll  $t8, $t7, 2
        add  $t8, $s0, $t8
        lw   $t9, 0($t8)
        beq  $t9, $a1, bb_si
        slt  $t6, $t9, $a1
        beq  $t6, $zero, bb_izq
        addi $t4, $t7, 1            # a[mid] < x: lo = mid+1
        j    bb
bb_izq: addi $t5, $t7, -1           # a[mid] > x: hi = mid-1
        j    bb
bb_si:  move $v0, $t7
        jr   $ra
bb_no:  li   $v0, -1
        jr   $ra

# imprimir_entero: $a0 en decimal (no hoja: guarda $ra y llama a imprimir_digito).
imprimir_entero:
        addi $sp, $sp, -4
        sw   $ra, 0($sp)
        move $t0, $a0
        bge  $t0, $zero, ie_pos
        li   $a0, 45                # '-'
        li   $v0, 11
        syscall
        sub  $t0, $zero, $t0
ie_pos: la   $t2, pot
        li   $t4, 0                 # 1 cuando ya hay digitos
ie_pot: lw   $t3, 0($t2)
        beq  $t3, $zero, ie_fin
        li   $t5, 0
ie_res: slt  $t1, $t0, $t3
        bne  $t1, $zero, ie_dig
        sub  $t0, $t0, $t3
        addi $t5, $t5, 1
        j    ie_res
ie_dig: li   $t1, 1
        beq  $t3, $t1, ie_imp       # las unidades siempre
        bne  $t5, $zero, ie_imp
        beq  $t4, $zero, ie_sig     # ceros a la izquierda no
ie_imp: li   $t4, 1
        move $a0, $t5
        jal  imprimir_digito
ie_sig: addi $t2, $t2, 4
        j    ie_pot
ie_fin: lw   $ra, 0($sp)
        addi $sp, $sp, 4
        jr   $ra

imprimir_digito:                    # hoja: imprime el digito $a0
        addi $a0, $a0, 48
        li   $v0, 11
        syscall
        jr   $ra
sp1:    li   $a0, 32
        li   $v0, 11
        syscall
        jr   $ra
nl:     li   $a0, 10
        li   $v0, 11
        syscall
        jr   $ra

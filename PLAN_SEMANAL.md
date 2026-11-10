# Plan de Implementación de 1 Semana — CPU S-MIPS Multiciclo

**Objetivo:** Entregar CPU funcional que pase todos los tests y obtenga 5/5 puntos.
**Estrategia:** Implementar en Logisim nativo (sin VHDL), iterar rápido con `run_tests.py`, documentar en paralelo.

---

## Día 1 — Lunes: Preparación + Datapath básico + Register_File + ALU

### Mañana (3-4h)
- [ ] Clonar repo, configurar `LOGISIM_JAR` y `MARS_JAR` en entorno.
- [ ] Ejecutar `bash open.sh` → abrir `circuit/smips.circ`, explorar `Board`, `Memory`, pines de `CPU`.
- [ ] Leer `docs/guide.pdf` secciones 1-4 (placa, pines, mapa memoria, ISA) con foco en **tabla de instrucciones** y **pines CPU**.
- [ ] Crear subcircuito **Register_File** dentro de `CPU`:
  - 32 registros × 32 bits (usar componente *Registro* de biblioteca Memoria).
  - 2 puertos lectura combinacional (A, B), 1 puerto escritura en flanco subida (WE).
  - `$zero` hardwired a 0 (salida siempre 0, escritura ignorada).
  - Reset síncrono: PC=0, `$gp`=0x1800, `$sp`=0x3FFC, resto 0.
  - **Test rápido**: meter en `CPU`, conectar pines dummy, simular escritura/lectura.

### Tarde (3-4h)
- [ ] Crear subcircuito **ALU** (combinacional):
  - Entradas: `A[31:0]`, `B[31:0]`, `ALUop[3:0]` (codificación libre, ej: 0=ADD, 1=SUB, 2=AND, 3=OR, 4=SLT, 5=SLL, 6=SRL).
  - Salidas: `Result[31:0]`, `Zero` (1 si Result==0).
  - Implementar con sumador/restador, puertas, comparador, shifters de biblioteca Aritmética.
  - **Test**: estímulos manuales en Logisim para cada op.

### Noche (1h)
- [ ] Commit: `Register_File` + `ALU` funcionales.
- [ ] Ejecutar `python3 tools/run_tests.py programs/hello.asm` → debe fallar (CPU vacía), pero verificar que ensambla y carga.

---

## Día 2 — Martes: Instruction_Decoder + Control_Unit (FSM)

### Mañana (4h)
- [ ] Crear **Instruction_Decoder** (combinacional):
  - Entradas: `op[5:0]` (bits 31-26), `funct[5:0]` (bits 5-0).
  - Salidas (ejemplo, ajustar a tu diseño):
    - `InstrClass[2:0]`: 0=R-ALU, 1=I-ALU, 2=LOAD, 3=STORE, 4=BRANCH, 5=JUMP, 6=JAL, 7=JR, 8=SYSCALL, 9=ILLEGAL
    - `ALUop[3:0]`: operación ALU para esta instrucción
    - `ExtOp[1:0]`: 0=SignExt, 1=ZeroExt, 2=LUI (shift 16), 3=Branch (<<2)
    - `RegDst`: 1=rd, 0=rt
    - `MemToReg`: 1=load de memoria, 0=ALU
    - `RegWrite`, `MemWrite`, `Branch`, `Jump`, `Jal`, `Jr`, `Syscall`, `Illegal`
  - Detectar ilegal: (op,funct) no en tabla → `Illegal=1`.
  - **Test**: simular cada instrucción de la tabla, verificar salidas.

### Tarde (4h)
- [ ] Diseñar **FSM Control_Unit** en papel (Moore recomendado):
  - Estados mínimos (~6-8):
    1. `FETCH`       — PC→MEM_ADDR, leer instrucción → IR
    2. `DECODE`      — leer regs, extender inm, calcular PC+4 en ALU
    3. `EXEC_R`      — ALU op R-type, escribir reg
    4. `EXEC_I`      — ALU op I-type (addi, andi, ori, slti, lui), escribir reg
    5. `MEM_ADDR`    — ALU calcula dirección efectiva (rs+imm)
    6. `MEM_READ`    — esperar MEM_RDATA (combinacional, 1 ciclo)
    7. `MEM_WRITE`   — MEM_WE=1, MEM_BE, MEM_WDATA listos
    8. `MEM_WB`      — escribir registro con dato memoria
    9. `BRANCH`      — evaluar condición, actualizar PC si tomado
    10. `JUMP`       — PC ← jump target
    11. `JAL`        — $ra ← PC+4, PC ← jump target
    12. `JR`         — PC ← RS
    13. `SYSCALL`    — evaluar $v0, TTY_WE/HALT
    14. `HALT_STATE` — HALT=1, bloquear todo hasta reset
  - Codificar estados (4 bits = 16 estados).
  - Tabla de transiciones + salidas de control por estado.

### Noche (1h)
- [ ] Implementar **Control_Unit** en Logisim:
  - Registro de estado (4 bits) + lógica combinacional next-state + salidas.
  - Reset síncrono a `FETCH`.
  - Salidas: selectores MUX (PC, ALU_A, ALU_B, RegDst, MemToReg, ExtOp), habilitaciones (RegWrite, MemWrite, PCWrite, IRWrite, TTY_WE, HALT), ALUop.
- [ ] Commit: Decoder + FSM básicos.

---

## Día 3 — Miércoles: Datapath completo + Branch_Control

### Mañana (4h)
- [ ] Crear **Datapath** integrando Register_File + ALU + MUXes + extensores:
  - **PC** (registro 32b, WE=PCWrite, reset=0).
  - **IR** (registro 32b, WE=IRWrite).
  - **MUX PC**: 0=PC+4 (de ALU), 1=Branch target, 2=Jump target, 3=JR target.
  - **MUX ALU_A**: 0=PC, 1=RS (RegFile A).
  - **MUX ALU_B**: 0=RT (RegFile B), 1=Inmediato extendido, 2=4 (para PC+4), 3=shamt.
  - **Extensor Inmediato**: SignExt / ZeroExt / LUI (<<16) / Branch (<<2) según `ExtOp`.
  - **MUX RegDst**: 0=RT (bits 20-16), 1=RD (bits 15-11), 2=31 (para $ra en JAL).
  - **MUX MemToReg**: 0=ALU Result, 1=MEM_RDATA (con extracción byte para lb/lbu).
  - **Alineador bytes** (combinacional):
    - `sb`: replicar byte bajo a 4 carriles según `MEM_ADDR[1:0]`, generar `MEM_BE` (one-hot).
    - `lb`/`lbu`: extraer byte `MEM_RDATA[8*k+7:8*k]` donde k=`MEM_ADDR[1:0]`, sign/zero extend.
  - **Jump target**: `{PC+4[31:28], IR[25:0], 2'b00}`.
  - **Branch target**: `PC+4 + (SignExt(imm) << 2)`.
  - Conectar salidas CPU: `MEM_ADDR`, `MEM_WDATA`, `MEM_BE`, `MEM_WE`, `TTY_DATA`, `TTY_WE`, `HALT`.

### Tarde (3h)
- [ ] Crear **Branch_Control** (combinacional):
  - Entradas: `Branch` (de Control_Unit), `Zero` (de ALU), `InstrClass` (beq/bne).
  - Salida: `PCWriteCond` (1 si branch tomado).
  - Lógica: `beq` → tomado si Zero=1; `bne` → tomado si Zero=0.
- [ ] Integrar todo en **CPU**: conectar Decoder → Control_Unit → Datapath, Branch_Control.
- [ ] Verificar pines: nombres, anchos, sentidos exactos según especificación.

### Noche (1h)
- [ ] Commit: CPU completa (estructura).
- [ ] Test humo: `python3 tools/run_tests.py programs/hello.asm` → depurar reset, PC, HALT.

---

## Día 4 — Jueves: Depuración intensiva + programas de ejemplo

### Mañana (4h)
- [ ] Ejecutar **batería completa**: `python3 tools/run_tests.py`
- [ ] Para cada fallo:
  1. Aislar programa fallido: `python3 tools/run_tests.py programs/X.asm`
  2. Abrir Logisim, cargar `.hex`, simular paso a paso (Ticks).
  3. Usar sondas/túneles con nombres claros para ver señales clave.
  4. Corregir: FSM (transiciones/faltantes), MUX selectores, extensores, byte alignment, syscall.
- [ ] Prioridad: `hello.asm` → `arithmetic.asm` → `memory.asm` → `branches.asm` → `array_sum.asm` → `gcd.asm` → `multiply.asm`.

### Tarde (4h)
- [ ] Iterar hasta **todos los 7 programas de `programs/` pasen**.
- [ ] Verificar casos límite:
  - `lb`/`lbu`/`sb` en 4 posiciones de byte (memoria.asm).
  - Saltos adelante/atrás (branches.asm).
  - `jal`/`jr` con pila (gcd.asm, multiply.asm).
  - Syscall 11 (imprimir char) y 10 (HALT).
  - Instrucción ilegal → HALT.
  - Reset asíncrono/síncrono correcto (R6).
  - `$zero` siempre 0 (R11).
  - `addu`/`addiu` como `add`/`addi` (R9).

### Noche (1h)
- [ ] Commit: CPU pasa todos los `programs/`.
- [ ] Ejecutar `python3 tools/run_tests.py > salida-tests.txt` (guardar para entrega).

---

## Día 5 — Viernes: Tests propios (`tests/`) + Cobertura completa

### Mañana (4h)
- [ ] Crear carpeta `tests/`.
- [ ] Escribir **programas de prueba propios** cubriendo **TODAS las filas de la Tabla 1 (guía)**:
  - Diseñar 4-6 programas agrupados por tipo:
    1. `test_arith.asm` — add/sub (pos/neg), and/or (bits altos), slt/slti (1/0, signo vs unsign), sll/srl (shamt=0/≠0, srl neg).
    2. `test_imm.asm` — addi (neg), andi/ori (imm bit15=1), lui (imm bit15=1), addiu/addu via li/move.
    3. `test_mem.asm` — lw/sw (desp +/-), lb/lbu (bit7=1, 2 posiciones), sb (4 posiciones + lw verify).
    4. `test_branch.asm` — beq/bne tomado/no tomado, salto atrás.
    5. `test_jump.asm` — j, jal/jr (proc no hoja, $ra en pila).
    6. `test_syscall_zero.asm` — syscall 11/10, escritura en $zero.
  - Cada programa: imprime valores calculados (hex/dec), termina con syscall 10, ≤12 líneas × 48 chars.
  - Comentario inicial listando instrucciones/casos cubiertos.

### Tarde (3h)
- [ ] Ensamblar y probar cada uno en MARS: `python3 tools/assemble.py tests/X.asm`
- [ ] Probar en CPU: `python3 tools/run_tests.py tests/X.asm`
- [ ] Depurar hasta que **todos pasen** y salida coincida con MARS.
- [ ] Completar **tabla de cobertura** (para informe): fila de Tabla 1 → programa test.

### Noche (1h)
- [ ] Commit: `tests/` completos y pasando.
- [ ] Actualizar `salida-tests.txt` con batería completa (programs + tests).

---

## Día 6 — Sábado: Informe + Pulido circuito + Claridad

### Mañana (4h)
- [ ] Escribir **`informe.pdf`** (máx 10 páginas) con secciones obligatorias:
  1. Nombre + componentes VHDL (ninguno) + justificación breve.
  2. **Diagrama ruta de datos** con nombres señales control (dibujar en draw.io / LaTeX / a mano escaneado).
  3. **Diagrama/tabla FSM**: estados, transiciones, condiciones.
  4. **Tabla señales de control por estado** (qué MUX selecciona qué, qué WE activos).
  5. **Codificación ALUop** y salidas Decoder.
  6. **Ciclos por clase** de instrucción (ej: R=4, I=4, Load=5, Store=4, Branch=4, Jump=3, Jal=3, Jr=3, Syscall=3).
  7. **Tabla cobertura tests/**.
  8. **Resultados run_tests.py** + limitaciones/errores conocidos (honestidad: penaliza menos).

### Tarde (3h)
- [ ] **Pulido circuito** (claridad = 10% nota):
  - Renombrar túneles/señales con nombres descriptivos (`PC_next`, `ALU_result`, `SignExt_imm`, etc.).
  - Agregar etiquetas de texto en Logisim explicando bloques clave.
  - Organizar subcircuitos limpiamente (sin cables cruzados caóticos).
  - Verificar jerarquía exacta: CPU → {Instruction_Decoder, Control_Unit, Branch_Control, Datapath → {Register_File, ALU}}.
  - Sin componentes RAM/ROM dentro de CPU (R17).
  - Un solo reloj CLK directo a todos los registros (R3).
  - TTY_WE = 1 exactamente 1 ciclo por char (R4).
  - MEM_WE = 1 solo en ciclo store (R5).

### Noche (1h)
- [ ] Commit: informe + circuito limpio.
- [ ] Test final completo: `python3 tools/run_tests.py` → 0 fallos.

---

## Día 7 — Domingo: Defensa + Entrega

### Mañana (2h)
- [ ] **Ensayo defensa** (10% nota): explicar en voz alta:
  - Ruta de datos y señales de control.
  - FSM: estados, por qué esa codificación, transiciones clave.
  - Cómo maneja lb/lbu/sb (alineación bytes).
  - Cómo detecta instrucción ilegal.
  - Reset y valores iniciales.
  - Cualquier decisión de diseño (ej: Moore vs Mealy, ciclos por instrucción).
- [ ] Preparar respuestas a preguntas típicas (ver FAQ guía).

### Tarde (1h)
- [ ] Verificar **checklist entrega** (R22, R23):
  - [ ] Repo GitHub público (o acceso dado a prof).
  - [ ] `circuit/smips.circ` con CPU implementada.
  - [ ] `informe.pdf` (≤10 páginas).
  - [ ] `tests/` con programas propios cubriendo tabla completa.
  - [ ] `salida-tests.txt` salida completa `run_tests.py`.
  - [ ] (Opcional) resto de material del proyecto.
- [ ] Último `git push` antes de deadline.
- [ ] Enviar enlace por Telegram al profesor.

---

## Resumen de hitos por día

| Día | Entregable clave | Tests que deben pasar |
|-----|------------------|----------------------|
| Lun | Register_File + ALU | — |
| Mar | Decoder + FSM Control_Unit | — |
| Mié | Datapath + Branch_Control + CPU integrada | `hello.asm` (básico) |
| Jue | **CPU funcional completa** | **Todos `programs/` (7)** |
| Vie | **Tests propios `tests/`** | **`programs/` + `tests/` (todos)** |
| Sáb | Informe + circuito pulido | Regresión completa |
| Dom | Defensa preparada + **Entrega** | — |

---

## Consejos para maximizar nota (5/5)

1. **Corrección (40%)**: Que pase **todo** `run_tests.py` (profesor usa tests no publicados iguales). No hacer trampas: CPU debe ejecutar correctamente.
2. **Pruebas propias (10%)**: Cubrir **cada fila** de la Tabla 1. Un programa por fila está bien; agrupar es mejor. Salida debe delatar fallos.
3. **Estructura (20%)**: Jerarquía exacta, una sola ALU, FSM síncrona, reset correcto, sin VHDL (o ≤2), sin RAM/ROM en CPU.
4. **Claridad (10%)**: Nombres claros, túneles etiquetados, textos explicativos en Logisim, subcircuitos ordenados.
5. **Informe (10%)**: Completo, coherente con circuito, tabla cobertura honesta, limitaciones declaradas.
6. **Defensa (10%)**: Saber explicar cualquier parte. Practicar 15 min antes.

---

## Comandos útiles diario

```bash
# Ensamblar un test
python3 tools/assemble.py tests/mi_test.asm

# Ejecutar un test en CPU
python3 tools/run_tests.py tests/mi_test.asm

# Batería completa
python3 tools/run_tests.py

# Guardar salida para entrega
python3 tools/run_tests.py > salida-tests.txt

# Abrir Logisim
bash open.sh
```

---

## Estructura de commits sugerida (historial limpio)

```
feat: Register_File y ALU básicos
feat: Instruction_Decoder con detección ilegal
feat: Control_Unit FSM (estados + salidas)
feat: Datapath completo + Branch_Control
fix: correcciones tras tests programs/ (varios commits)
feat: tests/ propios cubriendo tabla completa
docs: informe.pdf completo
style: limpieza circuito, nombres, textos
chore: entrega final
```

---

¡Éxito! La clave es **iterar rápido con `run_tests.py`** desde el día 3 y no dejar la depuración para el final.
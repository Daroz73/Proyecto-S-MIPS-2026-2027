# Guía Día 1: Register_File + ALU en Logisim Evolution

> Ábrelo con `bash open.sh` → doble clic en **CPU** (en la pestaña izquierda "Circuits") → empieza a construir **dentro** del circuito CPU.

---

## 1. Register_File (subcircuito dentro de CPU)

### 1.1 Crear el subcircuito
1. Menú **Project → Add Circuit...**
2. Nombre: `Register_File` ✓
3. Se abre una pestaña nueva vacía.

### 1.2 Pines de Register_File (añade con herramienta Pin, librería Wiring)

| Pin | Dir. | Ancho | Label | Notas |
|-----|------|-------|-------|-------|
| CLK | In | 1 | CLK | Reloj |
| RESET | In | 1 | RESET | Reset síncrono (1 = resetear) |
| A1 | In | 5 | A1 | Dirección puerto lectura 1 (rs) |
| A2 | In | 5 | A2 | Dirección puerto lectura 2 (rt) |
| A3 | In | 5 | A3 | Dirección puerto escritura (rd/rt/31) |
| WD | In | 32 | WD | Dato a escribir |
| WE | In | 1 | WE | Write Enable (flanco subida CLK) |
| RD1 | Out | 32 | RD1 | Dato leído puerto 1 |
| RD2 | Out | 32 | RD2 | Dato leído puerto 2 |

> **Importante**: Usa **túneles** (Wiring → Tunnel) con labels `CLK`, `RESET`, `A1`, `A2`, `A3`, `WD`, `WE`, `RD1`, `RD2` para conectar sin cables largos.

### 1.3 Implementación (32 registros × 32 bits)

**Opción A — Componente Register (recomendado, más limpio):**
1. Arrastra 32 **Register** (librería Memory, no RAM/ROM) → cada uno 32 bits.
2. Configura cada Register:
   - Data Bits: 32
   - Enable: conecta a `WE` **y** decodificador de dirección (ver abajo)
   - Clock: conecta a túnel `CLK`
   - Reset: conecta a túnel `RESET` (valor 0, excepto $gp/$sp)
   - Q (salida): conecta a MUX de lectura
3. **Decodificador de escritura**: 
   - Usa **Decoder 5→32** (Plexers → Decoder) con entrada `A3` y enable `WE`.
   - Cada salida `i` → Enable del Register `i`.
   - **Excepción $zero (registro 0)**: su Enable siempre 0 (conecta a constante 0).
4. **MUX de lectura (2 puertos)**:
   - Dos **MUX 32→1** (Plexers → Multiplexer, 32 inputs, 5 select bits).
   - Select: `A1` para RD1, `A2` para RD2.
   - Inputs: salidas Q de los 32 registers.
   - Salidas → túneles `RD1`, `RD2`.

**Valores de reset (R6):**
- Register 0 ($zero): siempre 0 (hardwired)
- Register 28 ($gp): 0x1800
- Register 29 ($sp): 0x3FFC
- Register 31 ($ra): 0
- Otros: 0
> Truco: pon constante en entrada D de cada Register y usa Reset asíncrono del componente, o maneja RESET en lógica de enable.

**Opción B — D Flip-Flops + MUX (más control, más trabajo):**
- 32 × 32 DFFs, decodificador, MUXes. Equivalente pero más tedioso.

### 1.4 Test rápido dentro de Register_File
1. Pestaña **Simulate** → **Reset Simulation** (Ctrl+R).
2. Poke `WE=1`, `A3=5`, `WD=0x12345678`, tick reloj → Register 5 = 0x12345678.
3. Poke `A1=5`, `A2=0` → `RD1=0x12345678`, `RD2=0`.
4. Poke `WE=1`, `A3=0`, `WD=0xFFFFFFFF` → `RD2` sigue 0 ($zero inmutable).

---

## 2. ALU (subcircuito dentro de CPU)

### 2.1 Crear subcircuito
**Project → Add Circuit...** → Nombre: `ALU`

### 2.2 Pines

| Pin | Dir. | Ancho | Label | Notas |
|-----|------|-------|-------|-------|
| A | In | 32 | A | Operando 1 |
| B | In | 32 | B | Operando 2 |
| ALUop | In | 4 | ALUop | Código operación (ver tabla) |
| Result | Out | 32 | Result | Resultado |
| Zero | Out | 1 | Zero | 1 si Result == 0 |

### 2.3 Codificación ALUop (sugerida, 4 bits = 16 ops)

| ALUop | Operación | Descripción |
|-------|-----------|-------------|
| 0x0 | ADD | A + B |
| 0x1 | SUB | A - B |
| 0x2 | AND | A & B |
| 0x3 | OR  | A \| B |
| 0x4 | SLT | (A < B signed) ? 1 : 0 |
| 0x5 | SLL | B << A[4:0] (shamt en A) |
| 0x6 | SRL | B >> A[4:0] (logical, entra ceros) |
| 0x7 | ADD_U | A + B (sin overflow, igual que ADD en MIPS) |
| 0x8 | PASS_B | B (para lui, jump target, etc.) |
| 0xF | RESERVED | — |

> Puedes usar otra codificación, pero documenta en el informe.

### 2.4 Implementación (combinacional, sin estado)

**Bloques base (librería Arithmetic + Gates):**
1. **Adder/Subtractor** (Arithmetic → Adder): 32 bits, carry-in = 0 para ADD, 1 para SUB (con NOT en B).
   - Usa un MUX 2→1 en B: 0 = B, 1 = ~B; carry-in = ALUop[0] para SUB.
   - O dos Adders separados y MUX en salida.
2. **AND/OR**: Gates → AND Gate / OR Gate (32 bits, configura "Number of Inputs" = 2, "Bit Width" = 32).
3. **SLT (Set Less Than signed)**:
   - Usa **Comparator** (Arithmetic → Comparator) 32 bits, signed.
   - Salida `LT` → extiende a 32 bits (0 o 1) con **Bit Extender** (Wiring → Bit Extender, 1→32).
4. **Shifters** (Arithmetic → Shifter):
   - SLL: Shifter tipo "Shift Left Logical", shift amount = A[4:0].
   - SRL: Shifter tipo "Shift Right Logical", shift amount = A[4:0].
5. **MUX principal 8→1** (Plexers → Multiplexer, 8 inputs, 3 select bits):
   - Select = `ALUop[2:0]` (usa 3 bits, ALUop[3] para futuras extensiones).
   - Inputs: salidas de ADD/SUB, AND, OR, SLT, SLL, SRL, PASS_B.
   - Salida → túnel `Result`.
6. **Zero detection**:
   - **Comparator** 32 bits comparando `Result` con constante 0 → salida `Zero` (1 bit).
   - O: **OR Gate** 32 entradas (reducción) → NOT → `Zero`.

### 2.5 Test rápido en ALU
| A | B | ALUop | Result esperado | Zero |
|---|---|-------|-----------------|------|
| 10 | 5 | 0 (ADD) | 15 | 0 |
| 10 | 5 | 1 (SUB) | 5 | 0 |
| 7 | 7 | 1 (SUB) | 0 | 1 |
| 0xF0F0 | 0x0F0F | 2 (AND) | 0 | 1 |
| 0xF0F0 | 0x0F0F | 3 (OR) | 0xFFFF | 0 |
| 5 | 10 | 4 (SLT) | 1 | 0 |
| 10 | 5 | 4 (SLT) | 0 | 1 |
| 2 (shamt) | 0x3 | 5 (SLL) | 0xC | 0 |
| 2 (shamt) | 0xC | 6 (SRL) | 0x3 | 0 |

---

## 3. Integrar en CPU (jerarquía obligatoria R16)

Dentro del circuito **CPU** (pestaña CPU):

1. **Project → Add Circuit...** → `Instruction_Decoder`, `Control_Unit`, `Branch_Control`, `Datapath` (vacíos por ahora).
2. Dentro de **Datapath**: arrastra `Register_File` y `ALU` (aparecen en la lista de circuitos del proyecto).
3. Conecta pines de CPU a subcircuitos usando **túneles** con nombres claros:
   - `CLK`, `RESET` → a todos los elementos secuenciales.
   - `MEM_RDATA` → Datapath.
   - `MEM_ADDR`, `MEM_WDATA`, `MEM_BE`, `MEM_WE` ← Datapath.
   - `TTY_DATA`, `TTY_WE`, `HALT` ← Datapath/Control_Unit.

### 3.1 Estructura de túneles sugerida (organiza por columnas)

```
Izquierda (entradas):     Centro (Datapath):        Derecha (salidas):
CLK ─────────────────────→│ Register_File           │────→ MEM_ADDR
RESET ───────────────────→│ ALU                     │────→ MEM_WDATA
MEM_RDATA ───────────────→│ PC, IR, MUXes, Extensores│────→ MEM_BE
                                                    │────→ MEM_WE
                                                    │────→ TTY_DATA
                                                    │────→ TTY_WE
                                                    │────→ HALT
```

---

## 4. Commit sugerido al final del día

```bash
git add circuit/smips.circ
git commit -m "feat: Register_File y ALU básicos implementados
- Register_File: 32 regs x32b, 2 read/1 write, $zero hardwired, reset R6
- ALU: ADD, SUB, AND, OR, SLT, SLL, SRL, PASS_B, Zero flag
- Subcircuitos creados dentro de CPU con jerarquía correcta"
```

---

## 5. Verificación rápida (sin tests completos aún)

En Logisim, pestaña **Simulate**:
1. **Reset Simulation** (Ctrl+R).
2. Poke `CLK` tick a mano (Simulate → Tick Full Cycle o Ctrl+T).
3. Verifica que Register_File y ALU responden a estímulos manuales.
4. **No ejecutes `run_tests.py` aún** — la CPU completa no existe.

---

## 6. Próximo paso (Día 2)

Mañana: `Instruction_Decoder` (combinacional) + diseñar FSM `Control_Unit` en papel → implementar.

---

### Atajos de teclado Logisim útiles
| Acción | Tecla |
|--------|-------|
| Herramienta Edit (seleccionar) | `1` |
| Herramienta Wiring (cables) | `2` |
| Herramienta Pin | `3` |
| Herramienta Poke (simular) | `4` |
| Añadir túnel | `T` (con wiring tool) |
| Rotar componente | `Ctrl+R` |
| Copiar/Pegar | `Ctrl+C` / `Ctrl+V` |
| Deshacer | `Ctrl+Z` |
| Zoom | `Ctrl+Scroll` |
| Tick reloj (simulación) | `Ctrl+T` |
| Reset simulación | `Ctrl+R` |

---

¡Manos a la obra! Cualquier duda con la implementación de Register_File o ALU, avísame.
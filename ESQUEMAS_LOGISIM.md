# Esquemas Detallados para Logisim Evolution — S-MIPS Multiciclo

> Copia estos esquemas componente a componente en Logisim. Usa **túneles** (tecla `T` con herramienta Wiring) para conectar bloques sin cables largos. Nombra cada túnel igual que la señal en las tablas.

---

## 1. REGISTER_FILE (subcircuito dentro de CPU → Datapath)

### 1.1 Interfaz (pines del subcircuito)

| Pin | Dir | Ancho | Label | Descripción |
|-----|-----|-------|-------|-------------|
| CLK | In | 1 | CLK | Reloj (flanco subida) |
| RESET | In | 1 | RESET | Reset síncrono (alto = reset) |
| A1 | In | 5 | A1 | Addr puerto lectura 1 (rs) |
| A2 | In | 5 | A2 | Addr puerto lectura 2 (rt) |
| A3 | In | 5 | A3 | Addr puerto escritura (rd/rt/31) |
| WD | In | 32 | WD | Write Data |
| WE | In | 1 | WE | Write Enable |
| RD1 | Out | 32 | RD1 | Read Data 1 |
| RD2 | Out | 32 | RD2 | Read Data 2 |

---

### 1.2 Componentes necesarios (biblioteca Memory + Plexers + Wiring)

| Componente | Cantidad | Configuración clave |
|------------|----------|---------------------|
| **Register** | 32 | Data Bits: 32, Enable: 1 bit, Clock: 1 bit, Reset: 1 bit, Async Reset: **unchecked** (síncrono) |
| **Decoder** | 1 | Select Bits: 5, Enable: **checked** (1 bit enable) |
| **MUX** (Multiplexer) | 2 | Data Bits: 32, Select Bits: 5, Inputs: 32 |
| **Constant** | 1 | Value: 0, Bit Width: 1 (para $zero enable) |
| **Constant** | 3 | Values: 0x00001800, 0x00003FFC, 0x00000000 (Bit Width: 32) — para reset values |
| **Tunnel** | muchos | Labels: CLK, RESET, A1, A2, A3, WD, WE, RD1, RD2, REG_WE[31:0], REG_Q[31:0][31:0] |

---

### 1.3 Esquema de conexiones (descripción textual)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           REGISTER_FILE                                      │
│                                                                             │
│  ┌──────┐    ┌────────────────────────────────────────────────────────┐    │
│  │  WE  │───→│                     DECODER 5→32                       │    │
│  │ (tun)│    │  Sel: A3[4:0] (tun)   En: WE (tun)                     │    │
│  └──────┘    │  Out[0] → CONST_0 (tun "ZERO_EN")                      │    │
│              │  Out[1] → Reg1.En                                      │    │
│              │  Out[2] → Reg2.En                                      │    │
│              │    ...                                                 │    │
│              │  Out[28] → Reg28.En  ($gp)                             │    │
│              │  Out[29] → Reg29.En  ($sp)                             │    │
│              │  Out[30] → Reg30.En                                    │    │
│              │  Out[31] → Reg31.En  ($ra)                             │    │
│              └────────────────────────────────────────────────────────┘    │
│                         │                    │                    │        │
│                    ┌────┴────┐         ┌────┴────┐         ┌────┴────┐     │
│                    ▼         ▼         ▼         ▼         ▼         ▼     │
│              ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│              │  Reg 0  │ │  Reg 1  │ │  Reg 2  │ │  ...    │ │ Reg 31  │  │
│              │ $zero   │ │  $at    │ │  $v0    │ │         │ │  $ra    │  │
│              └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘  │
│                   │           │           │           │           │        │
│                   ▼           ▼           ▼           ▼           ▼        │
│              ┌────────────────────────────────────────────────────────┐    │
│              │              MUX RD1 (32→1, Sel=A1)                   │    │
│              │  In[0] ← Reg0.Q  (siempre 0)                          │    │
│              │  In[1] ← Reg1.Q                                       │    │
│              │    ...                                                │    │
│              │  In[31] ← Reg31.Q                                     │    │
│              │  Out → TUNNEL "RD1"                                   │    │
│              └────────────────────────────────────────────────────────┘    │
│                                                                             │
│              ┌────────────────────────────────────────────────────────┐    │
│              │              MUX RD2 (32→1, Sel=A2)                   │    │
│              │  In[0] ← Reg0.Q  (siempre 0)                          │    │
│              │  In[1] ← Reg1.Q                                       │    │
│              │    ...                                                │    │
│              │  In[31] ← Reg31.Q                                     │    │
│              │  Out → TUNNEL "RD2"                                   │    │
│              └────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  Cada REGISTER (32 bits):                                           │  │
│  │    D[31:0]  ← TUNNEL "WD"        (compartido, 32 bits)              │  │
│  │    Clock    ← TUNNEL "CLK"       (1 bit)                            │  │
│  │    Reset    ← TUNNEL "RESET"     (1 bit)                            │  │
│  │    Enable   ← salida Decoder[i]  (1 bit)  — excepto Reg0 = CONST_0  │  │
│  │    Q[31:0]  → MUX RD1 In[i], MUX RD2 In[i]                          │  │
│  │                                                                     │  │
│  │  Reset values (configurar en propiedad "Reset Value" del Register): │  │
│  │    Reg0  ($zero): 0x00000000  (hardwired, enable=0)                │  │
│  │    Reg28 ($gp):   0x00001800                                         │  │
│  │    Reg29 ($sp):   0x00003FFC                                         │  │
│  │    Reg31 ($ra):   0x00000000                                         │  │
│  │    Otros:         0x00000000                                         │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.4 Paso a paso en Logisim

1. **Crear 32 Registers**: Arrastra 1, configura (Data Bits=32, Enable=1, Clock=1, Reset=1), copia/pega 31 veces. Renombra: `Reg0`...`Reg31`.
2. **Decoder**: Plexers → Decoder. Select Bits=5, Enable=checked. Conecta `A3` a Select, `WE` a Enable.
3. **Constante 0**: Wiring → Constant, Value=0, Bit Width=1. Conecta a `Decoder.Out[0]` y a `Reg0.Enable`.
4. **MUX RD1 y RD2**: Plexers → Multiplexer. Data Bits=32, Select Bits=5, Inputs=32. Conecta salidas `Reg{i}.Q` a `In[i]`.
5. **Túneles**: Para cada señal compartida (CLK, RESET, WD, A1, A2, A3, WE, RD1, RD2).
6. **Reset values**: Click en cada Register → Properties → "Reset Value" → pon el valor hex correspondiente.
7. **Test**: Simulate → Reset Simulation → Poke WE=1, A3=5, WD=0xDEADBEEF, Ctrl+T → verifica RD1 con A1=5.

---

## 2. ALU (subcircuito dentro de CPU → Datapath)

### 2.1 Interfaz

| Pin | Dir | Ancho | Label |
|-----|-----|-------|-------|
| A | In | 32 | A |
| B | In | 32 | B |
| ALUop | In | 4 | ALUop |
| Result | Out | 32 | Result |
| Zero | Out | 1 | Zero |

---

### 2.2 Codificación ALUop (4 bits)

| ALUop[3:0] | Mnemo | Operación | Uso típico |
|------------|-------|-----------|------------|
| 0x0 | ADD | A + B | add, addi, lw/sw addr, PC+4 |
| 0x1 | SUB | A - B | sub, beq/bne cmp |
| 0x2 | AND | A & B | and, andi |
| 0x3 | OR | A \| B | or, ori |
| 0x4 | SLT | (A < B signed) ? 1 : 0 | slt, slti |
| 0x5 | SLL | B << A[4:0] | sll (shamt en A) |
| 0x6 | SRL | B >> A[4:0] (logical) | srl |
| 0x8 | PASS_B | B | lui, jump target |
| 0xF | — | Reservado | — |

---

### 2.3 Componentes (biblioteca Arithmetic + Gates + Plexers + Wiring)

| Componente | Cantidad | Configuración |
|------------|----------|---------------|
| **Adder** | 2 | Data Bits: 32, Carry In: 1 bit, Carry Out: unconnected |
| **NOT Gate** | 1 | Inputs: 32 (para invertir B en SUB) |
| **AND Gate** | 1 | Inputs: 2, Bit Width: 32 |
| **OR Gate** | 1 | Inputs: 2, Bit Width: 32 |
| **Comparator** | 2 | Data Bits: 32, Signed: checked (1 para SLT, 1 para Zero) |
| **Shifter** | 2 | Data Bits: 32, Shift Amount Bits: 5, Type: "Shift Left Logical" / "Shift Right Logical" |
| **MUX** (Multiplexer) | 1 | Data Bits: 32, Select Bits: 3, Inputs: 8 |
| **Bit Extender** | 1 | In: 1, Out: 32 (para SLT result 0/1 → 32 bits) |
| **Constant** | varias | 0 (32b), 1 (1b), 4 (32b para PC+4) |
| **Tunnel** | muchos | Labels: A, B, ALUop, Result, Zero, ADD_OUT, SUB_OUT, AND_OUT, OR_OUT, SLT_OUT, SLL_OUT, SRL_OUT, PASS_B_OUT |

---

### 2.4 Esquema de conexiones

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 ALU                                          │
│                                                                             │
│  ENTRADAS:  TUNNEL "A"[31:0]    TUNNEL "B"[31:0]    TUNNEL "ALUop"[3:0]    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     SUMA / RESTA (comparten Adder)                  │   │
│  │                                                                     │   │
│  │   B[31:0] ───→┐                                                     │   │
│  │               │    ┌──────────┐    ┌──────────────────────────┐   │   │
│  │               ├──→│  MUX 2→1 │───→│ B_in (Adder)             │   │   │
│  │               │    │ Sel=ALUop[0]│   │                          │   │   │
│  │               │    └──────────┘    │ Cin = ALUop[0]           │   │   │
│  │   ~B[31:0] ──→┘   (0=B, 1=~B)      │                          │   │   │
│  │         (NOT Gate 32b)             │ A[31:0] ────────────────→│   │   │
│  │                                    │                          │   │   │
│  │                                    │ SUM[31:0] ───────────────→│   │   │
│  │                                    └──────────────────────────┘   │   │
│  │                                              │                    │   │
│  │                              ┌───────────────┴───────────────┐    │   │
│  │                              ▼                               ▼    │   │
│  │                         TUNNEL "ADD_OUT"               TUNNEL "SUB_OUT"│
│  │                         (ALUop=0x0)                    (ALUop=0x1)   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        AND / OR                                     │   │
│  │                                                                     │   │
│  │   A[31:0] ────────────────→┐                                        │   │
│  │                            ├──→ AND Gate (2 inputs, 32b) → TUNNEL "AND_OUT"│
│  │   B[31:0] ────────────────→┘                                        │   │
│  │                                                                     │   │
│  │   A[31:0] ────────────────→┐                                        │   │
│  │                            ├──→ OR Gate  (2 inputs, 32b) → TUNNEL "OR_OUT" │
│  │   B[31:0] ────────────────→┘                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        SLT (Set Less Than signed)                   │   │
│  │                                                                     │   │
│  │   A[31:0] ────────────────→┐                                        │   │
│  │                            ├──→ Comparator (32b, Signed)           │   │
│  │   B[31:0] ────────────────→┘        LT (1 bit)                     │   │
│  │                                              │                      │   │
│  │                                              ▼                      │   │
│  │                                    Bit Extender (1→32)             │   │
│  │                                              │                      │   │
│  │                                              ▼                      │   │
│  │                                    TUNNEL "SLT_OUT" (0x0 o 0x1)     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        SHIFTS (shamt = A[4:0])                      │   │
│  │                                                                     │   │
│  │   B[31:0] ────────────────→┐                                        │   │
│  │                            ├──→ Shifter (Shift Left Logical)       │   │
│  │   A[4:0]  ─────────────────→│   Shift Amt: A[4:0]                  │   │
│  │                            │   Out → TUNNEL "SLL_OUT"              │   │
│  │                            │                                        │   │
│  │   B[31:0] ────────────────→┤                                        │   │
│  │                            ├──→ Shifter (Shift Right Logical)      │   │
│  │   A[4:0]  ─────────────────→│   Shift Amt: A[4:0]                  │   │
│  │                            │   Out → TUNNEL "SRL_OUT"              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        PASS_B (para LUI, jumps)                     │   │
│  │                                                                     │   │
│  │   B[31:0] ──────────────────────────────────────────────────────→   │   │
│  │                                    TUNNEL "PASS_B_OUT"             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    MUX PRINCIPAL 8→1 (Select = ALUop[2:0])         │   │
│  │                                                                     │   │
│  │   In[0] ← TUNNEL "ADD_OUT"     (ALUop=0x0)                         │   │
│  │   In[1] ← TUNNEL "SUB_OUT"     (ALUop=0x1)                         │   │
│  │   In[2] ← TUNNEL "AND_OUT"     (ALUop=0x2)                         │   │
│  │   In[3] ← TUNNEL "OR_OUT"      (ALUop=0x3)                         │   │
│  │   In[4] ← TUNNEL "SLT_OUT"     (ALUop=0x4)                         │   │
│  │   In[5] ← TUNNEL "SLL_OUT"     (ALUop=0x5)                         │   │
│  │   In[6] ← TUNNEL "SRL_OUT"     (ALUop=0x6)                         │   │
│  │   In[7] ← TUNNEL "PASS_B_OUT"  (ALUop=0x8)                         │   │
│  │                                                                     │   │
│  │   Out → TUNNEL "Result"                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        ZERO FLAG                                    │   │
│  │                                                                     │   │
│  │   TUNNEL "Result"[31:0] ─────────────────────────────────────→     │   │
│  │                                 │                                   │   │
│  │                                 ▼                                   │   │
│  │                       Comparator (32b, Unsigned)                   │   │
│  │                       Compare with: Constant 0 (32b)               │   │
│  │                       Out: EQ (1 bit)                              │   │
│  │                                 │                                   │   │
│  │                                 ▼                                   │   │
│  │                       TUNNEL "Zero"  (1 si Result==0)              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  SALIDAS:  TUNNEL "Result"[31:0]    TUNNEL "Zero"[1]                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 2.5 Detalles de implementación clave

**Adder compartido ADD/SUB:**
- Un solo **Adder** (Arithmetic → Adder, 32 bits, Carry In=1 bit).
- Entrada B del Adder: **MUX 2→1** (Plexers → Multiplexer, Data Bits=32, Select Bits=1, Inputs=2).
  - In[0] = `B` (túnel B)
  - In[1] = `~B` (NOT Gate 32 bits sobre túnel B)
  - Sel = `ALUop[0]` (bit 0 del ALUop: 0=ADD, 1=SUB)
- Carry In del Adder = `ALUop[0]` (para SUB: suma complemento a 2).
- Salida Adder → TUNNEL "ADD_OUT" (cuando ALUop[0]=0) y "SUB_OUT" (cuando ALUop[0]=1). En realidad es la misma señal; el MUX principal selecciona según ALUop[2:0].

**SLT:**
- Comparator (Arithmetic → Comparator): Data Bits=32, **Signed=checked**.
- Salida `LT` (1 bit) → **Bit Extender** (Wiring → Bit Extender, Data Bits In=1, Out=32) → da 0x00000000 o 0x00000001.

**Shifters:**
- Shifter (Arithmetic → Shifter): Data Bits=32, Shift Amount Bits=5.
- Tipo: "Shift Left Logical" para SLL, "Shift Right Logical" para SRL.
- Shift Amount conectado a `A[4:0]` (usar **Splitter** Wiring → Splitter: In=32, Fan Out=1, Bit 0-4 conectados, resto "none").

**MUX Principal:**
- Multiplexer: Data Bits=32, Select Bits=3 (usa ALUop[2:0]), Inputs=8.
- ALUop[3] se ignora en este MUX (para futuras extensiones).

**Zero Flag:**
- Comparator (32b, Unsigned) comparando `Result` con **Constant 0** (32b).
- Salida `EQ` → túnel `Zero`.

---

## 3. DATAPATH (subcircuito dentro de CPU)

> El Datapath es el **contenedor principal** que instancia Register_File, ALU, y añade: PC, IR, MUXes, extensores, alineadores de bytes, cálculo de jump/branch targets.

### 3.1 Interfaz del Datapath (pines hacia CPU)

| Pin | Dir | Ancho | Label | Descripción |
|-----|-----|-------|-------|-------------|
| CLK | In | 1 | CLK | Reloj |
| RESET | In | 1 | RESET | Reset |
| MEM_RDATA | In | 32 | MEM_RDATA | Dato leído de memoria (combinacional) |
| Ctrl_* | In | var | (ver §3.3) | Señales de control desde Control_Unit |
| Dec_* | In | var | (ver §3.3) | Salidas de Instruction_Decoder |
| MEM_ADDR | Out | 32 | MEM_ADDR | Dirección memoria |
| MEM_WDATA | Out | 32 | MEM_WDATA | Dato a escribir (alineado) |
| MEM_BE | Out | 4 | MEM_BE | Byte enables |
| MEM_WE | Out | 1 | MEM_WE | Write enable memoria |
| TTY_DATA | Out | 7 | TTY_DATA | Char a imprimir |
| TTY_WE | Out | 1 | TTY_WE | TTY write enable |
| HALT | Out | 1 | HALT | LED Halt |
| Branch_Cond | Out | 1 | Branch_Cond | A Branch_Control (condición branch) |
| PC_Write | In | 1 | PC_Write | Desde Control_Unit |
| IR_Write | In | 1 | IR_Write | Desde Control_Unit |
| Reg_Write | In | 1 | Reg_Write | Desde Control_Unit |

> **Nota**: Las señales de control (Ctrl_*) vienen de Control_Unit. Las de decodificación (Dec_*) vienen de Instruction_Decoder. Para hoy, crea los pines vacíos; los conectarás en Día 2-3.

---

### 3.2 Componentes internos del Datapath

| Bloque | Componentes Logisim | Cantidad |
|--------|---------------------|----------|
| **PC** | Register (32b, en=PC_Write, clk=CLK, reset=RESET, reset value=0) | 1 |
| **IR** | Register (32b, en=IR_Write, clk=CLK, reset=RESET, reset value=0) | 1 |
| **Register_File** | (subcircuito ya creado) | 1 |
| **ALU** | (subcircuito ya creado) | 1 |
| **MUX PC** | MUX 4→1 (32b, Sel=2b: 0=PC+4, 1=Branch, 2=Jump, 3=JR) | 1 |
| **MUX ALU_A** | MUX 2→1 (32b: 0=PC, 1=RS) | 1 |
| **MUX ALU_B** | MUX 4→1 (32b: 0=RT, 1=ImmExt, 2=Const4, 3=Shamt) | 1 |
| **MUX RegDst** | MUX 3→1 (5b: 0=RT[20:16], 1=RD[15:11], 2=Const31) | 1 |
| **MUX MemToReg** | MUX 2→1 (32b: 0=ALU_Result, 1=Mem_Data_Aligned) | 1 |
| **Extensor Inmediato** | Combinacional: SignExt / ZeroExt / LUI / Branch | 1 |
| **Alineador Bytes** | Combinacional: sb/lb/lbu según MEM_ADDR[1:0] | 1 |
| **Jump Target** | Concatenador: {PC+4[31:28], IR[25:0], 2'b00} | 1 |
| **Branch Target** | Sumador: PC+4 + (SignExt(imm)<<2) | 1 |
| **Splitters/Túneles** | Para IR[31:26], IR[25:21], IR[20:16], IR[15:11], IR[10:6], IR[5:0] | varios |

---

### 3.3 Esquema completo del Datapath (vista arquitectura)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                      DATAPATH                                        │
│                                                                                      │
│  ENTRADAS DESDE CPU:                                                                 │
│  ────────────────────                                                                │
│  CLK, RESET, MEM_RDATA[31:0]                                                         │
│  Ctrl_PC_Write, Ctrl_IR_Write, Ctrl_Reg_Write, Ctrl_MEM_WE, Ctrl_TTY_WE, Ctrl_HALT  │
│  Ctrl_MUX_PC_Sel[1:0], Ctrl_MUX_ALU_A_Sel, Ctrl_MUX_ALU_B_Sel[1:0]                 │
│  Ctrl_MUX_RegDst_Sel[1:0], Ctrl_MUX_MemToReg_Sel, Ctrl_ExtOp[1:0]                   │
│  Ctrl_ALUop[3:0], Ctrl_MEM_BE_Sel[1:0], Ctrl_TTY_Sel                                │
│  Dec_InstrClass[3:0], Dec_ALUop[3:0], Dec_ExtOp[1:0], Dec_RegDst, Dec_MemToReg,    │
│  Dec_RegWrite, Dec_MemWrite, Dec_Branch, Dec_Jump, Dec_Jal, Dec_Jr, Dec_Syscall    │
│                                                                                      │
│  SALIDAS HACIA CPU:                                                                  │
│  ───────────────────                                                                 │
│  MEM_ADDR[31:0], MEM_WDATA[31:0], MEM_BE[3:0], MEM_WE, TTY_DATA[6:0], TTY_WE, HALT │
│  Branch_Cond (a Branch_Control)                                                      │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                          FETCH STAGE                                         │    │
│  │                                                                              │    │
│  │   ┌─────────┐     ┌────────────────────────────────────────────────────┐   │    │
│  │   │   PC    │────→│ MEM_ADDR[31:0]  (túnel)                            │   │    │
│  │   │ Register│     │          (combinacional a Memory)                  │   │    │
│  │   │ 32b, en=│     │                                                    │   │    │
│  │   │PC_Write │     │   MEM_RDATA[31:0] (entrada CPU) ──────────────────→│   │    │
│  │   │ clk=CLK │     │          │                                        │   │    │
│  │   │ rst=RST │     │          ▼                                        │   │    │
│  │   │ val=0   │     │   ┌─────────┐                                     │   │    │
│  │   └────┬────┘     │   │   IR    │                                     │   │    │
│  │        │          │   │ Register│                                     │   │    │
│  │        │ PC_next  │   │ 32b, en=│                                     │   │    │
│  │        │ (MUX PC) │   │IR_Write │                                     │   │    │
│  │        ▼          │   │ clk=CLK │                                     │   │    │
│  │   ┌──────────┐    │   │ rst=RST │                                     │   │    │
│  │   │MUX PC 4→1│    │   │ val=0   │                                     │   │    │
│  │   │Sel=PC_Sel│    │   └────┬────┘                                     │   │    │
│  │   │In0:PC+4  │    │        │ IR[31:0]                                │   │    │
│  │   │In1:Branch│    │        │  │                                      │   │    │
│  │   │In2:Jump  │    │        ▼  ▼                                      │   │    │
│  │   │In3:JR    │    │   ┌────────────────────────────────────────┐    │   │    │
│  │   └────┬─────┘    │   │         SPLITTER IR (Wiring→Splitter)  │    │   │    │
│  │        │          │   │   In: 32  FanOut: 6  Bit0-5: op, rs... │    │   │    │
│  │        ▼          │   │   op[5:0]=IR[31:26]  → túnel "IR_op"   │    │   │    │
│  │   TUNNEL          │   │   rs[4:0]=IR[25:21]  → túnel "IR_rs"   │    │   │    │
│  │   "PC_next"       │   │   rt[4:0]=IR[20:16]  → túnel "IR_rt"   │    │   │    │
│  │                   │   │   rd[4:0]=IR[15:11]  → túnel "IR_rd"   │    │   │    │
│  │                   │   │   shamt=IR[10:6]     → túnel "IR_shamt"│    │   │    │
│  │                   │   │   funct=IR[5:0]      → túnel "IR_funct"│    │   │    │
│  │                   │   │   imm[15:0]=IR[15:0]   → túnel "IR_imm" │    │   │    │
│  │                   │   │   addr[25:0]=IR[25:0]  → túnel "IR_addr"│   │   │    │
│  │                   │   └────────────────────────────────────────┘    │   │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         DECODE / REG FETCH STAGE                             │    │
│  │                                                                              │    │
│  │   ┌─────────────────────┐     ┌────────────────────────────────────────┐   │    │
│  │   │  Register_File      │     │         EXTENSOR INMEDIATO             │   │    │
│  │   │  (subcircuito)      │     │  (combinacional, según ExtOp)          │   │    │
│  │   │                     │     │                                        │   │    │
│  │   │ A1 ← IR_rs[4:0]     │     │  IR_imm[15:0] ─────────────────────→  │   │    │
│  │   │ A2 ← IR_rt[4:0]     │     │       │                                │   │    │
│  │   │ A3 ← RegDst_MUX     │     │       ▼                                │   │    │
│  │   │ WD ← MemToReg_MUX   │     │  ┌────────────────────────────────┐  │   │    │
│  │   │ WE ← Reg_Write      │     │  │ ExtOp=00: SignExt(imm)  → 32b  │  │   │    │
│  │   │ CLK, RESET          │     │  │ ExtOp=01: ZeroExt(imm)  → 32b  │  │   │    │
│  │   │                     │     │  │ ExtOp=10: LUI (imm<<16)  → 32b  │  │   │    │
│  │   │ RD1[31:0] ──────────┼────→│  │ ExtOp=11: Branch(imm<<2) → 32b  │  │   │    │
│  │   │ RD2[31:0] ──────────┼────→│  └────────────────────────────────┘  │   │    │
│  │   └─────────────────────┘     │       │                                │   │    │
│  │        │            │         │       ▼                                │   │    │
│  │        │            │         │  TUNNEL "ImmExt"[31:0]                │   │    │
│  │        ▼            ▼         │                                        │   │    │
│  │   ┌─────────┐   ┌─────────┐   │                                        │   │    │
│  │   │ MUX     │   │ MUX     │   │                                        │   │    │
│  │   │ ALU_A   │   │ ALU_B   │   │                                        │   │    │
│  │   │ 2→1     │   │ 4→1     │   │                                        │   │    │
│  │   │ Sel:    │   │ Sel:    │   │                                        │   │    │
│  │   │ ALU_A_Sel│   │ ALU_B_Sel│   │                                        │   │    │
│  │   │ In0:PC  │   │ In0:RD2 │   │                                        │   │    │
│  │   │ In1:RD1 │   │ In1:ImmExt│  │                                        │   │    │
│  │   └────┬────┘   │ In2:4   │   │                                        │   │    │
│  │        │        │ In3:shamt│  │                                        │   │    │
│  │        ▼        └────┬────┘   │                                        │   │    │
│  │   TUNEL "ALU_A"      │        │                                        │   │    │
│  │                      ▼        │                                        │   │    │
│  │               TUNEL "ALU_B"  │                                        │   │    │
│  │                                                                              │    │
│  │   ┌──────────────────────────────────────────────────────────────────┐    │    │
│  │   │                      ALU (subcircuito)                          │    │    │
│  │   │   ALU_A[31:0] ───────────────────────────────────────────────→  │    │    │
│  │   │   ALU_B[31:0] ───────────────────────────────────────────────→  │    │    │
│  │   │   ALUop[3:0] (desde Control_Unit/Decoder) ──────────────────→  │    │    │
│  │   │                                                                 │    │    │
│  │   │   Result[31:0] ─────────────────────────────────────────────→  │    │    │
│  │   │   Zero (1b) ────────────────────────────────────────────────→  │    │    │
│  │   └────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         EXECUTE / MEMORY STAGE                               │    │
│  │                                                                              │    │
│  │   ALU_Result[31:0] ──────────────────────────────────────────────────────→  │    │
│  │        │                                                                     │    │
│  │        ├──→ MEM_ADDR[31:0] (túnel)  — para lw/sw                            │    │
│  │        │                                                                     │    │
│  │        ├──→ Branch Target: PC+4 + (ImmExt<<2) → túnel "Branch_Target"      │    │
│  │        │                                                                     │    │
│  │        ├──→ Jump Target: {PC+4[31:28], IR_addr[25:0], 2'b00} → "Jump_Target"│   │
│  │        │                                                                     │    │
│  │        └──→ JR Target: RD1 (RS value) → túnel "JR_Target"                  │    │
│  │                                                                              │    │
│  │   ┌────────────────────────────────────────────────────────────────────┐   │    │
│  │   │                  ALINEADOR DE BYTES (combinacional)               │   │    │
│  │   │                                                                    │   │    │
│  │   │  PARA STORE (sw/sb):                                               │   │    │
│  │   │  RD2[31:0] + MEM_ADDR[1:0] + InstrClass (sb/sw)                  │   │    │
│  │   │       │                                                            │   │    │
│  │   │       ▼                                                            │   │    │
│  │   │  ┌──────────────────────────────────────────────────────────┐    │   │    │
│  │   │  │  sw: MEM_WDATA = RD2,  MEM_BE = 4'b1111                  │    │   │    │
│  │   │  │  sb: byte = RD2[7:0]                                     │    │   │    │
│  │   │  │       case MEM_ADDR[1:0]:                                 │    │   │    │
│  │   │  │         00: MEM_WDATA[7:0]   = byte, MEM_BE = 4'b0001    │    │   │    │
│  │   │  │         01: MEM_WDATA[15:8]  = byte, MEM_BE = 4'b0010    │    │   │    │
│  │   │  │         10: MEM_WDATA[23:16] = byte, MEM_BE = 4'b0100    │    │   │    │
│  │   │  │         11: MEM_WDATA[31:24] = byte, MEM_BE = 4'b1000    │    │   │    │
│  │   │  └──────────────────────────────────────────────────────────┘    │   │    │
│  │   │                                                                    │   │    │
│  │   │  PARA LOAD (lw/lb/lbu):                                            │   │    │
│  │   │  MEM_RDATA[31:0] + MEM_ADDR[1:0] + InstrClass (lb/lbu)           │   │    │
│  │   │       │                                                            │   │    │
│  │   │       ▼                                                            │   │    │
│  │   │  ┌──────────────────────────────────────────────────────────┐    │   │    │
│  │   │  │  lw:  Mem_Data = MEM_RDATA                               │    │   │    │
│  │   │  │  lb:  byte = MEM_RDATA[8*k+7:8*k], k=MEM_ADDR[1:0]      │    │   │    │
│  │   │  │       Mem_Data = SignExt(byte) → 32b                     │    │   │    │
│  │   │  │  lbu: byte = MEM_RDATA[8*k+7:8*k]                        │    │   │    │
│  │   │  │       Mem_Data = ZeroExt(byte) → 32b                     │    │   │    │
│  │   │  └──────────────────────────────────────────────────────────┘    │   │    │
│  │   │                                                                    │   │    │
│  │   │  Out: Mem_Data_Aligned[31:0] → MUX MemToReg In1                 │   │    │
│  │   └────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                              │    │
│  │   ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │   │                    MUX MemToReg (2→1, 32b)                      │   │    │
│  │   │   In0: ALU_Result                                               │   │    │
│  │   │   In1: Mem_Data_Aligned                                         │   │    │
│  │   │   Sel: MemToReg_Sel                                             │   │    │
│  │   │   Out: WD (Write Data) → Register_File.WD                       │   │    │
│  │   └────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                              │    │
│  │   ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │   │                    MUX RegDst (3→1, 5b)                         │   │    │
│  │   │   In0: IR_rt[4:0]    (rt)                                       │   │    │
│  │   │   In1: IR_rd[4:0]    (rd)                                       │   │    │
│  │   │   In2: Constant 31   ($ra para JAL)                             │   │    │
│  │   │   Sel: RegDst_Sel                                               │   │    │
│  │   │   Out: A3 → Register_File.A3                                    │   │    │
│  │   └────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         SYSCALL / TTY / HALT                                 │    │
│  │                                                                              │    │
│  │   Syscall_Detected (desde Control_Unit) + $v0 (Reg_File Reg2) + $a0 (Reg4) │    │    │
│  │        │                                                                     │    │    │
│  │        ├──→ Si $v0==11: TTY_DATA = $a0[6:0], TTY_WE = 1 (1 ciclo)         │    │    │
│  │        ├──→ Si $v0==10: HALT = 1 (latch hasta reset)                       │    │    │
│  │        └──→ Otro: no efecto                                                 │    │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  SALIDAS FINALES:                                                                    │
│  ────────────────                                                                    │
│  MEM_ADDR[31:0] ← ALU_Result (en ciclo MEM)                                         │
│  MEM_WDATA[31:0] ← Alineador salida (sb/sw)                                         │
│  MEM_BE[3:0] ← Alineador salida (sb/sw)                                             │
│  MEM_WE ← Ctrl_MEM_WE (desde Control_Unit, 1 solo en ciclo store)                  │
│  TTY_DATA[6:0] ← $a0[6:0] si syscall 11                                             │
│  TTY_WE ← 1 ciclo si syscall 11                                                     │
│  HALT ← Latch (syscall 10 o instrucción ilegal)                                     │
│  Branch_Cond ← (beq & Zero) | (bne & ~Zero)  → a Branch_Control                    │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.4 Implementación práctica en Logisim (orden sugerido)

1. **Crea subcircuito Datapath** (Project → Add Circuit → "Datapath").
2. **Arrastra Register_File y ALU** desde la lista de circuitos del proyecto.
3. **PC e IR**: Dos Registers (32b, enable, clock, reset). PC reset=0, IR reset=0.
4. **Splitter IR**: Wiring → Splitter, In=32, FanOut=6. Conecta bits según tabla.
5. **MUXes**: Todos de Plexers → Multiplexer. Configura Data Bits, Select Bits, Inputs.
6. **Extensor Inmediato**: Combinacional con MUXes + Bit Extenders + Shifters. O un subcircuito aparte `Immediate_Extender`.
7. **Alineador Bytes**: Combinacional con MUXes + Splitters + Bit Extenders. Subcircuito `Memory_Interface` recomendado.
8. **Jump/Branch Targets**: Concatenadores (Wiring → Bit Extender / Splitter) + Adder para branch.
9. **Túneles**: Úsalos **masivamente**. Nombres sugeridos:
   - `PC`, `PC_next`, `IR`, `IR_op`, `IR_rs`, `IR_rt`, `IR_rd`, `IR_shamt`, `IR_funct`, `IR_imm`, `IR_addr`
   - `RS_val`, `RT_val`, `ImmExt`, `ALU_A`, `ALU_B`, `ALU_Result`, `ALU_Zero`
   - `Branch_Target`, `Jump_Target`, `JR_Target`, `PC_Sel`, `Mem_Data_Aligned`, `WD`
   - `RegDst_Sel`, `MemToReg_Sel`, `ExtOp`, `ALUop`, `ALU_A_Sel`, `ALU_B_Sel`
   - `MEM_ADDR`, `MEM_WDATA`, `MEM_BE`, `MEM_WE`, `TTY_DATA`, `TTY_WE`, `HALT`
   - `Branch_Cond`, `Syscall_11`, `Syscall_10`

---

## 4. RESUMEN DE JERARQUÍA FINAL (R16)

```
CPU (circuito principal)
├── Instruction_Decoder    (combinacional, Día 2)
├── Control_Unit           (FSM síncrona, Día 2-3)
├── Branch_Control         (combinacional, Día 3)
└── Datapath
    ├── Register_File      ← DÍA 1 ✓
    ├── ALU                ← DÍA 1 ✓
    ├── PC (Register)
    ├── IR (Register)
    ├── MUX_PC (4→1)
    ├── MUX_ALU_A (2→1)
    ├── MUX_ALU_B (4→1)
    ├── MUX_RegDst (3→1)
    ├── MUX_MemToReg (2→1)
    ├── Immediate_Extender (combinacional)
    ├── Memory_Interface   (alineador bytes, combinacional)
    ├── Jump_Target_Calc
    ├── Branch_Target_Calc
    └── Syscall_Handler
```

---

## 5. CHECKLIST DÍA 1 (antes de commit)

- [ ] `Register_File` creado dentro de CPU → Datapath
  - [ ] 32 Registers (32b, enable, clk, reset)
  - [ ] Decoder 5→32 + enable WE
  - [ ] $zero enable = 0
  - [ ] 2 MUX 32→1 para RD1, RD2
  - [ ] Reset values: $gp=0x1800, $sp=0x3FFC, resto 0
  - [ ] Test manual: write reg5, read reg5, write reg0 → no cambia
- [ ] `ALU` creado dentro de CPU → Datapath
  - [ ] ADD/SUB compartiendo Adder + MUX 2→1 en B + Cin
  - [ ] AND, OR gates 32b
  - [ ] SLT: Comparator signed + Bit Extender 1→32
  - [ ] SLL, SRL: Shifters con shift amount = A[4:0]
  - [ ] PASS_B: B directo
  - [ ] MUX 8→1 principal (Sel=ALUop[2:0])
  - [ ] Zero: Comparator Result vs 0
  - [ ] Test manual: todas las ops de la tabla
- [ ] `Datapath` creado con PC, IR, Register_File, ALU instanciados
- [ ] Túneles principales colocados y nombrados
- [ ] Commit: `git commit -m "feat: Register_File y ALU básicos + Datapath estructura"`

---

## 6. TRUCOS LOGISIM PARA AHORRAR TIEMPO

| Truco | Cómo |
|-------|------|
| Copiar/pegar componente con cables | Selecciona componente + cables conectados → Ctrl+C → Ctrl+V |
| Crear túnel rápido | Herramienta Wiring (2) → Click en cable → `T` → escribe label |
| Multi-selección | Shift+Click o arrastrar rectángulo con Edit tool (1) |
| Cambiar bit width de varios | Multi-selecciona → Properties → Data Bits |
| Ver valores en simulación | Simulate → Poke tool (4) → hover sobre cable/túnel muestra valor |
| Etiquetas de texto | Text tool (A) → click → escribe comentario (ej: "// PC+4 calculado aquí") |
| Subcircuito desde selección | Selecciona componentes → Project → "Create Subcircuit from Selection" |

---

¡Con esto tienes todo para construir Register_File, ALU y la estructura del Datapath hoy mismo! Si te atascas en algún bloque concreto (ej. el extensor inmediato o el alineador de bytes), dímelo y te doy el sub-esquema detallado de ese bloque.
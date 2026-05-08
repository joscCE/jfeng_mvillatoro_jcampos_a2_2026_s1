# Quartus Prime 20.1 Project Setup Notes

## Project Cleanup Completed ✓

El proyecto ha sido limpiado y reorganizado para funcionar correctamente con Quartus Prime 20.1. Los siguientes cambios fueron realizados:

### Archivos Eliminados:
- ✅ Todos los archivos `.bak` (backups obsoletos)
- ✅ `proyecto2.qsf` y `proyecto2.qws` (proyecto obsoleto)
- ✅ Carpeta `output_files/` (artefactos de compilación generados)
- ✅ Carpeta `db/`, `work/`, `incremental_db/` (bases de datos de Quartus generadas)
- ✅ Carpeta `simulation/modelsim/` (archivos de simulación generados)
- ✅ Carpeta `simulation/questa/` (archivos generados)
- ✅ Archivos temporales: `.xrf`, `.rpt`, `.sof`, `.jdi`, `.smsg`, `.summary`, `.done`, `.asm`
- ✅ Archivos legacy de VGA: `CounterV.sv`, `deco_BDS.sv`, `Square_Area.sv`, `Register.sv`, `Comparator.sv`
- ✅ Archivos temporales: `trace4.mif`, `trace0.ver`, `vsim.wlf`, `c5_pin_model_dump.txt`
- ✅ Carpeta `testbench/` (duplicada)

### Configuración Actualizada:
- ✅ `Top.qsf`: TOP_LEVEL_ENTITY cambiado de `Top_ff` a `Top` (protocolo MSI)
- ✅ `Top.qsf`: EDA_NATIVELINK_SIMULATION_TEST_BENCH cambiado de `Top_ff_tb` a `Top_tb`
- ✅ `Top.qsf`: Eliminadas referencias a archivos que ya no existen
- ✅ Archivos `.sv` activos: Todos referenciados correctamente en Top.qsf

## Estructura del Proyecto (Final)

```
jfeng_mvillatoro_jcampos_a2_2026_s1/
├── Top.qsf                           # Archivo de configuración de Quartus (PRINCIPAL)
│
├── RTL - Top-level Modules:
├── Top.sv                            # Top-level MSI (write-invalidate protocol) - PRINCIPAL
├── Top_ff.sv                         # Top-level Firefly (write-update protocol) - ALTERNATIVO
│
├── RTL - Cache Modules:
├── Cache_MSI.sv                      # Cache MSI protocol
├── Cache_ff.sv                       # Cache Firefly protocol
│
├── RTL - Interconnect Modules:
├── Interconnect_MSI.sv               # Interconnect MSI protocol
├── Interconnect_FF.sv                # Interconnect Firefly protocol
│
├── RTL - Memory & Support:
├── Ram.sv                            # Shared RAM/main memory
├── PE.sv                             # Processor Element (trace loader)
├── clk_div.sv                        # Clock divider
├── Timer.sv                          # Timer utility
├── Counter.sv                        # Counter utility
├── Vga_Controller.sv                 # VGA output (used by both Top.sv and Top_ff.sv)
│
├── Test Benches:
├── Cache_MSI_tb.sv                   # Unit test for Cache MSI
├── Cache_ff_tb.sv                    # Unit test for Cache Firefly
├── Interconnect_MSI_tb.sv            # Unit test for Interconnect MSI
├── Interconnect_FF_tb.sv             # Unit test for Interconnect Firefly
├── Ram_tb.sv                         # Unit test for RAM
├── Top_tb.sv                         # System test for Top.sv (MSI)
├── Top_ff_tb.sv                      # System test for Top_ff.sv (Firefly)
├── Coherence_MSI_FF_massive_tb.sv    # Integration test (MSI path)
├── Coherence_Integration_Full_tb.sv  # Full integration test
├── tb_pe.sv                          # Processor Element test
│
├── Data Files:
├── trace0.mif                        # Processor trace 0 (processor loads)
├── trace1.mif                        # Processor trace 1
├── trace2.mif                        # Processor trace 2
├── trace3.mif                        # Processor trace 3
│
├── Documentation:
├── README.md                         # Project documentation
├── QUARTUS_SETUP_NOTES.md           # This file
├── docs/                             # Additional documentation
│
├── Development:
├── python/                           # Python scripts (development)
├── .git/                             # Git repository
└── .gitignore                        # Git ignore file
```

## Pasos para Abrir en Quartus Prime 20.1

### 1. Abrir Proyecto
```
File → Open Project → Select: Top.qsf
```
Quartus Prime automáticamente:
- Creará un nuevo archivo `Top.qpf` (project file)
- Recreará carpetas de trabajo (db/, output_files/, etc.)
- Cargará todos los archivos `.sv` referenciados en Top.qsf

### 2. Verificar Configuración
Antes de compilar, verificar:
- **Device**: Cyclone V (5CSEMA5F31C6) ✓ Configurado
- **TOP_LEVEL_ENTITY**: Top (MSI protocol) ✓ Configurado
- **EDA Tool**: ModelSim-Altera ✓ Configurado

### 3. Compilar Diseño
```
Quartus Prime → Processing → Start Compilation
o presionar: Ctrl+K
```

### 4. Ejecutar Simulación
Para probar con testbench antes de sintetizar:
```
Tools → Run EDA Simulation Tool → Run
```
Esto ejecutará `Top_tb.sv` (configurado como EDA_NATIVELINK_SIMULATION_TEST_BENCH)

## Cambiar entre Protocolos

### Para sintetizar con protocolo MSI (write-invalidate):
**Ya está configurado así**, pero si lo necesitas cambiar back:
```
En Top.qsf o en Quartus GUI:
Assignments → Settings → TOP_LEVEL_ENTITY = "Top"
```

### Para sintetizar con protocolo Firefly (write-update):
```
En Top.qsf o en Quartus GUI:
Assignments → Settings → TOP_LEVEL_ENTITY = "Top_ff"
```
**Nota**: Si cambias a Top_ff, también:
- Cambiar EDA_NATIVELINK_SIMULATION_TEST_BENCH a `Top_ff_tb`
- Vga_Controller.sv estará disponible (ambos tops usan VGA)

## Información Importante

### Protocolo Actual: MSI (Write-Invalidate)
- `Top.sv` está configurado como TOP_LEVEL_ENTITY
- Expected behavior:
  - Bus operaciones: `bus_rd`, `bus_inv`, `bus_update`
  - Escrituras disparan invalidaciones (bus_inv) en otros caches
  - Contador: `inv_cache1` mostrará invalidaciones

### MSI Testbench Status:
- ✅ Cache_MSI_tb: PASS (18/18)
- ✅ Interconnect_MSI_tb: PASS (15/15)
- ⚠️ Coherence_MSI_FF_massive_tb: 4 fallos diagnosticados (issue: handshake en Interconnect)

### Firefly Path (Alternativo):
- `Top_ff.sv` disponible como alternativa
- Protocolo: Write-update
- Expected behavior:
  - Bus operaciones: `bus_rd`, `bus_update` (sin bus_inv)
  - Escrituras actualizan otros caches (sin invalidar)

## Próximos Pasos Recomendados

1. **Abrir Quartus Prime 20.1** y cargar Top.qsf
2. **Verificar compilación limpia** (sin errores)
3. **Si usas síntesis en FPGA:**
   - Asignar pines según tu board específica
   - Los pines VGA están pre-asignados (pueden necesitar cambios)
4. **Para debugging MSI coherence issues:**
   - Revisar Coherence_MSI_FF_massive_tb.sv
   - Issue: Interconnect reatending señales mientras help=high

---

**Proyecto limpio y listo para Quartus Prime 20.1** ✓

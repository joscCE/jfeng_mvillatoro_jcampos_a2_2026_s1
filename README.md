# jfeng_mvillatoro_jcampos_a2_2026_s1

## Especificacion rapida de interfaces

## Ejecucion rapida de testbenches (MSI y Firefly)

Desde `simulation/modelsim`:

1. Correr MSI en consola:

```powershell
vsim -c -do "Top_run_msim_rtl_verilog.do"
```

2. Correr Firefly en consola:

```powershell
vsim -c -do "Top_ff_run_msim_rtl_verilog.do"
```

3. Correr ambas corridas y resumir resultados:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_sims.ps1
```

Notas:
- Los scripts `.do` usan rutas relativas al repo para que cualquier clon pueda ejecutar sin editar paths locales.
- Los trazos `trace0.mif` a `trace4.mif` estan versionados y se usan directamente durante la simulacion.

### Cache <-> Interconnect (MSI)

```text
Cache -> Interconnect (por cada cache)
- help:          1 bit   (hay request pendiente)
- request_packet:38 bits ({type[1], address[5], data[32]})
- ready_c:       1 bit   (el cache ya proceso el snoop actual)
- wb_valid:      1 bit   (el cache devuelve linea sucia en bus_rd)
- cache_line_c: 64 bits  (payload de la linea para writeback)

Interconnect -> Cache (broadcast/respuesta)
- ic_ready:      1 bit   (pulso de respuesta valida)
- bus_inv:       1 bit   (snoop de invalidacion)
- bus_rd:        1 bit   (snoop de lectura)
- snoop_addr:    5 bits  (direccion del snoop)
- resp_id:       2 bits  (id del cache que hizo el request)
- ic_tag:        2 bits  (tag de la respuesta)
- ic_cache_line:64 bits  (linea de cache que se devuelve)

Notas
- El lado del interconnect va vectorizado para 4 caches:
	help[3:0], request_packet[3:0], ready_c[3:0], wb_valid[3:0], cache_line_c[3:0].
- Cada cache acepta ic_ready solo si resp_id coincide con su cache_id local.
```

### Interconnect <-> RAM

```text
Interconnect -> RAM
- mem_req:      1 bit   (pulso de request de un ciclo)
- mem_we:       1 bit   (1=escritura, 0=lectura)
- mem_address:  5 bits  (direccion de linea)
- mem_data_in: 64 bits  (payload de linea para escritura)

RAM -> Interconnect
- mem_data_out:64 bits  (payload de linea leida)
- mem_ready:    1 bit   (pulso de operacion completada)
```

## Testbench masivo final

El testbench grande final es [Coherence_MSI_FF_massive_tb.sv](Coherence_MSI_FF_massive_tb.sv).

Que cubre:

1. Un sistema MSI completo en paralelo:
- 4 Cache_MSI
- 1 Interconnect_MSI
- 1 Ram

2. Un sistema Firefly completo en paralelo:
- 4 Cache_ff
- 1 Interconnect_FF
- 1 Ram

3. Casos de coherencia y arbitraje para ambos protocolos:
- read miss
- write miss
- write hit local
- upgrade / invalidez remota en MSI
- write-update remoto en Firefly
- read remoto sobre linea compartida o modificada
- requests simultaneos sin deadlock
- consistencia de datos despues de snoop o update remoto

### Cobertura de estados validada

MSI:
- I -> S
- I -> M
- S -> M
- M -> M
- M -> S
- S -> I
- M -> I

Firefly:
- INVALID -> SHARED
- VALID/SHARED con write-update
- propagacion de update remoto entre caches
- permanencia de coherencia sin invalidacion global
- verificacion de que bus_inv se mantiene en 0

### Resultado actual

Ultima corrida del testbench masivo:

1. Pasaron 31 checks.
2. No hubo checks fallidos.
3. Hubo 1 mensaje informativo en MSI sobre una transicion intermedia sensible al timing interno, pero la invalidez fuerte de esa linea si se valida despues en un caso posterior del mismo bench.

### Pruebas que pasaron

MSI:
- I -> S en cache0
- I -> M en cache2
- estado compartido correcto entre caches que leen la misma linea
- S -> M al hacer upgrade de escritura
- M -> M en write hit local
- M -> S por read remoto
- invalidacion remota S/M -> I
- reemplazo de owner M por write de otro cache (M -> I)
- arbitraje simultaneo sin deadlock

Firefly:
- write miss inicial correcto
- lectura remota de linea ya compartida
- write hit con propagacion de update remoto
- observacion del dato actualizado desde otro cache
- tercer lector manteniendo SHARED
- nueva actualizacion global correcta
- arbitraje simultaneo sin deadlock
- bus_inv siempre en 0
- ningun cache entra en DIRTY durante la corrida final

### Pruebas que no pasaron

Actualmente ninguna en la ultima corrida estable del testbench masivo.

### Testbenches eliminados por redundancia

Se eliminaron estos benches porque el testbench masivo ya cubre su rol de integracion/coherencia completa:

1. Coherence_MSI_tb.sv
2. Interconnect_RAM_tb.sv
3. Interconnect_RAM_FF_tb.sv

Se conservaron los benches unitarios porque todavia sirven para depurar modulos individuales mas rapido.
# =================================================================
# Workload: Productor-Consumidor con buffer compartido (4 PEs)
#
# Descomposición de addr[4:0]:
#   addr[4:3] = tag    (2 bits)
#   addr[2:1] = index  (2 bits -> slot 0,1,2,3)
#   addr[0]   = offset (1 bit  -> word 0 o word 1 dentro de la línea)
#
# Buffer compartido (tag=00):
#   buffer_0  -> slot 0 -> addr = 0  (00_00_0)  <- PE0 produce aquí
#   buffer_1  -> slot 1 -> addr = 2  (00_01_0)  <- PE1 produce aquí
#   flag_0    -> slot 2 -> addr = 4  (00_10_0)  <- flag "dato listo" de PE0
#   flag_1    -> slot 3 -> addr = 6  (00_11_0)  <- flag "dato listo" de PE1
#
# Área privada de consumidores (tag=01):
#   result_PE2 -> slot 0 -> addr = 8  (01_00_0)  <- PE2 acumula aquí
#   result_PE3 -> slot 1 -> addr = 10 (01_01_0)  <- PE3 acumula aquí
#
# Patrón productor-consumidor:
#   PE0/PE1 escriben datos al buffer y levantan su flag
#   PE2/PE3 leen la flag, leen el buffer, escriben resultado local
#   → PE2/PE3 NO escriben al buffer compartido
#   → Las invalidaciones vienen SOLO de PE0/PE1
#   → MSI debería ganar: writes en ráfaga sin lecturas intermedias del productor
#
# Formato: (req_type, addr, data)
#   req_type: 0 = read, 1 = write
#   addr:     dirección del recurso
#   data:     valor escrito (ignorado en read)
# =================================================================

REPEATS = 4

FLAG_READY = 1
FLAG_DONE  = 0

# Datos que produce cada productor por iteración
datos_PE0 = [10, 20, 30, 40]
datos_PE1 = [11, 22, 33, 44]

def producir(pe, buffer_addr, flag_addr, datos, repeats):
    """
    Productor: escribe el dato al buffer y levanta la flag.
    NO re-lee el buffer entre escrituras (ráfaga pura).
    → Con MSI: invalida a los consumidores una vez y escribe sin re-fetch.
    → Con Firefly: manda update en cada write aunque los consumidores
                   aún no estén leyendo → bandwidth desperdiciado.
    """
    for i in range(repeats):
        pe.append([1, buffer_addr, datos[i]])  # W buffer  -> M, invalida sharers
        pe.append([1, flag_addr,   FLAG_READY]) # W flag    -> señal al consumidor

def consumir(pe, buffer_addr, flag_addr, result_addr, repeats):
    """
    Consumidor: espera la flag, lee el buffer y acumula en su área privada.
    Lee flag y buffer DESPUÉS de cada producción.
    """
    for i in range(repeats):
        pe.append([0, flag_addr,   0])          # R flag    -> espera señal
        pe.append([0, buffer_addr, 0])          # R buffer  -> lee dato producido
        pe.append([0, result_addr, 0])          # R result  -> lee acumulado actual
        pe.append([1, result_addr, (i + 1)])    # W result  -> actualiza acumulado

# ==========================
# PE0 — Productor 0
# Escribe en buffer_0 (addr=0) y flag_0 (addr=4)
# ==========================
workload_PE0 = [
    # Fase 1: verificar que el buffer esté libre antes de producir
    [0, 0, 0],   # R buffer_0  -> MISS, I->S, slot 0 tag=00
    [0, 4, 0],   # R flag_0    -> MISS, I->S, slot 2 tag=00
    [0, 2, 0],   # R buffer_1  -> MISS, I->S, slot 1 tag=00
    [0, 6, 0],   # R flag_1    -> MISS, I->S, slot 3 tag=00
]
# Fase 2: producir en ráfaga (sin re-leer entre writes)
producir(workload_PE0, 0, 4, datos_PE0, REPEATS)

# ==========================
# PE1 — Productor 1
# Escribe en buffer_1 (addr=2) y flag_1 (addr=6)
# ==========================
workload_PE1 = [
    # Fase 1: verificar que el buffer esté libre antes de producir
    [0, 2, 0],   # R buffer_1  -> MISS, I->S, slot 1 tag=00
    [0, 6, 0],   # R flag_1    -> MISS, I->S, slot 3 tag=00
    [0, 0, 0],   # R buffer_0  -> MISS, I->S, slot 0 tag=00
    [0, 4, 0],   # R flag_0    -> MISS, I->S, slot 2 tag=00
]
# Fase 2: producir en ráfaga (sin re-leer entre writes)
producir(workload_PE1, 2, 6, datos_PE1, REPEATS)

# ==========================
# PE2 — Consumidor 0
# Lee buffer_0 (addr=0) y flag_0 (addr=4), acumula en result_PE2 (addr=8)
# ==========================
workload_PE2 = [
    # Fase 1: snapshot inicial de ambos buffers
    [0, 0, 0],   # R buffer_0  -> MISS, I->S, slot 0 tag=00
    [0, 4, 0],   # R flag_0    -> MISS, I->S, slot 2 tag=00
    [0, 2, 0],   # R buffer_1  -> MISS, I->S, slot 1 tag=00
    [0, 6, 0],   # R flag_1    -> MISS, I->S, slot 3 tag=00
]
# Fase 2: consumir (lee flag -> lee buffer -> acumula resultado)
consumir(workload_PE2, 0, 4, 8, REPEATS)

# ==========================
# PE3 — Consumidor 1
# Lee buffer_1 (addr=2) y flag_1 (addr=6), acumula en result_PE3 (addr=10)
# ==========================
workload_PE3 = [
    # Fase 1: snapshot inicial de ambos buffers
    [0, 2, 0],   # R buffer_1  -> MISS, I->S, slot 1 tag=00
    [0, 6, 0],   # R flag_1    -> MISS, I->S, slot 3 tag=00
    [0, 0, 0],   # R buffer_0  -> MISS, I->S, slot 0 tag=00
    [0, 4, 0],   # R flag_0    -> MISS, I->S, slot 2 tag=00
]
# Fase 2: consumir (lee flag -> lee buffer -> acumula resultado)
consumir(workload_PE3, 2, 6, 10, REPEATS)


# Agrupar los 4 programas
test = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
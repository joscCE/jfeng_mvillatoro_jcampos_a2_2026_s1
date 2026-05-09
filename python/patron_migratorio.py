# =================================================================
# Workload: Mutex con Busy Waiting ()

# addr 40: El Lock/Mutex (Dato migratorio)
# addr 50: Recurso Protegido (Precio de carta)
# =================================================================

def lock_and_update(pe, mutex_addr, data_addr, wait_cycles):
    # 1. BUSY WAITING 
    # El PE lee el lock constantemente. Esto mantiene la línea en estado 'S'.
    for _ in range(wait_cycles):
        pe.append([0, mutex_addr, 0]) 

    # 2. ADQUIRIR MUTEX (Transición S -> M)
    # El PE intenta escribir un 1 para avisar que es suyo.
    # Esto INVALIDA a todos los demás que estaban haciendo busy waiting.
    pe.append([1, mutex_addr, 1])

    # 3. SECCIÓN CRÍTICA
    # Modifica el dato protegido.
    pe.append([0, data_addr, 0])
    pe.append([1, data_addr, 500])

    # 4. LIBERAR MUTEX (Migración al siguiente)
    # Escribe un 0. El siguiente PE que esté en busy waiting verá el cambio.
    pe.append([1, mutex_addr, 0])


# ==========================
# Instrucciones PE0
# entra primero
# ==========================
workload_PE0 = []
lock_and_update(workload_PE0, 40, 50, 0)

# ==========================
# Instrucciones PE1 
# Espera un poco haciendo busy waiting y luego intenta entrar
# ==========================
workload_PE1 = []
lock_and_update(workload_PE1, 40, 50, 10)

# ==========================
# Instrucciones PE2 
# Hace mucho busy waiting (espera a PE0 y PE1)
# ==========================
workload_PE2 = []
lock_and_update(workload_PE2, 40, 50, 20)

# ==========================
# Instrucciones PE2 
# Máxima espera activa
# ==========================
workload_PE3 = []
lock_and_update(workload_PE3, 40, 50, 40)

# Agrupar los 4 programas para los 4 PEs
patron_migratorio = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
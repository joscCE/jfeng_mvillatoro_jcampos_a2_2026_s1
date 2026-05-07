# =================================================================
# Workload: Spinlock con 4 PEs ((Alta contención))
#
# Convención de direcciones:
#   addr = 5 -> lock (0 = libre, 1 = ocupado)
#   addr = 12 -> recurso compartido (simulado con writes)
#
# Formato: (req_type, addr, data)
#   req_type: 0 = read, 1 = write
#   addr:     dirección del recurso compartido
#   data:     valor escrito en caso de write (ignorando en read)
# =================================================================


# ==========================
# Instrucciones PE0
# ==========================
workload_PE0 = []
for i in range(3):
    # Loop de espera (busy wait)
    for j in range(5):  
        workload_PE0.append((0, 5, 0))  # READ lock
    
    # Intento de tomar el lock
    workload_PE0.append((1, 5, 1))      # WRITE lock = 1
    
    # Sección crítica (simulada con writes)
    workload_PE0.append((1, 12, i))     
    workload_PE0.append((1, 12, i+1))
    
    # Liberar lock
    workload_PE0.append((1, 5, 0))      # WRITE lock = 0


# ==========================
# Instrucciones PE1
# ==========================
workload_PE1 = []
for i in range(3):
    # Loop de espera (busy wait)
    for j in range(15):  
        workload_PE1.append((0, 5, 0))  # READ lock
    
    # Intento de tomar el lock
    workload_PE1.append((1, 5, 1))      # WRITE lock = 1
    
    # Sección crítica (simulada con writes)
    workload_PE1.append((1, 12, i+1000))     
    workload_PE1.append((1, 12, i+1001))
    
    # Liberar lock
    workload_PE1.append((1, 5, 0))      # WRITE lock = 0


# ==========================
# Instrucciones PE2
# ==========================
workload_PE2 = []
for i in range(3):
    # Loop de espera (busy wait)
    for j in range(10):  
        workload_PE2.append((0, 5, 0))  # READ lock
    
    # Intento de tomar el lock
    workload_PE2.append((1, 5, 1))      # WRITE lock = 1
    
    # Sección crítica (simulada con writes)
    workload_PE2.append((1, 12, i+2000))     
    workload_PE2.append((1, 12, i+2001))
    
    # Liberar lock
    workload_PE2.append((1, 5, 0))      # WRITE lock = 0

# ==========================
# Instrucciones PE3
# ==========================
workload_PE3 = []
for i in range(3):
    # Loop de espera (busy wait)
    for j in range(20):  
        workload_PE3.append((0, 5, 0))  # READ lock
    
    # Intento de tomar el lock
    workload_PE3.append((1, 5, 1))      # WRITE lock = 1
    
    # Sección crítica (simulada con writes)
    workload_PE3.append((1, 12, i+3000))     
    workload_PE3.append((1, 12, i+3001))
    
    # Liberar lock
    workload_PE3.append((1, 5, 0))      # WRITE lock = 0


# Agrupar los 4 programas para los 4 PEs
contencion = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
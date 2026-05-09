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
workload_PE0.append((1, 5, 0)) # R dir 5
workload_PE0.append((0, 5, 0)) # R dir 5



# ==========================
# Instrucciones PE1
# ==========================

workload_PE1 = []
workload_PE1.append((1, 5, 0)) # R dir 5







# ==========================
# Instrucciones PE2
# ==========================
workload_PE2 = []




# ==========================
# Instrucciones PE3
# ==========================

workload_PE3 = []




# Agrupar los 4 programas para los 4 PEs
contencion = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
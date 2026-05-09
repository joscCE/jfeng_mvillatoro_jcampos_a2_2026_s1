# =================================================================
# TEST 
#
# Formato: (req_type, addr, data)
#   req_type: 0 = read, 1 = write
#   addr:     dirección del recurso compartido
#   data:     valor escrito en caso de write (ignorando en read)
# =================================================================


# ==========================
# Instrucciones PE0
# ==========================
workload_PE0 = [
    [0, 4, 0],
    [1, 4, 0],
    [1, 4, 0],
    [0, 15, 0],

]


# ==========================
# Instrucciones PE1
# ==========================
workload_PE1 = [
    [0, 4, 0],

]

# ==========================
# Instrucciones PE2
# ==========================
workload_PE2 = [

]

# ==========================
# Instrucciones PE3
# ==========================
workload_PE3 = [

]

# Agrupar los 4 programas para los 4 PEs
test = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
# =================================================================
# Workload: Carrito de compras con 4 PEs (Alta contención)
#
# Descomposición de addr[4:0]:
#   addr[4:3] = tag    (2 bits)
#   addr[2:1] = index  (2 bits -> slot 0,1,2,3)
#   addr[0]   = offset (1 bit  -> word 0 o word 1 dentro de la línea)
#
# Productos compartidos (tag=00, slots distintos):
#   stock_laptop     -> slot 0 -> addr = 0  (00_00_0)
#   stock_phone      -> slot 1 -> addr = 2  (00_01_0)
#   stock_headphones -> slot 2 -> addr = 4  (00_10_0)
#   stock_tablet     -> slot 3 -> addr = 6  (00_11_0)
#
# Carritos privados (tag=01, slots distintos):
#   cart_user0 -> slot 0 -> addr = 8  (01_00_0)
#   cart_user1 -> slot 1 -> addr = 10 (01_01_0)
#   cart_user2 -> slot 2 -> addr = 12 (01_10_0)
#   cart_user3 -> slot 3 -> addr = 14 (01_11_0)
#
# Formato: (req_type, addr, data)
#   req_type: 0 = read, 1 = write
#   addr:     dirección del recurso compartido
#   data:     valor escrito en caso de write (ignorando en read)
# =================================================================

stk_laptop     = 10  
stk_phone      = 30  
stk_headphones = 20 
stk_tablet     = 10  

productos = ["phone", "laptop", "tablet", "headphones"]

reps = 4  # Número de veces que cada PE intentará comprar cada producto


def buy_product(pe, product, cart_addr, repeats):
    if product == "phone":
        stock_addr = 2
        initial_stock = stk_phone
    elif product == "laptop":
        stock_addr = 0
        initial_stock = stk_laptop
    elif product == "headphones":
        stock_addr = 4
        initial_stock = stk_headphones
    elif product == "tablet":
        stock_addr = 6
        initial_stock = stk_tablet

    final_cart = 0
    for i in range(repeats):
        pe.append([0, stock_addr, 0])  #  RE-LEE antes de escribir (fuerza I→S→M)
        pe.append([1, stock_addr, initial_stock - i])  # W -> invalida a los demás
        final_cart += 1

    pe.append([0, cart_addr, 0])
    pe.append([1, cart_addr, final_cart])

# ==========================
# Instrucciones PE0 (phone, headphones, tablet)
# ==========================
workload_PE0 = [
    # Fase 1: verificar stock inicial
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00

    #[0,  8, 0],   # R cart_user0         -> MISS, I->S,  slot 0 tag=01
]
# Fase 2: comprar productos 
for producto in productos:
    buy_product(workload_PE0, producto, 8,  reps)

# ==========================
# Instrucciones PE1 (laptop, headphones, tablet)
# ==========================
workload_PE1 = [
    # Fase 1: verificar stock
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00

    #[0, 10, 0],   # R cart_user1         -> MISS, I->S,  slot 1 tag=01
]
# Fase 2: comprar productos  
for producto in productos:
    buy_product(workload_PE1, producto, 10, reps)

#=========================
# Instrucciones PE2 (laptop, phone, tablet)
# ==========================
workload_PE2 = [
    # Fase 1: browse inicial
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00

    #[0, 12, 0],   # R cart_user2         -> MISS, I->S,  slot 2 tag=01
]     
# Fase 2: comprar productos  
for producto in productos:
    buy_product(workload_PE2, producto, 12, reps)

# ==========================
# Instrucciones PE3 (laptop, phone, headphones)
# ==========================
workload_PE3 = [
    # Fase 1: verificar stock
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00

    #[0, 14, 0],   # R cart_user3         -> MISS, I->S,  slot 3 tag=01
]
# Fase 2: comprar productos 
for producto in productos:
    buy_product(workload_PE3, producto, 14, reps)


# Agrupar los 4 programas para los 4 PEs
contencion = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
# =================================================================
# Workload: Carrito de compras para 4 PEs
#
# Convención de direcciones:
#   addr = 0 -> stock_A
#   addr = 1 -> stock_B
#   addr = 2 -> carrito_usuario
#   addr = 3 -> total_compra
#
# Formato: (req_type, addr, data)
#   req_type: 0 = read, 1 = write
#   addr:     dirección del recurso compartido
#   data:     valor escrito en caso de write (ignorando en read)
# =================================================================


# ==========================
# Instrucciones PE1
# ==========================
instr_pe1 = [
    (0, 0, 0),           # READ  stock_A          -> consultar inventario del producto A
    (0, 1, 0),           # READ  stock_B          -> consultar inventario del producto B
    (1, 2, 1),           # WRITE carrito_usuario  -> añadir 1 unidad al carrito
    (0, 2, 0),           # READ  carrito_usuario  -> revisar cuántos items lleva
    (1, 3, 1000),        # WRITE total_compra     -> registrar total = 1000
    (0, 3, 0),           # READ  total_compra     -> verificar el total
]


# ==========================
# Instrucciones PE2
# ==========================
instr_pe2 = [
    (0, 0, 0),           # READ  stock_A          -> revisar inventario del producto A
    (1, 2, 2),           # WRITE carrito_usuario  -> agregar 2 items al carrito
    (1, 3, 2000),        # WRITE total_compra     -> registrar total = 2000
    (0, 3, 0),           # READ  total_compra     -> verificar el total
]


# ==========================
# Instrucciones PE3
# ==========================
instr_pe3 = [
    (0, 1, 0),           # READ  stock_B          -> consultar inventario del producto B
    (1, 2, 3),           # WRITE carrito_usuario  -> agregar 3 items
    (0, 2, 0),           # READ  carrito_usuario  -> revisar cuántos items lleva
    (1, 3, 3000),        # WRITE total_compra     -> registrar total = 3000
]


# ==========================
# Instrucciones PE4
# ==========================
instr_pe4 = [
    (0, 0, 0),           # READ  stock_A          -> revisar inventario
    (0, 1, 0),           # READ  stock_B          -> revisar inventario
    (1, 2, 4),           # WRITE carrito_usuario  -> agregar 4 unidades
    (1, 3, 4000),        # WRITE total_compra     -> registrar total = 4000
    (0, 3, 0),           # READ  total_compra     -> verificar el total
]


# Agrupar los 4 programas para los 4 PEs
contencion = [
    instr_pe1,
    instr_pe2,
    instr_pe3,
    instr_pe4
]
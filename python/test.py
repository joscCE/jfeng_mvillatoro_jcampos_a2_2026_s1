# =================================================================
# Workload: Carrito de compras con 4 PEs (Alta contención)
#
# Descomposición de addr[4:0]:
#   addr[4:3] = tag    (2 bits)
#   addr[2:1] = index  (2 bits -> slot 0,1,2,3)
#   addr[0]   = offset (1 bit  -> word 0 o word 1 dentro de la línea)
#
# Para usar los 4 slots distintos necesitamos addr[2:1] = 00,01,10,11
# Usamos offset=0 siempre (addr[0]=0), entonces las direcciones
# base por slot son:
#
#   slot 0 -> addr[2:1]=00, addr[0]=0 -> addr & 0b00110 = 0b00000 -> +0
#   slot 1 -> addr[2:1]=01, addr[0]=0 -> addr & 0b00110 = 0b00010 -> +2
#   slot 2 -> addr[2:1]=10, addr[0]=0 -> addr & 0b00110 = 0b00100 -> +4
#   slot 3 -> addr[2:1]=11, addr[0]=0 -> addr & 0b00110 = 0b00110 -> +6
#
# Elegimos un bloque de tag=00 (bits[4:3]=00) -> base 0
# y tag=01 (bits[4:3]=01) -> base 8  para los carritos privados
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


# ==========================
# Instrucciones PE0
# ==========================
workload_PE0 = [
    # Fase 1: verificar stock inicial
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00

    # Fase 2: reservar laptop
    [1,  0, 9],   # W stock_laptop=9     -> needs_upgrade S->M, INV broadcast
                  #                         slot 0 sigue tag=00, ahora M
    [1,  8, 1],   # W cart_user0=1       -> MISS I->M, slot 0 tag=01
                  #                         *** evicta stock_laptop (tag=00->01) ***
    [0,  0, 0],   # R stock_laptop       -> MISS conflicto (slot 0 tiene tag=01), I->S
                  #                         *** evicta cart_user0 (tag=01->00) ***

    # Fase 3: ver si otros cambiaron el stock
    [0,  2, 0],   # R stock_phone        -> HIT si nadie invalidó (slot 1, tag=00, S)
    [0,  4, 0],   # R stock_headphones   -> HIT si nadie invalidó (slot 2, tag=00, S)
    [0,  6, 0],   # R stock_tablet       -> HIT si nadie invalidó (slot 3, tag=00, S)

    # Fase 4: reservar headphones
    [1,  4, 14],  # W stock_headphones=14 -> needs_upgrade S->M, slot 2 tag=00
    [1,  8, 2],   # W cart_user0=2        -> MISS conflicto slot 0 (tag=00->01)
                  #                          evicta stock_laptop otra vez
    [0,  4, 0],   # R stock_headphones    -> HIT (slot 2 sigue en M, tag=00)

    # Fase 5: re-verificar stock (posibles invalidaciones de otros PEs)
    [0,  0, 0],   # R stock_laptop        -> MISS conflicto slot 0 (tag=01->00)
                  #                          o MISS inv si PE3 invalidó
    [0,  2, 0],   # R stock_phone         -> HIT o MISS inv si PE1 invalidó
    [0,  4, 0],   # R stock_headphones    -> HIT o MISS inv si PE2 invalidó
    [0,  6, 0],   # R stock_tablet        -> HIT (slot 3, nadie lo tocó aún)

    # Fase 6: checkout final
    [1,  0, 8],   # W stock_laptop=8      -> S->M, INV broadcast
    [1,  6, 4],   # W stock_tablet=4      -> S->M, INV broadcast
    [1,  8, 3],   # W cart_user0=3        -> MISS conflicto slot 0 otra vez
    [0,  8, 0],   # R cart_user0          -> HIT (slot 0 en M, tag=01)
    [0,  0, 0],   # R stock_laptop        -> MISS conflicto slot 0 (tag=01->00)
    [0,  2, 0],   # R stock_phone         -> HIT o MISS inv
    [0,  4, 0],   # R stock_headphones    -> HIT o MISS inv
    [0,  6, 0],   # R stock_tablet        -> HIT o MISS inv
    [1,  8, 4],   # W cart_user0 final    -> MISS conflicto slot 0 (tag=00->01)
]


# ==========================
# Instrucciones PE1
# ==========================
workload_PE1 = [
    # Fase 1: verificar stock
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00

    # Fase 2: tomar phone y laptop
    [1,  2, 19],  # W stock_phone=19     -> S->M, INV broadcast, slot 1
    [1,  0, 9],   # W stock_laptop=9     -> S->M o MISS inv (PE0 tenía M)
    [1, 10, 1],   # W cart_user1=1       -> MISS I->M, slot 1 tag=01
                  #                         *** evicta stock_phone (tag=00->01) ***
    [0,  2, 0],   # R stock_phone        -> MISS conflicto slot 1 (tag=01->00)
    [0,  0, 0],   # R stock_laptop       -> HIT (slot 0, M)

    # Fase 3: espiar actividad de otros
    [0,  4, 0],   # R stock_headphones   -> HIT o MISS inv (PE0 escribió)
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S, slot 3 tag=00
    [0,  8, 0],   # R cart_user0 (Ana)   -> MISS I->S, slot 0 tag=01
                  #                         *** evicta stock_laptop (tag=00->01) ***

    # Fase 4: re-reserva agresiva
    [1,  2, 18],  # W stock_phone=18     -> MISS conflicto slot 1 (tag=01->00) o MISS inv
    [1,  4, 13],  # W stock_headphones=13 -> S->M o MISS inv, slot 2
    [1, 10, 2],   # W cart_user1=2        -> MISS conflicto slot 1 (tag=00->01)
    [0,  2, 0],   # R stock_phone         -> MISS conflicto slot 1 (tag=01->00)
    [0,  4, 0],   # R stock_headphones    -> HIT (slot 2, M)

    # Fase 5: checkout
    [0,  0, 0],   # R stock_laptop        -> MISS conflicto slot 0 o MISS inv
    [0,  6, 0],   # R stock_tablet        -> HIT o MISS inv (PE0 escribió)
    [1,  2, 17],  # W stock_phone=17      -> S->M, slot 1
    [1,  4, 12],  # W stock_headphones=12 -> M->M o MISS inv
    [1, 10, 3],   # W cart_user1=3        -> MISS conflicto slot 1
    [0,  2, 0],   # R stock_phone         -> MISS conflicto slot 1
    [1,  0, 8],   # W stock_laptop=8      -> MISS conflicto slot 0 o MISS inv
    [0, 10, 0],   # R cart_user1          -> MISS conflicto slot 1
    [1,  2, 16],  # W stock_phone=16      -> MISS conflicto slot 1
    [0, 10, 0],   # R cart_user1 final    -> MISS conflicto slot 1
]

# ==========================
# Instrucciones PE2
# ==========================
workload_PE2 = [
    # Fase 1: browse inicial
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00

    # Fase 2: tomar headphones
    [0,  4, 0],   # R stock_headphones   -> HIT o MISS inv (PE0 escribió)
    [1,  4, 13],  # W stock_headphones=13 -> S->M, INV broadcast, slot 2
    [1, 12, 1],   # W cart_user2=1        -> MISS I->M, slot 2 tag=01
                  #                          *** evicta stock_headphones ***
    [0,  4, 0],   # R stock_headphones    -> MISS conflicto slot 2 (tag=01->00)

    # Fase 3: revisar stock de otros
    [0,  2, 0],   # R stock_phone        -> HIT o MISS inv (PE1 escribió)
    [0,  0, 0],   # R stock_laptop       -> HIT o MISS inv
    [0,  6, 0],   # R stock_tablet       -> HIT (slot 3, S)

    # Fase 4: también quiere phone
    [1,  2, 18],  # W stock_phone=18     -> S->M o MISS inv, slot 1
    [1, 12, 2],   # W cart_user2=2       -> MISS conflicto slot 2 (tag=00->01)
    [0,  2, 0],   # R stock_phone        -> MISS conflicto slot 1 (tag=01->00) si hubo eviction... o HIT
    [0,  4, 0],   # R stock_headphones   -> MISS inv o HIT

    # Fase 5: luchar por headphones de vuelta
    [1,  4, 12],  # W stock_headphones=12 -> S->M o MISS inv, slot 2
    [0,  4, 0],   # R stock_headphones    -> HIT (slot 2, M)
    [0,  2, 0],   # R stock_phone         -> HIT o MISS inv

    # Fase 6: checkout
    [0,  0, 0],   # R stock_laptop        -> HIT o MISS inv
    [0,  6, 0],   # R stock_tablet        -> HIT o MISS inv
    [1,  4, 11],  # W stock_headphones=11 -> M->M o MISS inv, slot 2
    [1,  2, 17],  # W stock_phone=17      -> M->M o MISS inv, slot 1
    [1, 12, 3],   # W cart_user2=3        -> MISS conflicto slot 2
    [0, 12, 0],   # R cart_user2          -> HIT (slot 2, M tag=01)
    [1,  2, 16],  # W stock_phone=16      -> MISS conflicto slot 1
    [0, 12, 0],   # R cart_user2 final    -> HIT (slot 2, M)
]

# ==========================
# Instrucciones PE3
# ==========================
workload_PE3 = [
    # Fase 1: verificar stock
    [0,  0, 0],   # R stock_laptop       -> MISS, I->S,  slot 0 tag=00
    [0,  2, 0],   # R stock_phone        -> MISS, I->S,  slot 1 tag=00
    [0,  4, 0],   # R stock_headphones   -> MISS, I->S,  slot 2 tag=00
    [0,  6, 0],   # R stock_tablet       -> MISS, I->S,  slot 3 tag=00

    # Fase 2: tomar laptop y tablet
    [0,  0, 0],   # R stock_laptop       -> HIT o MISS inv (PE0/PE1 escribieron)
    [1,  0, 7],   # W stock_laptop=7     -> S->M, INV broadcast, slot 0
    [1,  6, 4],   # W stock_tablet=4     -> S->M o MISS inv, slot 3
    [1, 14, 1],   # W cart_user3=1       -> MISS I->M, slot 3 tag=01
                  #                         *** evicta stock_tablet (tag=00->01) ***
    [0,  0, 0],   # R stock_laptop       -> HIT (slot 0, M)
    [0,  6, 0],   # R stock_tablet       -> MISS conflicto slot 3 (tag=01->00)

    # Fase 3: revisar actividad de otros
    [0,  2, 0],   # R stock_phone        -> HIT o MISS inv
    [0,  4, 0],   # R stock_headphones   -> HIT o MISS inv
    [0,  8, 0],   # R cart_user0 (Ana)   -> MISS I->S, slot 0 tag=01
                  #                         *** evicta stock_laptop (tag=00->01) ***
    [0,  0, 0],   # R stock_laptop       -> MISS conflicto slot 0 (tag=01->00)

    # Fase 4: agregar headphones
    [1,  4, 11],  # W stock_headphones=11 -> S->M o MISS inv, slot 2
    [1, 14, 2],   # W cart_user3=2        -> MISS conflicto slot 3 (tag=00->01)
    [0,  4, 0],   # R stock_headphones    -> HIT (slot 2, M)
    [0,  6, 0],   # R stock_tablet        -> MISS conflicto slot 3 (tag=01->00)

    # Fase 5: checkout final
    [0,  2, 0],   # R stock_phone         -> HIT o MISS inv
    [0,  0, 0],   # R stock_laptop        -> HIT o MISS inv
    [1,  0, 6],   # W stock_laptop=6      -> S->M, INV broadcast
    [1,  6, 3],   # W stock_tablet=3      -> S->M o MISS inv
    [1, 14, 3],   # W cart_user3=3        -> MISS conflicto slot 3
    [0, 14, 0],   # R cart_user3          -> HIT (slot 3, M tag=01)
    [1,  4, 10],  # W stock_headphones=10 -> MISS inv o HIT
    [0, 14, 0],   # R cart_user3 final    -> HIT (slot 3, M)
]

# Agrupar los 4 programas para los 4 PEs
contencion = [
    workload_PE0,
    workload_PE1,
    workload_PE2,
    workload_PE3
]
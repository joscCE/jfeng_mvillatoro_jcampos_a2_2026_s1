# ===============================================
#  Script para generar MIF de instrucciones para PE
# ===============================================

DEPTH = 256       # Número de palabras en tu ROM
WIDTH = 38        # Bits por palabra (req_type+addr+data)
FILL_VALUE = 0x3F_DEADDDDD  # Valor para llenar espacios vacíos
OUTPUT_FILE = "trace.mif"

# ------------------------------------------------
# Función de empaquetado (encoding)
# ------------------------------------------------
def encode(req_type, addr, data):
    """
    req_type: 1 bit
    addr:     5 bits
    data:     32 bits
    """
    return (req_type << 37) | (addr << 32) | (data & 0xFFFFFFFF)


# ------------------------------------------------
# Aquí defines tus instrucciones
# ------------------------------------------------
instrucciones = [
    #  req_type, addr, data
    (1, 5, 0x12345678),
    (0, 3, 0xABCDEF01),
    (1, 1, 0xCAFEBABE),
]

# ------------------------------------------------
# Codificar todas las instrucciones
# ------------------------------------------------
encoded = [encode(r, a, d) for (r, a, d) in instrucciones]

# Asegurar que no se excede la memoria
if len(encoded) > DEPTH:
    raise ValueError("ERROR: Hay más instrucciones que espacio en el MIF.")

# Rellenar el resto con FILL_VALUE
while len(encoded) < DEPTH:
    encoded.append(FILL_VALUE)

# ------------------------------------------------
# Escribir archivo MIF
# ------------------------------------------------
with open(OUTPUT_FILE, "w") as f:
    f.write(f"WIDTH={WIDTH};\n")
    f.write(f"DEPTH={DEPTH};\n\n")
    f.write("ADDRESS_RADIX=HEX;\n")
    f.write("DATA_RADIX=HEX;\n\n")
    f.write("CONTENT BEGIN\n")

    for addr, value in enumerate(encoded):
        f.write(f"    {addr:02X} : {value:010X};\n")

    f.write("END;\n")

print(f"Archivo MIF generado: {OUTPUT_FILE}")
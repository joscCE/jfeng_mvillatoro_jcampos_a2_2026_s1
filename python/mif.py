
# Varias constantes para configuración de la ROM
DEPTH = 256                     # Número de palabras en ROM
WIDTH = 38                      # Bits por palabra (req_type + addr + data)
FILL_VALUE = 0x3F_DEADDDDD      # Valor para rellenar memoria vacía


# ====================================================
# Función de empaquetado (encoding)
# ====================================================
def encode(req_type, addr, data):
    """
    Empaqueta una instrucción de 38 bits:
    req_type : 1 bit
    addr     : 5 bits
    data     : 32 bits
    """
    return (req_type << 37) | (addr << 32) | (data & 0xFFFFFFFF)


# ====================================================
# Función para generar archivo MIF
# ====================================================
def generate_mif(instructions, output_file="trace.mif"):
    """
    instructions: lista de tuplas (req_type, addr, data)
    output_file : nombre de archivo .mif
    """
    encoded = [encode(r, a, d) for (r, a, d) in instructions]

    if len(encoded) > DEPTH:
        raise ValueError("ERROR: Hay más instrucciones que espacio en la ROM")

    # Rellenar con palabras vacías
    while len(encoded) < DEPTH:
        encoded.append(FILL_VALUE)

    # Escribir archivo MIF
    with open(output_file, "w") as f:
        f.write(f"WIDTH={WIDTH};\n")
        f.write(f"DEPTH={DEPTH};\n\n")
        f.write("ADDRESS_RADIX=HEX;\n")
        f.write("DATA_RADIX=HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        for addr, value in enumerate(encoded):
            f.write(f"    {addr:02X} : {value:010X};\n")

        f.write("END;\n")

    print(f"[OK] Archivo MIF generado: {output_file}")
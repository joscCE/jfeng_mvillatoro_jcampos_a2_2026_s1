from mif import generate_mif
from contention import contencion
from patron_migratorio import patron_migratorio

"""
instrucción de 38 bits:
req_type : 1 bit         0 = read, 1 = write
addr     : 5 bits        dirección del recurso compartido
data     : 32 bits       valor escrito en caso de write (ignorando en read)
"""

instr_pe_test_MSI_LOCAL = [
    (0, 0, 0),  # READ dir 0, Miss, State Invalid -> Shared
    (0, 0, 0),  # READ dir 0, Hit, State Shared -> Shared
    (1, 0, 1),  # WRITE dir 0, Miss, State Shared -> Modified
    (0, 0, 0),  # READ dir 0, Hit, State Modified -> Modified
    (1, 0, 2),  # WRITE dir 0, Hit, State Modified -> Modified
]

#generate_mif(instr_pe_test_MSI_LOCAL, f"trace.mif")

if input("1. Alta Contencion o 2. Patrón Migratorio? (1/2): ") == "1":
    # Generar MIF para cada conjunto de instrucciones de contención
    for i, instr in enumerate(contencion):
        print(f"\nInstrucciones PE{i+1}:")
        generate_mif(instr, f"trace{i+1}.mif")
else:
    # Generar MIF para cada conjunto de instrucciones del patrón migratorio
    for i, instr in enumerate(patron_migratorio):
        print(f"\nInstrucciones PE{i+1}:")
        generate_mif(instr, f"trace{i+1}.mif")

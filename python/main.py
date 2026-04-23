from mif import generate_mif
from contention import contencion

# Generar MIF para cada conjunto de instrucciones de contención
for i, instr in enumerate(contencion):
    print(f"\nInstrucciones PE{i+1}:")
    generate_mif(instr, f"trace{i+1}.mif")
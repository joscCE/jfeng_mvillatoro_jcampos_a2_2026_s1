module Ram (
    input  logic        clk,
    input  logic        reset,

    // IC -> RAM
    input  logic        we,             // 1=escritura, 0=lectura
    input  logic [4:0]  address,        // direccion de 5 bits igual que el cache
    input  logic [63:0] data_in,        // linea completa a escribir (2 bloques x 32 bits)

    // RAM -> IC
    output logic [63:0] data_out,       // linea completa leida
    output logic        mem_ready       // operacion completada, IC puede avanzar
);

    // ----------------------------------------------------------------
    // Arreglo de memoria
    // 4 entradas porque el indice del cache es de 2 bits (address[2:1])
    // cada entrada almacena una linea completa de 64 bits
    // Quartus infiere esto como logica de registros dado el tamano pequeno
    // ----------------------------------------------------------------

    logic [63:0] memory [0:3];

    // ----------------------------------------------------------------
    // Logica de lectura y escritura
    // ----------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (reset) begin
            // Limpiar salidas y contenido de memoria en reset
            data_out  <= 64'b0;
            mem_ready <= 1'b0;
            memory[0] <= 64'b0;
            memory[1] <= 64'b0;
            memory[2] <= 64'b0;
            memory[3] <= 64'b0;

        end else begin

            // mem_ready se limpia por defecto cada ciclo
            // solo se activa el ciclo en que se completa la operacion
            mem_ready <= 1'b0;

            if (we) begin
                // Escritura: usar address[2:1] como indice
                // consistente con el campo index del cache
                // address[4:3] = tag
                // address[2:1] = index  <- indice de la RAM
                // address[0]   = offset
                memory[address[2:1]] <= data_in;
                data_out             <= 64'b0;  // sin dato util en escritura
                mem_ready            <= 1'b1;   // confirmar al IC que termino

            end else begin
                // Lectura: devolver linea completa del indice correspondiente
                // el dato estara disponible en data_out en el ciclo siguiente
                data_out  <= memory[address[2:1]];
                mem_ready <= 1'b1;  // confirmar al IC que termino
            end

        end
    end

endmodule
module Ram (
    input  logic        clk,
    input  logic        reset,

    // IC -> RAM
    input  logic        req,            // pulso de un ciclo: IC pide operacion
    input  logic        we,             // 1=escritura, 0=lectura
    input  logic [4:0]  address,        // direccion de 5 bits igual que el cache
    input  logic [63:0] data_in,        // linea completa a escribir (2 bloques x 32 bits)

    // RAM -> IC
    output logic [63:0] data_out,       // linea completa leida
    output logic        mem_ready       // todo listo, IC puede avanzar
);

    // ----------------------------------------------------------------
    // Arreglo de memoria.
    // 4 entradas porque el indice del cache es de 2 bits (address[2:1]).
    // Cada entrada almacena una linea completa de 64 bits.
    // address[4:3] = tag
    // address[2:1] = index 
    // address[0] = offset.
    // ----------------------------------------------------------------

    logic [63:0] memory [0:3];

    // ----------------------------------------------------------------
    // Lectura y escritura
    // mem_ready se activa el ciclo despues de req y data_out queda valido
    // ----------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (reset) begin
            data_out  <= 64'b0;
            mem_ready <= 1'b0;
        end else begin
            // Por defecto mem_ready se limpia cada ciclo
            mem_ready <= 1'b0;

            if (req) begin
                if (we) begin
                    memory[address[2:1]] <= data_in;
                end
                data_out  <= memory[address[2:1]];
                mem_ready <= 1'b1;
            end
        end
    end

endmodule
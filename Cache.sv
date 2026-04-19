module Cache(
    input logic clk,
    input logic reset,
    input logic we,            // Write Enable del procesador
    input logic rd,            // Read Enable del procesador
    input logic [4:0] address,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic stall,        // Avisa al procesador que espere

    // Interfaz con el Interconnect (IC)
    input logic ready,         // IC dice: "Dato/Estado listo"
    input logic bus_inv,       // IC dice: "Invalida este bloque"
    input logic bus_rd,        // IC dice: "Alguien lee, pasa a Shared"
    input logic [1:0] ic_tag,  // Tag que manda el IC
    input logic [63:0] ic_data,// Bloque completo que manda el IC
    
    // Salidas al IC
    output logic [1:0] current_state,
    output logic [1:0] current_tag
);

    // Estados MSI
    localparam INVALID  = 2'b00;
    localparam SHARED   = 2'b01;
    localparam MODIFIED = 2'b10;

    logic offset;
    logic [1:0] index;
    logic [1:0] tag;

    assign offset = address[0];
    assign index  = address[2:1];
    assign tag    = address[4:3];

    // Cache: [tag(2)][bloque1(32)][bloque0(32)][state(2)]
    logic [67:0] cache [0:3];
    
    logic [67:0] cache_line;
    assign cache_line = cache[index];
    
    assign current_tag   = cache_line[67:66];
    assign current_state = cache_line[1:0];

    // Lógica de Hit
    logic hit;
    assign hit = (current_tag == tag) && (current_state != INVALID);

    // Stall: Si el procesador quiere algo y no hay hit, debe esperar al 'ready' del IC
    assign stall = (rd || we) && !hit && !ready;

    // Lectura de datos
    always_comb begin
        if (hit)
            data_out = (offset) ? cache_line[65:34] : cache_line[33:2];
        else
            data_out = 32'bz;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) cache[i] <= 68'b0;
        end else begin
            
            // 1. REACCIÓN A EVENTOS DEL BUS (SNOOPING / IC COMMANDS)
            // Estas tienen prioridad para mantener la coherencia
            if (current_tag == tag) begin // Si la operación del bus es sobre mi línea
                if (bus_inv) begin
                    cache[index][1:0] <= INVALID;
                end else if (bus_rd && current_state == MODIFIED) begin
                    cache[index][1:0] <= SHARED;
                end
            end

            // 2. REACCIÓN A PETICIONES DEL PROCESADOR (LOCAL)
            if (hit) begin
                if (we) begin
                    // Write Hit local
                    cache[index][1:0] <= MODIFIED;
                    if (offset) cache[index][65:34] <= data_in;
                    else        cache[index][33:2]  <= data_in;
                end
            end 
            // 3. MANEJO DE MISS (ESPERANDO AL IC)
            else if ((rd || we) && ready) begin
                // El IC respondió con el dato y el tag nuevo
                cache[index][67:66] <= ic_tag;
                cache[index][65:2]  <= ic_data;
                
                // Determinamos el nuevo estado según la intención original
                if (we) begin
                    cache[index][1:0] <= MODIFIED;
                    // Actualizamos con el dato que el procesador quería escribir
                    if (offset) cache[index][65:34] <= data_in;
                    else        cache[index][33:2]  <= data_in;
                end else begin
                    cache[index][1:0] <= SHARED;
                end
            end
        end
    end

endmodule
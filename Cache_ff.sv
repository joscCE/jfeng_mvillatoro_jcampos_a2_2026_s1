module Cache_ff(
    input logic clk,                // Reloj
    input logic reset,              // Reset sincrónico
    input logic [1:0] cache_id,     // ID de cache para respuestas
    input logic we,                 // Señal de escritura
    input logic rd,                 // Señal de lectura
    input logic [4:0] address,      // Dirección de acceso
    input logic [31:0] data_in,     // Datos de escritura
    output logic [31:0] data_out,   // Datos de lectura
    output logic stall,             // Señal de stall hacia PE

    // Cache -> IC
    output logic help,
    output logic [37:0] request_packet, // {type[1], address[5], data[32]}
    output logic ready_c,               // Acknowledge de snoop
    output logic wb_valid,              // Valida write-back de línea
    output logic [63:0] cache_line_c,   // Datos de línea para write-back

    // IC -> Cache
    input logic ready,              // Respuesta a request (hit/miss)
    input logic bus_rd,             // Señal de lectura en bus
    input logic bus_update,         // Señal de actualización en bus (write-back o write hit)
    input logic [4:0] snoop_addr,   // Dirección de snoop
    input logic [1:0] resp_id,      // ID de respuesta
    input logic [1:0] ic_tag,       // Tag de IC
    input logic [63:0] ic_data,     // Datos de IC

    // Debug
    output logic [1:0] current_state,   // Estado de la línea cache
    output logic [1:0] current_tag      // Tag de la línea cache
);

    localparam VALID   = 2'b00;
    localparam SHARED  = 2'b01;
    localparam DIRTY   = 2'b10;
    localparam INVALID = 2'b11;

    logic offset;               // Offset dentro de la línea
    logic [1:0] index;          // Índice de la línea de cache
    logic [1:0] tag;            // Tag de la dirección de acceso
    logic snoop_offset;         // Offset del snoop
    logic [1:0] snoop_index;    // Índice del snoop
    logic [1:0] snoop_tag;      // Tag de la dirección de snoop

    assign offset = address[0];
    assign index  = address[2:1];
    assign tag    = address[4:3];
    assign snoop_offset = snoop_addr[0];
    assign snoop_index  = snoop_addr[2:1];
    assign snoop_tag    = snoop_addr[4:3];

    logic [67:0] cache [0:3];   // 4 líneas de cache con {tag[2], data[64], state[2]}
    logic [67:0] cache_line;    // Línea de cache seleccionada por el índice

    assign cache_line = cache[index];
    assign current_tag   = cache_line[67:66];
    assign current_state = cache_line[1:0];

    logic hit;                      // Si hay un hit en el cache
    logic needs_update;             // Si la línea necesita ser actualizada en escritura
    logic pending;                  // Si hay una request pendiente hacia IC
    logic pending_ready_armed;      // Si el request pendiente ya puede aceptar el ready de IC
    logic [2:0] pending_age;        // Información del request pendiente
    logic pending_type;             // Tipo de request pendiente (0 write, 1 read)
    logic [4:0] pending_address;    // Dirección de la request pendiente
    logic [31:0] pending_data;      // Datos de la request pendiente
    logic self_snoop;               // Indica si la request pendiente es un snoop propio

    assign hit = (current_tag == tag) && (current_state != INVALID);
    assign needs_update = we && hit && (current_state == SHARED);
    assign self_snoop = pending && (pending_address == snoop_addr);

    assign help = pending;
    assign request_packet = {pending_type, pending_address, pending_data};
    assign stall = pending || (((rd || we) && (!hit || needs_update)) && !ready);

    always_comb begin
        if (hit)
            data_out = (offset) ? cache_line[65:34] : cache_line[33:2];
        else
            data_out = 32'b0;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                cache[i] <= 68'b0;
                cache[i][1:0] <= INVALID;
            end
            pending            <= 1'b0;
            pending_ready_armed<= 1'b0;
            pending_age        <= 3'b0;
            pending_type       <= 1'b0;
            pending_address    <= 5'b0;
            pending_data       <= 32'b0;
            ready_c            <= 1'b0;
            wb_valid           <= 1'b0;
            cache_line_c       <= 64'b0;
        end else begin
            ready_c  <= 1'b0;
            wb_valid <= 1'b0;
            cache_line_c <= 64'b0;

            // Snoop de bus: si el snoop afecta milínea se responde con ready_c y actualizo estado/linea si es necesario
            if (bus_rd || bus_update) begin
                ready_c <= 1'b1;
                if (cache[snoop_index][67:66] == snoop_tag &&
                    cache[snoop_index][1:0] != INVALID && !self_snoop) begin
                    if (bus_update) begin
                        if (snoop_offset)
                            cache[snoop_index][65:34] <= ic_data[63:32];
                        else
                            cache[snoop_index][33:2] <= ic_data[31:0];
                        cache[snoop_index][1:0] <= SHARED;
                    end
                    if (bus_rd) begin
                        cache[snoop_index][1:0] <= SHARED;
                    end
                end
            end

            // Write-back de línea por reemplazo o invalidación
            if (!pending && hit && !needs_update) begin
                if (we) begin
                    if (offset)
                        cache[index][65:34] <= data_in;
                    else
                        cache[index][33:2] <= data_in;

                    if (current_state == SHARED)
                        cache[index][1:0] <= SHARED;
                    else
                        cache[index][1:0] <= VALID;
                end
            end

            // Generación de request hacia IC
            if (!pending && ((rd || we) && (!hit || needs_update))) begin
                pending            <= 1'b1;
                pending_ready_armed<= 1'b0;
                pending_age        <= 3'b0;
                pending_type       <= rd ? 1'b1 : 1'b0;
                pending_address    <= address;
                pending_data       <= data_in;
            end

            // Manejo de respuesta de IC para request pendiente
            if (pending && !pending_ready_armed)
                pending_ready_armed <= 1'b1;

            // Aging de request pendiente para evitar esperar indefinidamente el ready de IC
            if (pending && pending_age != 3'b111)
                pending_age <= pending_age + 3'd1;

            // Si el ready de IC corresponde a la request pendiente, actualizo línea y estado según tipo de request
            if (pending && pending_ready_armed && (pending_age >= 3'd2) &&
                ready && (resp_id == cache_id)) begin
                logic [1:0] p_index;
                logic p_offset;
                p_index = pending_address[2:1];
                p_offset = pending_address[0];

                cache[p_index][67:66] <= ic_tag;
                cache[p_index][65:2]  <= ic_data;

                // Si es escritura la línea queda en SHARED (write hit) o VALID (miss). Si es lectura queda en SHARED.
                if (pending_type == 1'b0) begin
                    if (p_offset)
                        cache[p_index][65:34] <= pending_data;
                    else
                        cache[p_index][33:2] <= pending_data;
                    cache[p_index][1:0] <= SHARED;
                end else begin
                    cache[p_index][1:0] <= SHARED;
                end

                pending <= 1'b0;
                pending_ready_armed <= 1'b0;
                pending_age <= 3'b0;
            end
        end
    end

endmodule
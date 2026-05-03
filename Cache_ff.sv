module Cache_ff(
    input logic clk,
    input logic reset,
    input logic we,
    input logic rd,
    input logic [4:0] address,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic stall,

    // Interconnect
    input logic ready,
    input logic bus_rd,
    input logic bus_update,
    input logic [31:0] bus_data,
    input logic [1:0] bus_tag,
    input logic [1:0] ic_tag,
    input logic [63:0] ic_data,
    input logic CE,

    // Debug
    output logic [1:0] current_state,
    output logic [1:0] current_tag
);

    // Estados
    localparam VALID   = 2'b00;
    localparam SHARED  = 2'b01;
    localparam DIRTY   = 2'b10; 
    localparam INVALID = 2'b11;

    logic offset;
    logic [1:0] index;
    logic [1:0] tag;

    assign offset = address[0];
    assign index  = address[2:1];
    assign tag    = address[4:3];

    logic [67:0] cache [0:3];
    logic [67:0] cache_line;

    assign cache_line = cache[index];

    assign current_tag   = cache_line[67:66];
    assign current_state = cache_line[1:0];

    logic hit;
    assign hit = (current_tag == tag) && (current_state != INVALID);

    assign stall = (rd || we) && !hit && !ready;

    // lectura
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
        end else begin

            // =====================================
            //  1. SNOOP: BUS UPDATE
            // =====================================
            if (bus_update && current_state != INVALID && current_tag == bus_tag) begin
                // actualizar dato local
                if (offset)
                    cache[index][65:34] <= bus_data;
                else
                    cache[index][33:2] <= bus_data;

                // sigue siendo compartido
                cache[index][1:0] <= SHARED;
            end

            // =====================================
            // 2. SNOOP: BUS READ
            // =====================================
            if (bus_rd && current_state != INVALID && current_tag == tag) begin
                cache[index][1:0] <= SHARED;
            end

            // =====================================
            // 3. HIT LOCAL
            // =====================================
            if (hit) begin

                // READ HIT → nada
                if (rd) begin
                end
                //  WRITE HIT
                if (we) begin
                    // escribir local
                    if (offset)
                        cache[index][65:34] <= data_in;
                    else
                        cache[index][33:2] <= data_in;

                    //  Firefly: update a otros
                    // (esto debería salir al bus en sistema real)

                    if (CE)
                        cache[index][1:0] <= SHARED;
                    else
                        cache[index][1:0] <= VALID;
                end
            end

            // =====================================
            // 4. MISS
            // =====================================
            else if ((rd || we) && ready) begin

                // traer bloque
                cache[index][67:66] <= ic_tag;
                cache[index][65:2]  <= ic_data;

                // READ MISS
                if (rd) begin
                    if (CE)
                        cache[index][1:0] <= SHARED;
                    else
                        cache[index][1:0] <= VALID;
                end

                //  WRITE MISS
                if (we) begin
                    // escribir
                    if (offset)
                        cache[index][65:34] <= data_in;
                    else
                        cache[index][33:2] <= data_in;

                    // update protocol
                    if (CE)
                        cache[index][1:0] <= SHARED;
                    else
                        cache[index][1:0] <= VALID;
                end
            end
        end
    end

endmodule
module Cache(
    input logic clk,
    input logic reset,
    input logic we,
    input logic rd,
    input logic [4:0] address,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic stall,

    output logic ready_c,

    // Interconnect
    input logic ready,
    input logic bus_inv,
    input logic bus_rd,
    input logic [1:0] bus_tag,   
    input logic [1:0] ic_tag,
    input logic [63:0] ic_data,
    
    // Debug / salida
    output logic [1:0] current_state,
    output logic [1:0] current_tag,
    output logic [63:0] cache_line_c
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

    // [tag][data][state]
    logic [67:0] cache [0:3];
    logic [67:0] cache_line;

    assign cache_line = cache[index];

    assign current_tag   = cache_line[67:66];
    assign current_state = cache_line[1:0];

    // dato que se manda al IC (bloque completo)
    assign cache_line_c = cache_line[65:2];

    // HIT
    logic hit;
    assign hit = (current_tag == tag) && (current_state != INVALID);

    // STALL
    assign stall = (rd || we) && !hit && !ready;

    // READ
    always_comb begin
        if (hit)
            data_out = (offset) ? cache_line[65:34] : cache_line[33:2];
        else
            data_out = 32'bz;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                cache[i] <= 68'b0;
            end
            ready_c <= 0;
        end else begin

            // default (pulso)
            ready_c <= 0;

            // =========================
            // 1. SNOOP (BUS)
            // =========================
            for (int i = 0; i < 4; i++) begin //para las 3 lineas de cache
                if (cache[i][67:66] == bus_tag && cache[i][1:0] != INVALID) begin //si tiene el mismo tag que el que pide el ic, y no esta invalido

                    //BUS READ
                    if (bus_rd) begin //si el ic lo pide
                        if (cache[i][1:0] == MODIFIED) begin //y es el valor mas actual
                            // write-back
                            cache_line_c <= cache[i][65:2]; //mande el dato al ic
                            ready_c <= 1; //le da el ready
                        end
                        cache[i][1:0] <= SHARED; //pone esa linea de cache en shared
                    end

                    //INVALIDATE
                    if (bus_inv) begin //si le da el invalidate
                        cache[i][1:0] <= INVALID; //la pone en invalidate xd
                    end
                end
            end

            // =========================
            // HIT LOCAL
            // =========================
            if (hit) begin //si hay hit
                if (we) begin
                    cache[index][1:0] <= MODIFIED; //escribe y modified

                    if (offset)
                        cache[index][65:34] <= data_in; //le da el valor al cpu depende del offset
                    else
                        cache[index][33:2] <= data_in;
                end
            end

            // =========================
            //MISS
            // =========================
            else if ((rd || we) && ready) begin

                cache[index][67:66] <= ic_tag; //nuevo tag
                cache[index][65:2]  <= ic_data; //nueva data

                if (we) begin
                    cache[index][1:0] <= MODIFIED; //si era escribri se pone en modi

                    if (offset)
                        cache[index][65:34] <= data_in; //se escribe el dato nuevo
                    else
                        cache[index][33:2] <= data_in;

                end else begin
                    cache[index][1:0] <= SHARED; //sino nada mas shared
                end
            end
        end
    end

endmodule
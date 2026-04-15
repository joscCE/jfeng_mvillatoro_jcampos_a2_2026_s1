module Cache(

    input logic clk,
    input logic reset,
    input logic we,
    input logic [4:0] address,
    input logic [31:0] data_in,
    output logic [31:0] data_out
);

// Dirección
logic offset;
logic [1:0] index;
logic [1:0] tag;

assign offset = address[0];
assign index  = address[2:1];
assign tag    = address[4:3];

// Cache: [tag(2)][bloque1(32)][bloque0(32)][state(2)]
logic [67:0] cache [0:3];

logic [67:0] cache_line;
logic [1:0] stored_tag;
logic [1:0] state;
logic hit;

assign cache_line = cache[index];

assign stored_tag = cache_line[67:66];
assign state      = cache_line[1:0];

assign hit = (stored_tag == tag) && (state != 2'b00);

always_comb begin
    if (hit) begin
        case(offset)
            1'b0: data_out = cache_line[33:2];
            1'b1: data_out = cache_line[65:34];
        endcase
    end else begin
        data_out = 32'b0;
    end
end

always_ff @(posedge clk or posedge reset) begin
    if (we && hit) begin
        case(offset)
            1'b0: cache[index][33:2]  <= data_in;  // bloque 0
            1'b1: cache[index][65:34] <= data_in;  // bloque 1
        endcase
        end
    end


endmodule
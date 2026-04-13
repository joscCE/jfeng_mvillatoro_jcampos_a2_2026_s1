module Cache(

    input logic clk,
    input logic reset,
    input logic we,
    input logic [31:0] address,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic hit
    
);


// Dirección

logic [1:0] offset;
logic [9:0] index;   
logic [19:0] tag;    

assign offset = address[1:0];
assign index  = address[11:2];
assign tag    = address[31:12];


// Cache
// [state(2)][tag(20)][bloque2(32)][bloque1(32)][bloque0(32)]
// total = 118 bits
logic [117:0] cache [0:1023];

// Señales internas
logic [117:0] cache_line;
logic [19:0] index_tag;   
logic [1:0] block_state;

// leer línea de cache
assign cache_line = cache[index];

// extraer campos
assign index_tag   = cache_line[115:96];
assign block_state = cache_line[1:0];

// HIT
assign hit = (index_tag == tag) && (block_state != 2'b00);

// Lectura
always_comb begin
    if (hit) begin
        case(offset)
            2'b00: data_out = cache_line[33:2];     // bloque 0
            2'b01: data_out = cache_line[65:34];    // bloque 1
            2'b10: data_out = cache_line[97:66];    // bloque 2
            default: data_out = 32'b0;              // offset inválido
        endcase
    end else begin
        data_out = 32'b0;
    end
end

endmodule
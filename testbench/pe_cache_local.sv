module pe_cache_local #(
    parameter TRACE_MIF = "trace2.mif"
)(
    input  logic        clk,
    input  logic        rst,

    // IC hacia la Cache 
    input  logic        ic_ready,      // IC: dato/estado listo
    input  logic        ic_bus_inv,    // IC: invalida este bloque
    input  logic        ic_bus_rd,     // IC: alguien leyó -> SHARED
    input  logic [1:0]  ic_tag,        // IC: tag del bloque que manda
    input  logic [63:0] ic_data,       // IC: bloque completo (2×32 b)

    // Cache hacia el IC 
    output logic [1:0]  cache_state,   // estado MSI del bloque
    output logic [1:0]  cache_tag,     // tag actual de la línea

    // Señal de fin de traza 
    output logic        finished
);

    // Señales internas PE -> Cache
    logic        pe_rd;
    logic        pe_we;
    logic [4:0]  pe_addr;
    logic [31:0] pe_data_out;   // dato que el PE quiere escribir

    // Señales internas Cache -> PE
    logic        stall;
    logic [31:0] cache_data_out;

    // Instancia del PE 
    PE #(
        .TRACE_MIF(TRACE_MIF)
    ) u_pe (
        .clk         (clk),
        .rst         (rst),
        .stall_cache (stall),
        .data_cache  (cache_data_out),
        .rd          (pe_rd),
        .we          (pe_we),
        .addr        (pe_addr),
        .data        (pe_data_out),
        .finished    (finished)
    );

    // Instancia de la Cache 
    Cache u_cache (
        .clk          (clk),
        .reset        (rst),
        .we           (pe_we),   // solo cuando PE tiene petición válida
        .rd           (pe_rd),
        .address      (pe_addr),
        .data_in      (pe_data_out),
        .data_out     (cache_data_out),
        .stall        (stall),
        // IC signals
        .ready        (ic_ready),
        .bus_inv      (ic_bus_inv),
        .bus_rd       (ic_bus_rd),
        .ic_tag       (ic_tag),
        .ic_data      (ic_data),
        // Cache -> IC
        .current_state(cache_state),
        .current_tag  (cache_tag)
    );

endmodule 
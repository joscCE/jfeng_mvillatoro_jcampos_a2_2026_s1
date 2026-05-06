module Top_ff (
    input  logic clk,
    input  logic reset
);

    // --- Señales PE <-> Cache ---
    logic [3:0]  pe_req_valid, pe_req_type;
    logic [4:0]  pe_addr [3:0];
    logic [31:0] pe_data_to_cache [3:0];
    logic [31:0] pe_data_from_cache [3:0];
    logic [3:0]  cache_stall;

    // --- Señales Cache <-> Interconnect (IC) ---
    logic [3:0]  cache_help;
    logic [37:0] cache_request_packet [3:0];
    logic [3:0]  cache_ready_c;
    logic [3:0]  cache_wb_valid;
    logic [63:0] cache_line_to_ic [3:0];

    // --- Señales Broadcast desde el IC ---
    logic        ic_ready;
    logic        bus_rd, bus_update;
    logic [1:0]  resp_id;
    logic [4:0]  snoop_addr;
    logic [1:0]  ic_tag;
    logic [63:0] ic_data_bus;

    // --- Señales IC <-> RAM ---
    logic        mem_req, mem_we, mem_ready;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_to_ram, mem_data_from_ram;
	 
	 logic [63:0] count_timer [3:0];
	 logic [63:0] count_updt [3:0];

    // ============================================================
    // 1. Instanciación de Procesadores (PE)
    // ============================================================
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_pe
            localparam string TRACE_FILE = (i == 0) ? "trace0.mif" :
                                           (i == 1) ? "trace1.mif" :
                                           (i == 2) ? "trace2.mif" : "trace3.mif";
            PE #(
                .TRACE_MIF(TRACE_FILE)
            ) u_pe (
                .clk(clk),
                .rst(reset),
                .done(!cache_stall[i]), // El PE avanza cuando NO hay stall[cite: 14]
                .req_valid(pe_req_valid[i]),
                .req_type(pe_req_type[i]),
                .addr(pe_addr[i]),
                .data(pe_data_to_cache[i]),
                .finished() 
            );
        end
    endgenerate

    // ============================================================
    // 2. Instanciación de Caches Firefly (Cache_ff)
    // ============================================================
    generate
        for (i = 0; i < 4; i++) begin : gen_cache
            Cache_ff u_cache (
                .clk(clk),
                .reset(reset),
                .cache_id(i[1:0]),
                .we(pe_req_type[i]),     // 0 = Write
                .rd(pe_req_valid[i]),    // 1 = Read[cite: 12]
                .address(pe_addr[i]),
                .data_in(pe_data_to_cache[i]),
                .data_out(pe_data_from_cache[i]),
                .stall(cache_stall[i]),
                
                // Salidas hacia el IC
                .help(cache_help[i]),
                .request_packet(cache_request_packet[i]),
                .ready_c(cache_ready_c[i]),
                .wb_valid(cache_wb_valid[i]),
                .cache_line_c(cache_line_to_ic[i]),

                // Entradas desde el IC
                .ready(ic_ready),
                .bus_rd(bus_rd),
                .bus_update(bus_update), // Especifico de Firefly[cite: 12]
                .snoop_addr(snoop_addr),
                .resp_id(resp_id),
                .ic_tag(ic_tag),
                .ic_data(ic_data_bus),
                
                .current_state(),
                .current_tag(),
					 
					 .Counter_upt(count_timer[i]),
                .Time_stall(count_updt[i])  
            );
        end
    endgenerate

    // ============================================================
    // 3. Interconectador Firefly (Interconnect_FF)[cite: 13]
    // ============================================================
    Interconnect_FF u_ic (
        .clk(clk),
        .reset(reset),
        .help(cache_help),
        .request_packet(cache_request_packet),
        .ready_c(cache_ready_c),
        .ic_ready(ic_ready),
        .bus_rd(bus_rd),
        .bus_update(bus_update),
        .resp_id(resp_id),
        .snoop_addr(snoop_addr),
        .ic_tag(ic_tag),
        .ic_cache_line(ic_data_bus),
        
        // Memoria
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_address(mem_address),
        .mem_data_in(mem_data_to_ram),
        .mem_data_out(mem_data_from_ram),
        .mem_ready(mem_ready)
    );

    // ============================================================
    // 4. Memoria RAM[cite: 15]
    // ============================================================
    Ram u_ram (
        .clk(clk),
        .reset(reset),
        .req(mem_req),
        .we(mem_we),
        .address(mem_address),
        .data_in(mem_data_to_ram),
        .data_out(mem_data_from_ram),
        .mem_ready(mem_ready)
    );

endmodule
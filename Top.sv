module Top (
    input  logic clk50,
    input  logic reset,
	 output logic Hs, Vs,
	 output logic VGA_Blank, VGA_Sync_N, VGA_CLK,
	 output logic [7:0]  R, G, B
	 
);

	logic clk;
	
	clk_div div_clo(
		 .clk(clk50),
		 .rst_active(reset),
		 .clk25(clk)
	);
	
assign VGA_CLK = clk;	
		
    // --- Señales PE <-> Cache ---
    logic [3:0]  pe_we, pe_rd, pe_stall;
    logic [4:0]  pe_address [3:0];
    logic [31:0] pe_data_to_cache [3:0];
    logic [31:0] pe_data_from_cache [3:0];

    logic [3:0]  cache_help;
    logic [37:0] cache_request_packet [3:0];
    logic [3:0]  cache_ready_c;
    logic [3:0]  cache_wb_valid;
    logic [63:0] cache_line_to_ic [3:0];

    // --- Señales Broadcast IC ---
    logic        ic_ready;
    logic        bus_inv, bus_rd;
    logic [1:0]  resp_id;
    logic [4:0]  snoop_addr;
    logic [1:0]  ic_tag;
    logic [63:0] ic_data_bus;

    // --- Señales IC <-> RAM ---
    logic        mem_req, mem_we, mem_ready;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_to_ram, mem_data_from_ram;

	 logic [63:0] count_timer [3:0];
	 logic [63:0] count_inv [3:0];
	 logic [63:0] count_miss [3:0];
	 logic [63:0] count_req [3:0];
	 
 	
//	Vga_Controller #(.N(8)) vga_control(
//    .clk(clk), 
//	 .rst(reset),
//    .Hs(Hs), 
//	 .Vs(Vs),
//    .VGA_Blank(VGA_Blank), 
//	 .VGA_Sync_N(VGA_Sync_N),
//    .Q_X(), 
//	 .Q_Y(),
//    .R(R), 
//	 .G(G), 
//	 .B(B),
//    .count_timer(count_timer),
//    .count_inv(count_inv) 
//);


PE #(
    .TRACE_MIF("trace1.mif")
) u_pe0 (
    .clk(clk),
    .rst(reset),
    .stall_cache(!pe_stall[0]),
    .rd(pe_rd[0]),
    .we(pe_we[0]),
    .addr(pe_address[0]),
    .data(pe_data_to_cache[0]),
    .finished()
);

PE #(
    .TRACE_MIF("trace2.mif")
) u_pe1 (
    .clk(clk),
    .rst(reset),
    .stall_cache(!pe_stall[1]),
    .rd(pe_rd[1]),
    .we(pe_we[1]),
    .addr(pe_address[1]),
    .data(pe_data_to_cache[1]),
    .finished()
);

PE #(
    .TRACE_MIF("trace3.mif")
) u_pe2 (
    .clk(clk),
    .rst(reset),
    .stall_cache(!pe_stall[2]),
    .rd(pe_rd[2]),
    .we(pe_we[2]),
    .addr(pe_address[2]),
    .data(pe_data_to_cache[2]),
    .finished()
);

PE #(
    .TRACE_MIF("trace4.mif")
) u_pe3 (
    .clk(clk),
    .rst(reset),
    .stall_cache(!pe_stall[3]),
    .rd(pe_rd[3]),
    .we(pe_we[3]),
    .addr(pe_address[3]),
    .data(pe_data_to_cache[3]),
    .finished()
);

    // ============================================================
    // 2. Instanciación de Caches MSI[cite: 8]
    // ============================================================
	genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_cache
            Cache_MSI u_cache (
                .clk(clk),
                .reset(reset),
                .cache_id(i[1:0]),
                .we(pe_we[i]),
                .rd(pe_rd[i]),
            .address(pe_address[i]),
                .data_in(pe_data_to_cache[i]),
                .data_out(pe_data_from_cache[i]),
                .stall(pe_stall[i]),
                .help(cache_help[i]),
                .request_packet(cache_request_packet[i]),
                .ready_c(cache_ready_c[i]),
                .wb_valid(cache_wb_valid[i]),
                .cache_line_c(cache_line_to_ic[i]),
                .ready(ic_ready),
                .bus_inv(bus_inv),
                .bus_rd(bus_rd),
                .snoop_addr(snoop_addr),
                .resp_id(resp_id),
                .ic_tag(ic_tag),
                .ic_data(ic_data_bus),
                .current_state(),
                .current_tag(),
				.Counter_inv(count_inv[i]),
				.Time_stall(count_timer[i]),
               .Counter_misses(count_miss[i]),
					.Counter_reques(count_req[i])
					
            );
        end
    endgenerate


    Interconnect_MSI u_ic (
        .clk(clk),
        .reset(reset),
        .help(cache_help),
        .request_packet(cache_request_packet),
        .ready_c(cache_ready_c),
        .wb_valid(cache_wb_valid),
        .cache_line_c(cache_line_to_ic),
        .ic_ready(ic_ready),
        .bus_inv(bus_inv),
        .bus_rd(bus_rd),
        .resp_id(resp_id),
        .snoop_addr(snoop_addr),
        .ic_tag(ic_tag),
        .ic_cache_line(ic_data_bus),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_address(mem_address),
        .mem_data_in(mem_data_to_ram),
        .mem_data_out(mem_data_from_ram),
        .mem_ready(mem_ready)
    );


    Ram u_ram (
        .clk(clk),
        .reset(reset),
        .req(mem_req),
        .we(mem_we),
        .address(mem_address),
        .data_in(mem_data_to_ram),
        .data_out(mem_data_from_ram),
        .mem_ready(mem_ready) // Corregido: antes era .ready
    );

endmodule
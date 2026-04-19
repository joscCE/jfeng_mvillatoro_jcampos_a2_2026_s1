module Top (
	input logic clk,
	input logic reset,
	input logic protocol_sel	// El switch en la FPGA para selccionar el protocolo
);

	// Los caches con IC
	logic [3:0] help;		// los bits de "Auxilio, salvame IC" de los 4 caches
	logic [64:0] request_packet [3:0];
	
	// El broadcast del maleducado (IC)
	logic			 ic_bus_rd;
	logic			 ic_bus_inv;
	logic			 ic_ready;
	logic [19:0] ic_tag;
	logic [95:0] ic_cache_line;
	
	// IC a memoria principal
	logic			 ic_mem_we;
	logic [31:0] ic_mem_address;
	logic [95:0] ic_mem_data_in;
	
	// Memoria principal a IC
	logic [95:0] mem_data_out;
	logic			 mem_ready;
	
	// Aca va la comunicacion entre PEs y cache, creo que asi es segun lo que lei en el Lucid
	// PE a cache
	logic [3:0]  pe_req_type;
	logic [3:0]  pe_req_valid;
	logic [31:0] pe_addr [3:0];
	
	// Cache a PE
	logic [3:0] cache_done;
	
	// Instancias de los 4 caches, igual hay que ver cuando se cambie lo de arriba
	genvar i;
	generate
		for (i = 0; i < 4; i++) begin : cache_gen
			Cache cache_inst (
				.clk					(clk),
				.reset				(reset),
				.req_type			(pe_req_type[i]),
				.req_valid			(pe_req_valid[i]),
				.addr					(pe_addr[i]),
				.done					(cache_done[i]),
				.bus_rd				(ic_bus_rd),
				.bus_inv				(ic_bus_inv),
				.tag_in				(ic_tag),
				.cache_line_in 	(ic_cache_line),
				.ready				(ic_ready),
				.help					(help[i]),
				.request_packet	(request_packet[i])
			);
		end
	endgenerate
	
	// Instancia del IC
	Interconnect ic_inst(
		.clk					(clk),
		.reset				(reset),
		.protocol_sel		(protocolo_sel),
		.help					(help),
		.request_package	(request_package),
		.bus_rd				(ic_bus_rd),
		.bus_inv				(ic_bus_inv),
		.ready				(ic_ready),
		.tag					(ic_tag),
		.cache_line			(ic_cache_line),
		.mem_we				(ic_mem_we),
		.mem_address		(ic_mem_address),
		.mem_data_in		(ic_mem_data_in),
		.mem_data_out		(mem_data_out),
		.mem_ready			(mem_ready)
	);
	
	// Instancia de memoria principal
	Ram ram_inst (
		.clk			(clk),
		.reset		(reset),
		.we			(ic_mem_we),
		.address		(ic_mem_address),
		.data_in		(ic_mem_data_in),
		.data_out	(mem_data_out),
		.mem_ready	(mem_ready)
	);
	
endmodule

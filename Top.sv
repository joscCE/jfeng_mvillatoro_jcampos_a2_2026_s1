module Top;

	// =========================
	// Señales
	// =========================

	// Clk y rst
	logic clk;
	logic rst;
	
	// Pe -> Cache
	logic req_valid;
	logic req_type;
	logic [4:0] addr;
	logic [31:0] data;
	logic finished;
	
	// Cache -> PE 
	logic stall_cache;
	logic [31:0] data_cache;

	
	// Señales Cache y IC 
	logic ready;
	logic bus_inv;
	logic bus_rd;
	logic [1:0] ic_tag;
	logic [63:0] ic_data;

	logic [1:0] current_state;
	logic [1:0] current_tag;
	
	// =========================
	// Instancias PE
	// =========================
	PE #(.TRACE_MIF("trace1.mif")
	) pe1 (
		.clk(clk),
		.rst(rst),

		.stall_cache(stall_cache),
		.data_cache(data_cache),

		.req_valid(req_valid),
		.req_type(req_type),
		.addr(addr),
		.data(data),
		.finished(finished)
	);
 
	// =========================
	// Instancias Caches
	// =========================
	Cache cache1 (
		.clk(clk),
		.reset(rst),

		.we(req_valid && req_type),
		.rd(req_valid && !req_type),
		.address(addr),
		.data_in(data),
		.data_out(data_cache),
		.stall(stall_cache),

		.ready(ready),
		.bus_inv(bus_inv),
		.bus_rd(bus_rd),
		.ic_tag(ic_tag),
		.ic_data(ic_data),

		.current_state(current_state),
		.current_tag(current_tag)
	);
	
endmodule 
module Interconnect (
	input logic		clk,
	input logic 	reset,
	input logic		protocol_sel,
	
	// Desde cache
	input logic [3:0]  help,
	input logic [64:0] request_packet [3:0],
	
	// Broadcast
	output logic		  bus_rd,
	output logic		  bus_inv,
	output logic		  ic_ready,
	output logic [19:0] tag,
	output logic [95:0] cache_line,
	
	// A memoria principal
	output logic		  mem_we,
	output logic [31:0] mem_address,
	output logic [95:0] mem_data_in
	
	// Desde memoria principal
	input logic [95:0] mem_data_out,
	input logic			 mem_ready
);

	// Ciclos de espera luego de snoop para que cache tenga tiempo de cambiar
	parameter int SNOOP_WAIT_CYCLES = 4;
	
	// Estados de la maquina de estados (duh)
	typedef enum logic [2:0] {
		IDLE			= 3'b000,
		ARBITRATE	= 3'b001,
		DECODE		= 3'b010,
		SNOOP_ISSUE = 3'b011,
		WAIT_SNOOP  = 3'b100,
		MEM_ACCESS  = 3'b101,
		RESPOND		= 3'b110
	} state_t;
	
	state_t current_state, next_state;
	
	// -------------Registrosd internos
	
	// extraccion de request_packet
	logic 	 	 req_type;
	logic [31:0] req_address;
	logic [31:0] req_data;
	
	// arbitro RR
	logic [1:0] rr_ptr;	// elige proximo PE
	logic [1:0] winner;	// PE a atender
	
	// Contador para espera en WAIT_SNOOP
	logic [3:0] snoop_counter;
	
	// -------------Registros de estado
	
	always_ff @(posedge clk) begin
		if (reset)
			current_state <= IDLE;
		else
			current_state <= next_state;
	end
	
	// -------------Logica de cambios de estado
	
	always_comb begin
		next_state = current_state;	// valor por defecto
		
		case (current_state)
		
			IDLE: begin
				// Bullshit 1
			end
			
			ARBITRATE: begin
				// Bullshit 2
			end
			
			DECODE: begin
				// Bullshit 3
			end
			
			SNOOP_ISSUE: begin
				// Bullshit 4
			end
			
			WAIT_SNOOP: begin
				// Bullshit 5
			end
			
			MEM_ACCESS: begin
				// Bullshit 6
			end
			
			RESPOND: begin
				// Bullshit 7
			end
			
			default: next_state = IDLE;
		endcase
	end
	
	// -------------Logica de registros y salidas
	
	always_ff @(posedge clk) begin
		if (reset) begin
			// Limpiar salidas
			bus_rd		<= 1'b0;
			bus_inv		<= 1'b0;
			ic_ready		<= 1'b0;
			tag			<= 20'b0;
			cache_line	<= 96'b0;
			mem_we		<= 1'b0;
			mem_address <= 32'b0;
			mem_data_in <= 96'b0;
			// Limpiar registros internos
			req_type			<= 1'b0;
			req_address	 	<= 32'b0;
			req_data			<= 32'b0;
			rr_ptr			<= 2'b0;
			winner			<= 2'b0;
			snoop_counter	<= 4'b0;
		end else begin
			case (current_state)
				IDLE: begin
					// Memristores 1
				end
				
				ARBITRATE: begin
					// Memristores 2
				end
				
				DECODE: begin
					// Memristores 3
				end
				
				SNOOP_ISSUE: begin
					// Memristores 4
				end
				
				WAIT_SNOOP: begin
					// Memristores 5
				end
				
				MEM_ACCESS: begin
					// Memristores 6
				end
				
				RESPOND: begin
					// Memristores 7
				end
			endcase
		end
	end
	
endmodule

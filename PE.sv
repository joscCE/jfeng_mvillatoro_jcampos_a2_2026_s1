module PE #(
	parameter TRACE_MIF = "trace.mif"
)(
	input logic clk, rst,
	input logic ready,
	input logic stall_cache,
	input logic [31:0] data_cache,
	
	output logic req_valid,
	output logic req_type,
	output logic [4:0] addr,
	output logic [31:0] data,
	output logic finished
);

	// Estados
	typedef enum logic [2:0] {
		START,
		FETCH_INSTR,
      FETCH_WAIT,
		SEND_REQ,
		WAIT_DONE,
		END_STATE
	} state_t;
	
	state_t state;
	
	logic [7:0] pc;
	logic [37:0] rom_q;
	logic [37:0] instr;
	

	// ROM para hardware (altsyncram)
	altsyncram #(
		.operation_mode("ROM"),
		.width_a(38),
		.widthad_a(8),
		.numwords_a(256),
		.outdata_reg_a("UNREGISTERED"),
		.init_file(TRACE_MIF),
		.intended_device_family("Cyclone V")
	) trace_rom (
		.clock0(clk),
		.address_a(pc),
		.q_a(rom_q),
		.wren_a(),
		.data_a(),
		.rden_a(1'b1)
	);

	
	// FSM
	always_ff @(posedge clk or posedge rst) begin
		
		if (rst) begin
			state     <= START;
			pc        <= 8'd0;
			instr     <= 38'd0;
			req_valid <= 1'b0;
			req_type  <= 1'b0;
			addr      <= 5'd0;
			data      <= 32'd0;
			finished  <= 1'b0;
		end
		else begin
			case (state) 
				// Estado inicial
				START: begin
					pc        <= 8'd0;
					instr     <= 38'd0;
					req_valid <= 1'b0;
					req_type  <= 1'b0;
					addr      <= 5'd0;
					data      <= 32'd0;
					finished  <= 1'b0;
					state     <= FETCH_INSTR;
				end
				
				// Presentar dirección a la ROM
				FETCH_INSTR: begin
					req_valid <= 1'b0;
					state     <= FETCH_WAIT;
				end
				
				
				// Esperar dato de la ROM y guardarlo
				FETCH_WAIT: begin
					instr <= rom_q;

					if (rom_q == 38'h3F_DEADDDDD) begin
						state <= END_STATE;
					end
					else begin
						state <= SEND_REQ;
					end
				end

				// Enviar a cache
				SEND_REQ: begin
					req_valid <= 1'b1;
					req_type  <= instr[37];
					addr      <= instr[36:32];
					data      <= instr[31:0];
					
					// Quedarse en este estado si cache está  ocupado
					if (stall_cache) begin
						state <= SEND_REQ;
					end
					else begin
					// Cache acepta la operacion
						req_valid <= 1'b0;
						state     <= WAIT_DONE;
					end
				end
				
				// Esperar a dato del cache
				WAIT_DONE: begin
					// Mientras haya stall, seguir esperando
					if (stall_cache) begin
						state <= WAIT_DONE;
					end
					else begin
					// Operacion completada
					req_valid <= 1'b0;
						pc    <= pc + 8'd1;
						state <= FETCH_INSTR;
					end
				end
				
				// Final
				END_STATE: begin
					req_valid <= 1'b0;
					req_type  <= 1'b0;
					addr      <= 5'd0;
					data      <= 32'd0;
					finished  <= 1'b1;
					state     <= END_STATE;
				end
				
			endcase
		end
	end
	
endmodule		
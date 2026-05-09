module PE #(
	parameter TRACE_MIF = "trace1.mif"
)(
	input logic clk, rst,
	input logic stall_cache,
	input logic [31:0] data_cache,
	
	output logic req_valid,
	output logic rd, // Read Enable del procesador
	output logic we, // Write Enable del procesador
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
	state_t state_prev;
	
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
			state_prev<= START;
			pc        <= 8'd0;
			instr     <= 38'd0;
			rd	      <= 1'b0;
			we	      <= 1'b0;
			addr      <= 5'd0;
			data      <= 32'd0;
			finished  <= 1'b0;
		end
		else begin
			state_prev <= state;

			`ifdef PE_DEBUG
			if ((state != state_prev) ||
			    ((state == SEND_REQ) && (rd || we)) ||
			    ((state == WAIT_DONE) && (stall_cache === 1'b1))) begin
				$display("[PE][%s] t=%0t state=%0d pc=%0d instr=%h rd=%0b we=%0b addr=%0d stall_cache=%0b finished=%0b",
					TRACE_MIF, $time, state, pc, instr, rd, we, addr, stall_cache, finished);
			end
			`endif

			case (state) 
				// Estado inicial
				START: begin
					pc        <= 8'd0;
					instr     <= 38'd0;
					rd	      <= 1'b0;
					we	      <= 1'b0;
					addr      <= 5'd0;
					data      <= 32'd0;
					finished  <= 1'b0;
					state     <= FETCH_INSTR;
				end
				
				// Presentar dirección a la ROM
				FETCH_INSTR: begin
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
					addr      <= instr[36:32];
					data      <= instr[31:0];

					// Configurar señales de lectura/escritura
					if (instr[37] == 1'b0) begin // Lectura si bit 37 es 0
						rd <= 1'b1;
						we <= 1'b0;
					end else begin // Escritura si bit 37 es 1
						rd <= 1'b0;
						we <= 1'b1;
					end
					
					// Quedarse en este estado si cache está  ocupado
					if (!stall_cache) begin
						state <= SEND_REQ;
					end
					else begin
					// Cache acepta la operacion
						state     <= WAIT_DONE;
					end
				end
				
				// Esperar a dato del cache
				WAIT_DONE: begin
					// mantener request vivo
					addr <= addr;
					data <= data;
					rd   <= rd;
					we   <= we;
					
					// Cuando stall_cache=1 el cache ya ha aceptado la operacion,
					// por lo que podemos cerrar el request y avanzar PC.
					if (stall_cache) begin
						// limpiar request
						rd <= 1'b0;
						we <= 1'b0;
						pc <= pc + 8'd1;
						state <= FETCH_INSTR;
					end
				end
				
				// Final
				END_STATE: begin
					rd	      <= 1'b0;
					we	      <= 1'b0;
					addr      <= 5'd0;
					data      <= 32'd0;
					finished  <= 1'b1;
					state     <= END_STATE;
				end
				
			endcase
		end
	end
	
endmodule		
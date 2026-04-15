module PE #(
	parameter string TRACE_FILE = ""
)(
	input logic clk, rst,
	input logic done,
	
	output logic req_valid,
	output logic req_type,
	output logic [4:0] addr,
	output logic [31:0] data,
	output logic finished
);

	// Estados
	typedef enum logic [1:0] {
		START,
		SEND_REQ,
		WAIT_DONE,
		END_STATE
	} state_t;
	
	state_t state;
	
	// instrucciones
	logic [37:0] trace_mem [0:255];
	// linea
	int pc;
	
	// Abrir archivo de instrucciones
	initial begin
		$readmemh(TRACE_FILE, trace_mem);
	end
	
	// FSM
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			state     <= START;
			pc        <= 0;
			req_valid <= 0;
			req_type  <= 0;
			addr      <= 5'd0;
			data      <= 32'd0;
			finished  <= 0;
		end else begin
		
			case (state) 
				// Estado inicial
				START: begin
					req_valid <= 0;
               finished  <= 0;
               pc        <= 0;
               state     <= SEND_REQ;
            end
				// Enviar a cache
				SEND_REQ: begin
					// detectar fin
					if (trace_mem[pc][31:0] == 32'hDEADDDDD) begin
						state <= END_STATE;
					end else begin
						req_valid <= 1;
						req_type  <= trace_mem[pc][37];
						addr      <= trace_mem[pc][36:32];
						data      <= trace_mem[pc][31:0];
						state     <= WAIT_DONE;
					end
				end
				// Esperar a dato del cache
				WAIT_DONE: begin
					req_valid <= 0;
					
					if (done) begin
						pc    <= pc + 1;
						state <= SEND_REQ;
					end 
				end
				// Final
				END_STATE: begin
					   req_valid <= 0;
                  req_type  <= 0;
                  addr      <= 5'd0;
						data      <= 32'd0;
                  finished  <= 1;
				end
			endcase
		end
	end
	
endmodule		
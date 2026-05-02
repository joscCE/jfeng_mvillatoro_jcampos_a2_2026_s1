module Interconnect_FF #(
	parameter int SNOOP_WAIT_CYCLES = 4
)(
	input logic		clk,
	input logic 	reset,
	
	// Cache -> IC
	input logic [3:0]  help,
	input logic [37:0] request_packet [3:0],	// type 1 + address 5 + data 32
	
	// IC Broadcast
	output logic		  ic_ready,
	output logic		  bus_inv,		// no se usa en Firefly, se mantiene a 0
	output logic		  bus_rd,		// snoop broadcast (lecturas y writes-update)
	output logic [1:0]  ic_tag,
	output logic [63:0] ic_cache_line,	// dos bloques de 32 bits
	
	// IC -> memoria principal
	output logic		  mem_req,		// pulso de un ciclo, le indica a la RAM que arranque
	output logic		  mem_we,
	output logic [4:0]  mem_address,
	output logic [63:0] mem_data_in,
	
	// Desde memoria principal
	input logic [63:0] mem_data_out,
	input logic			 mem_ready
);

	// =============================================================
	// Interconnect_FF - protocolo Firefly (Write-Update).
	//
	// Lo mismo que Interconnect_MSI pero con cambio en SNOOP_ISSUE:
	//   - Lectura  (req_type=1): revisa bus_rd, igual que MSI.
	//   - Escritura(req_type=0): revisa bus_rd y publica el dato
	//     nuevo en ic_cache_line para que los caches remotos hagan
	//     write-update y permanezcan validos en estado Shared.
	//     bus_inv NUNCA se revisa en Firefly.


	// Estados
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
	
	// -------------Registros internos
	logic 	 	 req_type;
	logic [4:0]  req_address;
	logic [31:0] req_data;
	
	logic [1:0]  rr_ptr;
	logic [1:0]  winner;
	
	logic [3:0]  snoop_counter;
	
	// -------------Registro de estado
	always_ff @(posedge clk) begin
		if (reset)	current_state <= IDLE;
		else			current_state <= next_state;
	end
	
	// -------------Logica de proximo estado
	always_comb begin
		next_state = current_state;
		
		case (current_state)
		
			// Lo mismo que MSI: si llega cualquier request, salta a DECODE.
			// El winner se elige en IDLE usando rr_ptr para no depender de
			// que help siga asertado en ciclos posteriores.
			IDLE: begin
				if (help == 4'b0000)
					next_state = IDLE;
				else
					next_state = DECODE;
			end

			// Estado conservado por compatibilidad; no se entra aqui.
			ARBITRATE: begin
				next_state = DECODE;
			end
			
			DECODE: begin
				next_state = SNOOP_ISSUE;
			end
			
			SNOOP_ISSUE: begin
				next_state = WAIT_SNOOP;
			end

			WAIT_SNOOP: begin
				if (snoop_counter == SNOOP_WAIT_CYCLES - 1)
					next_state = MEM_ACCESS;
				else
					next_state = WAIT_SNOOP;
			end
	
			MEM_ACCESS: begin
				if (mem_ready)
					next_state = RESPOND;
				else
					next_state = MEM_ACCESS;
			end
	
			RESPOND: begin
				next_state = IDLE;
			end
			
			default: next_state = IDLE;
			
		endcase
	end
	
	// -------------Logica de registros y salidas
	always_ff @(posedge clk) begin
		if (reset) begin
			bus_rd			<= 1'b0;
			bus_inv			<= 1'b0;
			ic_ready		<= 1'b0;
			ic_tag			<= 2'b0;
			ic_cache_line	<= 64'b0;
			mem_req			<= 1'b0;
			mem_we			<= 1'b0;
			mem_address 	<= 5'b0;
			mem_data_in 	<= 64'b0;
			req_type		<= 1'b0;
			req_address	 	<= 5'b0;
			req_data		<= 32'b0;
			rr_ptr			<= 2'b0;
			winner			<= 2'b0;
			snoop_counter	<= 4'b0;
		end else begin
		
			// Limpieza por defecto de senales uniciclo
			bus_rd	<= 1'b0;
			bus_inv	<= 1'b0;	// en Firefly siempre permanece en 0
			ic_ready<= 1'b0;
			mem_req	<= 1'b0;
			mem_we	<= 1'b0;
		
			case (current_state)
			
				// ---------------------------------------
				// IDLE. Se elige winner con prioridad rr_ptr.
				// ---------------------------------------
				IDLE: begin
					snoop_counter <= 4'b0;
					if (help != 4'b0000) begin
						if      (help[rr_ptr])         winner <= rr_ptr;
						else if (help[rr_ptr + 2'd1])  winner <= rr_ptr + 2'd1;
						else if (help[rr_ptr + 2'd2])  winner <= rr_ptr + 2'd2;
						else                           winner <= rr_ptr + 2'd3;
					end
				end
				
				// ---------------------------------------
				// Camino legacy.
				// ---------------------------------------
				ARBITRATE: begin
					if      (help[rr_ptr])         winner <= rr_ptr;
					else if (help[rr_ptr + 2'd1])  winner <= rr_ptr + 2'd1;
					else if (help[rr_ptr + 2'd2])  winner <= rr_ptr + 2'd2;
					else                           winner <= rr_ptr + 2'd3;
				end

				// ---------------------------------------
				// DECODE: extrae los campos del paquete y avanza rr_ptr
				// ---------------------------------------
				DECODE: begin
					req_type    <= request_packet[winner][37];
					req_address <= request_packet[winner][36:32];
					req_data    <= request_packet[winner][31:0];
					rr_ptr      <= winner + 2'd1;
				end
				
				// ---------------------------------------
				// SNOOP_ISSUE - Firefly Write-Update
				// Lectura  (req_type=1)
				// Escritura(req_type=0)
				// ---------------------------------------
				SNOOP_ISSUE: begin
					bus_rd  <= 1'b1;
					bus_inv <= 1'b0;	// reafirmamos: Firefly nunca invalida
					if (req_type == 1'b0) begin
						// publicar dato nuevo a remotos para write-update
						ic_cache_line <= (req_address[0]) ?
											{req_data, 32'b0} :
											{32'b0, req_data};
						ic_tag <= req_address[4:3];
					end
					snoop_counter <= 4'b0;
				end

				// ---------------------------------------
				// WAIT_SNOOP - en el ultimo ciclo se le avisa a la RAM.
				// La RAM debe quedar coherente: en escritura tambien
				// le mandamos mem_we=1 para que actualice memoria
				// (write-update + write-through).
				// ---------------------------------------
				WAIT_SNOOP: begin
					snoop_counter <= snoop_counter + 4'd1;
					if (snoop_counter == SNOOP_WAIT_CYCLES - 1) begin
						mem_req     <= 1'b1;
						mem_address <= req_address;
						if (req_type == 1'b0) begin
							mem_we      <= 1'b1;
							mem_data_in <= (req_address[0]) ?
												{req_data, 32'b0} :
												{32'b0, req_data};
						end
					end
				end
				
				// ---------------------------------------
				// MEM_ACCESS - solo esperamos mem_ready
				// ---------------------------------------
				MEM_ACCESS: begin
					// nada
				end

				// ---------------------------------------
				// RESPOND - confirma fin de operacion al requestor
				// ---------------------------------------
				RESPOND: begin
					ic_ready		<= 1'b1;
					ic_tag			<= req_address[4:3];
					ic_cache_line	<= mem_data_out;
				end
				
			endcase
		end
	end
	
endmodule

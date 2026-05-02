module Interconnect_MSI #(
	parameter int SNOOP_WAIT_CYCLES = 4
)(
	input logic		clk,
	input logic 	reset,
	
	// Cache -> IC
	input logic [3:0]  help,
	input logic [37:0] request_packet [3:0],	// type 1 + address 5 + data 32
	
	// IC Broadcast
	output logic		  ic_ready,
	output logic		  bus_inv,		// Shared/Modified a Invalid
	output logic		  bus_rd,		// Modified a shared
	output logic [1:0]  ic_tag,
	output logic [63:0] ic_cache_line,	// Doa bloques 32
	
	// IC -> memoria principal
	output logic		  mem_req,		// pulso de un ciclo, le indica a la RAM que arranque
	output logic		  mem_we,
	output logic [4:0]  mem_address,
	output logic [63:0] mem_data_in,
	
	// Desde memoria principal
	input logic [63:0] mem_data_out,
	input logic			 mem_ready
);

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
	
	// -------------Registros internos
	
	// extraccion de request_packet
	logic 	 	 req_type;
	logic [4:0]  req_address;
	logic [31:0] req_data;
	
	// arbitro RR
	logic [1:0] rr_ptr;	// elige proximo PE
	logic [1:0] winner;	// PE a atender
	
	// Contador para espera en WAIT_SNOOP
	logic [3:0] snoop_counter;
	
	// -------------Registros de estado
	
	always_ff @(posedge clk) begin
		if (reset)	current_state <= IDLE;
		else			current_state <= next_state;
	end
	
	// -------------Logica de cambios de estado
	
	always_comb begin
		next_state = current_state;	// valor por defecto
		
		case (current_state)
		
			// Se recibe que un cache ocupa ser salvado.
			// El winner se decide en el mismo ciclo IDLE usando
			// rr_ptr como prioridad, asi no dependemos de que help
			// siga asertado en un ciclo posterior.
			IDLE: begin
				if (help == 4'b0000)
					next_state = IDLE;
				else
					next_state = DECODE;
			end

			// Estado conservado por compatibilidad; no se usa.
			ARBITRATE: begin
				next_state = DECODE;
			end
			
			// Decifra el request_package
			DECODE: begin
				next_state = SNOOP_ISSUE;
			end
			
			// IC emite el broadcast por el bus
			SNOOP_ISSUE: begin
				next_state = WAIT_SNOOP;
			end

			// IC espera que el cache termine
			WAIT_SNOOP: begin
				if (snoop_counter == SNOOP_WAIT_CYCLES - 1)
					next_state = MEM_ACCESS;
				else
					next_state = WAIT_SNOOP;
			end
	
			// Esperar que RAM confirme
			MEM_ACCESS: begin
				if (mem_ready)
					next_state = RESPOND;
				else
					next_state = MEM_ACCESS;
			end
	
			// Responde el final de operacion y vuelve a IDLE
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
			ic_ready			<= 1'b0;
			ic_tag				<= 2'b0;
			ic_cache_line		<= 64'b0;
			mem_req			<= 1'b0;
			mem_we			<= 1'b0;
			mem_address 	<= 5'b0;
			mem_data_in 	<= 64'b0;
			req_type			<= 1'b0;
			req_address	 	<= 5'b0;
			req_data			<= 32'b0;
			rr_ptr			<= 2'b0;
			winner			<= 2'b0;
			snoop_counter	<= 4'b0;
		end else begin
		
			// Limpia senales uniciclo para que no queden pegadas
			bus_rd	<= 1'b0;
			bus_inv	<= 1'b0;
			ic_ready	<= 1'b0;
			mem_req	<= 1'b0;
			mem_we	<= 1'b0;
		
			case (current_state)
			
				// ---------------------------------------
				// Nada activo
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
				// RR para elegir proximo PE a atender
				// ---------------------------------------
				ARBITRATE: begin
					if			(help[rr_ptr])				winner <= rr_ptr;
					else if	(help[rr_ptr + 2'd1])	winner <= rr_ptr + 2'd1;
					else if	(help[rr_ptr + 2'd2])	winner <= rr_ptr + 2'd2;
					else										winner <= rr_ptr + 2'd3;
				end

				// ---------------------------------------
				// Si solo hay un PE pidiendo ayuda se empieza aqui
				// ---------------------------------------
				DECODE: begin
					req_type    <= request_packet[winner][37];
					req_address <= request_packet[winner][36:32];
					req_data    <= request_packet[winner][31:0];
					// Avanza el puntero RR para no atender al mismo PE dos veces seguidas
					rr_ptr      <= winner + 2'd1;
				end
				
				// ---------------------------------------
				// MSI
				// req_type = 0 escritura
				// req_type = 1 lectura
				// ---------------------------------------
				SNOOP_ISSUE: begin
					if (req_type == 1'b0)
						bus_inv <= 1'b1;	// Invalidar cache remoto por escritura
					else
						bus_rd <= 1'b1;	// Lectura que pasa de M a S
						
					snoop_counter <= 4'b0;	// Contador reset
				end

				// ---------------------------------------
				// Esperar que los caches remotos terminen.
				// En el ultimo ciclo se le avisa a RAM:
				//   mem_req es uniciclo (limpiado al inicio del bloque),
				//   mem_address y mem_data_in son registros que la RAM
				//   muestrea junto con mem_req.
				// ---------------------------------------
				WAIT_SNOOP: begin
					snoop_counter <= snoop_counter + 4'd1;
					if (snoop_counter == SNOOP_WAIT_CYCLES - 1) begin
						mem_req     <= 1'b1;
						mem_address <= req_address;
						if (req_type == 1'b0) begin
							// Escritura: mandar dato a RAM
							mem_we      <= 1'b1;
							mem_data_in <= (req_address[0]) ?
												{req_data, 32'b0} :  // offset=1 bloque alto
												{32'b0, req_data};   // offset=0 bloque bajo
						end
					end
				end
				
				// ---------------------------------------
				// Acceder a memoria principal:
				// solo esperamos el handshake mem_ready de la RAM.
				// ---------------------------------------
				MEM_ACCESS: begin
					// nada: mem_req ya fue emitido en el ultimo ciclo de WAIT_SNOOP
				end

				// ---------------------------------------
				//
				// ---------------------------------------
				RESPOND: begin
					// Activa bus y manda tag y linea de cache a cache
					ic_ready		<= 1'b1;
					ic_tag			<= req_address[4:3];
					ic_cache_line	<= mem_data_out;
				end
				
			endcase
		end
	end
	
endmodule

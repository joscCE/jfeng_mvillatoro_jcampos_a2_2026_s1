module Interconnect_MSI #(
	parameter int SNOOP_WAIT_CYCLES = 4
)(
	input logic		clk,		// Reloj del sistema
	input logic 	reset,		// PE -> cache (4 PEs)
	
	// Cache -> IC
	input logic [3:0]  help,					// Cada bit indica que el cache respectivo necesita ayuda
	input logic [37:0] request_packet [3:0],	// type 1 + address 5 + data 32
	input logic [3:0]  ready_c,					// Cada bit indica que el cache respectivo ya proceso snoop
	input logic [3:0]  wb_valid,				// Cada bit indica que el cache respectivo tiene una linea valida para wb
	input logic [63:0] cache_line_c [3:0],		// Linea que el cache respectivo devuelve para wb (2 palabras de 32)
	
	// IC Broadcast
	output logic		ic_ready,		// IC responde a cache que hizo request
	output logic		bus_inv,		// Shared/Modified a Invalid
	output logic		bus_rd,			// Modified a shared
	output logic [1:0]  resp_id,		// ID del cache al que se le responde (read miss)
	output logic [4:0]  snoop_addr,		// Direccion que se esta snoopeando (read miss o write miss)
	output logic [1:0]  ic_tag,			// Tag que se esta enviando en el bus (read miss o write miss)
	output logic [63:0] ic_cache_line,	// Dos bloques 32
	
	// IC -> memoria principal
	output logic		  mem_req,		// indica al RAM que arranque
	output logic		  mem_we,		// 1 para write, 0 para read
	output logic [4:0]  mem_address,	// direccion de la linea a acceder en RAM
	output logic [63:0] mem_data_in,	// datos a escribir en RAM (en caso de write)
	
	// Desde memoria principal
	input logic [63:0]		mem_data_out,	// datos leidos desde RAM (en caso de read)
	input logic				mem_ready		// RAM indica que esta listo
);

	// Estados de la maquina de estados
	typedef enum logic [2:0] {
		IDLE		= 3'b000,		// Sin actividad
		DECODE		= 3'b001,		// Se decodifica el request_packet
		SNOOP_ISSUE = 3'b010,		// Se emite el snoop por el bus
		WAIT_SNOOP  = 3'b011,		// Espera que los caches respondan a snoop
		MEM_ACCESS  = 3'b100,		// Espera a que RAM confirme la operacion
		RESPOND		= 3'b101		// Responde al cache que hizo el request y vuelve a IDLE
	} state_t;
	
	state_t current_state, next_state;
	
	// -------------Registros internos
	// extraccion de request_packet
	logic 	 	 req_type;
	logic [4:0]  req_address;
	logic [63:0] owner_line;
	logic        owner_found;
	logic        mem_cmd_issued;
	logic        use_owner_line_in_respond;
	
	// arbitro RR
	logic [1:0] rr_ptr;	// elige proximo PE
	logic [1:0] winner;	// PE a atender

	// Helper: todos los caches ya procesaron snoop
	logic all_ready_c;
	assign all_ready_c = &ready_c;
	
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
			IDLE: begin
				if (help == 4'b0000)
					next_state = IDLE;
				else
					next_state = DECODE;
			end
			
			// Decifra el request_packet
			DECODE: begin
				next_state = SNOOP_ISSUE;
			end
			
			// IC emite el broadcast por el bus
			SNOOP_ISSUE: begin
				next_state = WAIT_SNOOP;
			end

			// Espera handshake real de caches (sin timer bandaid)
			WAIT_SNOOP: begin
				if (all_ready_c)
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
			resp_id			<= 2'b0;
			snoop_addr		<= 5'b0;
			ic_tag				<= 2'b0;
			ic_cache_line		<= 64'b0;
			mem_req			<= 1'b0;
			mem_we			<= 1'b0;
			mem_address 	<= 5'b0;
			mem_data_in 	<= 64'b0;
			req_type			<= 1'b0;
			req_address	 	<= 5'b0;
			owner_line		<= 64'b0;
			owner_found		<= 1'b0;
			mem_cmd_issued	<= 1'b0;
			use_owner_line_in_respond <= 1'b0;
			rr_ptr			<= 2'b0;
			winner			<= 2'b0;
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
					owner_found <= 1'b0;
					owner_line  <= 64'b0;
					mem_cmd_issued <= 1'b0;
					use_owner_line_in_respond <= 1'b0;
					if (help != 4'b0000) begin
						if      (help[rr_ptr])         winner <= rr_ptr;
						else if (help[rr_ptr + 2'd1])  winner <= rr_ptr + 2'd1;
						else if (help[rr_ptr + 2'd2])  winner <= rr_ptr + 2'd2;
						else                           winner <= rr_ptr + 2'd3;
					end
				end
				
				// ---------------------------------------
				// Si solo hay un PE pidiendo ayuda se empieza aqui
				// ---------------------------------------
				DECODE: begin
					req_type    <= request_packet[winner][37];
					req_address <= request_packet[winner][36:32];
					resp_id     <= winner;
					// Avanza el puntero RR para no atender al mismo PE dos veces seguidas
					rr_ptr      <= winner + 2'd1;
					snoop_addr  <= request_packet[winner][36:32];
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

					// Asegura que snoop_addr este estable en el ciclo de broadcast
					snoop_addr <= req_address;
				end

				// ---------------------------------------
				// Espera de snoop por handshake de caches.
				// Si algun cache retorna wb_valid, capturamos owner_line.
				// ---------------------------------------
				WAIT_SNOOP: begin
					if (wb_valid != 4'b0000) begin
						if      (wb_valid[0]) begin owner_found <= 1'b1; owner_line <= cache_line_c[0]; end
						else if (wb_valid[1]) begin owner_found <= 1'b1; owner_line <= cache_line_c[1]; end
						else if (wb_valid[2]) begin owner_found <= 1'b1; owner_line <= cache_line_c[2]; end
						else                  begin owner_found <= 1'b1; owner_line <= cache_line_c[3]; end
					end
				end
				
				// ---------------------------------------
				// Acceder a RAM.
				// - Read miss sin owner -> lectura RAM.
				// - Read/Write miss con owner M -> writeback de owner_line.
				// - Write miss sin owner -> solo lectura de linea RAM.
				// ---------------------------------------
				MEM_ACCESS: begin
					if (!mem_cmd_issued) begin
						mem_req     <= 1'b1;
						mem_address <= req_address;

						if (owner_found) begin
							// Hubo linea sucia en un remoto: writeback obligatorio
							mem_we      <= 1'b1;
							mem_data_in <= owner_line;
							use_owner_line_in_respond <= 1'b1;
						end else begin
							// Sin owner, pedimos linea RAM (read)
							mem_we <= 1'b0;
							use_owner_line_in_respond <= 1'b0;
						end

						mem_cmd_issued <= 1'b1;
					end
				end

				// ---------------------------------------
				// RESPOND al requestor
				// ---------------------------------------
				RESPOND: begin
					ic_ready		<= 1'b1;
					ic_tag			<= req_address[4:3];
					if (use_owner_line_in_respond)
						ic_cache_line <= owner_line;
					else
						ic_cache_line <= mem_data_out;

					mem_cmd_issued <= 1'b0;
				end
				
			endcase
		end
	end
	
endmodule

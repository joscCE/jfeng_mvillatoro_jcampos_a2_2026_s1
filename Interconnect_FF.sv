module Interconnect_FF #(
	parameter int SNOOP_WAIT_CYCLES = 4
)(
	input logic		clk,
	input logic 	reset,
	
	// Cache -> IC
	input logic [3:0]  help,					// Una línea de cada cache puede solicitar acceso al bus cada ciclo
	input logic [37:0] request_packet [3:0],	// type 1 + address 5 + data 32
	input logic [3:0]  ready_c,
	
	// IC Broadcast
	output logic		  ic_ready,
	output logic		  bus_inv,		// no se usa en Firefly, se mantiene a 0
	output logic		  bus_rd,		// snoop broadcast para lecturas y seguimiento remoto
	output logic      bus_update,		// write-update para escritura remota
	output logic [1:0]  resp_id,		// ID del cache al que se responde
	output logic [4:0]  snoop_addr,		// dirección de snoop para que los caches receptores comparen líneas
	output logic [1:0]  ic_tag,			// tag de dirección de acceso para que el cache receptor actualice estado
	output logic [63:0] ic_cache_line,	// dos bloques de 32 bits
	
	// IC -> memoria principal
	output logic		  mem_req,		// pulso de un ciclo, le indica a la RAM que arranque
	output logic		  mem_we,		// 1 para write, 0 para read
	output logic [4:0]  mem_address,	// dirección de la línea a acceder en RAM
	output logic [63:0] mem_data_in,	// datos a escribir en RAM (en caso de write)
	
	// Desde memoria principal
	input logic [63:0] mem_data_out,	// datos leidos desde RAM (en caso de read)
	input logic			 mem_ready		// RAM indica que esta listo
);

	// Estados
	typedef enum logic [2:0] {
		IDLE			= 3'b000,
		DECODE		= 3'b001,
		SNOOP_ISSUE = 3'b010,
		WAIT_SNOOP  = 3'b011,
		MEM_ACCESS  = 3'b100,
		RESPOND		= 3'b101
	} state_t;
	
	state_t current_state, next_state;
	
	// -------------Registros internos
	logic 	 	 req_type;			// 0 para write, 1 para read
	logic [4:0]  req_address;		// en write, se necesita enviar el dato en el bus, por lo que se extrae del request_packet
	logic [31:0] req_data;			// en write, se necesita enviar el dato en el bus, por lo que se extrae del request_packet
	logic        mem_cmd_issued;	// si ya se emitió el comando a RAM para evitar repetirlo durante MEM_ACCESS
	
	logic [1:0]  rr_ptr;			// puntero para round-robin entre los caches que solicitan ayuda
	logic [1:0]  winner;			// cache elegido para atender su request (en caso de múltiples solicitudes simultáneas)
	logic all_ready_c;				// helper para saber si todos los caches ya respondieron a snoop
	assign all_ready_c = &ready_c;	// si todos los bits de ready_c son 1, entonces all_ready_c es 1
	
	// -------------Registro de estado
	always_ff @(posedge clk) begin
		if (reset)	current_state <= IDLE;
		else			current_state <= next_state;
	end
	
	// -------------Logica de proximo estado
	always_comb begin
		next_state = current_state;
		
		case (current_state)
		
			IDLE: begin
				if (help == 4'b0000)
					next_state = IDLE;
				else
					next_state = DECODE;
			end
			
			DECODE: begin
				next_state = SNOOP_ISSUE;
			end
			
			SNOOP_ISSUE: begin
				next_state = WAIT_SNOOP;
			end

			WAIT_SNOOP: begin
				if (all_ready_c)
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
			bus_update	<= 1'b0;
			ic_ready		<= 1'b0;
			resp_id			<= 2'b0;
			snoop_addr	<= 5'b0;
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
			mem_cmd_issued <= 1'b0;
		end else begin
		
			// Limpieza por defecto de senales uniciclo
			bus_rd	<= 1'b0;
			bus_inv	<= 1'b0;	// en Firefly siempre permanece en 0
			bus_update <= 1'b0;
			ic_ready<= 1'b0;
			mem_req	<= 1'b0;
			mem_we	<= 1'b0;
		
			case (current_state)
			
				// ---------------------------------------
				// IDLE. Se elige winner con prioridad rr_ptr.
				// ---------------------------------------
				IDLE: begin
					mem_cmd_issued <= 1'b0;
					if (help != 4'b0000) begin
						if      (help[rr_ptr])         winner <= rr_ptr;
						else if (help[rr_ptr + 2'd1])  winner <= rr_ptr + 2'd1;
						else if (help[rr_ptr + 2'd2])  winner <= rr_ptr + 2'd2;
						else                           winner <= rr_ptr + 2'd3;
					end
				end
				
				// ---------------------------------------
				// DECODE: extrae los campos del paquete y avanza rr_ptr
				// ---------------------------------------
				DECODE: begin
					req_type    <= request_packet[winner][37];
					req_address <= request_packet[winner][36:32];
					req_data    <= request_packet[winner][31:0];
					resp_id     <= winner;
					snoop_addr  <= request_packet[winner][36:32];
					rr_ptr      <= winner + 2'd1;
				end
				
				// ---------------------------------------
				// SNOOP_ISSUE - Firefly Write-Update
				// Read:  bus_rd
				// Write: bus_rd + bus_update
				// ---------------------------------------
				SNOOP_ISSUE: begin
					bus_rd <= 1'b1;
					bus_inv <= 1'b0;
					snoop_addr <= req_address;
					if (req_type == 1'b0) begin
						bus_update <= 1'b1;
						ic_cache_line <= (req_address[0]) ?
											{req_data, 32'b0} :
											{32'b0, req_data};
					end
					ic_tag <= req_address[4:3];
				end

				// ---------------------------------------
				// Espera de snoop por handshake real de caches.
				// ---------------------------------------
				WAIT_SNOOP: begin
					// nada, solo espera all_ready_c
				end
				
				// ---------------------------------------
				// MEM_ACCESS - emitir un solo comando RAM y esperar mem_ready
				// ---------------------------------------
				MEM_ACCESS: begin
					if (!mem_cmd_issued) begin
						mem_req     <= 1'b1;
						mem_address <= req_address;
						if (req_type == 1'b0) begin
							mem_we      <= 1'b1;
							mem_data_in <= (req_address[0]) ?
												{req_data, 32'b0} :
												{32'b0, req_data};
						end else begin
							mem_we <= 1'b0;
						end
						mem_cmd_issued <= 1'b1;
					end
				end

				// ---------------------------------------
				// RESPOND - confirma fin de operacion al requestor
				// ---------------------------------------
				RESPOND: begin
					ic_ready		<= 1'b1;
					ic_tag			<= req_address[4:3];
					if (req_type == 1'b0)
						ic_cache_line <= (req_address[0]) ?
											{req_data, 32'b0} :
											{32'b0, req_data};
					else
						ic_cache_line <= mem_data_out;
					mem_cmd_issued <= 1'b0;
				end
				
			endcase
		end
	end
	
endmodule

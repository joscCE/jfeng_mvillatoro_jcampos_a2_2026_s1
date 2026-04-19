
module Ram (
	input  logic		  clk,
	input  logic		  reset,
	input  logic		  we,				// write enable
	input  logic [31:0] address,		// Direcciond de memoria
	input  logic [95:0] data_in,		// Datos para escribir
	output logic [95:0] data_out,		// Datos para leer
	output logic		  mem_ready,	// para que el IC sepa que mem esta lista
);

	// Arreglo de memoria
	// 1024 entradas para el indice de cache 10 
	// Entradas de 96 bits para almacenar lineas completas de cache
	logic [95:0] memory [0:1023];
	
	always_ff @(posedge clk) begin
		
		// Reset para limpiar salidas
		if (reset) begin
			mem_ready <= 1'b0;
			data_out <= 96'b0;
			
		end else begin
		
			if (we) begin
				
				// Escritura completa de los 96 bits
				memory[address[11:2]] <= data in;
				data_out <= 96'b0;
				mem_ready <= 1'b1;
				
			end else begin
				
				// Lectura completa de 96 bits (IMPORTANTE: DURA UN CICLO EN ESTAR LISTO)
				data_out <= memory[address[11:2]];
				mem_ready <= 1'b1;
			
			end
			
		end
		
	end
	
endmodule

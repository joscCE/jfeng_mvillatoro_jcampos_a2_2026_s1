`timescale 1ns/1ps

module pe_cache_local_tb;

    logic clk, rst;

    // Señales IC -> Cache
    logic        ic_ready;
    logic        ic_bus_inv;
    logic        ic_bus_rd;
    logic [1:0]  ic_tag;
    logic [63:0] ic_data;

    // Señales de monitoreo
    logic [1:0] cache_state;
    logic [1:0] cache_tag;
    logic       finished;

    // DUT
    pe_cache_local #(
        .TRACE_MIF("trace.mif")
    ) dut (
        .clk(clk),
        .rst(rst),
        .ic_ready(ic_ready),
        .ic_bus_inv(ic_bus_inv),
        .ic_bus_rd(ic_bus_rd),
        .ic_tag(ic_tag),
        .ic_data(ic_data),
        .cache_state(cache_state),
        .cache_tag(cache_tag),
        .finished(finished)
    );

    // Clock = 10ns
    always #5 clk = ~clk;

    //--------------------------------------------
    //  TASK: Respuesta sincrónica del IC en un MISS
    //--------------------------------------------
		task automatic ic_respond(input logic [4:0] addr);
		begin
			 ic_tag  = addr[4:3];
			 ic_data = {32'hAAAA0000 | addr, 32'hBBBB0000 | addr};
			 $display("   [IC] Respuesta MISS addr=%0d tag=%b (ciclo %0t)",
						 addr, ic_tag, $time);

			 // ← Sin @(posedge clk) previo: activa ready ahora mismo
			 ic_ready = 1;
			 @(posedge clk); // ready válido por 1 ciclo completo
			 ic_ready = 0;
		end
		endtask
		
		
		function string msi_name(input logic [1:0] state);
			 case (state)
				  2'b00: return "INVALID";
				  2'b01: return "SHARED";
				  2'b10: return "MODIFIED";
				  default: return "UNKNOWN";
			 endcase
		endfunction


    //--------------------------------------------
    //   SECUENCIA PRINCIPAL
    //--------------------------------------------
    initial begin
        clk = 0;
        rst = 1;

        ic_ready   = 0;
        ic_bus_inv = 0;
        ic_bus_rd  = 0;

        //----------------------------------------
        //   RESET
        //----------------------------------------
        repeat (3) @(posedge clk);
        rst = 0;

        $display("\n==== SIMULACIÓN PE + CACHE + MSI ====\n");

        //----------------------------------------
        //   BUCLE PRINCIPAL
        //----------------------------------------

			while (!finished) begin
				 @(posedge clk);
				 #1; // ← agrega esto: deja que la lógica combinacional se resuelva

				 if (dut.pe_rd || dut.pe_we) begin
					  $display("[PE] op=%s addr=%0d | stall=%b | state=%b tag=%b (time %0t)",
							dut.pe_we ? "WRITE" : " READ",
							dut.pe_addr, dut.stall,
							msi_name(cache_state), cache_tag, $time);

					  // Solo responde si stall es REAL en este delta
					  if (dut.stall && !ic_ready)
							ic_respond(dut.pe_addr);
				 end
			end
		  
		  

        //----------------------------------------
        //  FIN
        //----------------------------------------
        $display("\n==== PE TERMINÓ LA TRAZA ====\n");

        repeat (5) @(posedge clk);
        $finish;
    end


endmodule 
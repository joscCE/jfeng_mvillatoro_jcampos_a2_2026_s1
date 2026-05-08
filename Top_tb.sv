`timescale 1ns / 1ps

module Top_tb();

    // Parámetros de simulación
    logic clk;
    logic reset;

    // Instancia del módulo Top
    Top dut (
        .clk50(clk),
        .reset(reset)
    );

    // Generación de Reloj (100MHz aprox)
    always #5 clk = ~clk;

    // ---- Monitor del estado del Interconnect MSI ----
    // Imprime cada cambio de estado de la FSM del IC
    string ic_state_name;
    logic [2:0] prev_state;
    logic [3:0] prev_help;
    logic prev_bus_inv;
    
    // Contadores de requests por PE
    integer count_requests[3:0];
    logic [3:0] prev_rw;  // Track previous rd|we per PE

    function string msi_state_to_str(input logic [2:0] st);
        case (st)
            3'b000: msi_state_to_str = "IDLE";
            3'b001: msi_state_to_str = "SNOOP_ISSUE";
            3'b010: msi_state_to_str = "WAIT_SNOOP";
            3'b011: msi_state_to_str = "MEM_ACCESS";
            3'b100: msi_state_to_str = "RESPOND";
            default: msi_state_to_str = "UNKNOWN";
        endcase
    endfunction

    always_comb begin
        case (dut.u_ic.current_state)
            3'b000: ic_state_name = "IDLE";
            3'b001: ic_state_name = "SNOOP_ISSUE";
            3'b010: ic_state_name = "WAIT_SNOOP";
            3'b011: ic_state_name = "MEM_ACCESS";
            3'b100: ic_state_name = "RESPOND";
            default: ic_state_name = "UNKNOWN";
        endcase
    end

    always @(posedge clk) begin
        if (!reset) begin
            // Count rising edges of (rd | we) for each PE
            if ((dut.u_pe0.rd | dut.u_pe0.we) && !prev_rw[0]) count_requests[0]++;
            if ((dut.u_pe1.rd | dut.u_pe1.we) && !prev_rw[1]) count_requests[1]++;
            if ((dut.u_pe2.rd | dut.u_pe2.we) && !prev_rw[2]) count_requests[2]++;
            if ((dut.u_pe3.rd | dut.u_pe3.we) && !prev_rw[3]) count_requests[3]++;
        
            prev_rw[0] <= (dut.u_pe0.rd | dut.u_pe0.we);
            prev_rw[1] <= (dut.u_pe1.rd | dut.u_pe1.we);
            prev_rw[2] <= (dut.u_pe2.rd | dut.u_pe2.we);
            prev_rw[3] <= (dut.u_pe3.rd | dut.u_pe3.we);

            prev_state <= dut.u_ic.current_state;
            prev_help <= dut.cache_help;
            prev_bus_inv <= dut.bus_inv;
        end else begin
            prev_state <= dut.u_ic.current_state;
            prev_help <= dut.cache_help;
            prev_bus_inv <= dut.bus_inv;
        end
    end

    // Proceso de prueba
    initial begin
        // Inicialización de señales
        clk = 0;
        reset = 1;
        
        // Inicializar contadores
        for (int i = 0; i < 4; i++) begin
            count_requests[i] = 0;
            prev_rw[i] = 1'b0;
        end

        // Reset del sistema
        $display("--- Iniciando Simulación del Sistema Multi-Core MSI ---");
        #20;
        reset = 0;
        $display("--- Reset liberado, ejecutando trazas ---");

        // Esperar a que los PE terminen o un tiempo prudencial
        #100000; 

        // Mostrar reporte de estadísticas por cada Cache
        $display("\n========================================================");
        $display("         REPORTE DE RENDIMIENTO (HARDWARE COUNTERS)      ");
        $display("========================================================");
        
        for (int i = 0; i < 4; i++) begin
            $display("CORE %0d:", i);
            $display("  > Requests emitidos (count_requests):     %0d", count_requests[i]);
            $display("  > Invalidaciones recibidas (count_inv):   %0d", dut.count_inv[i]);
            $display("  > Ciclos totales en STALL (count_timer):  %0d", dut.count_timer[i]);
            $display("--------------------------------------------------------");
        end
        
        $display("\nTotales MSI (trace0-3):");
        $display("  Total Requests: %0d (esperado: 15)", 
            count_requests[0] + count_requests[1] + count_requests[2] + count_requests[3]);
        
        $display("\nSimulación finalizada a las %0t", $time);
        $finish;
    end

endmodule 
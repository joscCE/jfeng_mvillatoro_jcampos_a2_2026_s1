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

    // Generación de reloj (100 MHz aprox)
    always #5 clk = ~clk;

    // ---- Monitor del estado del Interconnect MSI ----
    string ic_state_name;
    logic [2:0] prev_state;
    logic [3:0] prev_help;
    logic prev_bus_inv;

    // Variables para estadísticas
    real miss_rate [3:0];
    real pseudo_ipc [3:0];

    real global_miss_rate;
    real bandwidth_bits;
    real bandwidth_bytes;

    longint total_req;
    longint total_miss;
    longint total_stall;

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
            prev_state   <= dut.u_ic.current_state;
            prev_help    <= dut.cache_help;
            prev_bus_inv <= dut.bus_inv;
        end
        else begin
            prev_state   <= dut.u_ic.current_state;
            prev_help    <= dut.cache_help;
            prev_bus_inv <= dut.bus_inv;
        end
    end


    //--------------------------------------------------
    // Proceso principal de prueba
    //--------------------------------------------------
    initial begin

        clk   = 0;
        reset = 1;

        total_req   = 0;
        total_miss  = 0;
        total_stall = 0;

        $display("--- Iniciando Simulación del Sistema Multi-Core MSI ---");

        #20;
        reset = 0;

        $display("--- Reset liberado, ejecutando trazas ---");

        // Esperar ejecución
        #100000;


        //--------------------------------------------------
        // Acumular estadísticas globales
        //--------------------------------------------------
        for (int i = 0; i < 4; i++) begin
            total_req   += dut.Count_req[i];
            total_miss  += dut.count_misses[i];
            total_stall += dut.count_timer[i];
        end


        //--------------------------------------------------
        // Reporte individual por core
        //--------------------------------------------------
        $display("\n========================================================");
        $display("         REPORTE DE RENDIMIENTO (HARDWARE COUNTERS)");
        $display("========================================================");

        for (int i = 0; i < 4; i++) begin

            // Miss Rate = misses / requests
            miss_rate[i] =
                (dut.Count_req[i] != 0) ?
                real'(dut.count_misses[i]) /
                real'(dut.Count_req[i]) :
                0.0;

            // Pseudo IPC = requests / stall
            pseudo_ipc[i] =
                (dut.count_timer[i] != 0) ?
                real'(dut.Count_req[i]) /
                real'(dut.count_timer[i]) :
                0.0;

            $display("CORE %0d:", i);

            $display("  > Invalidaciones recibidas:      %0d",
                     dut.count_inv[i]);

            $display("  > Ciclos totales en STALL:       %0d",
                     dut.count_timer[i]);

            $display("  > Cantidad de Misses:            %0d",
                     dut.count_misses[i]);

            $display("  > Cantidad de Requests:          %0d",
                     dut.Count_req[i]);

            $display("  > Miss Rate:                     %.4f",
                     miss_rate[i]);

            $display("  > IPC estimado (Req/Stall):      %.4f",
                     pseudo_ipc[i]);

            $display("--------------------------------------------------------");
        end


        //--------------------------------------------------
        // Estadísticas globales
        //--------------------------------------------------
        global_miss_rate =
            (total_req != 0) ?
            real'(total_miss) / real'(total_req) :
            0.0;

        // Bandwidth en bits/cycle
        bandwidth_bits =
            (total_stall != 0) ?
            real'(total_miss * 64) /
            real'(total_stall) :
            0.0;

        // Bandwidth en bytes/cycle
        bandwidth_bytes =
            (total_stall != 0) ?
            real'(total_miss * 8) /
            real'(total_stall) :
            0.0;


        $display("\n================ ESTADISTICAS GLOBALES =================");

        $display("Total Requests:                    %0d",
                 total_req);

        $display("Total Misses:                      %0d",
                 total_miss);

        $display("Total Stall Cycles:                %0d",
                 total_stall);

        $display("Global Miss Rate:                  %.4f",
                 global_miss_rate);

        $display("Bandwidth efectivo:                %.4f bits/cycle",
                 bandwidth_bits);

        $display("Bandwidth efectivo:                %.4f bytes/cycle",
                 bandwidth_bytes);

        $display("========================================================");


        $display("\nSimulación finalizada a las %0t", $time);
        $finish;
    end

endmodule
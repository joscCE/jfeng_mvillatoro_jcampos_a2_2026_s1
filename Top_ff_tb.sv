`timescale 1ns / 1ps

module Top_ff_tb();

    //--------------------------------------------------
    // Parámetros de simulación
    //--------------------------------------------------
    logic clk;
    logic reset;

    //--------------------------------------------------
    // Instancia del DUT
    //--------------------------------------------------
    Top_ff dut (
        .clk50(clk),
        .reset(reset)
    );

    //--------------------------------------------------
    // Generación de reloj
    //--------------------------------------------------
    // 100 MHz aprox
    always #5 clk = ~clk;

    //--------------------------------------------------
    // Monitor del estado del Interconnect Firefly
    //--------------------------------------------------
    string ic_state_name;

    logic [2:0] prev_state;
    logic [3:0] prev_help;
    logic       prev_bus_update;

    //--------------------------------------------------
    // Variables para estadísticas
    //--------------------------------------------------
    real miss_rate [3:0];
    real pseudo_ipc [3:0];

    real global_miss_rate;

    // Bandwidth Misses
    real bandwidth_miss_bits;
    real bandwidth_miss_bytes;

    // Bandwidth Updates
    real bandwidth_update_bits;
    real bandwidth_update_bytes;

    // Bandwidth Total
    real bandwidth_total_bits;
    real bandwidth_total_bytes;

    //--------------------------------------------------
    // Contadores globales
    //--------------------------------------------------
    longint total_req;
    longint total_miss;
    longint total_stall;
    longint total_update;

    //--------------------------------------------------
    // Conversión de estados a string
    //--------------------------------------------------
    function string ff_state_to_str(input logic [2:0] st);
        case (st)
            3'b000: ff_state_to_str = "IDLE";
            3'b001: ff_state_to_str = "SNOOP_ISSUE";
            3'b010: ff_state_to_str = "WAIT_SNOOP";
            3'b011: ff_state_to_str = "MEM_ACCESS";
            3'b100: ff_state_to_str = "RESPOND";
            default: ff_state_to_str = "UNKNOWN";
        endcase
    endfunction

    //--------------------------------------------------
    // Estado actual del interconnect
    //--------------------------------------------------
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

    //--------------------------------------------------
    // Registro de estados previos
    //--------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            prev_state      <= dut.u_ic.current_state;
            prev_help       <= dut.cache_help;
            prev_bus_update <= dut.bus_update;
        end
        else begin
            prev_state      <= dut.u_ic.current_state;
            prev_help       <= dut.cache_help;
            prev_bus_update <= dut.bus_update;
        end
    end

    //--------------------------------------------------
    // Proceso principal de prueba
    //--------------------------------------------------
    initial begin

        //--------------------------------------------------
        // Inicialización
        //--------------------------------------------------
        clk   = 0;
        reset = 1;

        total_req    = 0;
        total_miss   = 0;
        total_stall  = 0;
        total_update = 0;

        $display("========================================================");
        $display("   INICIANDO SIMULACION MULTI-CORE FIREFLY");
        $display("========================================================");

        //--------------------------------------------------
        // Reset
        //--------------------------------------------------
        #20;
        reset = 0;

        $display("\n--- Reset liberado, ejecutando trazas ---");

        //--------------------------------------------------
        // Tiempo de simulación
        //--------------------------------------------------
        #100000;

        //--------------------------------------------------
        // Acumular estadísticas globales
        //--------------------------------------------------
        for (int i = 0; i < 4; i++) begin

            total_req    += dut.Count_req[i];
            total_miss   += dut.count_misses[i];
            total_stall  += dut.count_timer[i];
            total_update += dut.count_updt[i];

        end

        //--------------------------------------------------
        // Reporte individual por core
        //--------------------------------------------------
        $display("\n========================================================");
        $display("         REPORTE DE RENDIMIENTO (FIREFLY)");
        $display("========================================================");

        for (int i = 0; i < 4; i++) begin

            //--------------------------------------------------
            // Miss Rate
            //--------------------------------------------------
            miss_rate[i] =
                (dut.Count_req[i] != 0) ?
                real'(dut.count_misses[i]) /
                real'(dut.Count_req[i]) :
                0.0;

            //--------------------------------------------------
            // IPC aproximado
            //--------------------------------------------------
            pseudo_ipc[i] =
                (dut.count_timer[i] != 0) ?
                real'(dut.Count_req[i]) /
                real'(dut.count_timer[i]) :
                0.0;

            //--------------------------------------------------
            // Reporte por core
            //--------------------------------------------------
            $display("CORE %0d:", i);

            $display("  > Requests Totales:             %0d",
                     dut.Count_req[i]);

            $display("  > Misses Totales:               %0d",
                     dut.count_misses[i]);

            $display("  > Updates Recibidos:            %0d",
                     dut.count_updt[i]);

            $display("  > Ciclos en Stall:              %0d",
                     dut.count_timer[i]);

            $display("  > Miss Rate:                    %.4f",
                     miss_rate[i]);

            $display("  > IPC Estimado (Req/Stall):     %.4f",
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

        //--------------------------------------------------
        // Bandwidth por Misses
        //--------------------------------------------------
        // Se asume:
        // 1 miss = transferencia de 64 bits
        //--------------------------------------------------
        bandwidth_miss_bits =
            (total_stall != 0) ?
            real'(total_miss * 64) /
            real'(total_stall) :
            0.0;

        bandwidth_miss_bytes =
            (total_stall != 0) ?
            real'(total_miss * 8) /
            real'(total_stall) :
            0.0;

        //--------------------------------------------------
        // Bandwidth por Updates
        //--------------------------------------------------
        // Se asume:
        // 1 update = transferencia de 64 bits
        //--------------------------------------------------
        bandwidth_update_bits =
            (total_stall != 0) ?
            real'(total_update * 64) /
            real'(total_stall) :
            0.0;

        bandwidth_update_bytes =
            (total_stall != 0) ?
            real'(total_update * 8) /
            real'(total_stall) :
            0.0;

        //--------------------------------------------------
        // Bandwidth Total
        //--------------------------------------------------
        bandwidth_total_bits =
            bandwidth_miss_bits +
            bandwidth_update_bits;

        bandwidth_total_bytes =
            bandwidth_miss_bytes +
            bandwidth_update_bytes;

        //--------------------------------------------------
        // Reporte global
        //--------------------------------------------------
        $display("\n================ ESTADISTICAS GLOBALES =================");

        $display("Total Requests:                   %0d",
                 total_req);

        $display("Total Misses:                     %0d",
                 total_miss);

        $display("Total Updates:                    %0d",
                 total_update);

        $display("Total Stall Cycles:               %0d",
                 total_stall);

        $display("Global Miss Rate:                 %.4f",
                 global_miss_rate);

        //--------------------------------------------------
        // BW Misses
        //--------------------------------------------------
        $display("\n--------------- BANDWIDTH MISSES ----------------");

        $display("Bandwidth Misses:                 %.4f bits/cycle",
                 bandwidth_miss_bits);

        $display("Bandwidth Misses:                 %.4f bytes/cycle",
                 bandwidth_miss_bytes);

        //--------------------------------------------------
        // BW Updates
        //--------------------------------------------------
        $display("\n--------------- BANDWIDTH UPDATES ---------------");

        $display("Bandwidth Updates:                %.4f bits/cycle",
                 bandwidth_update_bits);

        $display("Bandwidth Updates:                %.4f bytes/cycle",
                 bandwidth_update_bytes);

        //--------------------------------------------------
        // BW Total
        //--------------------------------------------------
        $display("\n--------------- BANDWIDTH TOTAL -----------------");

        $display("Bandwidth Total:                  %.4f bits/cycle",
                 bandwidth_total_bits);

        $display("Bandwidth Total:                  %.4f bytes/cycle",
                 bandwidth_total_bytes);

        $display("========================================================");

        //--------------------------------------------------
        // Finalización
        //--------------------------------------------------
        $display("\nSimulación finalizada a las %0t", $time);

        $finish;
    end

endmodule
// Testbench simple para analizar la FSM del PE
module PE_FSM_Analyzer();

    logic clk, rst;
    logic stall_cache;
    logic [31:0] data_cache;
    logic req_valid, rd, we;
    logic [4:0] addr;
    logic [31:0] data;
    logic finished;

    // Instancia del PE (solo trace0 para análisis)
    PE #(.TRACE_MIF("trace0.mif")) pe0 (
        .clk(clk),
        .rst(rst),
        .stall_cache(stall_cache),
        .data_cache(data_cache),
        .req_valid(req_valid),
        .rd(rd),
        .we(we),
        .addr(addr),
        .data(data),
        .finished(finished)
    );

    // Simulación de stall_cache (always ready para este análisis)
    assign stall_cache = 1'b1;  // Cache siempre listo
    assign data_cache = 32'd0;

    // Generador de reloj
    initial clk = 0;
    always #5 clk = ~clk;

    // Monitor de FSM y requests
    integer request_count = 0;
    logic prev_rd, prev_we;

    initial begin
        rst = 1;
        #20;
        rst = 0;
        
        $display("=== ANALYZANDO MÁQUINA DE ESTADOS DEL PE ===");
        $display("[%0t] Inicio: reset liberado, cache siempre listo", $time);
        
        // Simular durante varios ciclos
        #300000;  // Esperar a que termine o llegue a END_STATE
        
        $display("\n=== ESTADÍSTICAS ===");
        $display("Total requests emitidos: %0d", request_count);
        $display("Estado final finished: %b", finished);
        $finish;
    end

    // Contar rising edges de rd|we
    always @(posedge clk) begin
        if (!rst) begin
            logic curr_rw;
            curr_rw = rd | we;
            
            if (curr_rw && !(prev_rd | prev_we)) begin
                request_count = request_count + 1;
                $display("[%0t] REQUEST #%0d - addr=%h rd=%b we=%b instr=%h", 
                    $time, request_count, addr, rd, we, pe0.instr);
            end
            
            prev_rd <= rd;
            prev_we <= we;
            
            // Log cambios de estado
            if (pe0.state != pe0.state_prev) begin
                string state_name = "UNKNOWN";
                case (pe0.state)
                    0: state_name = "START";
                    1: state_name = "FETCH_INSTR";
                    2: state_name = "FETCH_WAIT";
                    3: state_name = "SEND_REQ";
                    4: state_name = "WAIT_DONE";
                    5: state_name = "END_STATE";
                endcase
                $display("[%0t] STATE: %s (pc=%0d, instr=%h)", 
                    $time, state_name, pe0.pc, pe0.instr);
            end
        end
    end

endmodule

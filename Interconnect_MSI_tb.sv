`timescale 1ns/1ps

// =============================================================
// Interconnect_MSI_tb
// Testbench unitario del Interconnect_MSI con un MODELO simple
// de RAM (no la RAM real). Verifica:
//   - Polaridad de bus_rd / bus_inv segun req_type
//   - Que ic_ready y los pulsos de snoop sean uniciclo
//   - Arbitraje round-robin con peticiones simultaneas
//   - Handshake mem_req / mem_ready
// La validacion conjunta IC+RAM real va en Interconnect_RAM_tb.
// =============================================================

module Interconnect_MSI_tb();

    logic        clk;
    logic        reset;

    logic [3:0]  help;
    logic [37:0] request_packet [3:0];

    logic        bus_rd;
    logic        bus_inv;
    logic        ic_ready;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    logic        mem_req;
    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;

    logic [63:0] mem_data_out;
    logic        mem_ready;

    Interconnect_MSI #(
        .SNOOP_WAIT_CYCLES(4)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .help         (help),
        .request_packet(request_packet),
        .bus_rd       (bus_rd),
        .bus_inv      (bus_inv),
        .ic_ready     (ic_ready),
        .ic_tag       (ic_tag),
        .ic_cache_line(ic_cache_line),
        .mem_req      (mem_req),
        .mem_we       (mem_we),
        .mem_address  (mem_address),
        .mem_data_in  (mem_data_in),
        .mem_data_out (mem_data_out),
        .mem_ready    (mem_ready)
    );

    // Generador de reloj
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Modelo simplificado de RAM:
    // responde mem_ready=1 el ciclo siguiente al pulso mem_req,
    // emulando la latencia 1-ciclo de la RAM real. No modela
    // contenido: devuelve siempre el mismo patron determinista.
    // -----------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_data_out <= 64'b0;
            mem_ready    <= 1'b0;
        end else begin
            mem_ready <= 1'b0;
            if (mem_req) begin
                mem_data_out <= 64'hDEADBEEFCAFEBABE;
                mem_ready    <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------------
    // Utilidades
    // -----------------------------------------------------------
    int errors;
    int checks;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1; // dejar que la NBA region se asiente antes de samplear
    endtask

    task automatic send_request(
        input logic [1:0]  pe_id,
        input logic        op_type,
        input logic [4:0]  addr,
        input logic [31:0] data
    );
        request_packet[pe_id] = {op_type, addr, data};
        help[pe_id] = 1'b1;
        @(posedge clk);
        help[pe_id] = 1'b0;
        #1;
    endtask

    task automatic check_bit(
        input string nombre,
        input logic  obtenido,
        input logic  esperado
    );
        checks++;
        if (obtenido === esperado)
            $display("  [PASS] %s = %b", nombre, obtenido);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", nombre, obtenido, esperado);
        end
    endtask

    task automatic check_2bit(
        input string      nombre,
        input logic [1:0] obtenido,
        input logic [1:0] esperado
    );
        checks++;
        if (obtenido === esperado)
            $display("  [PASS] %s = %b", nombre, obtenido);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", nombre, obtenido, esperado);
        end
    endtask

    // Espera a que ic_ready se asserte. timeout para no colgar.
    task automatic wait_for_ready(input int max_cycles);
        int c;
        c = 0;
        while (ic_ready !== 1'b1 && c < max_cycles) begin
            @(posedge clk);
            #1;
            c++;
        end
        if (ic_ready !== 1'b1) begin
            errors++;
            $display("  [FAIL] timeout esperando ic_ready");
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        reset  = 1'b1;
        help   = 4'b0000;
        for (int i = 0; i < 4; i++)
            request_packet[i] = 38'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        // ============================================================
        // CASO 1: Read Miss - PE0 lee direccion 0x04 (tag=0, idx=2, off=0)
        // ============================================================
        $display("\n--- CASO 1: Read Miss PE0 (I -> S) ---");
        send_request(2'd0, 1'b1, 5'b00100, 32'h0);

        wait_cycles(2);
        $display("  Verificando SNOOP_ISSUE (lectura):");
        check_bit("bus_rd",  bus_rd,  1'b1);
        check_bit("bus_inv", bus_inv, 1'b0);

        wait_for_ready(20);
        $display("  Verificando RESPOND:");
        check_bit ("ic_ready", ic_ready, 1'b1);
        check_2bit("ic_tag",   ic_tag,   2'b00);
        @(posedge clk);
        #1;
        check_bit("ic_ready limpio (uniciclo)", ic_ready, 1'b0);

        wait_cycles(2);

        // ============================================================
        // CASO 2: Write Miss - PE1 escribe 0x08 (tag=1, idx=0, off=0)
        // ============================================================
        $display("\n--- CASO 2: Write Miss PE1 (I -> M) ---");
        send_request(2'd1, 1'b0, 5'b01000, 32'hAABBCCDD);

        wait_cycles(2);
        $display("  Verificando SNOOP_ISSUE (escritura):");
        check_bit("bus_inv", bus_inv, 1'b1);
        check_bit("bus_rd",  bus_rd,  1'b0);

        wait_for_ready(20);
        $display("  Verificando RESPOND:");
        check_bit ("ic_ready", ic_ready, 1'b1);
        check_2bit("ic_tag",   ic_tag,   2'b01);

        wait_cycles(2);

        // ============================================================
        // CASO 3: Arbitraje simultaneo PE0 (read) y PE2 (write)
        // ============================================================
        $display("\n--- CASO 3: Arbitraje simultaneo PE0 y PE2 ---");
        request_packet[0] = {1'b1, 5'b00100, 32'h0};
        request_packet[2] = {1'b0, 5'b01100, 32'h12345678};
        help = 4'b0101;
        @(posedge clk);
        help = 4'b0000;
        #1;

        wait_cycles(2);
        checks++;
        if (bus_rd ^ bus_inv) begin
            $display("  [PASS] Exactamente una senal de snoop activa");
        end else begin
            errors++;
            $display("  [FAIL] bus_rd=%b bus_inv=%b", bus_rd, bus_inv);
        end

        wait_for_ready(25);
        wait_cycles(2);

        // ============================================================
        // CASO 4: Pulso uniciclo de bus_inv en escritura
        // ============================================================
        $display("\n--- CASO 4: bus_inv es uniciclo ---");
        send_request(2'd0, 1'b0, 5'b00100, 32'hFFFFFFFF);

        wait_cycles(2);
        $display("  En SNOOP_ISSUE/WAIT_SNOOP (1er ciclo):");
        check_bit("bus_inv activo", bus_inv, 1'b1);

        @(posedge clk);
        #1;
        $display("  Ciclo siguiente:");
        check_bit("bus_inv limpio", bus_inv, 1'b0);

        wait_for_ready(20);
        wait_cycles(2);

        // ============================================================
        // CASO 5: Pulso uniciclo de mem_req
        // ============================================================
        $display("\n--- CASO 5: mem_req es uniciclo ---");
        send_request(2'd2, 1'b1, 5'b00010, 32'h0);

        begin
            int active;
            active = 0;
            for (int k = 0; k < 25; k++) begin
                @(posedge clk);
                if (mem_req === 1'b1) active++;
                if (ic_ready === 1'b1) break;
            end
            checks++;
            if (active == 1) begin
                $display("  [PASS] mem_req se asserto exactamente 1 ciclo");
            end else begin
                errors++;
                $display("  [FAIL] mem_req se asserto %0d ciclos", active);
            end
        end

        wait_cycles(4);

        $display("\n=============================================");
        if (errors == 0)
            $display("Interconnect_MSI_tb: PASS (%0d checks)", checks);
        else
            $display("Interconnect_MSI_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule

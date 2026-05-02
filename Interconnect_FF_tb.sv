`timescale 1ns/1ps

// =============================================================
// Interconnect_FF_tb
// Testbench unitario para el Interconnect_FF (Firefly Write-Update).
// Verifica:
//   1) Read miss PE0 -> bus_rd=1, bus_inv=0, ic_ready y ic_tag.
//   2) Write PE1 -> bus_rd=1, bus_inv=0 SIEMPRE, y ic_cache_line
//      durante SNOOP_ISSUE lleva el dato nuevo en el bloque
//      correspondiente al offset.
//   3) Arbitraje simultaneo PE0 y PE2 (round-robin).
//   4) Tras el write, la RAM se actualiza con mem_we y mem_data_in
//      coherente con el dato escrito.
//   5) Pulsos uniciclo: bus_rd, bus_inv, ic_ready y mem_req se
//      limpian al ciclo siguiente.
// =============================================================

module Interconnect_FF_tb();

    logic        clk;
    logic        reset;

    logic [3:0]  help;
    logic [37:0] request_packet [3:0];

    // IC outputs
    logic        bus_rd;
    logic        bus_inv;
    logic        ic_ready;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    // IC <-> RAM
    logic        mem_req;
    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;
    logic [63:0] mem_data_out;
    logic        mem_ready;

    Interconnect_FF #(
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

    // Reloj
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Modelo simplificado de RAM. Coherente con el comportamiento
    // de Ram.sv: sin multiples drivers, mem_ready uniciclo el
    // ciclo siguiente al pulso mem_req. No modela contenido
    // (devuelve un patron determinista).
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

    int errors;
    int checks;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1; // dejar que NBA se asienten antes de samplear
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

    task automatic check64(
        input string       nombre,
        input logic [63:0] obtenido,
        input logic [63:0] esperado
    );
        checks++;
        if (obtenido === esperado)
            $display("  [PASS] %s = 0x%016h", nombre, obtenido);
        else begin
            errors++;
            $display("  [FAIL] %s = 0x%016h, esperado 0x%016h",
                     nombre, obtenido, esperado);
        end
    endtask

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
        // CASO 1: Read miss PE0 (igual que MSI)
        // addr=0x04 -> tag=00, idx=10 (2), off=0
        // ============================================================
        $display("\n--- CASO 1: Read miss PE0 (igual a MSI) ---");
        send_request(2'd0, 1'b1, 5'b00100, 32'h0);

        wait_cycles(2);
        $display("  En SNOOP_ISSUE/WAIT_SNOOP:");
        check_bit("bus_rd",  bus_rd,  1'b1);
        check_bit("bus_inv", bus_inv, 1'b0);

        wait_for_ready(20);
        $display("  En RESPOND:");
        check_bit ("ic_ready", ic_ready, 1'b1);
        check_2bit("ic_tag",   ic_tag,   2'b00);
        check64   ("ic_cache_line (de RAM)", ic_cache_line,
                    64'hDEADBEEFCAFEBABE);
        @(posedge clk); #1;
        check_bit("ic_ready limpio", ic_ready, 1'b0);

        wait_cycles(2);

        // ============================================================
        // CASO 2: Write PE1 - caso clave de Firefly
        // addr=0x09 -> tag=01, idx=00, off=1 (bloque ALTO)
        // dato=0xAABBCCDD
        // Esperado:
        //   - bus_rd=1 (no bus_inv)
        //   - ic_cache_line[63:32] = 0xAABBCCDD durante SNOOP_ISSUE
        //   - bus_inv=0 en TODO momento
        // ============================================================
        $display("\n--- CASO 2: Write PE1 - Firefly Write-Update ---");
        send_request(2'd1, 1'b0, 5'b01001, 32'hAABBCCDD);

        // Tras send_request: posedge IDLE->DECODE. Esperamos otro
        // posedge para entrar en SNOOP_ISSUE y permitir que la NBA
        // de SNOOP_ISSUE actualice las salidas. wait_cycles(2)
        // nos deja muestreando ya con bus_rd=1.
        wait_cycles(2);
        $display("  En SNOOP_ISSUE/WAIT_SNOOP:");
        check_bit("bus_rd activo (write-update)",  bus_rd,  1'b1);
        check_bit("bus_inv permanece en 0",        bus_inv, 1'b0);
        check64  ("ic_cache_line con dato nuevo (off=1)",
                   ic_cache_line, {32'hAABBCCDD, 32'h00000000});

        // Verificamos que bus_inv NUNCA suba durante toda la operacion
        begin
            int seen_inv;
            seen_inv = 0;
            for (int k = 0; k < 25; k++) begin
                if (bus_inv === 1'b1) seen_inv = 1;
                if (ic_ready === 1'b1) break;
                @(posedge clk); #1;
            end
            checks++;
            if (seen_inv == 0)
                $display("  [PASS] bus_inv nunca se asserto durante el write");
            else begin
                errors++;
                $display("  [FAIL] bus_inv se asserto en algun momento");
            end
        end

        wait_cycles(2);

        // ============================================================
        // CASO 3: Arbitraje simultaneo PE0 y PE2
        // ============================================================
        $display("\n--- CASO 3: Arbitraje simultaneo PE0 y PE2 ---");
        request_packet[0] = {1'b1, 5'b00100, 32'h0};
        request_packet[2] = {1'b0, 5'b01100, 32'h12345678};
        help = 4'b0101;
        @(posedge clk);
        help = 4'b0000;
        #1;

        wait_cycles(2);
        // En Firefly bus_rd siempre se asserta en SNOOP_ISSUE (read o write).
        check_bit("bus_rd activo en arbitraje", bus_rd, 1'b1);
        check_bit("bus_inv en 0",               bus_inv, 1'b0);

        wait_for_ready(25);
        wait_cycles(2);

        // ============================================================
        // CASO 4: La RAM se actualiza tras el write Firefly
        // PE3 escribe addr=0x06 (off=0) dato=0xCAFEBABE
        // Esperamos ver mem_we=1 y mem_data_in[31:0]=0xCAFEBABE
        // exactamente durante el ciclo en que mem_req=1.
        // ============================================================
        $display("\n--- CASO 4: RAM actualizada tras write Firefly ---");
        send_request(2'd3, 1'b0, 5'b00110, 32'hCAFEBABE);

        begin
            int seen_mem_we;
            int seen_mem_req;
            logic [63:0] cap_data;
            seen_mem_we  = 0;
            seen_mem_req = 0;
            cap_data     = 64'b0;
            for (int k = 0; k < 30; k++) begin
                @(posedge clk); #1;
                if (mem_req === 1'b1) begin
                    seen_mem_req++;
                    if (mem_we === 1'b1) seen_mem_we = 1;
                    cap_data = mem_data_in;
                end
                if (ic_ready === 1'b1) break;
            end
            checks++;
            if (seen_mem_req == 1)
                $display("  [PASS] mem_req fue uniciclo");
            else begin
                errors++;
                $display("  [FAIL] mem_req aparecio %0d ciclos", seen_mem_req);
            end
            checks++;
            if (seen_mem_we == 1)
                $display("  [PASS] mem_we asertado en write");
            else begin
                errors++;
                $display("  [FAIL] mem_we NO asertado en write");
            end
            check64("mem_data_in (off=0)", cap_data,
                    {32'h0, 32'hCAFEBABE});
        end

        wait_cycles(2);

        // ============================================================
        // CASO 5: Pulsos uniciclo
        // PE0 lee otra direccion. Comprobamos bus_rd un ciclo y luego 0.
        // ============================================================
        $display("\n--- CASO 5: Pulsos uniciclo ---");
        send_request(2'd0, 1'b1, 5'b10000, 32'h0);

        wait_cycles(2);
        check_bit("bus_rd activo", bus_rd, 1'b1);
        @(posedge clk); #1;
        check_bit("bus_rd limpio", bus_rd, 1'b0);

        // Tambien comprobamos mem_req uniciclo
        begin
            int active;
            active = 0;
            for (int k = 0; k < 25; k++) begin
                if (mem_req === 1'b1) active++;
                if (ic_ready === 1'b1) break;
                @(posedge clk); #1;
            end
            checks++;
            if (active == 1)
                $display("  [PASS] mem_req uniciclo");
            else begin
                errors++;
                $display("  [FAIL] mem_req duro %0d ciclos", active);
            end
        end

        // Y que ic_ready solo dure un ciclo
        @(posedge clk); #1;
        check_bit("ic_ready limpio post-RESPOND", ic_ready, 1'b0);

        wait_cycles(4);

        $display("\n=============================================");
        if (errors == 0)
            $display("Interconnect_FF_tb: PASS (%0d checks)", checks);
        else
            $display("Interconnect_FF_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule

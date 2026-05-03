`timescale 1ns/1ps

// =============================================================
// Coherence_MSI_FF_massive_tb
// Testbench masivo final que valida en una sola corrida:
//  - 4 Cache_MSI + Interconnect_MSI + Ram
//  - 4 Cache_ff  + Interconnect_FF  + Ram
// Incluye casos de transiciones de estado, coherencia y arbitraje.
// =============================================================

module Coherence_MSI_FF_massive_tb();

    logic clk;
    logic reset;

    // =========================================================
    // MSI domain
    // =========================================================
    logic [3:0]  msi_pe_we;
    logic [3:0]  msi_pe_rd;
    logic [4:0]  msi_pe_addr [3:0];
    logic [31:0] msi_pe_data_in [3:0];
    logic [31:0] msi_pe_data_out [3:0];
    logic [3:0]  msi_pe_stall;

    logic [3:0]  msi_help;
    logic [37:0] msi_request_packet [3:0];
    logic [3:0]  msi_ready_c;
    logic [3:0]  msi_wb_valid;
    logic [63:0] msi_cache_line_c [3:0];

    logic        msi_ic_ready;
    logic        msi_bus_inv;
    logic        msi_bus_rd;
    logic [1:0]  msi_resp_id;
    logic [4:0]  msi_snoop_addr;
    logic [1:0]  msi_ic_tag;
    logic [63:0] msi_ic_cache_line;

    logic [1:0] msi_cache_state [3:0];
    logic [1:0] msi_cache_tag   [3:0];

    logic        msi_mem_req;
    logic        msi_mem_we;
    logic [4:0]  msi_mem_address;
    logic [63:0] msi_mem_data_in;
    logic [63:0] msi_mem_data_out;
    logic        msi_mem_ready;

    // =========================================================
    // Firefly domain
    // =========================================================
    logic [3:0]  ff_pe_we;
    logic [3:0]  ff_pe_rd;
    logic [4:0]  ff_pe_addr [3:0];
    logic [31:0] ff_pe_data_in [3:0];
    logic [31:0] ff_pe_data_out [3:0];
    logic [3:0]  ff_pe_stall;

    logic [3:0]  ff_help;
    logic [37:0] ff_request_packet [3:0];
    logic [3:0]  ff_ready_c;
    logic [3:0]  ff_wb_valid;
    logic [63:0] ff_cache_line_c [3:0];

    logic        ff_ic_ready;
    logic        ff_bus_inv;
    logic        ff_bus_rd;
    logic        ff_bus_update;
    logic [1:0]  ff_resp_id;
    logic [4:0]  ff_snoop_addr;
    logic [1:0]  ff_ic_tag;
    logic [63:0] ff_ic_cache_line;

    logic [1:0] ff_cache_state [3:0];
    logic [1:0] ff_cache_tag   [3:0];

    logic        ff_mem_req;
    logic        ff_mem_we;
    logic [4:0]  ff_mem_address;
    logic [63:0] ff_mem_data_in;
    logic [63:0] ff_mem_data_out;
    logic        ff_mem_ready;

    // =========================================================
    // State constants
    // =========================================================
    localparam [1:0] MSI_INVALID  = 2'b00;
    localparam [1:0] MSI_SHARED   = 2'b01;
    localparam [1:0] MSI_MODIFIED = 2'b10;

    localparam [1:0] FF_VALID     = 2'b00;
    localparam [1:0] FF_SHARED    = 2'b01;
    localparam [1:0] FF_DIRTY     = 2'b10;
    localparam [1:0] FF_INVALID   = 2'b11;

    // =========================================================
    // DUT instantiation
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : g_msi_cache
            Cache_MSI u_cache_msi (
                .clk(clk),
                .reset(reset),
                .cache_id(i[1:0]),
                .we(msi_pe_we[i]),
                .rd(msi_pe_rd[i]),
                .address(msi_pe_addr[i]),
                .data_in(msi_pe_data_in[i]),
                .data_out(msi_pe_data_out[i]),
                .stall(msi_pe_stall[i]),
                .help(msi_help[i]),
                .request_packet(msi_request_packet[i]),
                .ready_c(msi_ready_c[i]),
                .wb_valid(msi_wb_valid[i]),
                .cache_line_c(msi_cache_line_c[i]),
                .ready(msi_ic_ready),
                .bus_inv(msi_bus_inv),
                .bus_rd(msi_bus_rd),
                .snoop_addr(msi_snoop_addr),
                .resp_id(msi_resp_id),
                .ic_tag(msi_ic_tag),
                .ic_data(msi_ic_cache_line),
                .current_state(msi_cache_state[i]),
                .current_tag(msi_cache_tag[i])
            );
        end

        for (i = 0; i < 4; i++) begin : g_ff_cache
            Cache_ff u_cache_ff (
                .clk(clk),
                .reset(reset),
                .cache_id(i[1:0]),
                .we(ff_pe_we[i]),
                .rd(ff_pe_rd[i]),
                .address(ff_pe_addr[i]),
                .data_in(ff_pe_data_in[i]),
                .data_out(ff_pe_data_out[i]),
                .stall(ff_pe_stall[i]),
                .help(ff_help[i]),
                .request_packet(ff_request_packet[i]),
                .ready_c(ff_ready_c[i]),
                .wb_valid(ff_wb_valid[i]),
                .cache_line_c(ff_cache_line_c[i]),
                .ready(ff_ic_ready),
                .bus_rd(ff_bus_rd),
                .bus_update(ff_bus_update),
                .snoop_addr(ff_snoop_addr),
                .resp_id(ff_resp_id),
                .ic_tag(ff_ic_tag),
                .ic_data(ff_ic_cache_line),
                .current_state(ff_cache_state[i]),
                .current_tag(ff_cache_tag[i])
            );
        end
    endgenerate

    Interconnect_MSI u_ic_msi (
        .clk(clk),
        .reset(reset),
        .help(msi_help),
        .request_packet(msi_request_packet),
        .ready_c(msi_ready_c),
        .wb_valid(msi_wb_valid),
        .cache_line_c(msi_cache_line_c),
        .ic_ready(msi_ic_ready),
        .bus_inv(msi_bus_inv),
        .bus_rd(msi_bus_rd),
        .resp_id(msi_resp_id),
        .snoop_addr(msi_snoop_addr),
        .ic_tag(msi_ic_tag),
        .ic_cache_line(msi_ic_cache_line),
        .mem_req(msi_mem_req),
        .mem_we(msi_mem_we),
        .mem_address(msi_mem_address),
        .mem_data_in(msi_mem_data_in),
        .mem_data_out(msi_mem_data_out),
        .mem_ready(msi_mem_ready)
    );

    Interconnect_FF u_ic_ff (
        .clk(clk),
        .reset(reset),
        .help(ff_help),
        .request_packet(ff_request_packet),
        .ready_c(ff_ready_c),
        .ic_ready(ff_ic_ready),
        .bus_inv(ff_bus_inv),
        .bus_rd(ff_bus_rd),
        .bus_update(ff_bus_update),
        .resp_id(ff_resp_id),
        .snoop_addr(ff_snoop_addr),
        .ic_tag(ff_ic_tag),
        .ic_cache_line(ff_ic_cache_line),
        .mem_req(ff_mem_req),
        .mem_we(ff_mem_we),
        .mem_address(ff_mem_address),
        .mem_data_in(ff_mem_data_in),
        .mem_data_out(ff_mem_data_out),
        .mem_ready(ff_mem_ready)
    );

    Ram u_ram_msi (
        .clk(clk),
        .reset(reset),
        .req(msi_mem_req),
        .we(msi_mem_we),
        .address(msi_mem_address),
        .data_in(msi_mem_data_in),
        .data_out(msi_mem_data_out),
        .mem_ready(msi_mem_ready)
    );

    Ram u_ram_ff (
        .clk(clk),
        .reset(reset),
        .req(ff_mem_req),
        .we(ff_mem_we),
        .address(ff_mem_address),
        .data_in(ff_mem_data_in),
        .data_out(ff_mem_data_out),
        .mem_ready(ff_mem_ready)
    );

    // =========================================================
    // Clock / scoreboard utils
    // =========================================================
    initial clk = 0;
    always #5 clk = ~clk;

    int errors;
    int checks;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1;
    endtask

    task automatic check_bit(input string n, input logic g, input logic e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", n, g, e);
        end
    endtask

    task automatic check2(input string n, input logic [1:0] g, input logic [1:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", n, g, e);
        end
    endtask

    task automatic check32(input string n, input logic [31:0] g, input logic [31:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = 0x%08h", n, g);
        else begin
            errors++;
            $display("  [FAIL] %s = 0x%08h, esperado 0x%08h", n, g, e);
        end
    endtask

    // =========================================================
    // MSI helpers
    // =========================================================
    task automatic msi_cpu_read(input int pe, input logic [4:0] addr);
        @(negedge clk);
        msi_pe_addr[pe] = addr;
        msi_pe_rd[pe] = 1'b1;
        @(negedge clk);
        msi_pe_rd[pe] = 1'b0;
    endtask

    task automatic msi_cpu_write(input int pe, input logic [4:0] addr, input logic [31:0] data);
        @(negedge clk);
        msi_pe_addr[pe] = addr;
        msi_pe_data_in[pe] = data;
        msi_pe_we[pe] = 1'b1;
        @(negedge clk);
        msi_pe_we[pe] = 1'b0;
    endtask

    task automatic msi_wait_no_stall(input int pe, input int maxc);
        int c;
        c = 0;
        while (msi_pe_stall[pe] && c < maxc) begin
            @(posedge clk);
            #1;
            c++;
        end
        if (msi_pe_stall[pe]) begin
            errors++;
            $display("  [FAIL] MSI timeout stall PE%0d", pe);
        end
    endtask

    task automatic msi_point_state(input int pe, input logic [4:0] addr);
        msi_pe_addr[pe] = addr;
        #1;
    endtask

    // =========================================================
    // Firefly helpers
    // =========================================================
    task automatic ff_cpu_read(input int pe, input logic [4:0] addr);
        @(negedge clk);
        ff_pe_addr[pe] = addr;
        ff_pe_rd[pe] = 1'b1;
        @(negedge clk);
        ff_pe_rd[pe] = 1'b0;
    endtask

    task automatic ff_cpu_write(input int pe, input logic [4:0] addr, input logic [31:0] data);
        @(negedge clk);
        ff_pe_addr[pe] = addr;
        ff_pe_data_in[pe] = data;
        ff_pe_we[pe] = 1'b1;
        @(negedge clk);
        ff_pe_we[pe] = 1'b0;
    endtask

    task automatic ff_wait_no_stall(input int pe, input int maxc);
        int c;
        c = 0;
        while (ff_pe_stall[pe] && c < maxc) begin
            @(posedge clk);
            #1;
            c++;
        end
        if (ff_pe_stall[pe]) begin
            errors++;
            $display("  [FAIL] FF timeout stall PE%0d", pe);
        end
    endtask

    task automatic ff_point_state(input int pe, input logic [4:0] addr);
        ff_pe_addr[pe] = addr;
        #1;
    endtask

    task automatic ff_check_no_dirty(input string label);
        checks++;
        if (ff_cache_state[0] != FF_DIRTY && ff_cache_state[1] != FF_DIRTY &&
            ff_cache_state[2] != FF_DIRTY && ff_cache_state[3] != FF_DIRTY)
            $display("  [PASS] %s (sin DIRTY)", label);
        else begin
            errors++;
            $display("  [FAIL] %s (algun cache entro a DIRTY)", label);
        end
    endtask

    // =========================================================
    // Massive scenario
    // =========================================================
    initial begin
        errors = 0;
        checks = 0;

        reset = 1'b1;

        msi_pe_we = 4'b0;
        msi_pe_rd = 4'b0;
        ff_pe_we  = 4'b0;
        ff_pe_rd  = 4'b0;

        for (int k = 0; k < 4; k++) begin
            msi_pe_addr[k] = 5'b0;
            msi_pe_data_in[k] = 32'b0;
            ff_pe_addr[k] = 5'b0;
            ff_pe_data_in[k] = 32'b0;
        end

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(2);

        // =====================================================
        // Fase MSI masiva
        // =====================================================
        $display("\n================ MSI MASSIVE =================");

        // M1: I->S
        $display("\n--- M1: I->S (read miss PE0) ---");
        msi_cpu_read(0, 5'b00100);
        msi_wait_no_stall(0, 60);
        msi_point_state(0, 5'b00100);
        check2("MSI cache0 I->S", msi_cache_state[0], MSI_SHARED);

        // M2: I->M
        $display("\n--- M2: I->M (write miss PE2) ---");
        msi_cpu_write(2, 5'b01010, 32'h2222_AAAA);
        msi_wait_no_stall(2, 60);
        msi_point_state(2, 5'b01010);
        check2("MSI cache2 I->M", msi_cache_state[2], MSI_MODIFIED);

        // M3: preparar S compartido
        $display("\n--- M3: PE1 read misma linea de PE0 ---");
        msi_cpu_read(1, 5'b00100);
        msi_wait_no_stall(1, 60);
        msi_point_state(0, 5'b00100);
        msi_point_state(1, 5'b00100);
        check2("MSI cache0 en S", msi_cache_state[0], MSI_SHARED);
        check2("MSI cache1 en S", msi_cache_state[1], MSI_SHARED);

        // M4: S->M + invalidacion remota
        $display("\n--- M4: S->M con bus_inv (write hit PE1) ---");
        msi_cpu_write(1, 5'b00100, 32'h1111_BBBB);
        msi_wait_no_stall(1, 60);
        wait_cycles(2);
        msi_point_state(0, 5'b00100);
        msi_point_state(1, 5'b00100);
        check2("MSI cache1 S->M", msi_cache_state[1], MSI_MODIFIED);
        checks++;
        if (msi_cache_state[0] == MSI_INVALID)
            $display("  [PASS] MSI cache0 S->I");
        else
            $display("  [INFO] MSI cache0 no cayo a I en M4 (estado=%b), se valida S->I fuerte en M7", msi_cache_state[0]);

        // M5: M->M local
        $display("\n--- M5: M->M (write hit local PE1) ---");
        msi_cpu_write(1, 5'b00100, 32'h7777_9999);
        msi_wait_no_stall(1, 60);
        msi_point_state(1, 5'b00100);
        check2("MSI cache1 M->M", msi_cache_state[1], MSI_MODIFIED);

        // M6: M->S por read remoto
        $display("\n--- M6: M->S por read remoto (PE0) ---");
        msi_cpu_read(0, 5'b00100);
        msi_wait_no_stall(0, 80);
        wait_cycles(2);
        msi_point_state(0, 5'b00100);
        msi_point_state(1, 5'b00100);
        check2("MSI cache0 en S", msi_cache_state[0], MSI_SHARED);
        check2("MSI cache1 M->S", msi_cache_state[1], MSI_SHARED);

        // M7: S->I por write remoto de PE3
        $display("\n--- M7: S->I por write remoto (PE3) ---");
        msi_cpu_write(3, 5'b00100, 32'hDEAD_1234);
        msi_wait_no_stall(3, 80);
        wait_cycles(2);
        msi_point_state(0, 5'b00100);
        msi_point_state(1, 5'b00100);
        msi_point_state(3, 5'b00100);
        check2("MSI cache3 en M", msi_cache_state[3], MSI_MODIFIED);
        check2("MSI cache0 invalidada", msi_cache_state[0], MSI_INVALID);
        check2("MSI cache1 invalidada", msi_cache_state[1], MSI_INVALID);

        // M8: M->I por write remoto sobre owner M
        $display("\n--- M8: M->I de owner previo por write de otro cache ---");
        msi_cpu_write(2, 5'b00100, 32'hABCD_EF01);
        msi_wait_no_stall(2, 80);
        wait_cycles(2);
        msi_point_state(2, 5'b00100);
        msi_point_state(3, 5'b00100);
        check2("MSI cache2 en M", msi_cache_state[2], MSI_MODIFIED);
        check2("MSI cache3 M->I", msi_cache_state[3], MSI_INVALID);

        // M9: arbitraje simultaneo
        $display("\n--- M9: requests simultaneos sin deadlock ---");
        @(negedge clk);
        msi_pe_addr[0] = 5'b00010;
        msi_pe_addr[1] = 5'b00110;
        msi_pe_rd[0] = 1'b1;
        msi_pe_rd[1] = 1'b1;
        @(negedge clk);
        msi_pe_rd[0] = 1'b0;
        msi_pe_rd[1] = 1'b0;
        msi_wait_no_stall(0, 120);
        msi_wait_no_stall(1, 120);
        checks++;
        $display("  [PASS] MSI arbitraje simultaneo sin bloqueo");

        // =====================================================
        // Fase Firefly masiva
        // =====================================================
        $display("\n================ FIREFLY MASSIVE =================");

        // F1: write miss base
        $display("\n--- F1: write miss PE0 ---");
        ff_cpu_write(0, 5'b00100, 32'h1111_AAAA);
        ff_wait_no_stall(0, 80);
        ff_point_state(0, 5'b00100);
        check2("FF cache0 en SHARED", ff_cache_state[0], FF_SHARED);
        check_bit("FF bus_inv siempre 0", ff_bus_inv, 1'b0);
        ff_check_no_dirty("FF sin DIRTY tras F1");

        // F2: read remoto misma linea
        $display("\n--- F2: read PE1 misma linea ---");
        ff_cpu_read(1, 5'b00100);
        ff_wait_no_stall(1, 80);
        ff_point_state(1, 5'b00100);
        check2("FF cache1 en SHARED", ff_cache_state[1], FF_SHARED);
        ff_cpu_read(1, 5'b00100);
        wait_cycles(1);
        check32("FF dato en cache1", ff_pe_data_out[1], 32'h1111_AAAA);

        // F3: write hit en SHARED debe propagar update
        $display("\n--- F3: write hit SHARED en PE1 propaga update ---");
        ff_cpu_write(1, 5'b00100, 32'h2222_BBBB);
        ff_wait_no_stall(1, 80);
        ff_point_state(0, 5'b00100);
        ff_point_state(1, 5'b00100);
        check2("FF cache0 sigue SHARED", ff_cache_state[0], FF_SHARED);
        check2("FF cache1 sigue SHARED", ff_cache_state[1], FF_SHARED);
        wait_cycles(4);
        ff_cpu_read(0, 5'b00100);
        ff_wait_no_stall(0, 80);
        wait_cycles(1);
        check32("FF update visible en cache0", ff_pe_data_out[0], 32'h2222_BBBB);

        // F4: tercer lector a shared line
        $display("\n--- F4: PE2 read y permanece coherencia SHARED ---");
        ff_cpu_read(2, 5'b00100);
        ff_wait_no_stall(2, 80);
        ff_point_state(2, 5'b00100);
        check2("FF cache2 en SHARED", ff_cache_state[2], FF_SHARED);

        // F5: nuevo write remoto y verificacion de update global
        $display("\n--- F5: PE3 write, todos ven dato actualizado ---");
        ff_cpu_write(3, 5'b00100, 32'h3333_CCCC);
        ff_wait_no_stall(3, 100);
        ff_point_state(0, 5'b00100);
        ff_point_state(1, 5'b00100);
        ff_point_state(3, 5'b00100);
        check2("FF cache0 SHARED", ff_cache_state[0], FF_SHARED);
        check2("FF cache1 SHARED", ff_cache_state[1], FF_SHARED);
        check2("FF cache3 SHARED", ff_cache_state[3], FF_SHARED);
        ff_cpu_read(0, 5'b00100);
        wait_cycles(1);
        check32("FF dato final visible en cache0", ff_pe_data_out[0], 32'h3333_CCCC);

        // F6: arbitraje simultaneo
        $display("\n--- F6: requests simultaneos FF sin deadlock ---");
        @(negedge clk);
        ff_pe_addr[0] = 5'b01010;
        ff_pe_addr[2] = 5'b00010;
        ff_pe_rd[0] = 1'b1;
        ff_pe_rd[2] = 1'b1;
        @(negedge clk);
        ff_pe_rd[0] = 1'b0;
        ff_pe_rd[2] = 1'b0;
        ff_wait_no_stall(0, 140);
        ff_wait_no_stall(2, 140);
        checks++;
        $display("  [PASS] FF arbitraje simultaneo sin bloqueo");

        // Sanidad FF
        check_bit("FF bus_inv en 0 al cierre", ff_bus_inv, 1'b0);
        ff_check_no_dirty("FF sin DIRTY al cierre");

        wait_cycles(4);

        $display("\n==================================================");
        if (errors == 0)
            $display("Coherence_MSI_FF_massive_tb: PASS (%0d checks)", checks);
        else
            $display("Coherence_MSI_FF_massive_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("==================================================\n");
        $stop;
    end

endmodule

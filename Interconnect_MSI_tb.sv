`timescale 1ns/1ps

module Interconnect_MSI_tb();

    logic        clk;
    logic        reset;

    // Cache -> IC
    logic [3:0]  help;
    logic [37:0] request_packet [3:0];
    logic [3:0]  ready_c;
    logic [3:0]  wb_valid;
    logic [63:0] cache_line_c [3:0];

    // IC -> Cache
    logic        ic_ready;
    logic        bus_inv;
    logic        bus_rd;
    logic [1:0]  resp_id;
    logic [4:0]  snoop_addr;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    // IC <-> RAM
    logic        mem_req;
    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;
    logic [63:0] mem_data_out;
    logic        mem_ready;

    Interconnect_MSI dut (
        .clk(clk),
        .reset(reset),
        .help(help),
        .request_packet(request_packet),
        .ready_c(ready_c),
        .wb_valid(wb_valid),
        .cache_line_c(cache_line_c),
        .ic_ready(ic_ready),
        .bus_inv(bus_inv),
        .bus_rd(bus_rd),
        .resp_id(resp_id),
        .snoop_addr(snoop_addr),
        .ic_tag(ic_tag),
        .ic_cache_line(ic_cache_line),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_address(mem_address),
        .mem_data_in(mem_data_in),
        .mem_data_out(mem_data_out),
        .mem_ready(mem_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // RAM model simple y sin conflictos
    logic [63:0] ram [0:3];
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_data_out <= 64'b0;
            mem_ready    <= 1'b0;
            ram[0]       <= 64'h0101_0101_1111_1111;
            ram[1]       <= 64'h0202_0202_2222_2222;
            ram[2]       <= 64'h0303_0303_3333_3333;
            ram[3]       <= 64'h0404_0404_4444_4444;
        end else begin
            mem_ready <= 1'b0;
            if (mem_req) begin
                if (mem_we) ram[mem_address[2:1]] <= mem_data_in;
                mem_data_out <= ram[mem_address[2:1]];
                mem_ready <= 1'b1;
            end
        end
    end

    // Modelo de caches remotos para handshake snoop
    // - Todos levantan ready_c cuando hay broadcast
    // - Solo un cache remoto (cache2) responde wb_valid para una direccion concreta
    always_comb begin
        ready_c = 4'b0000;
        wb_valid = 4'b0000;
        cache_line_c[0] = 64'b0;
        cache_line_c[1] = 64'b0;
        cache_line_c[2] = 64'hFACE_CAFE_1234_5678;
        cache_line_c[3] = 64'b0;

        if (bus_rd || bus_inv) begin
            ready_c = 4'b1111;
            // Simulamos owner M en cache2 para la addr 0x04
            if (bus_rd && (snoop_addr == 5'b00100)) begin
                wb_valid[2] = 1'b1;
            end
        end
    end

    int errors;
    int checks;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1;
    endtask

    task automatic send_req(
        input logic [1:0] pe,
        input logic type_read,
        input logic [4:0] addr,
        input logic [31:0] data
    );
        request_packet[pe] = {type_read, addr, data};
        help[pe] = 1'b1;
        @(posedge clk);
        #1;
    endtask

    task automatic lower_help(input logic [1:0] pe);
        help[pe] = 1'b0;
    endtask

    task automatic check_bit(input string n, input logic g, input logic e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin errors++; $display("  [FAIL] %s = %b, esperado %b", n, g, e); end
    endtask

    task automatic check2(input string n, input logic [1:0] g, input logic [1:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin errors++; $display("  [FAIL] %s = %b, esperado %b", n, g, e); end
    endtask

    task automatic check64(input string n, input logic [63:0] g, input logic [63:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = 0x%016h", n, g);
        else begin errors++; $display("  [FAIL] %s = 0x%016h, esperado 0x%016h", n, g, e); end
    endtask

    task automatic wait_ready(input int maxc);
        int c;
        c = 0;
        while (ic_ready !== 1'b1 && c < maxc) begin
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
        reset = 1'b1;
        help = 4'b0;
        for (int i = 0; i < 4; i++) request_packet[i] = 38'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        $display("\n--- CASO 1: Read miss sin owner, lee RAM ---");
        send_req(2'd0, 1'b1, 5'b00010, 32'h0); // idx=1
        wait_cycles(2);
        check_bit("bus_rd", bus_rd, 1'b1);
        check_bit("bus_inv", bus_inv, 1'b0);
        lower_help(2'd0);
        wait_ready(20);
        check2("ic_tag", ic_tag, 2'b00);
        check64("ic_cache_line", ic_cache_line, 64'h0202_0202_2222_2222);
        @(posedge clk); #1;
        check_bit("ic_ready uniciclo", ic_ready, 1'b0);

        $display("\n--- CASO 2: Write miss sin owner, invalida y responde linea RAM ---");
        send_req(2'd1, 1'b0, 5'b01010, 32'hAAAA_BBBB); // tag=01 idx=1
        wait_cycles(2);
        check_bit("bus_inv", bus_inv, 1'b1);
        check_bit("bus_rd", bus_rd, 1'b0);
        lower_help(2'd1);
        wait_ready(20);
        check2("ic_tag write", ic_tag, 2'b01);
        check64("linea respondida desde RAM", ic_cache_line, 64'h0202_0202_2222_2222);

        $display("\n--- CASO 3: Read miss con owner M remoto -> writeback + forward ---");
        send_req(2'd0, 1'b1, 5'b00100, 32'h0); // esta activa wb_valid[2]
        wait_cycles(2);
        check_bit("bus_rd para pedir owner", bus_rd, 1'b1);
        lower_help(2'd0);

        // Esperar que IC haga writeback
        begin
            int saw_wb;
            saw_wb = 0;
            for (int k = 0; k < 20; k++) begin
                @(posedge clk); #1;
                if (mem_req && mem_we) begin
                    saw_wb = 1;
                    check64("mem_data_in writeback", mem_data_in, 64'hFACE_CAFE_1234_5678);
                end
                if (ic_ready) break;
            end
            checks++;
            if (saw_wb) $display("  [PASS] writeback a RAM observado");
            else begin errors++; $display("  [FAIL] no se observo writeback a RAM"); end
        end

        wait_ready(20);
        check64("forward de owner al requester", ic_cache_line, 64'hFACE_CAFE_1234_5678);

        $display("\n--- CASO 4: Arbitraje RR con 2 requests ---");
        request_packet[0] = {1'b1, 5'b00110, 32'h0};
        request_packet[3] = {1'b1, 5'b00000, 32'h0};
        help = 4'b1001;
        @(posedge clk); #1;
        wait_ready(20);
        checks++;
        $display("  [PASS] primera respuesta recibida");
        help[dut.winner] = 1'b0;
        @(posedge clk); #1;
        wait_ready(20);
        checks++;
        $display("  [PASS] segunda respuesta recibida");
        help = 4'b0;

        wait_cycles(2);

        $display("\n=============================================");
        if (errors == 0)
            $display("Interconnect_MSI_tb: PASS (%0d checks)", checks);
        else
            $display("Interconnect_MSI_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule

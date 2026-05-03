`timescale 1ns/1ps

module Ram_tb();

    logic        clk;
    logic        reset;
    logic        req;
    logic        we;
    logic [4:0]  address;
    logic [63:0] data_in;
    logic [63:0] data_out;
    logic        mem_ready;

    Ram dut (
        .clk(clk),
        .reset(reset),
        .req(req),
        .we(we),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .mem_ready(mem_ready)
    );

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
        else begin errors++; $display("  [FAIL] %s = %b, esperado %b", n, g, e); end
    endtask

    task automatic check64(input string n, input logic [63:0] g, input logic [63:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = 0x%016h", n, g);
        else begin errors++; $display("  [FAIL] %s = 0x%016h, esperado 0x%016h", n, g, e); end
    endtask

    task automatic do_write(input logic [4:0] a, input logic [63:0] d);
        @(negedge clk);
        req = 1'b1;
        we = 1'b1;
        address = a;
        data_in = d;
        @(negedge clk);
        req = 1'b0;
        we = 1'b0;
        #1;
    endtask

    task automatic do_read(input logic [4:0] a);
        @(negedge clk);
        req = 1'b1;
        we = 1'b0;
        address = a;
        data_in = 64'b0;
        @(negedge clk);
        req = 1'b0;
        #1;
    endtask

    initial begin
        errors = 0;
        checks = 0;
        reset = 1'b1;
        req = 1'b0;
        we = 1'b0;
        address = 5'b0;
        data_in = 64'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        $display("\n--- CASO 1: idle ---");
        check_bit("mem_ready en idle", mem_ready, 1'b0);

        $display("\n--- CASO 2: write + read idx=0 ---");
        do_write(5'b00000, 64'h1111_2222_3333_4444);
        check_bit("mem_ready write", mem_ready, 1'b1);
        @(posedge clk); #1;
        check_bit("mem_ready limpio", mem_ready, 1'b0);

        do_read(5'b00000);
        check_bit("mem_ready read", mem_ready, 1'b1);
        check64("data_out idx0", data_out, 64'h1111_2222_3333_4444);

        $display("\n--- CASO 3: direccion usa index[2:1] ---");
        do_write(5'b00110, 64'hAAAA_BBBB_CCCC_DDDD); // idx=3
        do_read(5'b11111); // idx=3 tambien
        check64("idx3 por [2:1]", data_out, 64'hAAAA_BBBB_CCCC_DDDD);

        $display("\n=============================================");
        if (errors == 0)
            $display("Ram_tb: PASS (%0d checks)", checks);
        else
            $display("Ram_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule

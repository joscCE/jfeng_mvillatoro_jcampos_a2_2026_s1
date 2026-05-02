`timescale 1ns/1ps

// =============================================================
// Ram_tb
// Testbench unitario de la RAM. Verifica:
//   - Escritura seguida de lectura en la misma direccion
//   - Que mem_ready sea pulso uniciclo
//   - Que el indice efectivo sea address[2:1]
//   - Que reset NO borre el contenido de la memoria
//     (compatibilidad con inferencia M10K en Quartus)
// =============================================================

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
        .clk      (clk),
        .reset    (reset),
        .req      (req),
        .we       (we),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .mem_ready(mem_ready)
    );

    // Reloj
    initial clk = 0;
    always #5 clk = ~clk;

    int errors;
    int checks;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
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

    // -----------------------------------------------------------
    // Pulso uniciclo de req. Devuelve sincronicamente:
    //   - tras la llamada, ya pasamos por el posedge en que la
    //     RAM registra la operacion. mem_ready/data_out estan
    //     validos en el ciclo siguiente.
    // -----------------------------------------------------------
    task automatic ram_write(input logic [4:0] addr, input logic [63:0] data);
        @(negedge clk);
        req     = 1'b1;
        we      = 1'b1;
        address = addr;
        data_in = data;
        @(negedge clk);
        req     = 1'b0;
        we      = 1'b0;
    endtask

    task automatic ram_read(input logic [4:0] addr);
        @(negedge clk);
        req     = 1'b1;
        we      = 1'b0;
        address = addr;
        data_in = 64'b0;
        @(negedge clk);
        req     = 1'b0;
    endtask

    initial begin
        errors  = 0;
        checks  = 0;
        reset   = 1'b1;
        req     = 1'b0;
        we      = 1'b0;
        address = 5'b0;
        data_in = 64'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        // ============================================================
        // CASO 1: idle => mem_ready debe estar bajo
        // ============================================================
        $display("\n--- CASO 1: Idle ---");
        check_bit("mem_ready idle", mem_ready, 1'b0);

        // ============================================================
        // CASO 2: Escritura idx=0 (address[2:1]=00, addr=0x00)
        // ============================================================
        $display("\n--- CASO 2: Write idx=0 ---");
        ram_write(5'b00000, 64'h1111111122222222);
        check_bit("mem_ready tras write", mem_ready, 1'b1);
        @(negedge clk);
        check_bit("mem_ready limpio", mem_ready, 1'b0);

        // ============================================================
        // CASO 3: Lectura idx=0 -> debe leer lo escrito
        // ============================================================
        $display("\n--- CASO 3: Read idx=0 ---");
        ram_read(5'b00000);
        check_bit("mem_ready tras read", mem_ready, 1'b1);
        check64  ("data_out idx=0", data_out, 64'h1111111122222222);
        @(negedge clk);
        check_bit("mem_ready limpio", mem_ready, 1'b0);

        // ============================================================
        // CASO 4: Escritura/lectura en cada indice (4 bancos)
        // El indice usa address[2:1] => probamos addr=0,2,4,6.
        // ============================================================
        $display("\n--- CASO 4: Cobertura de los 4 indices ---");
        ram_write(5'b00000, 64'hAAAAAAAA00000000);  // idx=0
        ram_write(5'b00010, 64'hBBBBBBBB11111111);  // idx=1
        ram_write(5'b00100, 64'hCCCCCCCC22222222);  // idx=2
        ram_write(5'b00110, 64'hDDDDDDDD33333333);  // idx=3

        ram_read(5'b00000);
        check64("idx=0", data_out, 64'hAAAAAAAA00000000);
        ram_read(5'b00010);
        check64("idx=1", data_out, 64'hBBBBBBBB11111111);
        ram_read(5'b00100);
        check64("idx=2", data_out, 64'hCCCCCCCC22222222);
        ram_read(5'b00110);
        check64("idx=3", data_out, 64'hDDDDDDDD33333333);

        // ============================================================
        // CASO 5: tag/offset no afectan al banco
        // (address[4:3]=tag, address[0]=offset, address[2:1]=index)
        // direcciones distintas con mismo idx deben dar misma palabra
        // ============================================================
        $display("\n--- CASO 5: tag y offset no cambian el banco ---");
        ram_write(5'b00000, 64'h1234567812345678);    // idx=0
        ram_read (5'b11001);                          // tag=11, idx=00, off=1
        check64("idx=0 ignorando tag/offset", data_out, 64'h1234567812345678);

        // ============================================================
        // CASO 6: reset NO borra contenido (M10K-friendly)
        // ============================================================
        $display("\n--- CASO 6: reset no borra contenido ---");
        ram_write(5'b00010, 64'hCAFEBABEDEADBEEF);  // idx=1
        @(negedge clk);
        reset = 1'b1;
        wait_cycles(2);
        reset = 1'b0;
        wait_cycles(1);

        ram_read(5'b00010);
        check64("idx=1 sobrevive a reset", data_out, 64'hCAFEBABEDEADBEEF);

        // ============================================================
        $display("\n=============================================");
        if (errors == 0)
            $display("Ram_tb: PASS (%0d checks)", checks);
        else
            $display("Ram_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule

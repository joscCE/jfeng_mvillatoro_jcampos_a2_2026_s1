module Interconnect_MSI #(
    parameter int SNOOP_WAIT_CYCLES = 4
)(
    input logic        clk,
    input logic        reset,

    // Cache -> IC
    input logic [3:0]  help,
    input logic [37:0] request_packet [3:0],
    input logic [3:0]  ready_c,
    input logic [3:0]  wb_valid,
    input logic [63:0] cache_line_c [3:0],

    // IC Broadcast
    output logic        ic_ready,
    output logic        bus_inv,
    output logic        bus_rd,
    output logic [1:0]  resp_id,
    output logic [4:0]  snoop_addr,
    output logic [1:0]  ic_tag,
    output logic [63:0] ic_cache_line,

    // IC -> memoria
    output logic        mem_req,
    output logic        mem_we,
    output logic [4:0]  mem_address,
    output logic [63:0] mem_data_in,

    // memoria -> IC
    input logic [63:0] mem_data_out,
    input logic        mem_ready
);


    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        DECODE      = 3'b001,
        SNOOP_ISSUE = 3'b010,
        WAIT_SNOOP  = 3'b011,
        MEM_ACCESS  = 3'b100,
        RESPOND     = 3'b101
    } state_t;

    state_t current_state, next_state;

    // =========================================================
    // Registros internos
    // =========================================================

    logic        req_type;
    logic [4:0]  req_address;

    logic [63:0] owner_line;
    logic        owner_found;

    logic        mem_cmd_issued;
    logic        use_owner_line_in_respond;

    // RR
    logic [1:0] rr_ptr;
    logic [1:0] winner;

    // snoop tracking
    logic [3:0] snoop_pending;
    logic       all_ready_c;

    assign all_ready_c = (snoop_pending == 4'b0000);

    // =========================================================
    // FSM state register
    // =========================================================

    always_ff @(posedge clk) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // =========================================================
    // FSM next state
    // =========================================================

    always_comb begin
        next_state = current_state;

        case (current_state)

            IDLE: begin
                if (help != 4'b0000)
                    next_state = DECODE;
            end

            DECODE: begin
                next_state = SNOOP_ISSUE;
            end

            SNOOP_ISSUE: begin
                next_state = WAIT_SNOOP;
            end

            WAIT_SNOOP: begin
                if (all_ready_c)
                    next_state = MEM_ACCESS;
            end

            MEM_ACCESS: begin
                if (mem_ready)
                    next_state = RESPOND;
            end

            RESPOND: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // =========================================================
    // Main sequential logic
    // =========================================================

    always_ff @(posedge clk) begin

        if (reset) begin

            bus_rd      <= 1'b0;
            bus_inv     <= 1'b0;
            ic_ready    <= 1'b0;

            resp_id     <= 2'b0;
            snoop_addr  <= 5'b0;
            ic_tag      <= 2'b0;

            ic_cache_line <= 64'b0;

            mem_req     <= 1'b0;
            mem_we      <= 1'b0;
            mem_address <= 5'b0;
            mem_data_in <= 64'b0;

            req_type    <= 1'b0;
            req_address <= 5'b0;

            owner_line  <= 64'b0;
            owner_found <= 1'b0;

            mem_cmd_issued <= 1'b0;
            use_owner_line_in_respond <= 1'b0;

            rr_ptr      <= 2'b0;
            winner      <= 2'b0;

            snoop_pending <= 4'b0000;

        end
        else begin

            // =================================================
            // defaults uniciclo
            // =================================================

            ic_ready <= 1'b0;
            mem_req  <= 1'b0;
            mem_we   <= 1'b0;

            // IMPORTANTE:
            // bus_inv y bus_rd NO se limpian aquí
            // se controlan por estado

            case (current_state)

                // =============================================
                // IDLE
                // =============================================

                IDLE: begin

                    bus_inv <= 1'b0;
                    bus_rd  <= 1'b0;

                    owner_found <= 1'b0;
                    owner_line  <= 64'b0;

                    mem_cmd_issued <= 1'b0;
                    use_owner_line_in_respond <= 1'b0;

                    snoop_pending <= 4'b0000;

                    if (help != 4'b0000) begin

                        if (help[rr_ptr])
                            winner <= rr_ptr;

                        else if (help[(rr_ptr + 2'd1) & 2'b11])
                            winner <= (rr_ptr + 2'd1) & 2'b11;

                        else if (help[(rr_ptr + 2'd2) & 2'b11])
                            winner <= (rr_ptr + 2'd2) & 2'b11;

                        else
                            winner <= (rr_ptr + 2'd3) & 2'b11;

                    end
                end

                // =============================================
                // DECODE
                // =============================================

                DECODE: begin

                    req_type    <= request_packet[winner][37];
                    req_address <= request_packet[winner][36:32];

                    resp_id     <= winner;

                    rr_ptr      <= winner + 2'd1;

                    snoop_addr  <= request_packet[winner][36:32];

                end

                // =============================================
                // SNOOP_ISSUE
                // =============================================

                SNOOP_ISSUE: begin

                    snoop_pending <= ~(4'b0001 << winner);

                    if (req_type == 1'b0)
                        bus_inv <= 1'b1;
                    else
                        bus_rd <= 1'b1;

                    snoop_addr <= req_address;

                    // $display(
                    //     "[IC] SNOOP addr=%0d winner=%0d type=%0d time=%0t",
                    //     req_address,
                    //     winner,
                    //     req_type,
                    //     $time
                    // );

                end

                // =============================================
                // WAIT_SNOOP
                // =============================================

                WAIT_SNOOP: begin

                    // mantener broadcast activo
                    if (req_type == 1'b0)
                        bus_inv <= 1'b1;
                    else
                        bus_rd <= 1'b1;

                    // limpiar participantes que ya respondieron
                    snoop_pending <= snoop_pending & ~ready_c;

                    // capturar owner modificado
                    if (wb_valid != 4'b0000) begin

                        if (wb_valid[0]) begin
                            owner_found <= 1'b1;
                            owner_line  <= cache_line_c[0];
                        end
                        else if (wb_valid[1]) begin
                            owner_found <= 1'b1;
                            owner_line  <= cache_line_c[1];
                        end
                        else if (wb_valid[2]) begin
                            owner_found <= 1'b1;
                            owner_line  <= cache_line_c[2];
                        end
                        else begin
                            owner_found <= 1'b1;
                            owner_line  <= cache_line_c[3];
                        end

                    end

                    // apagar broadcast cuando termina
                    if (all_ready_c) begin
                        bus_inv <= 1'b0;
                        bus_rd  <= 1'b0;
                    end

                end

                // =============================================
                // MEM_ACCESS
                // =============================================

                MEM_ACCESS: begin

                    bus_inv <= 1'b0;
                    bus_rd  <= 1'b0;

                    if (!mem_cmd_issued) begin

                        mem_req     <= 1'b1;
                        mem_address <= req_address;

                        if (owner_found) begin

                            mem_we      <= 1'b1;
                            mem_data_in <= owner_line;

                            use_owner_line_in_respond <= 1'b1;

                        end
                        else begin

                            mem_we <= 1'b0;

                            use_owner_line_in_respond <= 1'b0;

                        end

                        mem_cmd_issued <= 1'b1;

                    end

                end

                // ============================================
                // RESPOND
                // =============================================
                RESPOND: begin

                    ic_ready <= 1'b1;

                    ic_tag <= req_address[4:3];

                    if (use_owner_line_in_respond)
                        ic_cache_line <= owner_line;
                    else
                        ic_cache_line <= mem_data_out;

                    mem_cmd_issued <= 1'b0;

                end

            endcase
        end
    end

endmodule
module Interconnect_FF #(
    parameter int SNOOP_WAIT_CYCLES = 4
)(
    input logic        clk,
    input logic        reset,

    // Cache -> IC
    input logic [3:0]  help,
    input logic [37:0] request_packet [3:0],
    input logic [3:0]  ready_c,

    // IC Broadcast
    output logic        ic_ready,
    output logic        bus_inv,        // Firefly no usa invalidaciones
    output logic        bus_rd,
    output logic        bus_update,
    output logic [1:0]  resp_id,
    output logic [4:0]  snoop_addr,
    output logic [1:0]  ic_tag,
    output logic [63:0] ic_cache_line,

    // IC -> memoria principal
    output logic        mem_req,
    output logic        mem_we,
    output logic [4:0]  mem_address,
    output logic [63:0] mem_data_in,

    // Desde memoria principal
    input logic [63:0] mem_data_out,
    input logic        mem_ready
);

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        SNOOP_ISSUE = 3'b001,
        WAIT_SNOOP  = 3'b010,
        MEM_ACCESS  = 3'b011,
        RESPOND     = 3'b100
    } state_t;

    state_t current_state, next_state;

    logic        req_type;           // 0=write, 1=read
    logic [4:0]  req_address;
    logic [31:0] req_data;

    logic        mem_cmd_issued;

    logic [1:0] rr_ptr;
    logic [1:0] winner;
    logic [1:0] selected_winner;

    // Evita doble servicio al mismo cache justo al volver a IDLE.
    logic        skip_cycle;
    logic [1:0]  last_served;

    logic [3:0] snoop_pending;
    logic       all_ready_c;
    logic [3:0] help_masked;
    logic [1:0] rr_ptr_safe;

    assign all_ready_c = (snoop_pending == 4'b0000);

    assign rr_ptr_safe = (^rr_ptr === 1'bx) ? 2'd0 : rr_ptr;

    always_comb begin
        help_masked = help;
        if (skip_cycle === 1'b1)
            help_masked[last_served] = 1'b0;
    end

    always_comb begin
        selected_winner = rr_ptr_safe;

        if (help_masked[rr_ptr_safe])
            selected_winner = rr_ptr_safe;
        else if (help_masked[(rr_ptr_safe + 2'd1) & 2'b11])
            selected_winner = (rr_ptr_safe + 2'd1) & 2'b11;
        else if (help_masked[(rr_ptr_safe + 2'd2) & 2'b11])
            selected_winner = (rr_ptr_safe + 2'd2) & 2'b11;
        else if (help_masked[(rr_ptr_safe + 2'd3) & 2'b11])
            selected_winner = (rr_ptr_safe + 2'd3) & 2'b11;
    end

    always_ff @(posedge clk) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (skip_cycle)
                    next_state = IDLE;
                else if (help_masked != 4'b0000)
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

    always_ff @(posedge clk) begin
        if (reset) begin
            bus_rd        <= 1'b0;
            bus_inv       <= 1'b0;
            bus_update    <= 1'b0;
            ic_ready      <= 1'b0;
            resp_id       <= 2'b0;
            snoop_addr    <= 5'b0;
            ic_tag        <= 2'b0;
            ic_cache_line <= 64'b0;

            mem_req       <= 1'b0;
            mem_we        <= 1'b0;
            mem_address   <= 5'b0;
            mem_data_in   <= 64'b0;

            req_type      <= 1'b0;
            req_address   <= 5'b0;
            req_data      <= 32'b0;

            mem_cmd_issued <= 1'b0;

            rr_ptr       <= 2'b0;
            winner       <= 2'b0;
            skip_cycle   <= 1'b0;
            last_served  <= 2'b0;

            snoop_pending <= 4'b0000;
        end else begin
            ic_ready   <= 1'b0;
            mem_req    <= 1'b0;
            mem_we     <= 1'b0;
            bus_rd     <= 1'b0;
            bus_inv    <= 1'b0;
            bus_update <= 1'b0;

            case (current_state)
                IDLE: begin
                    mem_cmd_issued <= 1'b0;
                    snoop_pending  <= 4'b0000;

                    if (skip_cycle) begin
                        skip_cycle <= 1'b0;
                    end else if (help_masked != 4'b0000) begin
                        winner <= selected_winner;

                        req_type    <= request_packet[selected_winner][37];
                        req_address <= request_packet[selected_winner][36:32];
                        req_data    <= request_packet[selected_winner][31:0];

                        resp_id    <= selected_winner;
                        snoop_addr <= request_packet[selected_winner][36:32];

                        rr_ptr <= selected_winner + 2'd1;
                    end
                end

                SNOOP_ISSUE: begin
                    snoop_pending <= ~(4'b0001 << winner);

                    bus_rd <= 1'b1;
                    if (req_type == 1'b0)
                        bus_update <= 1'b1;

                    snoop_addr <= req_address;
                    ic_tag <= req_address[4:3];

                    if (req_type == 1'b0)
                        ic_cache_line <= req_address[0] ? {req_data, 32'b0} : {32'b0, req_data};
                end

                WAIT_SNOOP: begin
                    bus_rd <= 1'b1;
                    if (req_type == 1'b0)
                        bus_update <= 1'b1;

                    snoop_pending <= snoop_pending & ~ready_c;

                    if (all_ready_c) begin
                        bus_rd <= 1'b0;
                        bus_update <= 1'b0;
                    end
                end

                MEM_ACCESS: begin
                    if (!mem_cmd_issued) begin
                        mem_req     <= 1'b1;
                        mem_address <= req_address;

                        if (req_type == 1'b0) begin
                            mem_we <= 1'b1;
                            mem_data_in <= req_address[0] ? {req_data, 32'b0} : {32'b0, req_data};
                        end else begin
                            mem_we <= 1'b0;
                        end

                        mem_cmd_issued <= 1'b1;
                    end
                end

                RESPOND: begin
                    ic_ready <= 1'b1;
                    ic_tag <= req_address[4:3];

                    if (req_type == 1'b0)
                        ic_cache_line <= req_address[0] ? {req_data, 32'b0} : {32'b0, req_data};
                    else
                        ic_cache_line <= mem_data_out;

                    mem_cmd_issued <= 1'b0;

                    skip_cycle  <= 1'b1;
                    last_served <= winner;
                end
            endcase
        end
    end

endmodule

module i2c_master_core (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire stop,
    input wire [6:0] addr,
    input wire rw,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg busy,
    output reg done,
    output reg ack_error,
    output reg arb_lost,
    inout wire sda,
    inout wire scl
);

    parameter CLK_FREQ = 100000000;
    parameter I2C_FREQ = 100000;

    localparam DIVIDER = CLK_FREQ / I2C_FREQ;
    localparam QUARTER = DIVIDER / 4;

    localparam S_IDLE = 0;
    localparam S_START = 1;
    localparam S_ADDR = 2;
    localparam S_RW = 3;
    localparam S_ACK = 4;
    localparam S_DATA = 5;
    localparam S_ACK2 = 6;
    localparam S_STOP = 7;

    reg [2:0] state;
    reg sda_o, scl_o;
    reg sda_oe, scl_oe;
    reg [15:0] cnt;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [7:0] rx_reg;
    
    wire sda_i, scl_i;
    assign sda = sda_oe? (sda_o? 1'bz : 1'b0) : 1'bz;
    assign scl = scl_oe? (scl_o? 1'bz : 1'b0) : 1'bz;
    assign sda_i = sda;
    assign scl_i = scl;
    
    reg stretch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            state <= S_IDLE;
            sda_o <= 1; scl_o <= 1;
            sda_oe <= 0; scl_oe <= 0;
            bit_cnt <= 0;
            busy <= 0; done <= 0;
            ack_error <= 0; arb_lost <= 0;
            data_out <= 0; rx_reg <= 0;
            stretch <= 0;
        end else begin
            if (scl_oe && scl_o &&!scl_i) begin
                stretch <= 1;
            end else begin
                stretch <= 0;
                if (cnt == DIVIDER - 1) cnt <= 0;
                else cnt <= cnt + 1;
            end

            if (!stretch) begin
                case (state)
                    S_IDLE: begin
                        busy <= 0; done <= 0; ack_error <= 0; arb_lost <= 0;
                        sda_oe <= 1; scl_oe <= 1;
                        sda_o <= 1; scl_o <= 1;
                        if (start) begin
                            state <= S_START;
                            busy <= 1;
                            shift_reg <= {addr, rw};
                            cnt <= 0;
                        end
                    end

                    S_START: begin
                        if (cnt == QUARTER) sda_o <= 0; 
                        else if (cnt == QUARTER*2) scl_o <= 0;
                        else if (cnt == QUARTER*3) begin
                            state <= S_ADDR;
                            bit_cnt <= 7;
                        end
                    end

                    S_ADDR: begin
                        if (cnt == 0) begin
                            sda_o <= shift_reg[bit_cnt];
                            if (sda_o &&!sda_i) begin 
                                arb_lost <= 1;
                                state <= S_IDLE;
                            end
                        end 
                        else if (cnt == QUARTER) scl_o <= 1;
                        else if (cnt == QUARTER*2) begin end 
                        else if (cnt == QUARTER*3) begin
                            scl_o <= 0;
                            if (bit_cnt == 0) state <= S_ACK;
                            else bit_cnt <= bit_cnt - 1;
                        end
                    end

                    S_ACK: begin
                        if (cnt == 0) begin
                            sda_oe <= 0; 
                        end
                        else if (cnt == QUARTER) scl_o <= 1;
                        else if (cnt == QUARTER*2) begin
                            if (sda_i) ack_error <= 1;
                        end
                        else if (cnt == QUARTER*3) begin
                            scl_o <= 0;
                            state <= S_DATA;
                            bit_cnt <= 7;
                            if (rw) sda_oe <= 0; 
                            else begin sda_oe <= 1; shift_reg <= data_in; end
                        end
                    end

                    S_DATA: begin
                        if (rw) begin
                            if (cnt == QUARTER) scl_o <= 1;
                            else if (cnt == QUARTER*2) rx_reg[bit_cnt] <= sda_i;
                            else if (cnt == QUARTER*3) begin
                                scl_o <= 0;
                                if (bit_cnt == 0) state <= S_ACK2;
                                else bit_cnt <= bit_cnt - 1;
                            end
                        end else begin 
                            if (cnt == 0) sda_o <= shift_reg[bit_cnt];
                            else if (cnt == QUARTER) scl_o <= 1;
                            else if (cnt == QUARTER*3) begin
                                scl_o <= 0;
                                if (bit_cnt == 0) state <= S_ACK2;
                                else bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end

                    S_ACK2: begin
                        if (rw) begin 
                             if (cnt == 0) begin sda_oe <= 1; sda_o <= stop; end 
                             else if (cnt == QUARTER) scl_o <= 1;
                             else if (cnt == QUARTER*3) begin scl_o <= 0; done <= 1; data_out <= rx_reg; state <= stop? S_STOP : S_IDLE; end
                        end else begin 
                             if (cnt == 0) sda_oe <= 0;
                             else if (cnt == QUARTER) scl_o <= 1;
                             else if (cnt == QUARTER*2) if (sda_i) ack_error <= 1;
                             else if (cnt == QUARTER*3) begin scl_o <= 0; done <= 1; state <= stop? S_STOP : S_IDLE; end
                        end
                    end

                    S_STOP: begin
                        if (cnt == 0) begin sda_oe <= 1; sda_o <= 0; end
                        else if (cnt == QUARTER) scl_o <= 1;
                        else if (cnt == QUARTER*2) sda_o <= 1;
                        else if (cnt == QUARTER*3) state <= S_IDLE;
                    end
                endcase
            end
        end
    end
endmodule

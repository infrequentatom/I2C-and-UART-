module i2c_slave_core (
    input wire clk,
    input wire rst_n,
    inout wire sda,
    inout wire scl,
    output reg [7:0] rx_data,
    input wire [7:0] tx_data,
    output reg data_valid
);

    parameter SLAVE_ADDR = 7'h50;

    localparam S_IDLE = 0;
    localparam S_ADDR = 1;
    localparam S_RW = 2;
    localparam S_ACK = 3;
    localparam S_DATA_RX = 4;
    localparam S_DATA_TX = 5;
    localparam S_ACK_WAIT = 6;

    reg [2:0] state;
    reg sda_o, sda_oe;
    reg [2:0] bit_cnt;
    reg [6:0] addr_reg;
    reg rw_reg;
    reg [7:0] shift_reg;
    
    reg sda_s, scl_s, sda_old, scl_old;
    
    wire sda_i, scl_i;
    assign sda = sda_oe? (sda_o? 1'bz : 1'b0) : 1'bz;
    assign scl = 1'bz; 
    assign sda_i = sda;
    assign scl_i = scl;
    
    wire start_det = scl_s &&!sda_s && sda_old;
    wire stop_det = scl_s && sda_s &&!sda_old;
    wire scl_rise = scl_s &&!scl_old;
    wire scl_fall =!scl_s && scl_old;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_s <= 1; scl_s <= 1;
            sda_old <= 1; scl_old <= 1;
        end else begin
            sda_s <= sda; scl_s <= scl;
            sda_old <= sda_s; scl_old <= scl_s;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            sda_oe <= 0;
            bit_cnt <= 0;
            data_valid <= 0;
            rx_data <= 0;
        end else begin
            if (start_det) begin
                state <= S_ADDR;
                bit_cnt <= 6;
                sda_oe <= 0;
            end else if (stop_det) begin
                state <= S_IDLE;
                sda_oe <= 0;
            end else begin
                case (state)
                    S_IDLE: begin
                        sda_oe <= 0;
                    end

                    S_ADDR: begin
                        if (scl_rise) begin
                            addr_reg[bit_cnt] <= sda_s;
                            if (bit_cnt == 0) state <= S_RW;
                            else bit_cnt <= bit_cnt - 1;
                        end
                    end

                    S_RW: begin
                        if (scl_rise) begin
                            rw_reg <= sda_s;
                            if (addr_reg == SLAVE_ADDR) state <= S_ACK;
                            else state <= S_IDLE;
                        end
                    end

                    S_ACK: begin
                        if (!scl_s) begin 
                            sda_oe <= 1; sda_o <= 0; 
                        end
                        if (scl_fall) begin 
                            sda_oe <= 0;
                            bit_cnt <= 7;
                            if (rw_reg) begin 
                                state <= S_DATA_TX;
                                shift_reg <= tx_data;
                            end else begin
                                state <= S_DATA_RX;
                            end
                        end
                    end

                    S_DATA_RX: begin
                        if (scl_rise) begin
                            shift_reg[bit_cnt] <= sda_s;
                            if (bit_cnt == 0) begin
                                rx_data <= {shift_reg[7:1], sda_s};
                                data_valid <= 1;
                                state <= S_ACK; 
                            end else bit_cnt <= bit_cnt - 1;
                        end
                    end
                    
                    S_DATA_TX: begin
                         if (!scl_s) begin
                            sda_oe <= 1;
                            sda_o <= shift_reg[bit_cnt];
                         end
                         if (scl_fall) begin
                            if (bit_cnt == 0) begin
                                sda_oe <= 0;
                                state <= S_ACK_WAIT;
                            end else bit_cnt <= bit_cnt - 1;
                         end
                    end

                    S_ACK_WAIT: begin
                        if (scl_rise) begin
                            if (sda_s) state <= S_IDLE; 
                            else begin 
                                state <= S_DATA_TX; 
                                bit_cnt <= 7; 
                            end
                        end
                    end
                endcase
            end
        end
    end
endmodule

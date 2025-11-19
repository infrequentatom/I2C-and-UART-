`timescale 1ns / 1ps

module uart_tx #(
    parameter P_DATA_BITS   = 8,
    parameter P_PARITY_TYPE = 0,
    parameter P_STOP_BITS   = 1
) (
    input  wire i_clk,
    input  wire i_rst_n,
    input  wire i_tx_data,
    input  wire i_tx_data_valid,
    output reg  o_tx_ready,
    output reg  o_serial_tx
);

    localparam P_PARITY_BITS = (P_PARITY_TYPE == 0)? 0 : 1;
    localparam P_FRAME_WIDTH = 1 + P_DATA_BITS + P_PARITY_BITS + P_STOP_BITS;
    
    reg [1:0] r_state;
    reg r_shifter;
    reg [3:0] r_bit_cnt;

    wire w_parity = (P_PARITY_TYPE == 1)? ^i_tx_data : (P_PARITY_TYPE == 2)? ~^i_tx_data : 0;
    
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= 0;
            o_tx_ready <= 1;
            o_serial_tx <= 1;
            r_bit_cnt <= 0;
        end else begin
            case (r_state)
                0: begin
                    o_tx_ready <= 1;
                    if (i_tx_data_valid) begin
                        o_tx_ready <= 0;
                        if (P_PARITY_TYPE == 0)
                            r_shifter <= {{(P_STOP_BITS){1'b1}}, i_tx_data, 1'b0};
                        else
                            r_shifter <= {{(P_STOP_BITS){1'b1}}, w_parity, i_tx_data, 1'b0};
                        
                        r_state <= 1;
                        r_bit_cnt <= 0;
                    end
                end
                1: begin
                    o_serial_tx <= r_shifter;
                    r_shifter <= r_shifter >> 1;
                    if (r_bit_cnt == P_FRAME_WIDTH-1) begin
                        r_state <= 0;
                    end else begin
                        r_bit_cnt <= r_bit_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule

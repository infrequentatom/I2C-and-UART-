`timescale 1ns / 1ps

module uart_rx #(
    parameter P_DATA_BITS       = 8,
    parameter P_PARITY_TYPE     = 0,
    parameter P_STOP_BITS       = 1
) (
    input  wire i_clk,
    input  wire i_rst_n,
    input  wire i_serial_rx,
    output reg o_rx_data,
    output reg o_rx_data_valid,
    output reg o_parity_err,
    output reg o_framing_err
);

    reg [2:0] r_state;
    reg [3:0] r_sample_cnt;
    reg [3:0] r_bit_cnt;
    reg [2:0] r_rx_sync;
    reg r_data_temp;
    reg r_parity_bit, r_stop_bit;
    
    wire w_rx_in = r_rx_sync[1];
    wire w_vote = (r_rx_sync[1] & r_rx_sync[2]) | (r_rx_sync[1] & r_rx_sync) | (r_rx_sync[2] & r_rx_sync);
    wire w_calc_parity = (P_PARITY_TYPE == 1)? ^r_data_temp : (P_PARITY_TYPE == 2)? ~^r_data_temp : 0;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) r_rx_sync <= 3'b111;
        else r_rx_sync <= {r_rx_sync[1:0], i_serial_rx};
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= 0;
            r_sample_cnt <= 0;
            r_bit_cnt <= 0;
            o_rx_data_valid <= 0;
            o_parity_err <= 0;
            o_framing_err <= 0;
        end else begin
            o_rx_data_valid <= 0;
            case (r_state)
                0: if (!w_rx_in) begin r_state <= 1; r_sample_cnt <= 0; end
                1: begin // Start Bit
                    if (r_sample_cnt == 7) begin
                        if (!w_vote) begin r_state <= 2; r_sample_cnt <= 0; r_bit_cnt <= 0; end
                        else r_state <= 0;
                    end else r_sample_cnt <= r_sample_cnt + 1;
                end
                2: begin // Data Bits
                    if (r_sample_cnt == 15) begin
                        r_sample_cnt <= 0;
                        r_data_temp[r_bit_cnt] <= w_vote;
                        if (r_bit_cnt == P_DATA_BITS-1) r_state <= (P_PARITY_TYPE!= 0)? 3 : 4;
                        else r_bit_cnt <= r_bit_cnt + 1;
                    end else r_sample_cnt <= r_sample_cnt + 1;
                end
                3: begin // Parity
                    if (r_sample_cnt == 15) begin
                        r_sample_cnt <= 0;
                        r_parity_bit <= w_vote;
                        r_state <= 4;
                    end else r_sample_cnt <= r_sample_cnt + 1;
                end
                4: begin // Stop
                    if (r_sample_cnt == 15) begin
                        r_stop_bit <= w_vote;
                        r_state <= 5;
                    end else r_sample_cnt <= r_sample_cnt + 1;
                end
                5: begin // Cleanup
                    o_rx_data <= r_data_temp;
                    o_rx_data_valid <= 1;
                    o_framing_err <=!r_stop_bit;
                    if (P_PARITY_TYPE!= 0) o_parity_err <= (r_parity_bit!= w_calc_parity);
                    r_state <= 0;
                end
            endcase
        end
    end
endmodule

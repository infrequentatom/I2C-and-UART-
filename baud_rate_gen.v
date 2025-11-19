`timescale 1ns / 1ps

module baud_rate_gen #(
    parameter P_SYS_CLK_FREQ    = 100_000_000,
    parameter P_BAUD_RATE       = 115200,
    parameter P_OVERSAMPLE_RATE = 16
) (
    input  wire i_sys_clk,
    input  wire i_sys_rst_n,
    output wire o_baud_tick,
    output wire o_oversample_tick
);

    localparam C_ACCUM_WIDTH = 20;
    localparam C_INC_VAL = ((P_BAUD_RATE * P_OVERSAMPLE_RATE * (1 << C_ACCUM_WIDTH)) / P_SYS_CLK_FREQ);

    reg r_accum;
    reg [3:0] r_tick_count;
    wire w_accum_overflow;
    wire w_next_accum;

    assign w_next_accum = r_accum + C_INC_VAL;
    assign w_accum_overflow = w_next_accum;
    assign o_oversample_tick = w_accum_overflow;
    assign o_baud_tick = (r_tick_count == 0) && o_oversample_tick;

    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n)
            r_accum <= 0;
        else
            r_accum <= w_next_accum;
    end

    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n)
            r_tick_count <= 0;
        else if (o_oversample_tick)
            r_tick_count <= r_tick_count + 1;
    end

endmodule

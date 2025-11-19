`timescale 1ns / 1ps

module async_fifo #(
    parameter P_DATA_WIDTH     = 8,
    parameter P_FIFO_DEPTH_BITS = 4
) (
    input  wire i_wr_clk,
    input  wire i_wr_rst_n,
    input  wire i_wr_en,
    input  wire i_wr_data,
    output wire o_full,
  
    input  wire i_rd_clk,
    input  wire i_rd_rst_n,
    input  wire i_rd_en,
    output wire o_rd_data,
    output wire o_empty
);

    localparam P_PTR_WIDTH = P_FIFO_DEPTH_BITS + 1;

    reg r_mem;
    reg r_wr_ptr_bin, r_rd_ptr_bin;
    wire w_wr_ptr_gray, w_rd_ptr_gray;
    wire r_wr_ptr_gray_sync, r_rd_ptr_gray_sync;
    wire r_wr_ptr_bin_sync, r_rd_ptr_bin_sync;

    always @(posedge i_wr_clk) begin
        if (i_wr_en &&!o_full)
            r_mem] <= i_wr_data;
    end

    assign o_rd_data = r_mem];

    always @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if (!i_wr_rst_n) r_wr_ptr_bin <= 0;
        else if (i_wr_en &&!o_full) r_wr_ptr_bin <= r_wr_ptr_bin + 1;
    end

    always @(posedge i_rd_clk or negedge i_rd_rst_n) begin
        if (!i_rd_rst_n) r_rd_ptr_bin <= 0;
        else if (i_rd_en &&!o_empty) r_rd_ptr_bin <= r_rd_ptr_bin + 1;
    end

    assign w_wr_ptr_gray = r_wr_ptr_bin ^ (r_wr_ptr_bin >> 1);
    assign w_rd_ptr_gray = r_rd_ptr_bin ^ (r_rd_ptr_bin >> 1);

    cdc_sync #(P_PTR_WIDTH) sync_rd_to_wr (i_wr_clk, i_wr_rst_n, w_rd_ptr_gray, r_rd_ptr_gray_sync);
    cdc_sync #(P_PTR_WIDTH) sync_wr_to_rd (i_rd_clk, i_rd_rst_n, w_wr_ptr_gray, r_wr_ptr_gray_sync);

    gray2bin #(P_PTR_WIDTH) g2b_rd (r_rd_ptr_gray_sync, r_rd_ptr_bin_sync);
    gray2bin #(P_PTR_WIDTH) g2b_wr (r_wr_ptr_gray_sync, r_wr_ptr_bin_sync);

    assign o_full  = (r_wr_ptr_bin == r_rd_ptr_bin_sync) && 
                     (r_wr_ptr_bin!= r_rd_ptr_bin_sync);
    assign o_empty = (r_rd_ptr_bin == r_wr_ptr_bin_sync);

endmodule

module cdc_sync #(parameter W=1) (input clk, rst_n, input in, output reg out);
    reg r_s1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {out, r_s1} <= 0;
        else {out, r_s1} <= {r_s1, in};
    end
endmodule

module gray2bin #(parameter W=5) (input gray, output bin);
    genvar i;
    generate
        for(i=0; i<W; i=i+1) assign bin[i] = ^gray;
    endgenerate
endmodule

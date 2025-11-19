`timescale 1ns / 1ps

module uart_top #(
    parameter P_SYS_CLK_FREQ    = 100_000_000,
    parameter P_BAUD_RATE       = 115200,
    parameter P_DATA_BITS       = 8,
    parameter P_PARITY_TYPE     = 0,
    parameter P_STOP_BITS       = 1,
    parameter P_FIFO_DEPTH_BITS = 4
) (
    input  wire i_sys_clk,
    input  wire i_sys_rst_n,
    
    input  wire i_tx_data,
    input  wire i_tx_write_en,
    output wire o_tx_full,
    
    output wire o_rx_data,
    output wire o_rx_valid,
    input  wire i_rx_read_en,
    output wire o_rx_empty,
    
    input  wire i_serial_rx,
    output wire o_serial_tx,
    
    output wire o_rx_parity_err,
    output wire o_rx_framing_err,
    output wire o_rx_overrun_err
);

    wire w_baud_tick, w_oversample_tick;
    wire w_tx_fifo_data;
    wire w_tx_fifo_valid_n, w_tx_ready;
    
    wire w_rx_data_raw;
    wire w_rx_data_valid_raw, w_rx_parity_err_raw, w_rx_framing_err_raw, w_rx_fifo_full;
    wire w_rx_fifo_rd_data;

    baud_rate_gen #(P_SYS_CLK_FREQ, P_BAUD_RATE, 16) baud_gen_inst (
       .i_sys_clk(i_sys_clk),.i_sys_rst_n(i_sys_rst_n),
       .o_baud_tick(w_baud_tick),.o_oversample_tick(w_oversample_tick)
    );

    async_fifo #(P_DATA_BITS, P_FIFO_DEPTH_BITS) tx_fifo_inst (
       .i_wr_clk(i_sys_clk),.i_wr_rst_n(i_sys_rst_n),.i_wr_en(i_tx_write_en),.i_wr_data(i_tx_data),.o_full(o_tx_full),
       .i_rd_clk(w_baud_tick),.i_rd_rst_n(i_sys_rst_n),.i_rd_en(w_tx_ready),.o_rd_data(w_tx_fifo_data),.o_empty(w_tx_fifo_valid_n)
    );

    uart_tx #(P_DATA_BITS, P_PARITY_TYPE, P_STOP_BITS) tx_inst (
       .i_clk(w_baud_tick),.i_rst_n(i_sys_rst_n),
       .i_tx_data(w_tx_fifo_data),.i_tx_data_valid(!w_tx_fifo_valid_n),
       .o_tx_ready(w_tx_ready),.o_serial_tx(o_serial_tx)
    );

    uart_rx #(P_DATA_BITS, P_PARITY_TYPE, P_STOP_BITS) rx_inst (
       .i_clk(w_oversample_tick),.i_rst_n(i_sys_rst_n),
       .i_serial_rx(i_serial_rx),
       .o_rx_data(w_rx_data_raw),.o_rx_data_valid(w_rx_data_valid_raw),
       .o_parity_err(w_rx_parity_err_raw),.o_framing_err(w_rx_framing_err_raw)
    );

    async_fifo #(P_DATA_BITS+2, P_FIFO_DEPTH_BITS) rx_fifo_inst (
       .i_wr_clk(w_oversample_tick),.i_wr_rst_n(i_sys_rst_n),
       .i_wr_en(w_rx_data_valid_raw),.i_wr_data({w_rx_framing_err_raw, w_rx_parity_err_raw, w_rx_data_raw}),
       .o_full(w_rx_fifo_full),
       .i_rd_clk(i_sys_clk),.i_rd_rst_n(i_sys_rst_n),
       .i_rd_en(i_rx_read_en),.o_rd_data(w_rx_fifo_rd_data),.o_empty(o_rx_empty)
    );

    assign {o_rx_framing_err, o_rx_parity_err, o_rx_data} = w_rx_fifo_rd_data;
    assign o_rx_valid =!o_rx_empty;
    assign o_rx_overrun_err = w_rx_data_valid_raw && w_rx_fifo_full;

endmodule

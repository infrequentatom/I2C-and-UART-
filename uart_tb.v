`timescale 1ns / 1ps

module uart_tb;
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD = 115200;
    
    reg clk = 0, rst_n = 0;
    reg [7:0] tx_data;
    reg tx_wr_en;
    wire tx_full, rx_valid, rx_empty, ser_tx;
    wire [7:0] rx_data;
    reg rx_rd_en = 0;
    
    always #5 clk = ~clk;

    uart_top #(CLK_FREQ, BAUD) uut (
       .i_sys_clk(clk),.i_sys_rst_n(rst_n),
       .i_tx_data(tx_data),.i_tx_write_en(tx_wr_en),.o_tx_full(tx_full),
       .o_rx_data(rx_data),.o_rx_valid(rx_valid),.i_rx_read_en(rx_rd_en),.o_rx_empty(rx_empty),
       .i_serial_rx(ser_tx),.o_serial_tx(ser_tx) // Loopback
    );

    initial begin
        rst_n = 0; #100; rst_n = 1; #100;
        
        // Test Loopback
        tx_data = 8'hA5; tx_wr_en = 1; 
        @(posedge clk); tx_wr_en = 0;
        
        wait(rx_valid);
        rx_rd_en = 1; @(posedge clk); rx_rd_en = 0;
        
        if (rx_data === 8'hA5) $display("PASSED: 0xA5 Loopback");
        else $display("FAILED: Expected 0xA5, got %h", rx_data);
        
        $finish;
    end
endmodule

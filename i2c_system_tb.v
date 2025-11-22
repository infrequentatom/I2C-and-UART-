`timescale 1ns/1ps

module i2c_system_tb;

    reg clk;
    reg rst_n;
    reg start, stop;
    reg [6:0] addr;
    reg rw;
    reg [7:0] tx_byte;
    wire [7:0] rx_byte;
    wire busy, done, ack_error, arb_lost;
    wire sda, scl;
    
    wire [7:0] slave_rx;
    wire slave_valid;
    reg [7:0] slave_tx_data;

    pullup(sda);
    pullup(scl);

    i2c_master_core #(.CLK_FREQ(100000000),.I2C_FREQ(400000)) u_master (
       .clk(clk),.rst_n(rst_n),
       .start(start),.stop(stop),
       .addr(addr),.rw(rw),
       .data_in(tx_byte),.data_out(rx_byte),
       .busy(busy),.done(done),
       .ack_error(ack_error),.arb_lost(arb_lost),
       .sda(sda),.scl(scl)
    );

    i2c_slave_core #(.SLAVE_ADDR(7'h50)) u_slave (
       .clk(clk),.rst_n(rst_n),
       .sda(sda),.scl(scl),
       .rx_data(slave_rx),.tx_data(slave_tx_data),
       .data_valid(slave_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    initial begin
        rst_n = 0;
        start = 0; stop = 0;
        addr = 0; rw = 0; tx_byte = 0;
        slave_tx_data = 8'hA5;
        
        #100 rst_n = 1;
        #100;

        // TEST 1: WRITE 0x55 to Slave 0x50
        $display("TEST 1: Master Write 0x55 to Slave 0x50");
        addr = 7'h50; rw = 0; tx_byte = 8'h55;
        start = 1;
        @(posedge clk); start = 0;
        
        wait(done);
        if (slave_rx == 8'h55 &&!ack_error) $display("PASS: Slave received 0x55");
        else $display("FAIL: Slave rx = %h, Error = %b", slave_rx, ack_error);
        
        stop = 1;
        @(posedge clk); stop = 0;
        #1000;

        // TEST 2: READ from Slave 0x50 (expecting 0xA5)
        $display("TEST 2: Master Read from Slave 0x50");
        addr = 7'h50; rw = 1;
        start = 1;
        @(posedge clk); start = 0;
        
        wait(done);
        if (rx_byte == 8'hA5 &&!ack_error) $display("PASS: Master received 0xA5");
        else $display("FAIL: Master rx = %h", rx_byte);

        stop = 1;
        @(posedge clk); stop = 0;
        #1000;

        // TEST 3: NACK from invalid address
        $display("TEST 3: Address NACK Check");
        addr = 7'h20; rw = 0;
        start = 1;
        @(posedge clk); start = 0;
        
        wait(done);
        if (ack_error) $display("PASS: Correctly received NACK");
        else $display("FAIL: Did not receive NACK");

        stop = 1;
        @(posedge clk); stop = 0;
        
        #2000 $finish;
    end
endmodule

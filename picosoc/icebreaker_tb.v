/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`timescale 1 ns / 1 ps

module testbench;
	reg clk;
	always #5 clk = (clk === 1'b0);

//PLL bypass (ignore)
	initial begin
		force uut.clk_16mhz  = clk;
		force uut.pll_locked = 1'b1;
	end
	//
	localparam ser_half_period = 53;
	event ser_sample;


	// Count read-buffer hits vs misses on the SoC clock to measure how often the read buffer serves a read instantly instead of going to RAM
	integer readbuf_hits  = 0;
	integer ram_read_miss = 0;

	always @(posedge clk) begin
		if (uut.soc.readbuf_hit)
			readbuf_hits <= readbuf_hits + 1;
		if (uut.soc.ram_ready && (uut.soc.mem_wstrb == 4'b0000))
			ram_read_miss <= ram_read_miss + 1;
	end
	//

	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);

		end


	wire led1, led2, led3, led4, led5;
	wire ledr_n, ledg_n;

	wire [6:0] leds = {!ledg_n, !ledr_n, led5, led4, led3, led2, led1};

	wire ser_rx;
	wire ser_tx;

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;
	wire flash_io2;
	wire flash_io3;

	integer cyc = 0, edges = 0, start_cyc = 0, start_hits = 0, start_miss = 0;
	reg led1_d = 1'b0;

	always @(posedge clk) begin
		led1_d <= led1;
		if (uut.resetn) begin
			cyc <= cyc + 1;
			if (led1 !== led1_d) begin
				if (edges == 0) begin
					start_cyc <= cyc; start_hits <= readbuf_hits;
					start_miss <= ram_read_miss; edges <= 1;
				end else if (edges == 1) begin
					$display("cycles for one pass: %0d", cyc - start_cyc);
					$display("read-buffer hits: %0d", readbuf_hits - start_hits);
					$display("RAM read misses: %0d", ram_read_miss - start_miss);
					if ((readbuf_hits-start_hits)+(ram_read_miss-start_miss) > 0)
						$display("hit rate: %0d%%", (100*(readbuf_hits-start_hits))/((readbuf_hits-start_hits)+(ram_read_miss-start_miss)));
					$finish;
				end
			end
		end
	end

	always @(posedge clk)
		if (cyc > 30000000) $finish;

	icebreaker #(
		// We limit the amount of memory in simulation
		// in order to avoid reduce simulation time
		// required for intialization of RAM
		.MEM_WORDS(256)
	) uut (
		.clk      (clk      ),
		.led1     (led1     ),
		.led2     (led2     ),
		.led3     (led3     ),
		.led4     (led4     ),
		.led5     (led5     ),
		.ledr_n   (ledr_n   ),
		.ledg_n   (ledg_n   ),
		.ser_rx   (ser_rx   ),
		.ser_tx   (ser_tx   ),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.flash_io2(flash_io2),
		.flash_io3(flash_io3)
	);

	spiflash spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(flash_io2),
		.io3(flash_io3)
	);

	reg [7:0] buffer;

	always begin
		@(negedge ser_tx);

		repeat (ser_half_period) @(posedge clk);
		-> ser_sample; // start bit

		repeat (8) begin
			repeat (ser_half_period) @(posedge clk);
			repeat (ser_half_period) @(posedge clk);
			buffer = {ser_tx, buffer[7:1]};
			-> ser_sample; // data bit
		end

		repeat (ser_half_period) @(posedge clk);
		repeat (ser_half_period) @(posedge clk);
		-> ser_sample; // stop bit

		if (buffer < 32 || buffer >= 127)
			$display("Serial data: %d", buffer);
		else
			$display("Serial data: '%c'", buffer);
	end
endmodule
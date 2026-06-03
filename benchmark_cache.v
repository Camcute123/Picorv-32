`timescale 1 ns / 1 ps

module benchmark_cache;

reg clk = 0;
reg resetn = 0;

wire        iomem_valid;
reg         iomem_ready = 0;
wire [3:0]  iomem_wstrb;
wire [31:0] iomem_addr;
wire [31:0] iomem_wdata;
reg  [31:0] iomem_rdata = 0;

wire ser_tx;
wire flash_csb;
wire flash_clk;

wire flash_io0_oe;
wire flash_io1_oe;
wire flash_io2_oe;
wire flash_io3_oe;

wire flash_io0_do;
wire flash_io1_do;
wire flash_io2_do;
wire flash_io3_do;

integer cycle_count;
integer ram_access_count;
integer readbuf_hit_count;

always #5 clk = ~clk;

picosoc dut (
    .clk(clk),
    .resetn(resetn),

    .iomem_valid(iomem_valid),
    .iomem_ready(iomem_ready),
    .iomem_wstrb(iomem_wstrb),
    .iomem_addr(iomem_addr),
    .iomem_wdata(iomem_wdata),
    .iomem_rdata(iomem_rdata),

    .irq_5(1'b0),
    .irq_6(1'b0),
    .irq_7(1'b0),

    .ser_tx(ser_tx),
    .ser_rx(1'b1),

    .flash_csb(flash_csb),
    .flash_clk(flash_clk),

    .flash_io0_oe(flash_io0_oe),
    .flash_io1_oe(flash_io1_oe),
    .flash_io2_oe(flash_io2_oe),
    .flash_io3_oe(flash_io3_oe),

    .flash_io0_do(flash_io0_do),
    .flash_io1_do(flash_io1_do),
    .flash_io2_do(flash_io2_do),
    .flash_io3_do(flash_io3_do),

    .flash_io0_di(1'b0),
    .flash_io1_di(1'b0),
    .flash_io2_di(1'b0),
    .flash_io3_di(1'b0)
);

always @(posedge clk) begin
    if (!resetn) begin
        cycle_count <= 0;
        ram_access_count <= 0;
        readbuf_hit_count <= 0;
    end else begin
        cycle_count <= cycle_count + 1;

        if (dut.ram_ready)
            ram_access_count <= ram_access_count + 1;

        if (dut.readbuf_hit)
            readbuf_hit_count <= readbuf_hit_count + 1;
    end
end

initial begin
    $dumpfile("benchmark_cache.vcd");
    $dumpvars(0, benchmark_cache);

    #100;
    resetn = 1;

    #5000000;

    $display("===== Cache Benchmark Result =====");
    $display("Cycles           = %0d", cycle_count);
    $display("RAM accesses     = %0d", ram_access_count);
    $display("Read buffer hits = %0d", readbuf_hit_count);

    $finish;
end

spiflash spiflash (
    .csb(flash_csb),
    .clk(flash_clk),
    .io0(flash_io0_do),
    .io1(flash_io1_di),
    .io2(flash_io2_di),
    .io3(flash_io3_di)
);

endmodule
// Copyright 2014 Brian Swetland <swetland@frotz.net>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`timescale 1ns / 1ps

module top(
	input clk,
	output [3:0]led,

	output phy0_clk,
	output phy0_txen,
	output phy0_tx0,
	output phy0_mdc,
	output phy0_mdio,
	input phy0_crs,
	input phy0_rx0,
	input phy0_rx1
	);

assign led = 0;

wire clk50;

mmcm_1in_3out #(
	.CLKIN_PERIOD(8.0),
	.VCO_MUL(8.000),
	.VCO_DIV(1),
	.OUT0_DIV(20.000),
	.OUT1_DIV(10),
	.OUT2_DIV(10)
	) mmcm0 (
	.i_clk(clk),
	.o_clk0(clk50),
	.o_clk1(),
	.o_clk2()
	);

assign phy0_clk = clk50;
assign phy0_mdc = 1;
assign phy0_mdio = 0;
assign phy0_tx0 = 0;
assign phy0_txen = 0;

wire [7:0]rxdata;
wire rxvalid;
wire rxeop;

(* keep_hierarchy = "yes" *)
eth_rmii_rx phy0(
	.clk50(clk50),
	.rx0(phy0_rx0),
	.rx1(phy0_rx1),
	.crs_dv(phy0_crs),
	.data(rxdata),
	.valid(rxvalid),
	.eop(rxeop)
	);

(* keep_hierarchy = "yes" *)
packetlogger log0(
	.clk50(clk50),
	.rxdata(rxdata),
	.rxvalid(rxvalid),
	.rxeop(rxeop)
	);

endmodule

module packetlogger(
	input clk50,
	input [7:0]rxdata,
	input rxvalid,
	input rxeop
	);

reg [11:0]rdptr = 0;
reg [11:0]rxptr = 0;
reg [11:0]next_rdptr;
reg [11:0]next_rxptr;

wire [8:0]rdata;
reg bufrd = 0;

ram rxbuffer(
	.clk(clk50),
	.wen(rxvalid | rxeop),
	.waddr(rxptr),
	.wdata( { rxeop, rxdata } ),
	.ren(bufrd),
	.raddr(rdptr),
	.rdata(rdata)
	);

wire [31:0]dbg_wdata;
reg [31:0]dbg_rdata;
wire [2:0]dbg_addr;
wire dbg_rd;
wire dbg_wr;

always_comb begin
	next_rxptr = rxptr;
	next_rdptr = rdptr;
	bufrd = 0;
	if (rxvalid | rxeop) begin
		next_rxptr = rxptr + 1;
	end
	if (dbg_rd) begin
		if (dbg_addr == 1) begin
			next_rdptr = rdptr + 1;
			bufrd = 1;
		end
	end
	case (dbg_addr)
	0: dbg_rdata = 32'h12345678;
	1: dbg_rdata = { 23'd0, rdata };
	2: dbg_rdata = { 20'd0, rxptr };
	default: dbg_rdata = 0;
	endcase
end

always_ff @(posedge clk50) begin
	rxptr <= next_rxptr;
	rdptr <= next_rdptr;
end

(* keep_hierarchy = "yes" *)
jtag_debug_port port0(
	.clk(clk50),
	.o_wdata(dbg_wdata),
	.i_rdata(dbg_rdata),
	.o_addr(dbg_addr),
	.o_rd(dbg_rd),
	.o_wr(dbg_wr)
	);

endmodule

module ram(
	input clk,
	input ren,
	input [11:0]raddr,
	output reg [8:0]rdata,
	input wen,
	input [11:0]waddr,
	input [8:0]wdata
	);

reg [8:0]memory[0:4095];

always_ff @(posedge clk) begin
	if (ren)
		rdata <= memory[raddr];
	if (wen)
		memory[waddr] <= wdata;
end

endmodule

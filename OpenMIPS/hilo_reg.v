`include "defines.v"

/* 將存取記憶體階段的運算結果，在下一個時脈傳遞到回寫階段 */
module hilo_reg(clk, rst, we, hi_i, lo_i, hi_o, lo_o);

	input wire							clk;				/* 時脈訊號 */
	input wire 							rst;				/* 重設訊號 */
	
	/* 寫入連接埠 */
	input wire							we;					/* HI、LO暫存器寫入啟用訊號 */
	input wire [`RegBus]		 		hi_i;				/* 要寫入HI暫存器的值 */
	input wire [`RegBus]				lo_i;				/* 要寫入LO暫存器的值 */
	
	/* 讀取連接埠 */
	output reg [`RegBus]				hi_o;				/* HI暫存器的值 */
	output reg [`RegBus]				lo_o;				/* LO暫存器的值 */
	
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				begin
					hi_o	<=	`NOPRegAddr;
					lo_o	<=	`WriteDisable;
				end
			else if(we == `WriteEnable)
				begin
					hi_o	<=	hi_i;
					lo_o	<=	lo_i;
				end
		end
		
endmodule

`include "defines.v"

/* 實現32個32位元通用整數暫存器，可以同時進行兩個暫存器的讀取操作和一個暫存器的寫入操作 */
/* 寫入暫存器操作為序向邏輯電路，寫入操作發生在時脈訊號的上升緣 */
/* 讀取暫存器操作為組合邏輯電路，意即一旦addr1或addr2發生變化時，會立即給出新位址對應的暫存器的值 */
module regfile(clk, rst, we, waddr, wdata, re1, raddr1, rdata1, re2, raddr2, rdata2);

	input wire 						clk;			/* 時脈訊號 */
	input wire 						rst;			/* 重設訊號，高電壓有效 */
	
	/* 寫入連接埠 */
	input wire						we;				/* 寫入啟用訊號 */
	input wire [`RegAddrBus] 		waddr;			/* 要寫入的暫存器位址 */
	input wire [`RegBus]			wdata;			/* 要寫入的資料 */
	
	/* 讀取連接埠1 */
	input wire						re1;			/* 第一個讀取暫存器連接埠讀取啟用訊號 */
	input wire [`RegAddrBus] 		raddr1;			/* 第一個讀取暫存器連接埠要讀取的暫存器的位址 */
	output reg [`RegBus]			rdata1;			/* 第一個讀取暫存器連接埠輸出的暫存器的值 */
	
	/* 讀取連接埠2 */
	input wire						re2;			/* 第二個讀取暫存器連接埠讀取啟用訊號 */
	input wire [`RegAddrBus] 		raddr2;			/* 第二個讀取暫存器連接埠要讀取的暫存器的位址 */
	output reg [`RegBus]			rdata2;			/* 第二個讀取暫存器連接埠輸出的暫存器的值 */
	
	/* 定義32個32位元暫存器 */
	reg [`RegBus] 	regs[0:`RegNum - 1];
			
	/* 寫入操作 */		
	always @(posedge clk)
		begin
			if(rst == `RstDisable)
				begin
					/* 若寫入啟用訊號有效，且寫入目的暫存器不等於0(因MIPS架構規定$0的值只能為0，所以不能寫入)，即進行寫入動作 */
					if((we == `WriteEnable) && (waddr != `RegNumLog2'h0))
						regs[waddr] <= wdata;
				end
		end
	
	/* 讀取連接埠1的讀取操作 */	
	always @( * )
		begin
			/* 若重設訊號有效時，第一個讀取暫存器連接埠的輸出始終為0 */
			if(rst == `RstEnable)
				rdata1 <= `ZeroWord;
			/* 若讀取的是$0，那麼直接給出0 */
			else if(raddr1 == `RegNumLog2'h0)
				rdata1 <= `ZeroWord;
			/* 若要讀取的暫存器是在下一個時脈上升緣要寫入的暫存器，那麼就將要寫入的資料直接作結果輸出，以便解決相隔2條指令存在管線相依的情況 */
			else if((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable))
				rdata1 <= wdata;
			/* 若上述情況都不成立，那麼給出第一個讀取暫存器連接埠要讀取的目標暫存器位址對應暫存器的值 */
			else if(re1 == `ReadEnable)
				rdata1 <= regs[raddr1];
			/* 若第一個讀取暫存器連接埠不能使用時，直接輸出0 */
			else
				rdata1 <= `ZeroWord;
		end
		
	/* 讀取連接埠2的讀取操作 */	
	always @( * )
		begin
			/* 若重設訊號有效時，第二個讀取暫存器連接埠的輸出始終為0 */
			if(rst == `RstEnable)
				rdata2 <= `ZeroWord;
			/* 若讀取的是$0，那麼直接給出0 */
			else if(raddr2 == `RegNumLog2'h0)
				rdata2 <= `ZeroWord;
			/* 若第二個讀取暫存器連接埠要讀取的目標暫存器與要寫入的目標暫存器的是同一個，那麼直接將要寫入的值做作為第二個讀取暫存器連接埠的輸出 */
			else if((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable))
				rdata2 <= wdata;
			/* 若上述情況都不成立，那麼給出第二個讀取暫存器連接埠要讀取的目標暫存器位址對應暫存器的值 */
			else if(re2 == `ReadEnable)
				rdata2 <= regs[raddr2];
			/* 若第二個讀取暫存器連接埠不能使用時，直接輸出0 */
			else
				rdata2 <= `ZeroWord;
		end

endmodule

`include "defines.v"

/* 將存取記憶體階段的運算結果，在下一個時脈傳遞到回寫階段 */
module mem_wb(clk, rst, stall, flush, mem_wd, mem_wreg, mem_wdata, mem_hi, mem_lo, mem_whilo, mem_LLbit_we, mem_LLbit_value, mem_cp0_reg_we, mem_cp0_reg_write_addr, mem_cp0_reg_data,
			  wb_wd, wb_wreg, wb_wdata, wb_hi, wb_lo, wb_whilo, wb_LLbit_we, wb_LLbit_value, wb_cp0_reg_we, wb_cp0_reg_write_addr, wb_cp0_reg_data);

	input wire							clk;					/* 時脈訊號 */
	input wire 							rst;					/* 重設訊號 */
	
	/* 來自控制模組的資訊 */
	input wire [5:0]					stall;					/* 管線暫停訊號 */
	input wire							flush;					/* 管線清除訊號 */
	
	/* 存取記憶體階段的結果 */
	input wire [`RegAddrBus]			mem_wd;					/* 存取記憶體階段的指令最終要寫入的目的暫存器位址 */
	input wire					 		mem_wreg;				/* 存取記憶體階段的指令最終是否有要寫入的目的暫存器 */
	input wire [`RegBus]				mem_wdata;				/* 存取記憶體階段的指令最終要寫入目的暫存器的值 */
	input wire [`RegBus]				mem_hi;					/* 存取記憶體階段的指令要寫入HI暫存器的值 */
	input wire [`RegBus]				mem_lo;					/* 存取記憶體階段的指令要寫入LO暫存器的值 */
	input wire							mem_whilo;				/* 存取記憶體階段的指令是否要寫入HI、LO暫存器 */
	
	input wire							mem_LLbit_we;			/* 存取記憶體階段的指令是否要寫入LLbit暫存器 */
	input wire							mem_LLbit_value;		/* 存取記憶體階段的指令要寫入LLbit暫存器的值 */
	
	input wire							mem_cp0_reg_we;			/* 存取記憶體階段的指令是否要寫入CP0中的暫存器 */
	input wire [4:0]					mem_cp0_reg_write_addr;	/* 存取記憶體階段的指令要寫入的CP0中暫存器的位址 */
	input wire [`RegBus]				mem_cp0_reg_data;		/* 存取記憶體階段的指令要寫入CP0中暫存器的資料 */
	
	/* 送到回寫階段的資訊 */
	output reg [`RegAddrBus]			wb_wd;					/* 回寫階段的指令要寫入的目的暫存器位址 */
	output reg 							wb_wreg;				/* 回寫階段的指令是否有要寫入的目的暫存器 */
	output reg [`RegBus]				wb_wdata;				/* 回寫階段的指令要寫入目的暫存器的值 */
	output reg [`RegBus]				wb_hi;					/* 回寫階段的指令要寫入HI暫存器的值 */
	output reg [`RegBus]				wb_lo;					/* 回寫階段的指令要寫入LO暫存器的值 */
	output reg							wb_whilo;				/* 回寫階段的指令是否要寫入HI、LO暫存器 */
	
	output reg							wb_LLbit_we;			/* 回寫階段的指令是否要寫入LLbit暫存器 */
	output reg							wb_LLbit_value;			/* 回寫階段的指令要寫入LLbit暫存器的值 */
	
	output reg							wb_cp0_reg_we;			/* 回寫階段的指令是否要寫入CP0中的暫存器 */
	output reg [4:0]					wb_cp0_reg_write_addr;	/* 回寫階段的指令要寫入的CP0中暫存器的位址 */
	output reg [`RegBus]				wb_cp0_reg_data;		/* 回寫階段的指令要寫入CP0中暫存器的資料 */
	
	/* (1)當stall[4]為Stop，stall[5]為NoStop時，表示存取記憶體階段暫停，而回寫階段繼續，
	**    所以使用空指令作為下一個周期進入回寫階段的指令
	** (2)當stall[4]為NoStop時，表示存取記憶體階段繼續，存取記憶體後的指令進入回寫階段
	** (3)其餘情況下，保存回寫階段的暫存器wb_wd、wb_wreg、wb_wdata、wb_hi、wb_lo、wb_whilo不變 */
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				begin
					wb_wd					<=	`NOPRegAddr;
					wb_wreg 				<=	`WriteDisable;
					wb_wdata				<=	`ZeroWord;
					wb_hi					<=	`ZeroWord;
					wb_lo					<=	`ZeroWord;
					wb_whilo				<=	`WriteDisable;
					wb_LLbit_we				<=	1'b0;
					wb_LLbit_value			<=	1'b0;
					wb_cp0_reg_we			<=	`WriteDisable;
					wb_cp0_reg_write_addr	<=	5'b00000;
					wb_cp0_reg_data			<=	`ZeroWord;
				end
			/* 清除管線 */
			else if(flush == 1'b1)
				begin
					wb_wd					<=	`NOPRegAddr;
					wb_wreg 				<=	`WriteDisable;
					wb_wdata				<=	`ZeroWord;
					wb_hi					<=	`ZeroWord;
					wb_lo					<=	`ZeroWord;
					wb_whilo				<=	`WriteDisable;
					wb_LLbit_we				<=	1'b0;
					wb_LLbit_value			<=	1'b0;
					wb_cp0_reg_we			<=	`WriteDisable;
					wb_cp0_reg_write_addr	<=	5'b00000;
					wb_cp0_reg_data			<=	`ZeroWord;
				end
			else if(stall[4] == `Stop && stall[5] == `NoStop)
				begin
					wb_wd					<=	`NOPRegAddr;
					wb_wreg 				<=	`WriteDisable;
					wb_wdata				<=	`ZeroWord;
					wb_hi					<=	`ZeroWord;
					wb_lo					<=	`ZeroWord;
					wb_whilo				<=	`WriteDisable;
					wb_LLbit_we				<=	1'b0;
					wb_LLbit_value			<=	1'b0;
					wb_cp0_reg_we			<=	`WriteDisable;
					wb_cp0_reg_write_addr	<=	5'b00000;
					wb_cp0_reg_data			<=	`ZeroWord;
				end
			/* 判斷存取記憶體階段是否暫停 */		
			else if(stall[4] == `NoStop)
				begin
					wb_wd					<=	mem_wd;
					wb_wreg 				<=	mem_wreg;
					wb_wdata				<=	mem_wdata;
					wb_hi					<=	mem_hi;
					wb_lo					<=	mem_lo;
					wb_whilo				<=	mem_whilo;
					wb_LLbit_we				<=	mem_LLbit_we;
					wb_LLbit_value			<=	mem_LLbit_value;
					wb_cp0_reg_we			<=	mem_cp0_reg_we;
					wb_cp0_reg_write_addr	<=	mem_cp0_reg_write_addr;
					wb_cp0_reg_data			<=	mem_cp0_reg_data;
				end
		end
		
endmodule

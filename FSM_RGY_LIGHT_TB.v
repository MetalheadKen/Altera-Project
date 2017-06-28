/* 時間單位是1ns，精度是1ps */
`timescale 1ns/1ps

/* 建立Test Bench檔案 */
module FSM_RGY_LIGHT_TB();
	
	reg 			CLOCK_27;		 /* 驅動訊號，此為時脈訊號 */
	reg 			RST;			 /* 驅動訊號，此為重設訊號 */
	
	/* 每隔10ns，CLOCK_27的值就翻轉一次，所以一個週期是20ns，對應50MHZ */
	initial begin
		CLOCK_27 = 1'b0;
		forever #19 CLOCK_27 = ~CLOCK_27;
	end
	
	/* 最初時刻，重設訊號有效，在第195ns，重設訊號無效，最小sopc開始執行，執行4100ns，暫停模擬 */
	initial begin
		RST = 1;
		#195 RST = 0;
		//#10000 $stop;
	end
		
	/* 實體化最小sopc */
	FSM_RGY_LIGHT_TB FSM_RGY_LIGHT_TB0(CLOCK_27, RST);
		
endmodule

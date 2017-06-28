`include "defines.v"

/* 處理除法指令模組 */
module div(rst, clk, signed_div_i, opdata1_i, opdata2_i, start_i, annul_i, result_o, ready_o);

	input wire 					rst;						/* 重設訊號，高電壓有效 */
	input wire					clk;						/* 時脈訊號 */
	
	input wire					signed_div_i;				/* 是否有號除法，為1表示有號除法 */
	input wire [31:0]			opdata1_i;					/* 被除數 */
	input wire [31:0]			opdata2_i;					/* 除數 */
	input wire					start_i;					/* 是否開始除法運算 */
	input wire					annul_i;					/* 是否取消除法運算，為1表示取消除法運算 */
	
	output reg [63:0]			result_o;					/* 除法運算結果 */
	output reg					ready_o;					/* 除法運算是否結束 */
	
	wire [32:0] div_temp;
	
	reg  [5:0]	cnt;			/* 記錄試商法進行了幾輪，當等於32時，表示試商法結束 */	
	reg  [64:0] dividend;
	reg  [1:0]  state;
	reg  [31:0] divisor;
	reg  [31:0] temp_op1;
	reg  [31:0] temp_op2;	
	
	/* dividend的低32位元保存的是被除數、中間結果，第k次迭代結束的時候dividend[k:0]保存的就是目前得到的中間結果，
	** dividend[31:k+1]保存的就是被除數中還沒有參與運算的資料，dividend高32位元是每次迭代時的被減數，所以dividend[63:32]
	** 就是圖7-16中的minuend，divisor就是圖7-16中的除數n，此處進行的就是minuend-n運算，結果保存在div_temp中 */
	assign div_temp = {1'b0, dividend[63:32]} - {1'b0, divisor};
	
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				begin
					state 	  <= `DivFree;
					ready_o	  <= `DivResultNotReady;
					result_o  <= {`ZeroWord, `ZeroWord};
				end
			else
				begin
					case(state)
						/* DivFree狀態。分三種情況：
						** (1)開始除法運算，但除數為0，那麼進入DivByZero狀態
						** (2)開始除法運算，且除數不為0，那麼進入DivOn狀態，初始化cnt為0，如果是有號除法，且被除數或者除數為負，
						**    那麼對被除數或者除數取補碼。
						**    除數保存到divisor中，將被除數的最高為保存到dividend的第32位元，準備進行第一次迭代
						** (3)沒有開始除法運算，保持ready_o為DivResultNotReady，保持result_o為0 */
						/* DivFree狀態 */
						`DivFree:
							begin
								if(start_i == `DivStart && annul_i == 1'b0)
									begin
										if(opdata2_i == `ZeroWord)
											state <= `DivByZero;					/* 除數為0 */
										else
											begin
												state <= `DivOn;					/* 除數不為0 */
												cnt	  <= 6'b000000;
												
												if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1)
													temp_op1 = ~opdata1_i + 1;		/* 被除數取補碼 */
												else
													temp_op1 = opdata1_i;
												
												if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1)
													temp_op2 = ~opdata2_i + 1;		/* 除數取補碼 */
												else
													temp_op2 = opdata2_i;
													
												dividend 		<= {`ZeroWord, `ZeroWord};
												dividend[32:1] 	<= temp_op1;
												divisor			<= temp_op2;
											end
									end
								else
									begin											/* 沒有開始除法運算 */
										ready_o  <= `DivResultNotReady;
										result_o <= {`ZeroWord, `ZeroWord};
									end
							end
						/* DivByZero狀態 */
						`DivByZero:
							begin
								dividend <= {`ZeroWord, `ZeroWord};
								state	 <= `DivEnd;
							end
							
						/* DivOn狀態。分三種情況：
						** (1)如果輸入訊號annul_i為1，表示處理器取消除法運算，那麼DIV模組直接回到DivFree狀態。
						** (2)如果annul_i為0，且cnt不為32，那麼表示試商法還沒有結束，此時如果減法結果div_temp為負，那麼此次迭代結果是0，
						**	  參考圖7-16；如果減法結果 div_temp為正，那麼此次迭代結果為1，參考圖7-16，dividend的最低為保存每次的迭代結果
						**	  。同時保持DivOn狀態，cnt加1
						** (3)如果annul_i為0，且cnt為32，那麼表示試商法結束，如果是有號除法，且被除數、除數一正一負，那麼將試商法的結果取
						**	  補碼，得到最終的結果，此處的商、餘數都要取補碼。商保存在dividend的低32位元，餘數保存在dividend的高32位元。
						**	  同時進入DivEnd狀態 */
						/* DivOn狀態 */
						`DivOn:
							begin
								if(annul_i == 1'b0)
									begin
										if(cnt != 6'b100000)
											begin
												/* 如果div_temp[32]為1，表示(minuend-n)結果小於0，將dividend向左移一位，這樣就將被除數還沒
												** 有參與運算的最高位加入到下一次迭代的被減數中，同時將0追加到中間結果 */
												if(div_temp[32] == 1'b1)
													dividend <= {dividend[63:0], 1'b0};
												else
												/* 如果div_temp[32]為0，表示(minuend-n)結果大於等於0，將減法的結果與被除數還沒有參與運算的
												** 最高位加入到下一次迭代的被減數中，同時將1追加到中間結果 */
													dividend <= {div_temp[31:0], dividend[31:0], 1'b1};
											
												cnt <= cnt + 1;									
											end
										else
											/* 試商法結束 */
											begin
												if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1))
													/* 求補碼 */
													dividend[31:0] <= (~dividend[31:0] + 1);
												
												if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1))
													/* 求補碼 */
													dividend[64:33] <= (~dividend[64:33] + 1);
												
												state <= `DivEnd;		/* 進入DivEnd狀態 */
												cnt	  <= 6'b000000;		/* cnt清為零 */
											end
									end
								else
									begin
										state <= `DivFree;				/* 如果annul_i為1，那麼直接回到DivFree狀態 */
									end
							end
							
						/* DivEnd狀態。
						** 除法運算結束，result_o的寬度64位元，其高32位元儲存餘數，低32位元儲存商，設定輸出訊號ready_o
						** 為DivResultReady，表示除法結束，然後等待EX模組送來DivStop訊號，當EX模組送來DivStop訊號時，
						** Div模組回到DivFree狀態 */
						/* DivEnd狀態 */
						`DivEnd:
							begin
								result_o <= {dividend[64:33], dividend[31:0]};
								ready_o  <= `DivResultReady;
								
								if(start_i == `DivStop)
									begin
										state <= `DivFree;
										ready_o <= `DivResultNotReady;
										result_o <= {`ZeroWord, `ZeroWord};
									end
							end
					endcase /* case state */
				end
		end
		
endmodule

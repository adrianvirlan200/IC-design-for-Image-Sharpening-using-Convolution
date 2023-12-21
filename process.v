`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output reg [5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg [23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output reg mirror_done,		// semnaleaza terminarea actiunii de oglindire (activ pe 1)
	output reg gray_done,		// semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
	output reg filter_done);	// semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)

// TODO add your finite state machines here

	reg [15:0] state = 0, next_state = 0;
	
	reg [5:0] next_row, next_col;
	
	reg [23:0] aux_pixel1, aux_pixel2; //variables that will store one pixel each, used to swap the pixels/mirror the image
	reg [7:0] min_pix, max_pix;
	
	reg [6:0] k, j, i;
	reg [5:0] j_start, i_start, i_end, j_end;
	
	reg signed[31:0] sharp_sum;
	reg [7:0] sharp_array[63:0];
	
	reg [7:0] aux_row[2:0][63:0];
	reg [5:0] aux_row_it1=0,  next_aux_row_it1 = 0, aux_row_it2=0,  next_aux_row_it2 = 0;
	
	reg last_row_flag = 0;
	
	integer it1, it2;
	
	//sequential part
	always@(posedge clk)begin
		state <= next_state;
		
		row <= next_row;
		col <= next_col;
		
		aux_row_it1 <= next_aux_row_it1;
		aux_row_it2 <= next_aux_row_it2;
	end
	
	
	//combinational part
	always@(*)begin
		out_we = 0;
		out_pix = 0;
		mirror_done = 0;
		gray_done = 0;
		filter_done = 0;
	
		case(state)
		0:begin
			next_row = 0;
			next_col = 0;
			
			out_we = 0;
			out_pix = 0;
			mirror_done = 0;
			gray_done = 0;
			filter_done = 0;
			
			next_aux_row_it1 = 0;
			next_aux_row_it2 = 0;
			
			next_state = 1;
		end
		1:begin
			
			aux_pixel1 = in_pix;
			next_row = 63 - row;
			next_col = col;
			
			next_state = 2;
		end
		
		2:begin
			
			aux_pixel2 = in_pix;
			next_row = row;
			next_col = col;
			
			next_state = 3;
		end
		
		3:begin
			
			out_we = 1;
			out_pix = aux_pixel1;
			
			next_col = col;
			next_row = 63 - row;
			
			next_state = 4;
		end
		
		4:begin
			
			out_we = 1;
			out_pix = aux_pixel2;
			
			next_state = 1;
			
			if(col < 63) begin
				next_col = col + 1;
				next_row = row;
			end
			else if( row < (63 - 1)/2) begin 
				next_col = 0;
				next_row = row + 1;
			end else 
				next_state = 5;
		end
		
		5:begin
			mirror_done = 1;
			
			next_row = 0;
			next_col = 0;
			next_state = 6;
		end
		
		6:begin
			//R 23:16; G 15:8; B 7:0
			min_pix = in_pix[23:16];
			max_pix = in_pix[23:16];
			
			if(in_pix[15:8] < min_pix)
				min_pix = in_pix[15:8];
			if(in_pix[15:8] > max_pix)
				max_pix = in_pix[15:8];
				
			if(in_pix[7:0] < min_pix)
				min_pix = in_pix[17:0];
			if(in_pix[7:0] > max_pix)
				max_pix = in_pix[7:0];
				
			min_pix = (min_pix + max_pix)/2;
			
			next_row = row;
			next_col = col;
			next_state = 7;
		end
		
		7:begin
			out_we = 1;
			out_pix = {8'b0, min_pix, 8'b0};
			
			//$display("image[%d][%d] = %d", row, col, min_pix);
			next_state = 6;
			
			if(col < 63)begin
				next_col = col + 1;
				next_row = row;
			end
			else if( row < 63) begin 
				next_col = 0;
				next_row = row + 1;
			end else 
				next_state = 8;
		end
		
		8:begin
			gray_done = 1;
			
			next_row = 0;
			next_col = 0;
			
			next_aux_row_it1 = 0;
			next_aux_row_it2 = 0;
			
			next_state = 9;
		end
		
		//only first row
		9:begin
			aux_row[aux_row_it1][col] = in_pix[15:8];
			
			next_state = 9;
			
			if(col < 63) begin
				next_col = col + 1;
				next_row = row;
				next_aux_row_it1 = aux_row_it1;
			end else begin
				if(aux_row_it1 < 2)begin
					next_row = row + 1;
					next_aux_row_it1 = aux_row_it1 + 1;
					next_col = 0;
					next_state = 9;
				end
				else begin
					next_state = 10;
					next_row = 0;
					next_col = 0;
				end
					
			end
		end
		
		10:begin
			//se intra cu row = 0, col = 0
			for(k = 0; k < 64; k = k + 1) begin
				i_start = 0;
				i_end = 1;
				
				if(k == 0) begin
					j_start = 0;
					j_end = 1;
				end
				else if(k == 63) begin
					j_start = 62;
					j_end = 63;
				end
				else begin
					j_start = k - 1;
					j_end = k + 1;
				end
			
				sharp_sum = aux_row[0][k] * 9;
				for(i = 0; i < 3; i = i + 1) begin
					for(j = 0; j < 64; j = j + 1) begin
						if(i != 0 || j != k) begin // bypass the central element
							if(i >= i_start && i <= i_end && j >= j_start && j <= j_end)
								sharp_sum = sharp_sum - aux_row[i][j];
						end
					end
				end

				if(sharp_sum > 255)
					sharp_sum = 255;
				if(sharp_sum < 0)
					sharp_sum = 0;
				
				sharp_array[k] = sharp_sum;
			end
			
			next_state = 11;
			
		end
		
		11:begin
			//se intra cu row = 0, col = 0
			out_we = 1;
			out_pix = {8'b0, sharp_array[col],8'b0};
			next_state = 11;
			
			if(col < 63)begin
				next_col = col + 1;
				next_row = row;
			end else begin
				next_state = 12;
				next_row = row + 1;
				next_col = 0;
			end
		end
		
		
		//for rows 2-63
		12:begin//COMPUTE ROW
			//se intra cu row = 1, col = 0
			
			for(k = 0; k < 64; k = k + 1) begin
				i_start = 0;
				i_end = 2;
				
				if(k == 0) begin
					j_start = 0;
					j_end = 1;
				end
				else if(k == 63) begin
					j_start = 62;
					j_end = 63;
				end
				else begin
					j_start = k - 1;
					j_end = k + 1;
				end
			
				sharp_sum = aux_row[1][k] * 9;
				//buna
				for(i = 0; i < 3; i = i + 1) begin
					for(j = 0; j < 64; j = j + 1) begin
						if(i != 1 || j != k) begin// bypass the central element
							if(i >= i_start && i <= i_end && j >= j_start && j <= j_end)
								sharp_sum = sharp_sum - aux_row[i][j];
							
						end
					end
				end

				if(sharp_sum > 255)
					sharp_sum = 255;
				if(sharp_sum < 0)
					sharp_sum = 0;
				
				sharp_array[k] = sharp_sum;
			end
			
			next_state = 13;
		end
		
		13:begin// WRITE
			//se intra cu row = 1, col = 0
		
			out_we = 1;
			out_pix = {8'b0, sharp_array[col],8'b0};
			next_state = 13;
			
			if(col < 63)begin
				next_col = col + 1;
				next_row = row;
			end else begin
				next_state = last_row_flag ? 16 : 14;//very important
				
				next_aux_row_it1 = 0;
            next_aux_row_it2 = 0;				
					
				next_row = row + 2;
				next_col = 0;
			end
		end
		
		14:begin//SHIFT
			//se intra cu row = 3, col = 0
		

			aux_row[aux_row_it1 ][aux_row_it2] = aux_row[aux_row_it1 + 1][aux_row_it2];
			next_state = 14;
			
			if(aux_row_it2 < 63)begin
				next_aux_row_it2 = aux_row_it2 + 1;
			end
			else if(aux_row_it1 < 2)begin
				next_aux_row_it1 = aux_row_it1 + 1;
				next_aux_row_it2 = 0;
			end
			else 
				next_state = 15;
		end
		
		15:begin// READ
			//$display("s a trecut de shiftare");
			//se intra cu row = 3, col = 0
			aux_row[2][col] = in_pix[15:8];
			
			next_state = 15;
			
			if(col < 63) begin
				next_col = col + 1;
				next_row = row;
			end else begin
				if(row < 63)
					next_state = 12;
				else begin
					last_row_flag = 1;
					next_state = 12;
					
				end
				next_col = 0;
				next_row = row - 1;
			end
		end
		
		//last row
		16:begin
			for(k = 0; k < 64; k = k + 1) begin
				i_start = 1;
				i_end = 2;
				
				if(k == 0) begin
					j_start = 0;
					j_end = 1;
				end
				else if(k == 63) begin
					j_start = 62;
					j_end = 63;
				end
				else begin
					j_start = k - 1;
					j_end = k + 1;
				end
			
				sharp_sum = aux_row[2][k] * 9;
				for(i = 0; i < 3; i = i + 1) begin
					for(j = 0; j < 64; j = j + 1) begin
						if(i != 2 || j != k) begin// bypass the central element
							if(i >= i_start && i <= i_end && j >= j_start && j <= j_end)
								sharp_sum = sharp_sum - aux_row[i][j];
							
						end
					end
				end

				if(sharp_sum > 255)
					sharp_sum = 255;
				if(sharp_sum < 0)
					sharp_sum = 0;
				
				sharp_array[k] = sharp_sum;
			end
			
			next_row = 63;
			next_col = 0;
			next_state = 17;
		
		end
		
		17:begin
			out_we = 1;
			out_pix = {8'b0, sharp_array[col], 8'b0};
			next_state = 17;
			
			if(col < 63)begin
				next_col = col + 1;
				next_row = row;
			end else begin
				next_state = 20;				
			end
		end
		
		20: filter_done = 1;
		
		default: next_state = 0;
		endcase
	end

endmodule
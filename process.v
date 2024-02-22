`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output  reg [5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg [23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output reg mirror_done=0,		// semnaleaza terminarea actiunii de oglindire (activ pe 1)
	output reg gray_done=0,		// semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
	output reg filter_done=0);	// semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)

// TODO add your finite state machines here


reg [6:0] r=0, c=0, stop=0;
reg [8:0] state=0, next_state=0;
reg [7:0] max, min, med;
reg [23:0] i_pix, o_pix; 
reg [7:0] a0,b0,c0,a1,b1,c1,a2,b2,c2; //matricea din jurul lui in_pix
reg f_done=0;
reg [8:0] aux;
reg[23:0]  sum[63:0][63:0]; //copia in care salvez toate sumele rezultate aplicarii filtrului sharpness pe in_pix



always @(posedge clk) begin
	 state<=next_state; //actualizez starea, randul si coloana
	 r<=row; //actualizez randul si coloana auxliare
	 c<=col;
	 //f_done<=filter_done;
	 //$display("f %0d", f_done);
	 
end

always @(*) begin

	case(state)
			0: begin // aici hotarasc pe ce actiune(mirror sau gray) merg si vreau sa am row si col in starea lor initiala
				row=0;
				col=0;
				if(mirror_done==0) //daca nu am facut mirror, o fac
					next_state=1;
				else if(gray_done==0) next_state=6; //daca am facut mirror, trec la gray
						else 
						if(filter_done==0)next_state=9; //inceperea lui sharpness
						
			end
			1:
			begin
			
			row=r;
			col=c;
			o_pix=in_pix; //pixelul actual pe care vreau sa il oglindesc (il pun deorate in o_pix ca sa nu il pierd)
			next_state=2;
			
			end
			2:
			begin
			row=63-r; //randul oglindit
			col=c;
			
			i_pix=in_pix; // pixelul din a doua jumatate a pozei (il pun deorate in i_pix ca sa nu il pierd)
			out_pix=o_pix; // in a doua jumatate a pozei il pun pe o_pix 
			out_we=1;
			next_state=3;
			
			
			end
			3:
			begin
			row=63-r; //ma intorc la prima jumatate
			col=c;
				
			out_pix=i_pix; // la prima jumatate pun pixelul din a doua jumatate initiala salvat in i_pix
			out_we=1; 
			next_state=4;
			
			end
			4:
			begin
			out_we = 0; 
				if(c<63 & r<=31) begin
						col=c+1; //trec la urmatorul pixel de pe acelasi rand
						row=r;
						next_state=1;
						end
					else if(r<31 & c==63) begin
						col=0;
						row=r+1; //trec la urmatorul rand
						next_state=1;
						end
					else if( r==31 & c==63) begin
								mirror_done=1; //anunt terminarea actiunii de mirror
								next_state=0; //ma intorc in state0 pentru a hotara plecarea spre gray
								end
			 
									
			
			end
	
			5: 	 begin	//aici fac scrierile
			 col=c;
			 row=r;
			 out_we=1;
			 out_pix[15:8]=med; //pe canalul G pun media, iar pe restul le fac zero
			 out_pix[23:16]=0;
			 out_pix[7:0]=0;
			 next_state=8; //trec la state8 care este state ul de calcularea randului si coloanei urmatoare
			 if(gray_done==1) next_state=0; // daca am terminat gray, merg la state0 pentru a hotara urmatoarea actiune si anume sharpnes
			 
					end
			
			6: begin //aici incepe actiunea de grey
				out_we=0;
					//calcularea maximului dintre canale
					if(in_pix[23:16]>= in_pix[15:8] && in_pix[23:16]>=in_pix[7:0]) max=in_pix[23:16];
					else if(in_pix[23:16]<= in_pix[15:8] && in_pix[15:8]>=in_pix[7:0]) max=in_pix[15:8];
					else if(in_pix[23:16]<= in_pix[7:0] && in_pix[15:8]<=in_pix[7:0]) max=in_pix[7:0]; 
					
					//calcularea minimumui dintre canale
					if(in_pix[23:16]<= in_pix[15:8] && in_pix[23:16]<=in_pix[7:0]) min=in_pix[23:16];
					else if(in_pix[23:16]>=in_pix[15:8] && in_pix[15:8]<=in_pix[7:0]) min=in_pix[15:8];
					else if(in_pix[23:16]>= in_pix[7:0] && in_pix[15:8]>=in_pix[7:0]) min=in_pix[7:0];
					
					next_state=7;

					
				end
				7: begin
					out_we=0;
					//media dintr min si max pusa in canalul G
					med=(min+max)/2;
					next_state=5; //merg cu cele calculate in state5 care e state de scriere
					
					end
				8: begin //state ul de calcularea randului si coloanei urmatoare
					out_we = 0; 
					if(c<63 & r<=63) begin
						col=c+1; //trec la urmatorul pixel de pe acelasi rand
						row=r;
						next_state=6;
						end
					else if(r<63 & c==63) begin
						col=0;
						row=r+1;//trec la randul urmator
						next_state=6;
						end
					else if( r==63 & c==63) begin
								gray_done=1; //anunt terminarea lui gray
								
								next_state=5; // ma intorc la state 5 sa scriu ultimul pixel ( cel de pe pozitia 63,63)
								end
								
			end
	//lucrez doar cu canalul G [15:8]
	9: 
	begin //(a0)
			//in_pix se afla pe primul rand
			if(r==0) a0=0;
			else
			
			//pix se afla pe ultimul rand
			if(r==63 & c==0) a0=0;
			else
			if(r==63 & c>0) begin row=r-1; col=c-1; a0=in_pix[15:8]; end
			else
			
			//pix se afla pe restul randurilor
			if(r>0 & r<63 & c==0) a0=0;
			else
			if(r>0 & r<63 & c<63 & c>0) begin row=r-1; col=c-1; a0=in_pix[15:8]; end
			
			row=r;
			col=c;
			
			
	
			//(b0)
			//pix se afla pe primul rand
			if(r==0) b0=0;
			else
			
			//in rest
			 begin row=r-1; col=c; b0=in_pix[15:8]; end
			
			row=r;
			col=c;
				
			
			
			
			//(c0)
			//pix se afla pe primul rand
			if(r==0) c0=0; else
			
			//pix se afla pe ultimul rand
			if(r==63 & c<63) begin row=r-1; col=c+1; c0=in_pix[15:8]; end else
			if(c==63) c0=0; else
			
			//pix se afla pe restul randurilor
			if(r>0 & r<63 & c<63) begin row=r-1; col=c+1; c0=in_pix[15:8]; end 
			
			row=r;
			col=c;
			
			//a1
			if(c==0) a1=0; 
			else begin row=r; col=c-1; a1=in_pix[15:8]; end
			
			row=r;
			col=c;
			
			//b1
			row=r; col=c; b1=in_pix[15:8];
				//$display("b1 %0d", b1);
			
			//c1
			if(c==63) c1=0;
			else begin row=r; col=c+1; c1=in_pix[15:8]; end
			row=r;
			col=c;
			
			
			//a2
			if(r==63) a2=0; else
			if(c==0) a2=0; else
			if(r<63 & c>0) begin row=r+1; col=c-1; a2=in_pix[15:8]; end
			row=r;
			col=c;
			
			
	//b2
			if(r==63) b2=0;
			else begin row=r+1; col=c; b2=in_pix[15:8]; end
			row=r;
			col=c;
			
			//c2
			if(c==63) c2=0;
			else if(r==63) c2=0;
			else begin row=r+1; col=c+1; c2=in_pix[15:8]; end
			row=r;
			col=c;
			next_state=11;
			
		end
	10:
	begin //state ul de calcularea randului si coloanei urmatoare
	out_we=0;
				if(c<63 & r<=63) begin
								col=c+1; //trec la urmatorul pixel de pe acelasi rand
								row=r;
								next_state=9;
								end
							else if(r<63 & c==63) begin
								col=0;
								row=r+1;//trec la randul urmator
								next_state=9;
								end
							else  begin
										filter_done=1; //anunt terminarea copierii
										 next_state=9;
										end
	
	end
	11:begin // calculez suma si o pun in matricea copie
			out_we = 1;
			aux=a0+b0+c0+a1+c1+a2+c2+b2;
			row=r;
			col=c;
			sum[row][col][15:8]=9*b1-aux;			// daca am terminatde aplicat filtru peste toti in_pix trec la state 20 unde transfer matricea sum peste out_pix
			if(filter_done==1) begin
			row=0; col=0;
			next_state=12; 
			end else next_state=10;
	end
	
	12:
	begin
			out_we=1;
			row=r;
			col=c;
			out_pix[15:8]=sum[row][col][15:8];
			if(row!=63 | col!=63) next_state=13; //stop anunta terminarea copierii
	end
	
	13:
	begin
			//parcurg pe randuri si coloane pentru a copia matricea
			
							if(c<63 & r<=63) begin
								col=c+1; //trec la urmatorul pixel de pe acelasi rand
								row=r;
								next_state=12;
								end
							else if(r<63 & c==63) begin
								col=0;
								row=r+1;//trec la randul urmator
								next_state=12;
								end
							else  begin
										stop=1; //anunt terminarea copierii
										 next_state=12;
										end
	end
	
	endcase
end

endmodule

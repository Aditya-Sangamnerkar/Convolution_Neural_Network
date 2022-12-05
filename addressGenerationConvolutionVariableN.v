module AddressGenerationConvolutionVariableN (

	// Control Signals
	input wire 		  clk						               ,
	input wire 		  reset_b				 	             ,
	input wire      dut_run 					           ,

	// Input SRAM interface
	output reg        input_sram_write_enable    ,
  output reg [11:0] input_sram_write_addresss  ,
  output reg [15:0] input_sram_write_data      ,
  output reg [11:0] input_sram_read_address    ,
  input wire [15:0] input_sram_read_data       ,

  //Weights SRAM interface                                                       
 	output reg        weights_sram_write_enable    ,
  output reg [11:0] weights_sram_write_addresss  ,
  output reg [15:0] weights_sram_write_data      ,
  output reg [11:0] weights_sram_read_address    ,
  input wire [15:0] weights_sram_read_data       ,

  // Output signals from module
  output reg signed [19:0] mac_register, // signed
  output reg [1 : 0] valid,
  output reg dut_busy

	);

//---------------------------------------------------------------------------
// Internal Signals and Parameters Declerations
//---------------------------------------------------------------------------



// state parameters
parameter
          S0 = 4'h0,
          S1 = 4'h1,
          S2 = 4'h2,
          S3 = 4'h3,
          S4 = 4'h4,
          S5 = 4'h5;
         
reg [3 : 0] current_state, next_state;

// input address
reg [11 : 0] input_address;
reg [11 : 0] ns_input_address;

// input vector size
reg [7 : 0] size_N;
reg [7 : 0] ns_size_N;

// counters
reg [15 : 0] conv_sync_counter;
reg [15 : 0] index;
reg [1 : 0] row_counter;
reg [1 : 0] col_counter;

reg [15 : 0] ns_conv_sync_counter;
reg [15 : 0] ns_index;
reg [1 : 0] ns_row_counter;
reg [1 : 0] ns_col_counter;


// convolution_address registers
reg [11 : 0] convolution_address;
reg [11 : 0] ns_convolution_address;

// weight addresses
reg [11 : 0] weight_address;
reg [11 : 0] ns_weight_address;


// convolution_base_addresses
reg [11 : 0] convolution_base_address;
reg [11 : 0] ns_convolution_base_address;

// convolution counter
reg [3 : 0] convolution_counter;
reg [3 : 0] ns_convolution_counter;


// convolution_input_select
reg [1 : 0] convolution_input_select;

// weight input select
reg [1 : 0] weight_input_select;

// input and weight data registers 
reg signed [7 : 0] ipx;
reg signed [7 : 0] ipw;


// dut busy
// reg dut_busy;
reg ns_dut_busy;

// mac registers
//reg [15 : 0] mac_register;
reg signed [19 : 0] ns_mac_register;

// valid register 
reg [1 : 0] ns_valid;


//---------------------------------------------------------------------------
// input sram interface
//---------------------------------------------------------------------------
always@(*)
begin
  if(current_state == S2)
   begin
    input_sram_read_address = input_address;
    input_sram_write_enable = 1'b0;
   end
  else if(current_state == S4)
   begin
    input_sram_read_address = convolution_address;
    input_sram_write_enable = 1'b0;
   end
  else
    input_sram_read_address = 12'hX;
    input_sram_write_enable =1'b0;
end

//---------------------------------------------------------------------------
// weight sram interface
//---------------------------------------------------------------------------
always@(*)
begin
  if(current_state == S4)
   begin
    weights_sram_read_address = weight_address;
    weights_sram_write_enable = 1'b0;
   end
  else
   begin
    weights_sram_read_address = 12'hX;
    weights_sram_write_enable = 1'b0;
   end
end

//---------------------------------------------------------------------------
// dut busy
//---------------------------------------------------------------------------

// dut_busy : sequential logic

always@(posedge clk)
begin
  if(!reset_b)
   begin
    dut_busy <= 0;
   end
  else
   begin
    dut_busy <= ns_dut_busy;
   end
end

// dut_busy : combinational logic

always@(*)
begin
  if(current_state == S0 || current_state == S1)
   begin
    ns_dut_busy = 1'b0;
   end
  else
   begin
    ns_dut_busy = 1'b1;
   end
end

//---------------------------------------------------------------------------
// input vector size
//---------------------------------------------------------------------------

// input vector size : sequential logic
always@(posedge clk)
begin
  if(!reset_b)
   begin
    size_N <= 8'h0;
   end
  else
   begin
    size_N <= ns_size_N;
   end 
end

// input vector size : combinational logic 
always@(*)
begin
  if(current_state == S3)
   begin
    ns_size_N = input_sram_read_data[7 : 0];
   end
  else if(current_state == S1)
   begin
    ns_size_N = 8'h0; 
   end
  else
    ns_size_N = size_N;
end


//---------------------------------------------------------------------------
// input address
//---------------------------------------------------------------------------

// input address : sequential logic

always@(posedge clk)
begin
  if(!reset_b)
   begin
    input_address <= 12'h0;
   end
  else
   begin
    input_address <= ns_input_address;
   end
end

// input address : combinational logic
always@(*)
begin
  if(current_state == S3)
   begin
    ns_input_address = input_address + ((input_sram_read_data[7 : 0] * input_sram_read_data[7 : 0]) >> 8'h1 )+ 12'h1;
   end
  else if(current_state == S1)
   begin
    ns_input_address = 12'h0;
   end
  else
   begin
    ns_input_address = input_address;
   end
end

//---------------------------------------------------------------------------
// row, column and index counters
//---------------------------------------------------------------------------

// counters : sequential logic
always@(posedge clk)
begin
  if(!reset_b)
    begin
      index <= 16'h0;
      row_counter <= 8'h0;
      col_counter <= 8'h0;
      conv_sync_counter <= 16'h0;
    end
  else
    begin
      index <= ns_index;
      row_counter <= ns_row_counter;
      col_counter <= ns_col_counter;
      conv_sync_counter <= ns_conv_sync_counter;
    end
end

// counters : next state combinational logic
always@(*)
begin
  // latch fix
  ns_row_counter = row_counter;
  ns_index = index;
  ns_conv_sync_counter = conv_sync_counter;
  if(col_counter < 2'h2 && current_state == S4) 
    begin
      ns_col_counter = col_counter + 2'h1;
    end
  else
    begin
      ns_col_counter = 2'h0;
      if(row_counter < 2'h2 && current_state == S4)
        begin 
          ns_row_counter = row_counter + 2'h1;
        end
      else
        begin
          ns_row_counter = 2'h0;
          if(current_state == S4) 
            begin 
              if(index < ((size_N-8'h2)*(size_N-8'h2)) - 8'h1)
                begin
                  ns_index = index + 16'h1;
                  if(conv_sync_counter < ((size_N - 8'h2)<<1)-1 )
                   begin
                    ns_conv_sync_counter = conv_sync_counter + 16'h1;
                   end
                  else
                   begin
                    ns_conv_sync_counter = 16'h0;
                   end
                end
              else
                begin
                  ns_conv_sync_counter = 16'h0;
                  ns_index = 16'h0;
                  
                end
            end
          else 
          begin
            ns_conv_sync_counter = 16'h0; 
            ns_index = 16'h0;
          end    

        end
    end
end

//--------------------------------------------------------------------------
// convolution base address 
//---------------------------------------------------------------------------

// convolution base address : sequential logic
always@(posedge clk)
begin
  if(!reset_b) 
    begin 
      convolution_base_address <= 12'h0;
    end
  else 
    begin 
      convolution_base_address <= ns_convolution_base_address;
    end
end

// convolution base address : combinational logic 
always@(*)
begin
  // latch fix
  ns_convolution_base_address = convolution_base_address;
  if(row_counter == 2'h2 && col_counter == 2'h2 && current_state == S4)
    begin
      if(index == ((size_N-8'h2)*(size_N-8'h2)) - 1)
        begin
          // ns_convolution_base_address = 12'h0;
          // ns_convolution_address = 12'h0;
          ns_convolution_base_address = convolution_base_address + size_N + 12'h2; 
          //ns_convolution_address =  convolution_base_address + size_N + 12'h2;      
        end
      else
        begin
          if(index[1 : 0] == 2'b00) 
            begin 
              ns_convolution_base_address = convolution_base_address;
              //ns_convolution_address = convolution_base_address;
            end
          else if (index[1 : 0] == 2'b01) 
            begin 
              ns_convolution_base_address = convolution_base_address + (size_N >> 1);
              //ns_convolution_address  = convolution_base_address + (size_N >> 1);
            end
          else if(index[1 : 0] == 2'b10) 
            begin
              ns_convolution_base_address = convolution_base_address;
              //ns_convolution_address = convolution_base_address;
            end
          else //if(index[1 : 0] == 2'b11) 
            begin 
              if(conv_sync_counter == ((size_N - 8'h2)<<1)-1)
                begin
                  ns_convolution_base_address = convolution_base_address + 12'h2;
                  //ns_convolution_address = convolution_base_address  + 12'h2;
                end
              else
                begin
                  ns_convolution_base_address = convolution_base_address - (size_N >> 1) + 12'b1;
                  //ns_convolution_address = convolution_base_address - (size_N >> 1) + 12'b1;
                end
            end
            
        end
    end
  else if(current_state == S0 || current_state == S1)
    begin
      ns_convolution_base_address = 12'h1;
      //ns_convolution_address = 12'h1;
    end
  else if(current_state == S5)
   begin
    ns_convolution_base_address = convolution_base_address + 12'h1;
    //ns_convolution_address = convolution_address + 12'h1;
   end
  else
   begin
    ns_convolution_base_address = convolution_base_address;
    //ns_convolution_address = convolution_address;
   end
end



//--------------------------------------------------------------------------
// convolution address 
//---------------------------------------------------------------------------

// convolution_address sequential logic
always@(posedge clk)
begin
  if(!reset_b)
  begin
    convolution_address <= 12'h0;
  end
  else
  begin
    convolution_address <= ns_convolution_address;
  end
end


//convolution_address combinational logic
always@(*)
begin
    if(current_state == S4)
      begin
        if(row_counter < 2'h2 || col_counter  < 2'h2)
          begin
            if(index[0] == 1'b0)
              begin
                if(col_counter == 2'h0)
                  begin
                    ns_convolution_address = convolution_address;
                  end
                else if(col_counter == 2'h1)
                  begin
                    ns_convolution_address = convolution_address + 12'h1;
                  end
                else //if(col_counter == 2'h2)
                  begin
                    ns_convolution_address = convolution_address + (size_N >> 1) - 12'h1;
                  end
            end
            else
              begin
                if(col_counter == 2'h0)
                  begin
                    ns_convolution_address = convolution_address + 12'h1;
                  end
                else if(col_counter == 2'h1)
                  begin
                    ns_convolution_address = convolution_address;
                  end
                else //if(col_counter == 2'h2)
                  begin
                    ns_convolution_address = convolution_address + (size_N >> 1) - 12'h1;
                  end
            end
        end
        else
         begin
          if(index == ((size_N-8'h2)*(size_N-8'h2)) - 1)
           begin
            ns_convolution_address =  convolution_base_address + size_N + 12'h2;      
           end
          else
           begin
            if(index[1 : 0] == 2'b00) 
             begin 
               ns_convolution_address = convolution_base_address;
             end
            else if (index[1 : 0] == 2'b01) 
             begin 
               ns_convolution_address  = convolution_base_address + (size_N >> 1);
             end
            else if(index[1 : 0] == 2'b10) 
             begin
               ns_convolution_address = convolution_base_address;
             end
            else //if(index[1 : 0] == 2'b11) 
             begin 
               if(conv_sync_counter == ((size_N - 8'h2)<<1)-1)
                 begin
                  ns_convolution_address = convolution_base_address  + 12'h2;
                 end
               else
                 begin
                  ns_convolution_address = convolution_base_address - (size_N >> 1) + 12'b1;
                 end
             end 
           end
         end
      end
    else if(current_state == S0 || current_state == S1)
     begin
      ns_convolution_address = 12'h1;
     end
    else if(current_state == S5)
     begin
      ns_convolution_address = convolution_address + 12'h1;
     end
    else
     begin
      ns_convolution_address = convolution_address;
     end
end


//---------------------------------------------------------------------------
// weight address
//---------------------------------------------------------------------------

// weight address : sequential logic 
always@(posedge clk)
begin
  if(!reset_b)
    begin
      weight_address <= 12'h0;
    end
  else
    begin
      weight_address <= ns_weight_address;
    end
end
// weight address : combinational logic 
always@(*)
begin
   if(current_state == S4)
    begin
      if(weight_address == 12'h4)
        begin
          ns_weight_address = 12'h0;
        end
      else
        begin
          casex({row_counter, col_counter})
            4'b0000: 
                begin
                  ns_weight_address = 12'h0;
                end
            4'b0001: 
                begin
                  ns_weight_address = 12'h1;
                end
            4'b0010: 
                begin
                  ns_weight_address = 12'h1;
                end
            4'b0100: 
                begin
                  ns_weight_address = 12'h2;
                end
            4'b0101: 
                begin
                  ns_weight_address = 12'h2;
                end
            4'b0110: 
                begin
                  ns_weight_address = 12'h3;
                end
            4'b1000: 
                begin
                  ns_weight_address = 12'h3;
                end
            4'b1001: 
                begin
                  ns_weight_address = 12'h4;
                end
            4'b1010: 
                begin
                  ns_weight_address = 12'h0;
                end
            default:
                begin
                  ns_weight_address = 12'h0;
                end
          endcase
        end

    end
  else  // changed
  begin
    ns_weight_address = 8'h0;
  end
end

//---------------------------------------------------------------------------
// Convolution 
//---------------------------------------------------------------------------

// convolution counter : sequential logic
always@(posedge clk)
begin
  if(!reset_b)
    begin
      convolution_counter <= 4'h0;
    end  
  else
    begin
      convolution_counter <= ns_convolution_counter;
    end
end
// convolution counter : combinational logic
always@(*)
begin
  if(current_state == S4)
    begin
      if(index == 16'h0 && row_counter == 2'h0 && col_counter == 2'h0)
        begin
          ns_convolution_counter = 4'h0;
        end
      else
        begin
          if(convolution_counter == 4'h8)
            begin
              ns_convolution_counter = 4'h0;
            end
          else
            begin
              ns_convolution_counter = convolution_counter + 4'h1;
            end
        end
    end

  else  //changed
    begin
        ns_convolution_counter = 4'h0;
    end
end


// convolution_input_select : combinational logic 
always@(*)
begin
  if(current_state == S4)
    begin
      if(row_counter == 2'h0 && col_counter == 2'h0 && index == 16'h0)
        begin
          convolution_input_select = 2'h1;
        end
      else
        begin
          if(index[0] == 1'h0) // even
            begin
              if(convolution_counter < 4'h8)
                begin
                  if( (convolution_counter[3]) || (convolution_counter[1]  && ~convolution_counter[0]) || (convolution_counter[2] && ~convolution_counter[1] && convolution_counter[0]) ||(~convolution_counter[2] && convolution_counter[1]) || (~convolution_counter[2] && ~convolution_counter[0]))
                    begin
                       convolution_input_select = 2'h2;
                    end
                  else
                    begin
                      convolution_input_select = 2'h1;
                    end
                end 
              else //if(convolution_counter == 4'h8) // latch fix
                begin
                    convolution_input_select = 2'h1;
                end
              end
          else //if(index[0] == 1'b1) // odd // latch fix
            begin
              if(convolution_counter < 4'h8)
                begin
                  if( (convolution_counter[3]) || (convolution_counter[1]  && ~convolution_counter[0]) || (convolution_counter[2] && ~convolution_counter[1] && convolution_counter[0]) ||(~convolution_counter[2] && convolution_counter[1]) || (~convolution_counter[2] && ~convolution_counter[0]))
                    begin
                       convolution_input_select = 2'h1;
                    end
                  else
                    begin
                      convolution_input_select = 2'h2;
                    end
                end 
              else //if(convolution_counter == 4'h8) // latch fix 
                begin
                    convolution_input_select = 2'h2;
                end
              end

        end

    end
  else //changed
    begin
      convolution_input_select = 2'h1;
    end
end

// weight input select : combinational logic 
always@(*)
begin
  if(current_state == S4 || current_state == S5)
    begin
      if(convolution_counter[0] == 1'b1)
        begin
          weight_input_select = 2'h1;
        end
      else if(convolution_counter[0] == 1'b0)
        begin
          weight_input_select = 2'h2;
        end
      // latch fix
      else 
       begin
         weight_input_select = 2'h1;
       end
    end
  else //changed
    begin
      weight_input_select = 2'h0;
    end
end



// convolution input and weight select data assignment : Combinational logic 
always@(*)
begin
  if(current_state == S4 || current_state == S5)
    begin
      casex(weight_input_select)
        2'h1:
             begin
              casex(convolution_input_select)
                2'h1:begin
                        ipw = $signed(weights_sram_read_data[7 : 0]);
                        ipx = $signed(input_sram_read_data [7 : 0]);
                      end
                2'h2:begin
                        ipw = $signed(weights_sram_read_data[7 : 0]);
                        ipx = $signed(input_sram_read_data[15 : 8]);
                      end
                // latch fix
                default:
                      begin
                        ipx = 8'h0;
                        ipw = 8'h0;
                      end
              endcase
              
             end
        2'h2:
             begin
              casex(convolution_input_select)
                2'h1:begin
                        ipw = $signed(weights_sram_read_data[15 : 8]);
                        ipx = $signed(input_sram_read_data [7 : 0]);
                      end
                2'h2:begin
                        ipw = $signed(weights_sram_read_data[15 : 8]);
                        ipx = $signed(input_sram_read_data[15 : 8]);
                      end
                // latch fix
                default:
                      begin
                        ipx = 8'h0;
                        ipw = 8'h0;
                      end
              endcase
             end
        default:begin
            ipw = 8'h0;
            ipx = 8'h0;
         end
      endcase
    end
  // latch fix
  else
   begin
    ipx = 8'h0;
    ipw = 8'h0;
   end
end




// MAC : sequential logic
always@(posedge clk)
begin
  if(!reset_b)
    begin
      mac_register <= 20'h0;
    end
  else
    begin
      mac_register <= ns_mac_register;
    end
end

// MAC : combinational logic
always@(*)
begin
  if(current_state == S4)
    begin
      if(row_counter == 2'h0 && col_counter == 2'h0 && index == 16'h0)
        begin
          ns_mac_register = 20'h0;
        end
      else if(convolution_counter > 4'h0)
        begin
          ns_mac_register = mac_register + (ipx * ipw);
        end
      else if(convolution_counter == 4'h0)
        begin
          ns_mac_register = ipx * ipw;
        end
      else
        begin
          ns_mac_register =  20'h0;
        end
    end
  else if(current_state == S5)
   begin
     ns_mac_register = mac_register + (ipx * ipw);
   end
  else //changed
    begin
      ns_mac_register = 20'h0;
    end
end

//---------------------------------------------------------------------------
// valid 
//---------------------------------------------------------------------------

// valid : sequential logic
always@(posedge clk)
begin
  if(!reset_b )
    begin
    valid <= 1'b0;
    end
  else
     begin
      valid <= ns_valid;
     end
end

// valid : combinational logic
always@(*)
begin
  if(convolution_counter  == 4'h8)
   begin
     if(current_state  == S5)
      begin
        ns_valid  = 2'h2;
      end
    else
     begin
        ns_valid = 2'h1;
     end

   end
  else if(current_state == S1)
   begin
    ns_valid = 2'h3;
   end
  else 
   begin
    ns_valid = 2'h0;
   end
end




//---------------------------------------------------------------------------
// state machine
//---------------------------------------------------------------------------

// state machine : sequential logic
always@(posedge clk)
begin
  if(!reset_b)
    begin
      current_state <= S0;
    end
  else
    begin
      current_state <= next_state;
    end
end


// state machine : next state combinational logic 
always@(*)
begin
  casex(current_state)
  S0 : begin
        if(reset_b == 1'b0)
          begin
            next_state = S0;
          end
        else
          begin 
            next_state = S1;
          end
       end
  S1 : begin
            if(dut_run == 1'b1)
             begin
              next_state = S2;
             end
            else
             begin
              next_state = S1;
             end
       end
  S2 : begin
         next_state = S3;
       end
  S3 : begin
        if(input_sram_read_data == 16'hFFFF)
         begin
          next_state = S1;
         end 
        else
         begin
          next_state = S4;
         end
       end
  S4 : begin
        if((index == ((size_N - 8'h2)*(size_N - 8'h2))- 8'h1) && row_counter == 2'h2 && col_counter == 2'h2)
         begin
          next_state = S5;
         end
        else
         begin
          next_state = S4;
         end
       end
  S5 :  begin
          next_state = S2;
        end
  default : begin
            next_state = S0;
            end
    endcase
end  


endmodule
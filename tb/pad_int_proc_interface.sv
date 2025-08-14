`ifndef PAD_INT_PROC_INTERFACE
`define PAD_INT_PROC_INTERFACE

interface pad_int_proc_interface;
    parameter PAD_INT_NUM = 16;

    wire                      clk          ; // clock, 250Mhz
    wire                      rst_n        ; // reset, low active
    wire [PAD_INT_NUM-1:0]    int_en       ; // enable
    wire [PAD_INT_NUM-1:0]    int_type     ; // interrupt type, 0: level ; 1: edge
    wire [PAD_INT_NUM-1:0]    int_polarity ; // intettupt polarity, 0: low level or falling edge; 1: high level or rising edge
    wire [PAD_INT_NUM-1:0]    int_both_edge; // both edge triiger, 0: single edge; 1: both edge , only affect edge type interrupt
    wire [PAD_INT_NUM*28-1:0] db_high_cnt_w; // debounce (db_high_cnt_w+1)*40ns high level glitch  
    wire [PAD_INT_NUM*28-1:0] db_low_cnt_w ; // debounce (db_low_cnt_w+1)*40ns low level glitch  
    wire [PAD_INT_NUM-1:0]    pad_int_i    ; // pad_int input raw interrupt
    wire [PAD_INT_NUM-1:0]    pad_int_level; // output after debounced level type interrupt
    wire [PAD_INT_NUM-1:0]    pad_int_pulse; // output after debounced pulse type interrupt
    wire [PAD_INT_NUM-1:0]    padint_real  ;

    wire[PAD_INT_NUM-1:0] refm_pad_int_level;
    wire[PAD_INT_NUM-1:0] refm_pad_int_pulse;
    wire[PAD_INT_NUM-1:0] refm_pad_int_real;

    bit check_en=1;
    event err_level[PAD_INT_NUM];
    event err_pulse[PAD_INT_NUM];
    event err_real[PAD_INT_NUM];

    wire[PAD_INT_NUM-1:0] pad_int_after_polarity;
    wire[PAD_INT_NUM-1:0] pad_int_after_polarity_int_en;
    bit[PAD_INT_NUM-1:0] pad_int_after_polarity_int_en_fliter;
    bit[PAD_INT_NUM-1:0] pad_int_after_unpolarity_int_en_fliter_flag;
    bit[PAD_INT_NUM-1:0] pad_int_after_polarity_int_en_fliter_d1;
    wire[27:0] active_cnt_4ns[PAD_INT_NUM];
    wire[27:0] inactive_cnt_4ns[PAD_INT_NUM];
    bit[27:0] my_active_cnt_4ns[PAD_INT_NUM];
    bit[27:0] my_inactive_cnt_4ns[PAD_INT_NUM];
    wire[PAD_INT_NUM-1:0] single_edge;
    wire[PAD_INT_NUM-1:0] both_edge;
    bit[PAD_INT_NUM-1:0] int_en_d;

    genvar i;
    generate 
        for (i=0; i<PAD_INT_NUM; i=i+1) begin:PAD_INT_GEN
            always@(posedge clk) begin
                if((pad_int_level[i]^refm_pad_int_level[i])&check_en&rst_n) begin
                    ->err_level[i];
                    `uvm_error("pad_int_proc_interface","err_level")
                end
            end
            always@(posedge clk) begin
                if((pad_int_pulse[i]^refm_pad_int_pulse[i])&check_en&rst_n) begin
                    ->err_pulse[i];
                    `uvm_error("pad_int_proc_interface","err_pulse")
                end
            end
            always@(posedge clk) begin
                if((padint_real[i]^refm_pad_int_real[i])&check_en&rst_n) begin
                    ->err_real[i];
                    `uvm_error("pad_int_proc_interface","err_real")
                end
            end

            assign refm_pad_int_real[i] = pad_int_i[i];
            assign pad_int_after_polarity[i] = (int_polarity[i]? pad_int_i[i] : ~pad_int_i[i]);
            assign pad_int_after_polarity_int_en[i] = (int_en[i]? pad_int_after_polarity[i] : 1'b0);

            assign active_cnt_4ns[i] = (int_polarity[i]? (db_high_cnt_w[(28*i)+:28]+1):(db_low_cnt_w[(28*i)+:28]+1) );
            assign inactive_cnt_4ns[i]  = (int_polarity[i]? (db_low_cnt_w[(28*i)+:28]+1) :(db_high_cnt_w[(28*i)+:28]+1));

            always@(posedge clk) begin
                if(~rst_n) begin
                    pad_int_after_polarity_int_en_fliter[i]<=0;
                end
                else if(~int_en[i]) begin
                    pad_int_after_polarity_int_en_fliter[i]<=0;
                end
                else if(my_active_cnt_4ns[i]==active_cnt_4ns[i]) begin
                    pad_int_after_polarity_int_en_fliter[i]<=1;
                end
                else if(my_inactive_cnt_4ns[i]==inactive_cnt_4ns[i]) begin
                    pad_int_after_polarity_int_en_fliter[i]<=0;
                end
            end

            always@(posedge clk) begin
                if(~rst_n) begin
                    my_active_cnt_4ns[i]<=0;
                end
                else if(~int_en[i]) begin
                    my_active_cnt_4ns[i]<=0;
                end
                else if(my_active_cnt_4ns[i]==active_cnt_4ns[i]) begin
                    my_active_cnt_4ns[i]<=0;
                end
                else if(pad_int_after_polarity_int_en[i]) begin
                    my_active_cnt_4ns[i]<=my_active_cnt_4ns[i]+1;
                end
                else begin
                    my_active_cnt_4ns[i]<=0;
                end
            end

            always@(posedge clk) begin
                if(~rst_n) begin
                    my_inactive_cnt_4ns[i]<=0;
                end
                else if(~int_en[i]) begin
                    my_inactive_cnt_4ns[i]<=0;
                end
                else if(my_inactive_cnt_4ns[i]==inactive_cnt_4ns[i]) begin
                    my_inactive_cnt_4ns[i]<=0;
                end
                else if(~pad_int_after_polarity_int_en[i]) begin
                    my_inactive_cnt_4ns[i]<=my_inactive_cnt_4ns[i]+1;
                end
                else begin
                    my_inactive_cnt_4ns[i]<=0;
                end
            end

            always@(posedge clk) begin
                if(~rst_n) begin
                    pad_int_after_unpolarity_int_en_fliter_flag[i]<=0;
                end
                else if(~int_en[i]) begin
                    pad_int_after_unpolarity_int_en_fliter_flag[i]<=0;
                end
                else if(my_inactive_cnt_4ns[i]==inactive_cnt_4ns[i]) begin
                    pad_int_after_unpolarity_int_en_fliter_flag[i]<=1;
                end
            end

            always@(posedge clk) begin
                int_en_d[i] <= int_en[i];
                pad_int_after_polarity_int_en_fliter_d1[i] <= pad_int_after_polarity_int_en_fliter[i];
            end

            assign single_edge[i] = (int_en[i]|int_en_d[i])&(pad_int_after_polarity_int_en_fliter[i]&~pad_int_after_polarity_int_en_fliter_d1[i])&pad_int_after_unpolarity_int_en_fliter_flag[i];
            assign both_edge[i] = (int_en[i]|int_en_d[i])&(pad_int_after_polarity_int_en_fliter[i]^pad_int_after_polarity_int_en_fliter_d1[i])&pad_int_after_unpolarity_int_en_fliter_flag[i];
    
            assign refm_pad_int_level[i] = ~int_type[i]? (int_en[i]|int_en_d[i])&pad_int_after_polarity_int_en_fliter[i]:1'b0;
            assign refm_pad_int_pulse[i] =  int_type[i]? (int_both_edge[i]? both_edge[i]:single_edge[i]):1'b0;
        end
    endgenerate

endinterface

`endif

`timescale 1ns / 1ps

module ChisFlashGB(
    // GB interface, inputs from host
    input [15:0] GB_A,      
    input [7:0]  GB_D,      
    input        GB_CS,     
    (* altera_attribute = "-name GLOBAL_SIGNAL OFF" *) input nGB_WR,    
    input        GB_RD,     
    input        GB_CLK,    

    // RAM & ROM interface, outputs to chips
    output       GB_RST,    
    output [22:14] ROM_A,   
    output [16:13] RAM_A,   
    output       nROM_CS,   
    output       nRAM_CS,   
    output       RAM_CS2    
);

// Oscillator setup
wire oscena_sig = 1'b1;
wire osc_sig;

OSC OSC_inst (
    .oscena ( oscena_sig ),
    .osc ( osc_sig )
);

assign RAM_CS2 = 1'b1; 
reg nRST_reg = 1'b1;
assign GB_RST = nRST_reg;
reg [15:0] rst_counter;
reg rst_active = 1'b0;
reg gamestart_flag = 1'b0; 

reg [8:0] rom_bank = 9'b000000001;
reg [4:0] ram_bank = 5'b0;
reg ram_en = 1'b0;
reg game_sel_en = 1'b0;
reg [1:0] game_sel = 2'b00;

// Memory mapped range enables - FULL PRECISION 16-bit compares
// (kept from ChisFlashGB.v: this is what allows flashing payload bytes
//  to pass through cleanly without being misread as control writes,
//  provided the specific overlap addresses below are excluded)
wire rom_addr_en = (GB_A <= 16'h7FFF);
wire ram_addr_en = (GB_A >= 16'hA000) && (GB_A <= 16'hBFFF); 
wire rom_addr_lo = (GB_A <= 16'h3FFF);

assign nROM_CS = (rom_addr_en) ? 1'b0 : 1'b1; 
assign nRAM_CS = ((ram_addr_en) && (ram_en) && (ram_bank[4] == 1'b0)) ? 1'b0 : 1'b1; 

wire [22:14] rom_a_pre; 
assign rom_a_pre[22:14] = rom_addr_lo ? 9'b0 : rom_bank[8:0]; 

wire [16:13] ram_a_pre; 
assign ram_a_pre[16:13] = ram_bank[3:0]; 

// 4-location game selection bank mapping
// NOTE: restored the v1.21 "game 3 gets double window" behavior
// ({1'b1, rom_a_pre[21]}) since the plain 2'b10 in ChisFlashGB.v
// would remove the >2MB slot-3 game support you confirmed you need.
// If your multicart is a strict 4-in-1 with all equal-size slots,
// change the 2'b10 case back to plain 2'b10 - see comment below.
reg [22:21] ROM_AB;
always @(*) begin
    if (game_sel_en) begin
        case (game_sel[1:0])
            2'b00:   ROM_AB[22:21] = 2'b00; // game 1
            2'b01:   ROM_AB[22:21] = 2'b01; // game 2
            2'b10:   ROM_AB[22:21] = {1'b1, rom_a_pre[21]}; // game 3 (up to 4MiB)
            // 2'b10:   ROM_AB[22:21] = 2'b10; // <- use this instead if game 3 should be a plain fixed 2MiB slot
            2'b11:   ROM_AB[22:21] = 2'b11; // game 4
            default: ROM_AB[22:21] = 2'b00;
        endcase
    end else begin
        ROM_AB[22:21] = rom_a_pre[22:21];
    end
end

assign ROM_A[22:21] = ROM_AB[22:21];
assign ROM_A[20]    = ((game_sel_en) && (game_sel[1:0] == 2'b00)) ? 1'b1 : rom_a_pre[20];
assign ROM_A[19:14] = rom_a_pre[19:14];  
assign RAM_A[16:15] = (game_sel_en) ? game_sel[1:0] : ram_a_pre[16:15];
assign RAM_A[14:13] = ram_a_pre[14:13];

// Immediate Edge Capture on nGB_WR Rising Edge
// (kept from ChisFlashGB.v - full precision decode + specific
//  exclusions for addresses the flasher's JEDEC unlock/program
//  sequence needs to pass through untouched)
always @(posedge nGB_WR) begin
    if (GB_A <= 16'h1FFF) begin
        ram_en <= (GB_D[3:0] == 4'hA);
    end

    if ((GB_A >= 16'h2000 && GB_A <= 16'h2FFF) && (GB_A != 16'h2AAA)) begin
        rom_bank[7:0] <= GB_D[7:0];
    end
    
    if (GB_A >= 16'h3000 && GB_A <= 16'h3FFF) begin
        rom_bank[8] <= GB_D[0];
    end
    
    // ram_bank[4] is the "multi-game control mode" flag. RESTORED to
    // unconditional (v1.21 behavior) - this is the actual fix for game
    // selection. The ChisFlashGB.v version gated this on ram_en==1,
    // which silently drops the control-mode write if the menu sets it
    // before ever enabling SRAM, permanently blocking game_en_clk /
    // game_sel_clk / the reset trigger below from ever firing.
    // This is safe for flashing: ram_bank never feeds ROM_A, so
    // payload bytes clobbering it mid-flash (which happens either way,
    // since ram_bank[3:0] below is already unconditional) never
    // disturbs flash addressing.
    if ((GB_A >= 16'h4000 && GB_A <= 16'h5FFF) && (GB_A != 16'h5555)) begin
        ram_bank[3:0] <= GB_D[3:0];
        if (!game_sel_en)
            ram_bank[4] <= GB_D[4];
        else
            ram_bank[4] <= 1'b0;
    end
    
    // RESTORED to v1.21 behavior: no ram_en requirement here either.
    // ChisFlashGB.v had added "ram_en &&" to both of these, same
    // regression pattern as the ram_bank[4] fix above - if the menu's
    // control-mode sequence doesn't also assert ram_en before writing
    // these, game_sel_en/game_sel can never be set correctly.
    if (GB_A == 16'hA000 && ram_bank[4]) begin
        game_sel_en <= GB_D[0];
    end
    
    if (GB_A == 16'hB000 && ram_bank[4]) begin
        game_sel[1:0] <= GB_D[1:0];
    end
end

// Reset Logic Timer - Synchronized across clock domains
// RESTORED trigger condition to ram_bank[4] (v1.21 behavior) to match
// the fix above - game_en_clk/game_sel_clk already require ram_bank[4],
// so the reset trigger must use the same flag, not ram_en, or it can
// never fire even after the fix above.
wire rst_clk_async = (!nGB_WR) && (GB_A == 16'h4000) && (ram_bank[4] == 1'b1) && (game_sel_en == 1'b1) && (gamestart_flag == 1'b0);

reg [1:0] rst_sync;
always @(posedge osc_sig) begin
    rst_sync <= {rst_sync[0], rst_clk_async};
end

wire rst_clk_sync = rst_sync[1];

always @(posedge osc_sig) begin
    if (rst_clk_sync) begin
        rst_active  <= 1'b1;   
        rst_counter <= 16'b0;  
        nRST_reg    <= 1'b0; 
    end else if (rst_active) begin
        if (rst_counter >= 16'd42016) begin 
            nRST_reg       <= 1'bz; 
            rst_active     <= 1'b0; 
            gamestart_flag <= 1'b1;
        end else begin
            rst_counter <= rst_counter + 1'b1; 
        end
    end
end

endmodule

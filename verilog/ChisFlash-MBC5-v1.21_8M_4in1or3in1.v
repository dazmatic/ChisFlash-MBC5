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

// Register declarations upfront
reg start_cmd = 1'b0;
reg rst_active = 1'b0;
reg gamestart_flag = 1'b0; 
reg nRST_reg = 1'b1;
reg [17:0] rst_counter;

reg [8:0] rom_bank = 9'b000000001;
reg [4:0] ram_bank = 5'b0;
reg ram_en = 1'b0;
reg game_sel_en = 1'b0;
reg [1:0] game_sel = 2'b00;
reg is_mbc1 = 1'b0;

// Dynamic Clock Gating: Oscillator stays OFF until game launch reset is
// triggered. is_mbc1 detection below no longer depends on this at all
// (see GB_CLK-clocked block), so this stays exactly as originally
// designed for the power saving - no extension needed.
wire oscena_sig = (start_cmd && !gamestart_flag) || rst_active;
wire osc_sig;

OSC OSC_inst (
    .oscena ( oscena_sig ),
    .osc ( osc_sig )
);

assign RAM_CS2 = 1'b1; 
assign GB_RST = nRST_reg;

// Memory mapped range enables
wire rom_addr_en = (GB_A <= 16'h7FFF);
wire ram_addr_en = (GB_A >= 16'hA000) && (GB_A <= 16'hBFFF); 
wire rom_addr_lo = (GB_A <= 16'h3FFF);

assign nROM_CS = (rom_addr_en) ? 1'b0 : 1'b1; 
assign nRAM_CS = ((ram_addr_en) && (ram_en) && (ram_bank[4] == 1'b0)) ? 1'b0 : 1'b1; 

// Bank 0 Hardware Translation
wire [8:0] mbc_rom_bank = (is_mbc1 && (rom_bank[4:0] == 5'b00000)) ? {rom_bank[8:5], 5'b00001} : rom_bank;

wire [22:14] rom_a_pre; 
assign rom_a_pre[22:14] = rom_addr_lo ? 9'b0 : mbc_rom_bank[8:0]; 

wire [16:13] ram_a_pre; 
assign ram_a_pre[16:13] = ram_bank[3:0]; 

// 4-location game selection bank mapping
reg [22:21] ROM_AB;
always @(*) begin
    if (game_sel_en) begin
        case (game_sel[1:0])
            2'b00:   ROM_AB[22:21] = 2'b00;
            2'b01:   ROM_AB[22:21] = 2'b01;
            2'b10:   ROM_AB[22:21] = {1'b1, rom_a_pre[21]};
            2'b11:   ROM_AB[22:21] = 2'b11;
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

// Direct register write block - driven directly by the real write
// strobe, so it works regardless of oscillator gating state.
// (is_mbc1 is NOT touched anywhere in this block anymore - see the
// single GB_CLK-clocked block below, which is now its sole owner.)
always @(posedge nGB_WR) begin
    if (GB_A <= 16'h1FFF) begin
        ram_en <= (GB_D[3:0] == 4'hA);
    end

    if ((GB_A >= 16'h2000 && GB_A <= 16'h2FFF) && (GB_A != 16'h2AAA)) begin
        rom_bank[7:0] <= GB_D[7:0];
    end
    
    if (GB_A >= 16'h3000 && GB_A <= 16'h3FFF) begin
        if (is_mbc1) begin
            rom_bank[7:0] <= GB_D[7:0];
        end else begin
            rom_bank[8] <= GB_D[0];
        end
    end
    
    if ((GB_A >= 16'h4000 && GB_A <= 16'h5FFF) && (GB_A != 16'h5555)) begin
        ram_bank[3:0] <= GB_D[3:0];
        if (!game_sel_en)
            ram_bank[4] <= GB_D[4];
        else
            ram_bank[4] <= 1'b0;
    end
    
    if (GB_A == 16'hA000 && ram_bank[4]) begin
        game_sel_en <= GB_D[0];
    end
    
    if (GB_A == 16'hB000 && ram_bank[4]) begin
        game_sel[1:0] <= GB_D[1:0];
    end

    if (GB_A == 16'h4000 && ram_bank[4] == 1'b1 && game_sel_en == 1'b1) begin
        start_cmd <= 1'b1;
    end
end

// Mapper auto-detect - SOLE owner of is_mbc1, clocked entirely off
// GB_CLK (the console's own bus clock, an existing but previously
// unused input pin - NOT the CPLD's internal gated OSC). GB_CLK ticks
// continuously during any real bus activity - reads, writes, or
// flashing - regardless of the internal oscillator's power-gating
// state, so this works reliably in every scenario without needing to
// extend the internal oscillator's on-time at all.
//
// Levels of nGB_WR/GB_RD are sampled here (not their edges), which is
// safe because GB_CLK ticks many times faster than a single read/write
// pulse lasts, guaranteeing at least one sample lands while the pulse
// is active.
always @(posedge GB_CLK) begin
    if (!nGB_WR && GB_A == 16'h2AAA) begin
        // Flasher escape hatch: force MBC5 mode any time a flash-unlock
        // write is in progress.
        is_mbc1 <= 1'b0;
    end else if (!GB_RD && GB_A == 16'h0147) begin
        // Header-byte snoop: watches for the console's OWN boot-ROM
        // checksum read at the cart-type byte - happens on every real
        // boot with zero cooperation needed from menu or flasher firmware.
        if (GB_D == 8'h01 || GB_D == 8'h02 || GB_D == 8'h03) begin
            is_mbc1 <= 1'b1;
        end else begin
            is_mbc1 <= 1'b0;
        end
    end
end

// Reset Logic Timer
wire rst_clk_async = (start_cmd == 1'b1) && (gamestart_flag == 1'b0);

reg [1:0] rst_sync;
always @(posedge osc_sig) begin
    rst_sync <= {rst_sync[0], rst_clk_async};
end

wire rst_clk_sync = rst_sync[1];

always @(posedge osc_sig) begin
    if (rst_clk_sync && !rst_active && !gamestart_flag) begin
        rst_active     <= 1'b1;   
        rst_counter    <= 17'b0;  
        nRST_reg       <= 1'b0;   // Phase 1: Actively drive LOW for ~20ms
    end else if (rst_active) begin
        if (rst_counter >= 17'd110000 && rst_counter < 17'd112000) begin 
            // Phase 2: Actively drive HIGH briefly to push-charge the 1uF capacitor
            nRST_reg     <= 1'b1; 
            rst_counter  <= rst_counter + 1'b1;
        end else if (rst_counter >= 17'd112000) begin
            // Phase 3: Now that the line is fully charged, safely float to High-Z (Z)
            nRST_reg     <= 1'bz; 
            rst_active   <= 1'b0; 
            gamestart_flag <= 1'b1;
        end else begin
            nRST_reg     <= 1'b0;   // Keep holding low during the rest window
            rst_counter  <= rst_counter + 1'b1; 
        end
    end else begin
        nRST_reg <= nRST_reg;
    end
end

endmodule

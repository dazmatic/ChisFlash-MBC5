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

// Dynamic Mapper Detection Flag
reg is_mbc1 = 1'b0;

// Synchronous Sniffer using Internal Oscillator
// Captures 0x0147 safely mid-read, bypassing edge-race conditions.
always @(posedge osc_sig) begin
    if (!nGB_WR && GB_A == 16'h2AAA) begin
        // Flasher Escape Hatch: Flash unlock sequences force MBC5 mode for >4MB writing
        is_mbc1 <= 1'b0;
    end else if (!GB_RD && GB_A == 16'h0147) begin
        // Sniff header byte to auto-detect MBC1 games (0x01, 0x02, 0x03)
        if (GB_D == 8'h01 || GB_D == 8'h02 || GB_D == 8'h03) begin
            is_mbc1 <= 1'b1;
        end else begin
            is_mbc1 <= 1'b0;
        end
    end
end

// Memory mapped range enables
wire rom_addr_en = (GB_A <= 16'h7FFF);
wire ram_addr_en = (GB_A >= 16'hA000) && (GB_A <= 16'hBFFF); 
wire rom_addr_lo = (GB_A <= 16'h3FFF);

assign nROM_CS = (rom_addr_en) ? 1'b0 : 1'b1; 
assign nRAM_CS = ((ram_addr_en) && (ram_en) && (ram_bank[4] == 1'b0)) ? 1'b0 : 1'b1; 

// Bank 0 Hardware Translation: Only active when an MBC1 game is detected
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

// Immediate Edge Capture on nGB_WR Rising Edge
always @(posedge nGB_WR) begin
    if (GB_A <= 16'h1FFF) begin
        ram_en <= (GB_D[3:0] == 4'hA);
    end

    // ROM Bank Register Logic (Smart MBC1 & MBC5 Hybrid)
    // 0x2000 - 0x2FFF: Always updates lower 8 bits safely
    if ((GB_A >= 16'h2000 && GB_A <= 16'h2FFF) && (GB_A != 16'h2AAA)) begin
        rom_bank[7:0] <= GB_D[7:0];
    end
    
    // 0x3000 - 0x3FFF: Context-aware mapping
    if (GB_A >= 16'h3000 && GB_A <= 16'h3FFF) begin
        if (is_mbc1) begin
            // SML2 / MBC1 Mode: 0x3000 writes the lower bank bits. Bit 8 untouched.
            rom_bank[7:0] <= GB_D[7:0];
        end else begin
            // MBC5 / Flasher Mode: 0x3000 explicitly writes the 9th bit for >4MB.
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
end

// Reset Logic Timer - Synchronized across clock domains
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

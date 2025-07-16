`ifndef INT_CONTROLLER_SV
`define INT_CONTROLLER_SV

// Interrupt Controller Module
// This module simulates a realistic interrupt controller with:
// - Interrupt status registers
// - Interrupt clear registers  
// - Interrupt mask registers
// - Interrupt pending registers
module int_controller #(
    parameter NUM_INTERRUPTS = 32,
    parameter ADDR_WIDTH = 8
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Interrupt sources
    input  logic [NUM_INTERRUPTS-1:0] interrupt_sources,
    
    // Processor interface (APB-like)
    input  logic                    psel,
    input  logic                    penable,
    input  logic                    pwrite,
    input  logic [ADDR_WIDTH-1:0]  paddr,
    input  logic [31:0]             pwdata,
    output logic [31:0]             prdata,
    output logic                    pready,
    
    // Interrupt outputs to processors
    output logic                    irq_to_ap,
    output logic                    irq_to_scp,
    output logic                    irq_to_mcp,
    output logic                    irq_to_imu,
    output logic                    irq_to_io,
    output logic                    irq_to_other_die
);

    // Register addresses
    localparam ADDR_INT_STATUS  = 8'h00;  // Interrupt Status Register (RO)
    localparam ADDR_INT_CLEAR   = 8'h04;  // Interrupt Clear Register (WO)
    localparam ADDR_INT_MASK    = 8'h08;  // Interrupt Mask Register (RW)
    localparam ADDR_INT_PENDING = 8'h0C;  // Interrupt Pending Register (RO)
    localparam ADDR_INT_CONFIG  = 8'h10;  // Interrupt Configuration Register (RW)

    // Internal registers
    logic [NUM_INTERRUPTS-1:0] int_status_reg;   // Latched interrupt status
    logic [NUM_INTERRUPTS-1:0] int_mask_reg;     // Interrupt mask (1=enabled, 0=masked)
    logic [NUM_INTERRUPTS-1:0] int_pending_reg;  // Pending interrupts (status & ~mask)
    logic [31:0]               int_config_reg;   // Configuration register

    // APB interface signals
    logic apb_write, apb_read;
    
    assign apb_write = psel & penable & pwrite;
    assign apb_read  = psel & penable & ~pwrite;
    assign pready    = 1'b1; // Always ready for simplicity

    // Interrupt status register - latches interrupt sources
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_status_reg <= '0;
        end else begin
            // Latch rising edges of interrupt sources
            for (int i = 0; i < NUM_INTERRUPTS; i++) begin
                if (interrupt_sources[i] && !int_status_reg[i]) begin
                    int_status_reg[i] <= 1'b1;
                end
            end
            
            // Clear interrupts when written to clear register
            if (apb_write && paddr == ADDR_INT_CLEAR) begin
                int_status_reg <= int_status_reg & ~pwdata[NUM_INTERRUPTS-1:0];
            end
        end
    end

    // Interrupt mask register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_mask_reg <= '0; // All interrupts masked by default
        end else if (apb_write && paddr == ADDR_INT_MASK) begin
            int_mask_reg <= pwdata[NUM_INTERRUPTS-1:0];
        end
    end

    // Configuration register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_config_reg <= '0;
        end else if (apb_write && paddr == ADDR_INT_CONFIG) begin
            int_config_reg <= pwdata;
        end
    end

    // Pending interrupts = status & mask
    always_comb begin
        int_pending_reg = int_status_reg & int_mask_reg;
    end

    // Generate interrupt outputs based on configuration
    // This is a simplified routing - in real hardware this would be more complex
    always_comb begin
        irq_to_ap       = |int_pending_reg; // Any pending interrupt goes to AP
        irq_to_scp      = int_config_reg[0] ? |int_pending_reg : 1'b0;
        irq_to_mcp      = int_config_reg[1] ? |int_pending_reg : 1'b0;
        irq_to_imu      = int_config_reg[2] ? |int_pending_reg : 1'b0;
        irq_to_io       = int_config_reg[3] ? |int_pending_reg : 1'b0;
        irq_to_other_die = int_config_reg[4] ? |int_pending_reg : 1'b0;
    end

    // APB read interface
    always_comb begin
        prdata = 32'h0;
        case (paddr)
            ADDR_INT_STATUS:  prdata = {{(32-NUM_INTERRUPTS){1'b0}}, int_status_reg};
            ADDR_INT_MASK:    prdata = {{(32-NUM_INTERRUPTS){1'b0}}, int_mask_reg};
            ADDR_INT_PENDING: prdata = {{(32-NUM_INTERRUPTS){1'b0}}, int_pending_reg};
            ADDR_INT_CONFIG:  prdata = int_config_reg;
            default:          prdata = 32'h0;
        endcase
    end

    // Debug and monitoring
    `ifdef SIMULATION
    // Monitor interrupt events
    always @(posedge clk) begin
        if (rst_n) begin
            for (int i = 0; i < NUM_INTERRUPTS; i++) begin
                if (interrupt_sources[i] && !int_status_reg[i]) begin
                    $display("[INT_CTRL] Time=%0t: Interrupt %0d asserted", $time, i);
                end
            end
            
            if (apb_write && paddr == ADDR_INT_CLEAR && pwdata != 0) begin
                $display("[INT_CTRL] Time=%0t: Clearing interrupts: 0x%08x", $time, pwdata);
            end
        end
    end
    `endif

endmodule

// Wrapper for UVM testbench integration
interface int_controller_if (
    input logic clk,
    input logic rst_n
);
    
    logic [31:0] interrupt_sources;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        irq_to_ap;
    logic        irq_to_scp;
    logic        irq_to_mcp;
    logic        irq_to_imu;
    logic        irq_to_io;
    logic        irq_to_other_die;

    // Instantiate the interrupt controller
    int_controller #(
        .NUM_INTERRUPTS(32),
        .ADDR_WIDTH(8)
    ) u_int_controller (
        .clk(clk),
        .rst_n(rst_n),
        .interrupt_sources(interrupt_sources),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .irq_to_ap(irq_to_ap),
        .irq_to_scp(irq_to_scp),
        .irq_to_mcp(irq_to_mcp),
        .irq_to_imu(irq_to_imu),
        .irq_to_io(irq_to_io),
        .irq_to_other_die(irq_to_other_die)
    );

    // Task to write to interrupt controller registers
    task write_register(input logic [7:0] addr, input logic [31:0] data);
        @(posedge clk);
        psel <= 1'b1;
        pwrite <= 1'b1;
        paddr <= addr;
        pwdata <= data;
        @(posedge clk);
        penable <= 1'b1;
        @(posedge clk);
        while (!pready) @(posedge clk);
        psel <= 1'b0;
        penable <= 1'b0;
        pwrite <= 1'b0;
    endtask

    // Task to read from interrupt controller registers
    task read_register(input logic [7:0] addr, output logic [31:0] data);
        @(posedge clk);
        psel <= 1'b1;
        pwrite <= 1'b0;
        paddr <= addr;
        @(posedge clk);
        penable <= 1'b1;
        @(posedge clk);
        while (!pready) @(posedge clk);
        data = prdata;
        psel <= 1'b0;
        penable <= 1'b0;
    endtask

    // Task to clear specific interrupts
    task clear_interrupts(input logic [31:0] clear_mask);
        write_register(8'h04, clear_mask); // Write to clear register
    endtask

    // Task to enable/disable interrupt mask
    task set_interrupt_mask(input logic [31:0] mask);
        write_register(8'h08, mask); // Write to mask register
    endtask

endinterface

`endif // INT_CONTROLLER_SV

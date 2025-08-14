`ifndef INT_DEF_SV
`define INT_DEF_SV

// Defines the groups of interrupts from the CSV file
typedef enum {
    IOSUB,
    USB,
    SCP,
    MCP,
    SMMU,
    IODAP,
    ACCEL,
    CSUB,
    PSUB,
    PCIE1,
    D2D,
    DDR0,
    DDR1,
    DDR2,
    IO_DIE,
    PMERGE
} interrupt_group_e;

localparam int PLL_MASK_WIDTH = 25;
typedef enum int {
    PLL_T_LOCK = 0,
    PLL_T_UNLOCK = 1,
    PLL_T_FRECHANGEDONE = 2,
    PLL_T_FRECHANGE_TOT_DONE = 3,
    PLL_T_INTDOCFRAC_ERR = 4
} pll_type_e;

// Defines trigger and polarity types
typedef enum { LEVEL, EDGE, PULSE, UNKNOWN_TRIGGER } interrupt_trigger_e;
typedef enum { ACTIVE_HIGH, ACTIVE_LOW, RISING_FALLING, UNKNOWN_POLARITY } interrupt_polarity_e;

// Defines the structure for a single interrupt entry in our model
typedef struct {
    string               name;
    int                  index;
    interrupt_group_e    group;
    interrupt_trigger_e  trigger;
    interrupt_polarity_e polarity;
    string               rtl_path_src; // RTL path to force the interrupt source
    int                  pulse_width_ns; // Width of pulse interrupt in nanoseconds (only for PULSE type)

    // Destination routing information and check paths
    bit                  to_ap;
    string               rtl_path_ap;
    int                  dest_index_ap;      // Index in destination interrupt vector
    bit                  to_scp;
    string               rtl_path_scp;
    int                  dest_index_scp;     // Index in destination interrupt vector
    bit                  to_mcp;
    string               rtl_path_mcp;
    int                  dest_index_mcp;     // Index in destination interrupt vector
    bit                  to_accel;
    string               rtl_path_accel;
    int                  dest_index_accel;     // Index in destination interrupt vector
    bit                  to_io;
    string               rtl_path_io;
    int                  dest_index_io;      // Index in destination interrupt vector
    bit                  to_other_die;
    string               rtl_path_other_die;
    int                  dest_index_other_die; // Index in destination interrupt vector
} interrupt_info_s;

localparam int PSUB_MASK_WIDTH = 20; // [19:0]
localparam int PCIE1_MASK_WIDTH = 20; // [19:0]

`endif // INT_DEF_SV

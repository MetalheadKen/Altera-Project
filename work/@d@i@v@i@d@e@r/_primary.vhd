library verilog;
use verilog.vl_types.all;
entity DIVIDER is
    port(
        CLK             : in     vl_logic;
        RESET           : in     vl_logic;
        CLK_1HZ         : out    vl_logic
    );
end DIVIDER;

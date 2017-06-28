library verilog;
use verilog.vl_types.all;
entity FSM_RGY_LIGHT is
    port(
        CLOCK_27        : in     vl_logic;
        SW              : in     vl_logic_vector(17 downto 0);
        HEX0            : out    vl_logic_vector(6 downto 0);
        LEDR            : out    vl_logic_vector(17 downto 0)
    );
end FSM_RGY_LIGHT;

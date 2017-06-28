library verilog;
use verilog.vl_types.all;
entity RGY_LIGHT is
    generic(
        RED             : vl_logic_vector(1 downto 0) := (Hi0, Hi0);
        GREEN           : vl_logic_vector(1 downto 0) := (Hi0, Hi1);
        YELLOW          : vl_logic_vector(1 downto 0) := (Hi1, Hi0)
    );
    port(
        CLK             : in     vl_logic;
        RESET           : in     vl_logic;
        SEC_SEGMENT     : out    vl_logic_vector(2 downto 0);
        RED_LED         : out    vl_logic;
        GREEN_LED       : out    vl_logic;
        YELLOW_LED      : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of RED : constant is 2;
    attribute mti_svvh_generic_type of GREEN : constant is 2;
    attribute mti_svvh_generic_type of YELLOW : constant is 2;
end RGY_LIGHT;

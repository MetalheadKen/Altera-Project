library verilog;
use verilog.vl_types.all;
entity SEGMENT is
    port(
        SECOND          : in     vl_logic_vector(2 downto 0);
        DATA            : out    vl_logic_vector(6 downto 0)
    );
end SEGMENT;

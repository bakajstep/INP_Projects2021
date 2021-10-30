-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): DOPLNIT
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

-- PC
	signal pc_inc      : std_logic;
	signal pc_dec      : std_logic;
	signal pc_output   : std_logic_vector(11 downto 0);
-- CNT
	signal cnt_inc     : std_logic;
	signal cnt_dec     : std_logic;
	signal cnt_output  : std_logic_vector(9 downto 0);
-- PTR
	signal ptr_inc     : std_logic;
	signal ptr_dec     : std_logic;
	signal ptr_output  : std_logic_vector(9 downto 0);
--MX
	signal mux_sel     : std_logic_vector(1 downto 0);
	signal mux_output  : std_logic_vector(7 downto 0);
-- FSM
	type fsm_state is (
		start,
		fetch,
		decode,
		--operators
		inc_ptr,
		dec_ptr,
		inc_val,
		inc_val_mux,
		inc_val_write,
		dec_val,
		dec_val_mux,
		dec_val_write,
		left_bracket,
		left_bracket_1,
		left_bracket_2,
		left_bracket_3,
		right_bracket,
		right_bracket_1,
		right_bracket_2,
		right_bracket_3,
		right_bracket_4,
		print,
		print_readed,
		load,
		load_ready,
		tilda,
		tilda_1,
		tilda_2,
		zero
	);
	signal state       : fsm_state;
	signal n_state     : fsm_state;
begin

-- Program counter
	pc: process (CLK, RESET, pc_inc, pc_dec) is
	begin
		if RESET = '1' then
			pc_output <= (others => '0');
		elsif rising_edge(CLK) then
				if pc_inc = '1' then
					pc_output <= pc_output + 1;
				elsif pc_dec = '1' then
					pc_output <= pc_output - 1;
				end if;
		end if;
	end process;
	CODE_ADDR <= pc_output;
	
-- Counter
	cnt: process (CLK, RESET, cnt_inc, cnt_dec) is
	begin
		if RESET = '1' then
			cnt_output <= (others => '0');
		elsif rising_edge(CLK) then
				if cnt_inc = '1' then
					cnt_output <= cnt_output + 1;
				elsif cnt_dec = '1' then
					cnt_output <= cnt_output - 1;
				end if;
		end if;
	end process;
	OUT_DATA <= DATA_RDATA;

-- Pointer
	ptr: process (CLK, RESET, ptr_inc, ptr_dec) is
	begin
		if RESET = '1' then
			ptr_output <= (others => '0');
		elsif rising_edge(CLK) then
				if ptr_inc = '1' then
					ptr_output <= ptr_output + 1;
				elsif ptr_dec = '1' then
					ptr_output <= ptr_output - 1;
				end if;
		end if;
	end process;
	DATA_ADDR <= ptr_output;
	
-- MUX
	mux: process (CLK, RESET, mux_sel) is
	begin
		if RESET = '1' then
			mux_output <= (others => '0');
		elsif rising_edge(CLK) then
			case mux_sel is
				when "00" =>
					mux_output <= IN_DATA;
				when "01" =>
					mux_output <= DATA_RDATA + 1;
				when "10" =>
					mux_output <= DATA_RDATA - 1;
				when others =>
					mux_output <= (others => '0');
			end case;
		end if;
	end process;
	DATA_WDATA <= mux_output;
	
-- FSM
	logic: process(CLK, RESET, EN) is
	begin
		if RESET = '1' then
			state <= start;
		elsif rising_edge(CLK) then
			if EN = '1' then
				state <= n_state;
			end if;
		end if;
	end process;
	
	fsm: process (state, IN_VLD, OUT_BUSY, CODE_DATA, DATA_RDATA) is
	begin
		-- Initialization
		pc_inc <= '0';
		pc_dec <= '0';
		cnt_inc <= '0';
		cnt_dec <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
		CODE_EN <= '0';
		DATA_EN <= '0';
		IN_REQ <= '0';
		OUT_WREN <= '0';
		mux_sel <= "00";
		
		-- switch
		case state is
			when start =>
				n_state <= fetch;
			when fetch =>
				CODE_EN <= '1';
				n_state <= decode;
			when decode =>
				case CODE_DATA is
					when X"3E" =>
						n_state <= inc_ptr;
					when X"3C" =>
						n_state <= dec_ptr;
					when X"2B" =>
						n_state <= inc_val;
					when X"2D" =>
						n_state <= dec_val;
					when X"5B" =>
						n_state <= left_bracket;
					when X"5D" =>
						n_state <= right_bracket;
					when X"2E" =>
						n_state <= print;
					when X"2C" =>
						n_state <= load;
					when X"7E" =>
						n_state <= tilda;
					when X"00" =>
						n_state <= zero;
					when others =>
						pc_inc <= '1';
						n_state <= decode;
				end case;
			when inc_ptr =>
				ptr_inc <= '1';
				pc_inc <= '1';
				n_state <= fetch;
			when dec_ptr => 
				ptr_dec <= '1';
				pc_inc <= '1';
				n_state <= fetch;
			when inc_val => 
				DATA_EN <= '1';
				DATA_WREN <= '0';
				n_state <= inc_val_mux;
			when inc_val_mux =>
				mux_sel <= "01";
				n_state <= inc_val_write;
			when inc_val_write =>
				DATA_EN <= '1';
				DATA_WREN <= '1';
				pc_inc <= '1';
				n_state <= fetch;
			when dec_val => 
				DATA_EN <= '1';
				DATA_WREN <= '0';
				n_state <= dec_val_mux;
			when dec_val_mux =>
				mux_sel <= "10";
				n_state <= dec_val_write;
			when dec_val_write =>
				DATA_EN <= '1';
				DATA_WREN <= '1';
				pc_inc <= '1';
				n_state <= fetch;
			when print =>
				DATA_EN <= '1';
				DATA_WREN <= '0';
				n_state <= print_readed;
			when print_readed =>
				if OUT_BUSY = '1' then
					DATA_EN <= '1';
					DATA_WREN <= '0';
					n_state <= print_readed;
				else
					OUT_WREN <= '1';
					pc_inc <= '1';
					n_state <= fetch;
				end if;
			when load =>
				IN_REQ <= '1';
				mux_sel <= "00";
				n_state <= load_ready;
			when load_ready =>
				if IN_VLD = '0' then
					IN_REQ <= '1';
					mux_sel <= "00";
					n_state <= load_ready;
				else
					DATA_EN <= '1';
					DATA_WREN <= '1';
					pc_inc <= '1';
					n_state <= fetch;
				end if;
			when left_bracket =>
				pc_inc <= '1';
				DATA_EN <= '1';
				DATA_WREN <= '0';
				n_state <= left_bracket_1;
			when left_bracket_1 =>
				if DATA_RDATA = "00000000" then -- if (ram[PTR] == 0)
					cnt_output <= "0000000001";
					CODE_EN <= '1';
					n_state <= left_bracket_2;
				else
					n_state <= fetch;
				end if;
			when left_bracket_3 =>  --CODE_DATA = ROM[CODE_ADDR]
				CODE_EN <= '1'; 
				n_state <= left_bracket_2;
			when left_bracket_2 =>
				if cnt_output /= "0000000000" then
					if CODE_DATA = X"5B" then -- if (CODE_DATA == '[')
						cnt_inc <= '1';
					elsif CODE_DATA = X"5D" then -- if (CODE_DATA == ']')
						cnt_dec <= '1';
					end if;
					pc_inc <= '1';
					n_state <= left_bracket_3;
				else
					n_state <= fetch;
				end if;
			when right_bracket =>
				DATA_EN <= '1';
				DATA_WREN <= '0';
				n_state <= right_bracket_1;
			when right_bracket_1 =>
				if DATA_RDATA = "00000000" then --if (ram[PTR] == 0)
					pc_inc <= '1';
					n_state <= fetch;
				else
					cnt_output <= "0000000001";
					pc_dec <= '1';
					n_state <= right_bracket_2;
				end if;
			when right_bracket_2 =>
				CODE_EN <= '1'; 
				n_state <= right_bracket_3;
			when right_bracket_3 =>
				if cnt_output = "0000000000" then
					n_state <= fetch;
				else
					if CODE_DATA = X"5D" then -- if (CODE_DATA == '[')
						cnt_inc <= '1';
					elsif CODE_DATA = X"5B" then -- if (CODE_DATA == ']')
						cnt_dec <= '1';
					end if;
					n_state <= right_bracket_4;
				end if;
			when right_bracket_4 =>
				if cnt_output = "0000000000" then
					pc_inc <= '1';
				else
					pc_dec <= '1';
				end if;
				n_state <= right_bracket_2;
			when tilda =>
				cnt_inc <= '1';
				pc_inc <= '1';
				n_state <= tilda_1;
			when tilda_1 =>
				CODE_EN <= '1';
				n_state <= tilda_2;
			when tilda_2 =>
				if cnt_output = "0000000000" then
					n_state <= fetch;
				else
					if CODE_DATA = X"5B" then -- if (CODE_DATA == '[')
						cnt_inc <= '1';
					elsif CODE_DATA = X"5D" then -- if (CODE_DATA == ']')
						cnt_dec <= '1';
					end if;
					pc_inc <= '1';
					n_state <= tilda_1;
				end if;
			when zero =>
				n_state <= zero;
			when others =>  
				pc_inc <= '1';
				n_state <= fetch;
		end case;
	end process;
end behavioral;
 

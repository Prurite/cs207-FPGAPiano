# Board id: xc7a35tcsg324-1

set_property IOSTANDARD LVCMOS33 [get_ports *]

set_property PACKAGE_PIN P17 [get_ports clk]
set_property PACKAGE_PIN R11 [get_ports sys_rst]

set_property PACKAGE_PIN K5 [get_ports ps2_clk]
set_property PACKAGE_PIN L4 [get_ports ps2_data]

# btn_arr => buttons, btn_notes => switches, btn_oct_up, btn_oct_down;
# sw_user_id => small switches

set_property PACKAGE_PIN T1 [get_ports audio_pwm]
set_property PACKAGE_PIN M6 [get_ports audio_sd]

set_property PACKAGE_PIN B4 [get_ports {seg[0][0]}]
set_property PACKAGE_PIN A4 [get_ports {seg[0][1]}]
set_property PACKAGE_PIN A3 [get_ports {seg[0][2]}]
set_property PACKAGE_PIN B1 [get_ports {seg[0][3]}]
set_property PACKAGE_PIN A1 [get_ports {seg[0][4]}]
set_property PACKAGE_PIN B3 [get_ports {seg[0][5]}]
set_property PACKAGE_PIN B2 [get_ports {seg[0][6]}]

set_property PACKAGE_PIN D4 [get_ports {seg[1][0]}]
set_property PACKAGE_PIN E3 [get_ports {seg[1][1]}]
set_property PACKAGE_PIN D3 [get_ports {seg[1][2]}]
set_property PACKAGE_PIN F4 [get_ports {seg[1][3]}]
set_property PACKAGE_PIN F3 [get_ports {seg[1][4]}]
set_property PACKAGE_PIN E2 [get_ports {seg[1][5]}]
set_property PACKAGE_PIN D2 [get_ports {seg[1][6]}]

set_property PACKAGE_PIN G2 [get_ports {seg_sel[0][0]}]
set_property PACKAGE_PIN C2 [get_ports {seg_sel[0][1]}]
set_property PACKAGE_PIN C1 [get_ports {seg_sel[0][2]}]
set_property PACKAGE_PIN H1 [get_ports {seg_sel[0][3]}]
set_property PACKAGE_PIN G1 [get_ports {seg_sel[1][0]}]
set_property PACKAGE_PIN F1 [get_ports {seg_sel[1][1]}]
set_property PACKAGE_PIN E1 [get_ports {seg_sel[1][2]}]
set_property PACKAGE_PIN G6 [get_ports {seg_sel[1][3]}]

# led displays

set_property PACKAGE_PIN F5 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN C6 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN B7 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D8 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN E6 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN E5 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN E7 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN D7 [get_ports {vga_hsync}]
set_property PACKAGE_PIN C4 [get_ports {vga_vsync}]
transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

set proj_root [file normalize [file join [pwd] ../..]]

vlog -sv -work work +incdir+$proj_root "$proj_root/Counter.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/Timer.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/PE.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/Cache_MSI.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/Interconnect_MSI.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/Ram.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/clk_div.sv"
vlog -sv -work work +incdir+$proj_root "$proj_root/Top.sv"

vlog -sv -work work +incdir+$proj_root "$proj_root/Top_tb.sv"

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  Top_tb

add wave *
view structure
view signals
run -all

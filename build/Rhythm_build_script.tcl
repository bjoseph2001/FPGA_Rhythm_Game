#Get base directory of the repo
set base_dir [exec git rev-parse --show-toplevel]

#Set the project name
set _xil_proj_name_ "FPGA_Rhythm_Game"

#Create project
create_project $_xil_proj_name_ $base_dir/build -part xc7a100tcsg324-1 -force 

#Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

if {[llength [get_filesets sources_1]] == 0} {
    create_fileset -srcset sources_1
}
if {[llength [get_filesets constrs_1]] == 0} {
    create_fileset -constrset constrs_1
}
if {[llength [get_filesets sim_1]] == 0} {
    create_fileset -simset sim_1
}

#Use glob to get all files in directory
set src_files [glob -nocomplain $base_dir/source/hdl/*.vhd]
set constrs_files [glob -nocomplain $base_dir/source/constraints/*.xdc]
set sim_files [glob -nocomplain $base_dir/source/sim/*]
set ip_files [glob -nocomplain $base_dir/source/ip/*.xci]

#Add source files
add_files -fileset sources_1 $src_files
#Add constraints
add_files -fileset constrs_1 $constrs_files
#Add sim files
add_files -fileset sim_1 $sim_files

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set project properties
set obj [current_project]
set_property -name "board_part" -value "digilentinc.com:nexys-a7-100t:part0:1.2" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${_xil_proj_name_}.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "platform.board_id" -value "nexys-a7-100t" -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "sim_compile_state" -value "1" -objects $obj
set_property -name "target_language" -value "VHDL" -objects $obj
set_property -name "webtalk.activehdl_export_sim" -value "3" -objects $obj
set_property -name "webtalk.modelsim_export_sim" -value "3" -objects $obj
set_property -name "webtalk.questa_export_sim" -value "3" -objects $obj
set_property -name "webtalk.riviera_export_sim" -value "3" -objects $obj
set_property -name "webtalk.vcs_export_sim" -value "3" -objects $obj
set_property -name "webtalk.xsim_export_sim" -value "3" -objects $obj
set_property -name "webtalk.xsim_launch_sim" -value "113" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC" -objects $obj
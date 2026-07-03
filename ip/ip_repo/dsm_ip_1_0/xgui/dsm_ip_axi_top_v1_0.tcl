# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ALGORITHM" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BB_SAMPLE_RATE_HZ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CLK_FREQ_HZ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXIS_TDATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DUC_MODE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LUT_AW" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PHASE_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RF_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SIGNAL_BW_HZ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TW_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "W" -parent ${Page_0}


}

proc update_PARAM_VALUE.ALGORITHM { PARAM_VALUE.ALGORITHM } {
	# Procedure called to update ALGORITHM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ALGORITHM { PARAM_VALUE.ALGORITHM } {
	# Procedure called to validate ALGORITHM
	return true
}

proc update_PARAM_VALUE.BB_SAMPLE_RATE_HZ { PARAM_VALUE.BB_SAMPLE_RATE_HZ } {
	# Procedure called to update BB_SAMPLE_RATE_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BB_SAMPLE_RATE_HZ { PARAM_VALUE.BB_SAMPLE_RATE_HZ } {
	# Procedure called to validate BB_SAMPLE_RATE_HZ
	return true
}

proc update_PARAM_VALUE.CLK_FREQ_HZ { PARAM_VALUE.CLK_FREQ_HZ } {
	# Procedure called to update CLK_FREQ_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CLK_FREQ_HZ { PARAM_VALUE.CLK_FREQ_HZ } {
	# Procedure called to validate CLK_FREQ_HZ
	return true
}

proc update_PARAM_VALUE.C_S_AXIS_TDATA_WIDTH { PARAM_VALUE.C_S_AXIS_TDATA_WIDTH } {
	# Procedure called to update C_S_AXIS_TDATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXIS_TDATA_WIDTH { PARAM_VALUE.C_S_AXIS_TDATA_WIDTH } {
	# Procedure called to validate C_S_AXIS_TDATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DUC_MODE { PARAM_VALUE.DUC_MODE } {
	# Procedure called to update DUC_MODE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DUC_MODE { PARAM_VALUE.DUC_MODE } {
	# Procedure called to validate DUC_MODE
	return true
}

proc update_PARAM_VALUE.LUT_AW { PARAM_VALUE.LUT_AW } {
	# Procedure called to update LUT_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LUT_AW { PARAM_VALUE.LUT_AW } {
	# Procedure called to validate LUT_AW
	return true
}

proc update_PARAM_VALUE.PHASE_W { PARAM_VALUE.PHASE_W } {
	# Procedure called to update PHASE_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PHASE_W { PARAM_VALUE.PHASE_W } {
	# Procedure called to validate PHASE_W
	return true
}

proc update_PARAM_VALUE.RF_W { PARAM_VALUE.RF_W } {
	# Procedure called to update RF_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RF_W { PARAM_VALUE.RF_W } {
	# Procedure called to validate RF_W
	return true
}

proc update_PARAM_VALUE.SIGNAL_BW_HZ { PARAM_VALUE.SIGNAL_BW_HZ } {
	# Procedure called to update SIGNAL_BW_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SIGNAL_BW_HZ { PARAM_VALUE.SIGNAL_BW_HZ } {
	# Procedure called to validate SIGNAL_BW_HZ
	return true
}

proc update_PARAM_VALUE.TW_W { PARAM_VALUE.TW_W } {
	# Procedure called to update TW_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TW_W { PARAM_VALUE.TW_W } {
	# Procedure called to validate TW_W
	return true
}

proc update_PARAM_VALUE.W { PARAM_VALUE.W } {
	# Procedure called to update W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.W { PARAM_VALUE.W } {
	# Procedure called to validate W
	return true
}


proc update_MODELPARAM_VALUE.W { MODELPARAM_VALUE.W PARAM_VALUE.W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.W}] ${MODELPARAM_VALUE.W}
}

proc update_MODELPARAM_VALUE.RF_W { MODELPARAM_VALUE.RF_W PARAM_VALUE.RF_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RF_W}] ${MODELPARAM_VALUE.RF_W}
}

proc update_MODELPARAM_VALUE.PHASE_W { MODELPARAM_VALUE.PHASE_W PARAM_VALUE.PHASE_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PHASE_W}] ${MODELPARAM_VALUE.PHASE_W}
}

proc update_MODELPARAM_VALUE.LUT_AW { MODELPARAM_VALUE.LUT_AW PARAM_VALUE.LUT_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LUT_AW}] ${MODELPARAM_VALUE.LUT_AW}
}

proc update_MODELPARAM_VALUE.TW_W { MODELPARAM_VALUE.TW_W PARAM_VALUE.TW_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TW_W}] ${MODELPARAM_VALUE.TW_W}
}

proc update_MODELPARAM_VALUE.ALGORITHM { MODELPARAM_VALUE.ALGORITHM PARAM_VALUE.ALGORITHM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ALGORITHM}] ${MODELPARAM_VALUE.ALGORITHM}
}

proc update_MODELPARAM_VALUE.DUC_MODE { MODELPARAM_VALUE.DUC_MODE PARAM_VALUE.DUC_MODE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DUC_MODE}] ${MODELPARAM_VALUE.DUC_MODE}
}

proc update_MODELPARAM_VALUE.CLK_FREQ_HZ { MODELPARAM_VALUE.CLK_FREQ_HZ PARAM_VALUE.CLK_FREQ_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CLK_FREQ_HZ}] ${MODELPARAM_VALUE.CLK_FREQ_HZ}
}

proc update_MODELPARAM_VALUE.BB_SAMPLE_RATE_HZ { MODELPARAM_VALUE.BB_SAMPLE_RATE_HZ PARAM_VALUE.BB_SAMPLE_RATE_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BB_SAMPLE_RATE_HZ}] ${MODELPARAM_VALUE.BB_SAMPLE_RATE_HZ}
}

proc update_MODELPARAM_VALUE.SIGNAL_BW_HZ { MODELPARAM_VALUE.SIGNAL_BW_HZ PARAM_VALUE.SIGNAL_BW_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SIGNAL_BW_HZ}] ${MODELPARAM_VALUE.SIGNAL_BW_HZ}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXIS_TDATA_WIDTH { MODELPARAM_VALUE.C_S_AXIS_TDATA_WIDTH PARAM_VALUE.C_S_AXIS_TDATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXIS_TDATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXIS_TDATA_WIDTH}
}


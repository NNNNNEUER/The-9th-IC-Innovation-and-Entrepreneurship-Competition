cd   "E:/eLinx3.0/bin/shell/bin"
set tclFile  "E:/eLinx3.0/bin/shell/bin/run_pack.tcl"
set dir "G:/jichuangsai/elinx_workspace/edge_eye_final(3)"
set prj edge_eye
set topEntity edge_eye
set seriesName "eHiChip6"
set deviceName "EQ6HL130"
set packageName "CSG484_H"
set synthName synth_1
source $tclFile
run_pack $dir $prj $topEntity $seriesName $deviceName $packageName $synthName
exit 0

cd   "E:/eLinx3.0/bin/shell/bin"
set tclFile  "E:/eLinx3.0/bin/shell/bin/run_route.tcl"
set dir "G:/jichuangsai/elinx_workspace/edge_eye_final(3)"
set prj edge_eye
set topEntity comet_ela_top
set seriesName "eHiChip6"
set deviceName EQ6HL130
set packageName CSG484_H
set synthName imple_1
set ImpleName imple_1
source $tclFile
run_route $dir $prj $topEntity $seriesName $deviceName $packageName $synthName $ImpleName
exit 0

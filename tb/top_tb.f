-f $MDL_PATH/tb/top_env.f
//--------------------------------------------//
//-----"Compile the subenv you need"----------//
-f $MDL_PATH/subenv/int_subenv/int_subenv.f
//--------------------------------------------//
$MDL_PATH/subenv/int_subenv/test/int_test_pkg.sv

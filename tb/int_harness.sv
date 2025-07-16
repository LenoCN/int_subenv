`ifndef INT_HARNESS1
`define INT_HARNESS1
module int_harness(
  );

  int_interface      u_int_if();
  initial begin :CFGDB_IF
      virtual int_interface v_int_if;
      v_int_if = u_int_if;
      uvm_config_db#(virtual int_interface)::set(uvm_root::get(),"","int_if",v_int_if);
  end

endmodule

bind top_tb int_harness u_int_harness(
);

`endif

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---------------------------------------------------------
// 1. INTERFACE
// ---------------------------------------------------------
interface fifo_if(input logic clk, input logic rst_n);
    logic we, re;
    logic [7:0] din, dout;
    logic full, empty;
endinterface

// ---------------------------------------------------------
// 2. TRANSACTION (Sequence Item)
// ---------------------------------------------------------
class fifo_item extends uvm_sequence_item;
    rand bit we;
    rand bit re;
    rand bit [7:0] din;
    bit [7:0] dout;

    // Constraint: Don't read and write on the exact same cycle for this basic test
    constraint c_op { we != re; }

    `uvm_object_utils_begin(fifo_item)
        `uvm_field_int(we, UVM_DEFAULT)
        `uvm_field_int(re, UVM_DEFAULT)
        `uvm_field_int(din, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "fifo_item");
        super.new(name);
    endfunction
endclass

// ---------------------------------------------------------
// 3. SEQUENCE (Patched for Maximum Coverage)
// ---------------------------------------------------------
class fifo_sequence extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_sequence)
    
    function new(string name = "fifo_sequence");
        super.new(name);
    endfunction

    task body();
        // Phase 1: Burst Write to hit the 'full' flag
        for(int i=0; i<17; i++) begin
            req = fifo_item::type_id::create("req"); start_item(req);
            assert(req.randomize() with { we == 1; re == 0; });
            finish_item(req);
        end

        // Phase 2: Burst Read to hit the 'empty' flag
        for(int i=0; i<16; i++) begin
            req = fifo_item::type_id::create("req"); start_item(req);
            assert(req.randomize() with { we == 0; re == 1; });
            finish_item(req);
        end

        // Phase 3: Random Stress Test
        for(int i=0; i<50; i++) begin
            req = fifo_item::type_id::create("req"); start_item(req);
            assert(req.randomize());
            finish_item(req);
        end
    endtask
endclass

// ---------------------------------------------------------
// 4. DRIVER
// ---------------------------------------------------------
class fifo_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_driver)
    virtual fifo_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.we <= req.we;
            vif.re <= req.re;
            vif.din <= req.din;
            seq_item_port.item_done();
        end
    endtask
endclass

// ---------------------------------------------------------
// 5. MONITOR (Upgraded with Functional Coverage)
// ---------------------------------------------------------
class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)
    virtual fifo_if vif;
    uvm_analysis_port #(fifo_item) ap;

    // The Functional Coverage Model
    covergroup fifo_cg;
        option.per_instance = 1;
        cp_we: coverpoint vif.we { bins active = {1}; }
        cp_re: coverpoint vif.re { bins active = {1}; }
        cp_full: coverpoint vif.full { bins is_full = {1}; bins not_full = {0}; }
        cp_empty: coverpoint vif.empty { bins is_empty = {1}; bins not_empty = {0}; }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        fifo_cg = new(); // Instantiate the covergroup
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "virtual interface missing");
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) continue;

            fifo_cg.sample(); // Sample coverage on every clock cycle

            // Sample Writes
            if (vif.we && !vif.full) begin
                fifo_item w_item = fifo_item::type_id::create("w_item");
                w_item.we = 1; w_item.re = 0; w_item.din = vif.din;
                ap.write(w_item);
            end

            // Sample Reads (Forked)
            if (vif.re && !vif.empty) begin
                fork
                    begin
                        fifo_item r_item = fifo_item::type_id::create("r_item");
                        r_item.we = 0; r_item.re = 1;
                        @(posedge vif.clk); 
                        r_item.dout = vif.dout;
                        ap.write(r_item);
                    end
                join_none
            end
        end
    endtask

    // Automatically print the coverage score at the end of the simulation
    function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE", $sformatf("FINAL FUNCTIONAL COVERAGE: %0.2f%%", fifo_cg.get_inst_coverage()), UVM_NONE);
    endfunction
endclass
// ---------------------------------------------------------
// 6. SCOREBOARD (The Brains)
// ---------------------------------------------------------
class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)
    uvm_analysis_imp #(fifo_item, fifo_scoreboard) ap_imp;
    
    int expected_q[$]; // The Golden Model

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(fifo_item item);
        if (item.we) begin
            expected_q.push_back(item.din);
            `uvm_info("SCB", $sformatf("Write detected: %0h", item.din), UVM_LOW);
        end
        if (item.re) begin
            if (expected_q.size() > 0) begin
                bit [7:0] exp_data = expected_q.pop_front();
                if (exp_data == item.dout) begin
                    `uvm_info("SCB_PASS", $sformatf("Match! Expected: %0h, Actual: %0h", exp_data, item.dout), UVM_LOW);
                end else begin
                    `uvm_error("SCB_FAIL", $sformatf("Mismatch! Expected: %0h, Actual: %0h", exp_data, item.dout));
                end
            end
        end
    endfunction
endclass

// ---------------------------------------------------------
// 7. ENVIRONMENT & TEST
// ---------------------------------------------------------
class fifo_env extends uvm_env;
    `uvm_component_utils(fifo_env)
    fifo_driver drv;
    fifo_monitor mon;
    fifo_scoreboard scb;
    uvm_sequencer #(fifo_item) seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = fifo_driver::type_id::create("drv", this);
        mon = fifo_monitor::type_id::create("mon", this);
        scb = fifo_scoreboard::type_id::create("scb", this);
        seqr = new("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.ap.connect(scb.ap_imp);
    endfunction
endclass

class fifo_test extends uvm_test;
    `uvm_component_utils(fifo_test)
    fifo_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_sequence seq;
        phase.raise_objection(this);
        seq = fifo_sequence::type_id::create("seq");
        seq.start(env.seqr);
        #100; // Let final transactions clear
        phase.drop_objection(this);
    endtask
endclass

// ---------------------------------------------------------
// 8. TOP MODULE
// ---------------------------------------------------------
module tb_top;
    logic clk;
    logic rst_n;

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Interface and DUT
    fifo_if vif(clk, rst_n);
    
    sync_fifo DUT (
        .clk(vif.clk),
        .rst_n(vif.rst_n),
        .we(vif.we),
        .re(vif.re),
        .din(vif.din),
        .dout(vif.dout),
        .full(vif.full),
        .empty(vif.empty)
    );

    // Start UVM
    initial begin
        uvm_config_db#(virtual fifo_if)::set(null, "*", "vif", vif);
        run_test("fifo_test");
    end
endmodule
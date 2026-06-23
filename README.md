# UVM Verification Environment for Synchronous FIFO

A complete, self-checking Universal Verification Methodology (UVM 1.2) testbench architected to verify an 8-bit Synchronous FIFO. This project demonstrates advanced constrained-random stimulus generation, cycle-accurate data integrity checking, and functional coverage tracking using SystemVerilog and Xilinx Vivado (XSim).

## Key Features & Verification Methodology

* **UVM Architecture:** Fully modular testbench featuring a standard UVM sequence, driver, monitor, and scoreboard topology.
* **100% Functional Coverage:** Implemented a custom `covergroup` within the monitor to natively track and verify interface edge cases (Full, Empty, Read, Write).
* **Golden Reference Model:** The `uvm_scoreboard` utilizes native SystemVerilog queues (`[$]`) to mimic internal memory state, automating pass/fail conditions with zero dropped transactions.
* **Parallel Bus Sampling:** Engineered non-blocking `fork...join_none` threads within the `uvm_monitor` to accurately capture simultaneous read/write cycles on the same clock edge.
* **Constrained-Random Stimulus:** Designed directed burst-read/write sequences to deliberately slam the FIFO into bounded states, followed by randomized stress testing.

## Project Structure

To maintain a streamlined execution flow for local command-line simulation, the project is consolidated into two primary files:

* `fifo.sv` - The Design Under Test (DUT). An 8-bit wide, 16-deep synchronous FIFO with `full` and `empty` control flags.
* `tb.sv` - The complete UVM testbench (Interface, Item, Sequence, Driver, Monitor, Scoreboard, Env, Test, and Top).

## Prerequisites

This environment is built to be simulated directly via the command line using Vivado Simulator (XSim). 
* Xilinx Vivado (Tested on version 2025.2)
* UVM 1.2 Library (Natively supported by XSim)

## Quickstart: Running the Simulation

You do not need to build a Vivado GUI project to run this testbench. Open the Vivado Tcl Shell, navigate to the directory containing the source files, and execute the following commands:

**1. Compile the SystemVerilog files and link the UVM library:**
```tcl
xvlog -L uvm -sv fifo.sv tb.sv
```
**2. Elaborate the design and build the snapshot**
```tcl
xelab -L uvm -top tb_top -snapshot uvm_snap
```
**3. Run the simulation**
```tcl
xsim uvm_snap -R
```

## Quickstart: Running the Simulation

```tcl
--- UVM Report Summary ---

** Report counts by severity
UVM_INFO :    89
UVM_WARNING :    0
UVM_ERROR :      0
UVM_FATAL :      0

** Report counts by id
[COVERAGE]       1    
[SCB_PASS]      42


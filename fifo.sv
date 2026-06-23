module sync_fifo #(parameter DEPTH=16, WIDTH=8) (
    input  logic clk,
    input  logic rst_n,
    input  logic we,
    input  logic re,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout,
    output logic full,
    output logic empty
);
    logic [WIDTH-1:0] mem [DEPTH];
    logic [$clog2(DEPTH)-1:0] wptr, rptr;
    logic [$clog2(DEPTH):0] count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0; rptr <= 0; count <= 0; dout <= 0;
        end else begin
            // Write Logic
            if (we && !full) begin
                mem[wptr] <= din;
                wptr <= wptr + 1;
            end
            // Read Logic
            if (re && !empty) begin
                dout <= mem[rptr];
                rptr <= rptr + 1;
            end
            // Count Update Logic
            if ((we && !full) && !(re && !empty))
                count <= count + 1;
            else if (!(we && !full) && (re && !empty))
                count <= count - 1;
        end
    end
endmodule
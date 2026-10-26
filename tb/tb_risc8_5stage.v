
 // =====================================================================
 //  TỆP         : tb/tb_risc8_5stage.v
 //  MODULE      : tb_risc8_5stage (TESTBENCH - chỉ dùng để mô phỏng)
 //  DỰ ÁN       : Bộ xử lý RISC 8-bit với đường ống 5 giai đoạn
 // ---------------------------------------------------------------------
 //  CHỨC NĂNG CỦA TỆP NÀY
 //    1. Tạo tín hiệu xung clock và reset.
 //    2. Chạy chương trình program.hex trên CPU 5 giai đoạn cho đến khi dừng.
 //    3. Hiển thị trạng thái của cả 5 giai đoạn sau mỗi chu kỳ clock.
 //    4. Kiểm tra thanh ghi, bộ nhớ và cờ trạng thái -> PASS / FAIL.
 //    5. Thống kê số chu kỳ, số lệnh, CPI, số lần dừng, xóa lệnh và chuyển tiếp dữ liệu.
 //    6. Xuất tệp risc8_5stage.vcd để xem dạng sóng bằng GTKWave.
 //
 //  MODULE ĐƯỢC GỌI (KHỞI TẠO) TRONG TỆP NÀY
 //    risc8_5stage_core từ rtl/risc8_5stage_core.v -> instance "dut"
 //
 //  CÁC TÍN HIỆU NỘI BỘ ĐƯỢC ĐỌC
 //    dut.*            Các thanh ghi của đường ống, stall, take_branch,
 //                     fwd_*_sel và các cờ trạng thái.
 //                     -> rtl/risc8_5stage_core.v
 //    dut.u_rf.r[...]  Mảng các thanh ghi bên trong CPU.
 //                     -> rtl/regfile.v
 //    dut.u_dmem.mem[...] Mảng bộ nhớ dữ liệu.
 //                     -> rtl/dmem.v
 //
 //  CÁC TỆP CẦN THIẾT KHI CHẠY
 //    program.hex được tạo bởi sw/asm8.py từ sw/program.s
 //
 //  CÁCH CHẠY
 //    python3 sw/asm8.py sw/program.s program.hex
 //    iverilog -g2005 -o sim.vvp rtl/*.v tb/tb_risc8_5stage.v
 //    vvp sim.vvp
 //    gtkwave risc8_5stage.vcd
 // =====================================================================

`timescale 1ns/1ps

module tb_risc8_5stage;

    reg clk = 0;
    reg rst = 1;
    wire       halted;
    wire [7:0] pc;
    wire [1:0] flags;        // {Z, C}: các cờ Zero và Carry từ CPU
    wire       instr_done;   // Bằng 1 khi một lệnh hoàn thành giai đoạn WB

    // -----------------------------------------------------------------
    // GỌI MODULE: risc8_5stage_core từ rtl/risc8_5stage_core.v
    // IMEM_FILE được truyền vào imem (rtl/imem.v) để sử dụng $readmemh.
    // -----------------------------------------------------------------
    risc8_5stage_core #(.IMEM_FILE("program.hex")) dut (
        .clk    (clk),
        .rst    (rst),
        .halted     (halted),
        .pc_out     (pc),
        .flags_out  (flags),
        .instr_done (instr_done)
    );

    // Xung clock 100 MHz (chu kỳ 10 ns): đảo trạng thái clk mỗi 5 ns
    // và tiếp tục lặp vô hạn.
    initial forever #5 clk = ~clk;

    // -----------------------------------------------------------------
    // Các biến đếm thống kê
    // -----------------------------------------------------------------
    integer cycles  = 0;   // Số chu kỳ từ khi nhả reset đến khi CPU dừng
    integer retired = 0;   // Số lệnh hợp lệ đã hoàn thành giai đoạn WB
    integer stalls  = 0;   // Số chu kỳ dừng do xung đột dữ liệu load-use
    integer flushes = 0;   // Số lần nhánh được thực hiện; mỗi lần xóa 2 lệnh
    integer fwds    = 0;   // Số lần toán hạng EX nhận dữ liệu qua cơ chế forwarding
    integer errors  = 0;   // Tổng số lỗi kiểm tra

    // -----------------------------------------------------------------
    // THEO DÕI TRẠNG THÁI SAU MỖI CHU KỲ CLOCK
    // -----------------------------------------------------------------
    always @(posedge clk) if (!rst && !halted) begin
        cycles <= cycles + 1;
        if (instr_done)      retired <= retired + 1;
        if (dut.stall)       stalls  <= stalls  + 1;
        if (dut.take_branch) flushes <= flushes + 1;

        // hazard_unit.v chỉ chuyển tiếp dữ liệu đến các toán hạng thực sự được sử dụng.
        if (dut.idex_valid && (dut.fwd_a_sel != 2'b00 || dut.fwd_b_sel != 2'b00))
            fwds <= fwds + 1;

        // Lệnh trong thanh ghi IF/ID được hiển thị dưới dạng mã hex.
        // "--" biểu thị một ô trống (bubble) trong đường ống.
        $display("t=%6t PC=%02h | ID:%s%04h | EX:v%b | MEM:v%b | WB:%s R%0d<=%02h | Z=%b C=%b %s%s%s",
                 $time, pc,
                 dut.ifid_valid ? " " : "-", dut.ifid_instr,
                 dut.idex_valid, dut.exmem_valid,
                 dut.memwb_reg_we ? "w" : "-", dut.memwb_rd, dut.memwb_data,
                 flags[1], flags[0],
                 dut.stall       ? " STALL"            : "",
                 dut.take_branch ? " BRANCH->flush 2" : "",
                 (dut.idex_valid && (dut.fwd_a_sel != 2'b00 || dut.fwd_b_sel != 2'b00)) ? " fwd" : "");
    end

    // -----------------------------------------------------------------
    // TASK: Kiểm tra giá trị của một thanh ghi
    // Đọc mảng thanh ghi bên trong rtl/regfile.v
    // -----------------------------------------------------------------
    task check_reg(input [2:0] r, input [7:0] exp);
        if (dut.u_rf.r[r] !== exp) begin
            $display("FAIL  R%0d = %02h, expected %02h", r, dut.u_rf.r[r], exp);
            errors = errors + 1;
        end else
            $display("PASS  R%0d = %02h", r, exp);
    endtask

    // -----------------------------------------------------------------
    // TRÌNH TỰ MÔ PHỎNG CHÍNH
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("risc8_5stage.vcd");
        $dumpvars(0, tb_risc8_5stage);

        #22 rst = 0;            // Nhả reset sau khoảng 2 chu kỳ clock
        wait (halted);          // Chạy cho đến khi tín hiệu halted được kích hoạt
        @(posedge clk); @(posedge clk);

        // Các giá trị mong đợi lấy từ sw/program.s
        // (chương trình giống với thiết kế CPU 3 giai đoạn).
        $display("\n------------- register / memory check -------------");
        check_reg(1, 8'h00);  check_reg(2, 8'h0F);
        check_reg(3, 8'h01);  check_reg(4, 8'h20);
        check_reg(5, 8'h00);  check_reg(6, 8'h66);
        check_reg(7, 8'h00);

        // Kiểm tra giá trị tại địa chỉ 0x20 trong bộ nhớ dữ liệu.
        if (dut.u_dmem.mem[8'h20] !== 8'h0F) begin
            $display("FAIL  MEM[20] = %02h", dut.u_dmem.mem[8'h20]); errors = errors + 1;
        end else $display("PASS  MEM[20] = 0F");

        // Kiểm tra các cờ trạng thái Zero (Z) và Carry (C).
        if (flags !== 2'b11) begin
            $display("FAIL  flags Z=%b C=%b", flags[1], flags[0]); errors = errors + 1;
        end else $display("PASS  flags Z=1 C=1");

        // Hiển thị các chỉ số đánh giá hiệu năng của CPU.
        $display("\ncycles=%0d  instructions=%0d  CPI=%0.2f  load-use stalls=%0d  taken branches=%0d  forwards=%0d",
                 cycles, retired, cycles * 1.0 / retired, stalls, flushes, fwds);

        // Kết luận kết quả kiểm tra.
        if (errors == 0) $display("*** ALL TESTS PASSED ***");
        else             $display("*** %0d TEST(S) FAILED ***", errors);
        $finish;
    end

    // Bộ giám sát thời gian: kết thúc mô phỏng nếu CPU không dừng.
    initial begin #20000 $display("TIMEOUT"); $finish; end

endmodule

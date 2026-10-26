
// =====================================================================
//  TỆP         : tb/tb_dump.v
//  MODULE      : tb_dump (TESTBENCH dùng để kiểm thử ngẫu nhiên)
//  DỰ ÁN       : Bộ xử lý RISC 8-bit với đường ống 5 giai đoạn
// ---------------------------------------------------------------------
//  CHỨC NĂNG CỦA TỆP NÀY
//    Chạy chương trình hiện có trong program.hex, chờ lệnh HLT,
//    sau đó ghi trạng thái cuối cùng của CPU vào tệp văn bản "dump.txt",
//    bao gồm:
//      - Giá trị của 8 thanh ghi.
//      - Các cờ trạng thái.
//      - Toàn bộ 256 byte của bộ nhớ dữ liệu.
//
//    Tệp này không tự kiểm tra kết quả. Script sw/random_test.py
//    sẽ so sánh dữ liệu trong dump.txt với kết quả chuẩn từ mô hình
//    tham chiếu sw/iss.py.
//
//  CÁC MODULE ĐƯỢC GỌI (KHỞI TẠO) TRONG TỆP NÀY
//    risc8_5stage_core từ rtl/risc8_5stage_core.v -> instance "dut"
//
//  CÁC TÍN HIỆU NỘI BỘ ĐƯỢC ĐỌC
//    dut.u_rf.r[...]       -> rtl/regfile.v (mảng thanh ghi)
//    dut.u_dmem.mem[...]   -> rtl/dmem.v (mảng bộ nhớ dữ liệu)
//
//  TỆP NÀY ĐƯỢC CHẠY BỞI
//    sw/random_test.py biên dịch bằng Icarus Verilog (iverilog)
//    và chạy mô phỏng bằng vvp.
// =====================================================================

`timescale 1ns/1ps

module tb_dump;
    reg clk = 0, rst = 1;
    wire halted;
    wire [7:0] pc;
    wire [1:0] flags;        // {Z, C}: cờ Zero và Carry
    wire       instr_done;
    integer f, i;
    integer retired = 0;     // Số lệnh đã hoàn thành (đếm từ instr_done)

    always @(posedge clk) if (instr_done) retired <= retired + 1;

    // GỌI MODULE: risc8_5stage_core từ rtl/risc8_5stage_core.v
    risc8_5stage_core #(.IMEM_FILE("program.hex")) dut (
        .clk(clk), .rst(rst), .halted(halted), .pc_out(pc),
        .flags_out(flags), .instr_done(instr_done));

    initial forever #5 clk = ~clk;   // Tạo xung clock 100 MHz

    initial begin
        #22 rst = 0;
        wait (halted);
        @(posedge clk);

        f = $fopen("dump.txt", "w");                 // Mở tệp đầu ra

        for (i = 0; i < 8; i = i + 1)
            $fwrite(f, "%02h\n", dut.u_rf.r[i]);     // Ghi các thanh ghi R0 đến R7

        $fwrite(f, "%0d %0d\n", flags[1], flags[0]); // Ghi các cờ Z và C

        for (i = 0; i < 256; i = i + 1)
            $fwrite(f, "%02h\n", dut.u_dmem.mem[i]); // Ghi toàn bộ bộ nhớ dữ liệu

        $fclose(f);

        $display("halted at PC=%02h after %0d instructions", pc, retired);
        $finish;
    end

    // Bộ giám sát thời gian: nếu CPU bị treo, kết thúc mô phỏng
    // mà không ghi tệp dump.txt.
    initial begin #200000 $display("TIMEOUT"); $finish; end

endmodule

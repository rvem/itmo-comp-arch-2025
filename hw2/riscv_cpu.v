module riscv_cpu(clk, pc, pc_new, instruction_memory_a, instruction_memory_rd, data_memory_a, data_memory_rd, data_memory_we, data_memory_wd,
                register_a1, register_a2, register_a3, register_we3, register_wd3, register_rd1, register_rd2);
  // сигнал синхронизации
  input clk;
  // текущее значение регистра PC
  inout [31:0] pc;
  // новое значение регистра PC (адрес следующей команды)
  output reg [31:0] pc_new;
  // we для памяти данных
  output reg data_memory_we;
  // адреса памяти и данные для записи памяти данных
  output reg  [31:0] instruction_memory_a, data_memory_a, data_memory_wd;
  // данные, полученные в результате чтения из памяти
  inout reg  [31:0] instruction_memory_rd, data_memory_rd;
  // we3 для регистрового файла
  output reg  register_we3;
  // номера регистров
  output reg  [4:0] register_a1, register_a2, register_a3;
  // данные для записи в регистровый файл
  output reg  [31:0] register_wd3;
  // данные, полученные в результате чтения из регистрового файла
  inout [31:0] register_rd1, register_rd2;

  always @(*) begin
      instruction_memory_a = pc;
  end

  wire [6:0] opcode = instruction_memory_rd[6:0]; // тип инструкции
  wire [4:0] rd = instruction_memory_rd[11:7]; // номер конечного регистра
  wire [2:0] funct3 = instruction_memory_rd[14:12]; // доп данные о инструкции
  wire [4:0] rs1 = instruction_memory_rd[19:15]; // регистр 1
  wire [4:0] rs2 = instruction_memory_rd[24:20]; // регситр 2
  wire [6:0] funct7 = instruction_memory_rd[31:25]; // еще доп инфы о инструкции


  // парсим константы
  wire [31:0] imm_i = {{20{instruction_memory_rd[31]}}, instruction_memory_rd[31:20]};
  wire [31:0] imm_s = {{20{instruction_memory_rd[31]}}, instruction_memory_rd[31:25], instruction_memory_rd[11:7]};
  wire [31:0] imm_b = {{19{instruction_memory_rd[31]}}, instruction_memory_rd[31],
                          instruction_memory_rd[7],
                          instruction_memory_rd[30:25],
                          instruction_memory_rd[11:8], 1'b0};
  wire [31:0] imm_u = {instruction_memory_rd[31:12], 12'b0};
  wire [31:0] imm_j = {{11{instruction_memory_rd[31]}}, instruction_memory_rd[31],
                          instruction_memory_rd[19:12],
                          instruction_memory_rd[20],
                          instruction_memory_rd[30:21], 1'b0};

    
  always @(*) begin

      pc_new = pc + 4;

      data_memory_we = 0;
      data_memory_a  = 0;
      data_memory_wd = 0;

      register_we3 = 0;
      register_a1 = rs1;
      register_a2 = rs2;
      register_a3 = rd;
      register_wd3 = 0;

      case (opcode)
          // R-type
          7'b0110011: begin
              register_we3 = 1;
              case (funct3)
                  // add или sub
                  3'b000: register_wd3 =
                    (funct7 == 7'b0100000) ? register_rd1 - register_rd2  : register_rd1 + register_rd2;
                  // and
                  3'b111: register_wd3 = register_rd1 & register_rd2; 
                  // or
                  3'b110: register_wd3 = register_rd1 | register_rd2; 
                  // slt
                  3'b010: register_wd3 =
                    ($signed(register_rd1) < $signed(register_rd2)) ? 1 : 0; 
              endcase
          end
          // ADDI 
          7'b0010011: begin
              register_we3 = 1;
              register_wd3 = register_rd1 + imm_i;
          end
          // LW 
          7'b0000011: begin
              register_we3 = 1;
              data_memory_a = register_rd1 + imm_i;
              register_wd3 = data_memory_rd;
          end
          // SW
          7'b0100011: begin
              data_memory_we = 1;
              data_memory_a  = register_rd1 + imm_s;
              data_memory_wd = register_rd2;
          end
           
          7'b1100011: begin
              case (funct3)
                  // beq
                  3'b000: if (register_rd1 == register_rd2) pc_new = pc + imm_b;
                  // bne
                  3'b001: if (register_rd1 != register_rd2) pc_new = pc + imm_b; 
                  // blt
                  3'b100: if ($signed(register_rd1) < $signed(register_rd2)) pc_new = pc + imm_b; 
              endcase
          end

          // LUI
          7'b0110111: begin
              register_we3 = 1;
              register_wd3 = imm_u;
          end

            // JAL
          7'b1101111: begin
              register_we3 = 1;
              register_wd3 = pc + 4;
              pc_new = pc + imm_j;
          end

          // JALR
          7'b1100111: begin
              register_we3 = 1;
              register_wd3 = pc + 4;
              pc_new = (register_rd1 + imm_i) & ~32'b1;
          end

        endcase
    end
endmodule

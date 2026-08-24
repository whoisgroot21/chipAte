package main

import "core:os"
import "core:strings"
import "core:fmt"
import "core:strconv"


/*
## Assembly format/specification

- newline separated instructions

- space separated operands

- anything after a ; till the new line character is considered a comment

- : for labels
*/


/*
can add later
. or * for current addr
$ for literal nums
*/


main::proc()
{
	PROGRAM_MEMORY_START::0x200

	/*wish i could do this TT
	#define fmt.printf("Error: Invalid Syntax at instructions number: %d %s", i, strings.join(instr, " ")); return;
	*/
	//for now
	invalid_syntax::proc(i : int, instr: []string){
		panic(fmt.tprintf("Error: Invalid Syntax at instructions number: %d %s", i+1, strings.join(instr, " ")))
	}



	//usage-
	//1) ./assembler <src_filepath> -> writes it to some default file name
	//2) ./assembler <src_filepath> -o  <destination>-> prints it out to stdout
	
	if len(os.args)<=1
	{
		fmt.println("Error: Missing or invalid input filepath.\nUsage: assembler <input_filepath>");
		return
	}

	src_filepath : string
	
	output_filepath : string
	output_to_file := false

	for i:=1;i<len(os.args);i+=1
	{
		if os.args[i]=="-o"
		{
			src_filepath = strings.join(os.args[1:i], " ")
			output_to_file=true
			output_filepath=strings.join(os.args[i+1:], " ")
		}
	}
	if  !output_to_file do src_filepath = strings.join(os.args[1:], " ")


	src_raw, err := os.read_entire_file_from_path(src_filepath, context.allocator)
	defer delete(src_raw)
	
	if err!=nil
	{
		fmt.println("Error: Failed to read file")
		return// err
	}

	src := string(src_raw)


	labels: map[string]int
	

	lines := strings.split(src, "\n")

	//instructions := make([dynamic]([]string), len(lines))
	//defer delete(instructions)
	instructions : [dynamic]([]string)


	for i in 0..<len(lines)
	{
		//remove comments
		lines[i] = strings.split(lines[i], ";")[0]

		//labels
		t := strings.split(lines[i], ":")
		if(len(t)>2)
		{
			fmt.printf("Error: Invalid label\n")
			return
		}
		else if(len(t)==2)
		{
			label:=strings.trim_space(t[0])
			//maybe check if labels are valid here
			if label==""// || other cases 
			{
				fmt.printf("Error: Invalid label\n")
				return
			}

			if _, ok := labels[label]; ok
			{
				fmt.printf("Error: repeated label name")
			}

			labels[label] = len(instructions)
			lines[i] = strings.trim_space(t[1])
		}

		//tokenize each line
		if(lines[i]!="")
		{
			append(&instructions, strings.fields(lines[i]))
		}

	}
	
	rom_data : = make([]u16, len(instructions))
	defer delete(rom_data)


	//for debugging
	//for i in instructions do fmt.println(i)

	for i in 0..<len(instructions)
	{
		instr:=instructions[i]



		switch instr[0]
		{
		//0nnn - SYS addr
		case "SYS" :
			if len(instr)!=2 do invalid_syntax(i, instr)
			addr, ok := strconv.parse_int(instr[1], 0)
			if !ok {
				addr, ok = labels[instr[1]]
				if !ok do invalid_syntax(i, instr)
				addr*=2
			}
			rom_data[i] = u16(0x0000 | (addr+PROGRAM_MEMORY_START))

		//00E0 - CLS
		case "CLS":
			if len(instr)!=1 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x00E0)

		//00EE - RET
		case "RET":
			if len(instr)!=1 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x00EE)


		//1nnn - JP addr
		//Bnnn - JP V0, addr
		case "JP":
			if (instr[1])=="V0"
			{
				if len(instr)!=3 do invalid_syntax(i, instr)

				addr, ok := strconv.parse_int(instr[2], 0)
				if !ok {
					addr, ok = labels[instr[2]]
					if !ok do invalid_syntax(i, instr)
					addr*=2
				}
				rom_data[i] = u16(0xB000 | (addr+PROGRAM_MEMORY_START))

			}
			else
			{
				if len(instr)!=2 do invalid_syntax(i, instr)
				addr, ok := strconv.parse_int(instr[1], 0)
				if !ok {
					addr, ok = labels[instr[1]]
					if !ok do invalid_syntax(i, instr)
					addr*=2
				}
				rom_data[i] = u16(0x1000 | (addr+PROGRAM_MEMORY_START))
			}


			


		//2nnn - CALL addr
		case "CALL":
			if len(instr)!=2 do invalid_syntax(i, instr)
			addr, ok := strconv.parse_int(instr[1], 0)
			if !ok {
				addr, ok = labels[instr[1]]
				if !ok do invalid_syntax(i, instr)
				addr*=2
			}
			rom_data[i] = u16(0x2000 | (addr+PROGRAM_MEMORY_START))


		//3xkk - SE Vx, byte
		//5xy0 - SE Vx, Vy
		case "SE":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' do invalid_syntax(i, instr)
			x, ok1 :=strconv.parse_int(instr[1][1:], 10)
			
			if instr[2][0]=='V'
			{
				y, ok2 :=strconv.parse_int(instr[2][1:], 10)
				
				if !ok1 || !ok2 do invalid_syntax(i, instr)
				rom_data[i] = u16(0x5000 | (x<<8 | y<<4))
			}
			else
			{
				b, ok2 :=strconv.parse_int(instr[2], 0)
			
				if !ok1 || !ok2 do invalid_syntax(i, instr)
				rom_data[i] = u16(0x3000 | (x<<8 | b))
			}


		//4xkk - SNE Vx, byte
		//9xy0 - SNE Vx, Vy
		case "SNE":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' do invalid_syntax(i, instr)
			x, ok1 :=strconv.parse_int(instr[1][1:], 10)
			
			if instr[2][0]=='V'
			{
				y, ok2 :=strconv.parse_int(instr[2][1:], 10)
				
				if !ok1 || !ok2 do invalid_syntax(i, instr)
				rom_data[i] = u16(0x9000 | (x<<8 | y<<4))
			}
			else
			{
				b, ok2 :=strconv.parse_int(instr[2], 0)
			
				if !ok1 || !ok2 do invalid_syntax(i, instr)
				rom_data[i] = u16(0x4000 | (x<<8 | b))
			}




		//Annn - LD I, addr
		//Fx07 - LD Vx, DT
		//Fx0A - LD Vx, K
		//Fx15 - LD DT, Vx
		//Fx18 - LD ST, Vx
		//Fx29 - LD F, Vx
		//Fx33 - LD B, Vx
		//Fx55 - LD [I], Vx
		//Fx65 - LD Vx, [I]
		//6xkk - LD Vx, byte
		//8xy0 - LD Vx, Vy
		case "LD":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if instr[1][0]=='V'
			{
				x, ok := strconv.parse_int(instr[1][1:], 10)
				if !ok do invalid_syntax(i, instr)
				if instr[2]=="[I]"
				{
					rom_data[i] = u16(0xF065 | u16(x<<8))
				}
				else if instr[2]=="DT"
				{
					rom_data[i] = u16(0xF007 | u16(x<<8))
				}
				else if instr[2]=="K"
				{
					rom_data[i] = u16(0xF00A | u16(x<<8))
				}
				else if instr[2][0]=='V'
				{
					y, ok := strconv.parse_int(instr[2][1:], 10)
					if !ok do invalid_syntax(i, instr)
					rom_data[i] = u16(0x8000 | u16(x<<8 | y<<4))
				}
				else
				{
					b, ok := strconv.parse_int(instr[2], 0)
					if !ok do invalid_syntax(i, instr)

					rom_data[i] = u16(0x6000 | u16(x<<8 | b))
				}
		}
		else if instr[1]=="I"
		{
			addr, ok := strconv.parse_int(instr[2], 0)
			if !ok {
				addr, ok = labels[instr[2]]
				if !ok do invalid_syntax(i, instr)
				addr*=2
			}
			rom_data[i] = u16(0xA000 | u16(addr+PROGRAM_MEMORY_START))

		}
		else
		{
			if instr[2][0]!='V' do invalid_syntax(i, instr)
			x, ok := strconv.parse_int(instr[2][1:], 10)
			if !ok do invalid_syntax(i, instr)
			switch instr[1]
			{
			case "DT":
				rom_data[i] = u16(0xF015 | u16(x<<8))
			case "ST":
				rom_data[i] = u16(0xF018 | u16(x<<8))
			case "F":
				rom_data[i] = u16(0xF029 | u16(x<<8))
			case "B":
				rom_data[i] = u16(0xF033 | u16(x<<8))
			case "[I]":
				rom_data[i] = u16(0xF055 | u16(x<<8))
			

			case:
				invalid_syntax(i, instr)
			}
		}



		//7xkk - ADD Vx, byte
		//8xy4 - ADD Vx, Vy
		//Fx1E - ADD I, Vx
		case "ADD":
		if len(instr)!=3 do invalid_syntax(i, instr)
			if instr[1]=="I"
			{
				if (instr[2])[0]!='V' do invalid_syntax(i, instr)
				x, ok1 :=strconv.parse_int(instr[2][1:], 10)
				if !ok1{
					fmt.printf("Error: Invalid Syntax at instructions number: %d %s", i, strings.join(instr, " "))
					return
				}
				rom_data[i] = u16(0xF01E | (x<<8))
			}
			else
			{
				if (instr[1])[0]!='V' do invalid_syntax(i, instr)
				x, ok1 :=strconv.parse_int(instr[1][1:], 10)

				if (instr[2])[0]!='V'
				{
					b, ok2 :=strconv.parse_int(instr[2], 0)
					if !ok1 || !ok2 do invalid_syntax(i, instr)
					rom_data[i] = u16(0x7000 | (x<<8 | b))

				}
				else
				{
				
					y, ok2 :=strconv.parse_int(instr[2][1:], 10)
					if !ok1 || !ok2 do invalid_syntax(i, instr)
					rom_data[i] = u16(0x8004 | (x<<8 | y<<4))
				}
			}


		// 8xy2 - AND Vx, Vy
		case "AND":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)

			x, ok1 :=strconv.parse_int(instr[1][1:], 10)
			y, ok2 :=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x8002 | (x<<8 | y<<4))


		//8xy1 - OR Vx, Vy
		case "OR":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)

			x, ok1 :=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x8001 | (x<<8 | y<<4))


		//8xy3 - XOR Vx, Vy
		case "XOR":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)

			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x8003 | (x<<8 | y<<4))


		//8xy6 - SHR Vx {, Vy}
		case "SHR":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)

			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x8006 | (x<<8 | y<<4))


		//8xyE - SHL Vx {, Vy}
		case "SHL":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)

			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x800E | (x<<8 | y<<4))

		//8xy5 - SUB Vx, Vy
		case "SUB":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)

			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x8005 | (x<<8 | y<<4))


		//8xy7 - SUBN Vx, Vy
		case "SUBN":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)
			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0x8007 | (x<<8 | y<<4))


		//Cxkk - RND Vx, byte
		case "RND":
			if len(instr)!=3 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' do invalid_syntax(i, instr)

			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			b, ok2:=strconv.parse_int(instr[1], 10)
			if !ok1 || !ok2 do invalid_syntax(i, instr)
			rom_data[i] = u16(0xC000 | (x<<8 | b))

		//Dxyn - DRW Vx, Vy, nibble
		case "DRW":
			if len(instr)!=4 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)
			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			y, ok2:=strconv.parse_int(instr[2][1:], 10)
			n, ok3:=strconv.parse_int(instr[3], 0)
			if !ok1 || !ok2 || !ok3 do invalid_syntax(i, instr)
			rom_data[i] = u16(0xD000 | (x<<8 | y<<4 | n))


		//Ex9E - SKP Vx
		case "SKP":
			if len(instr)!=2 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)
			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			if !ok1 do invalid_syntax(i, instr)
			rom_data[i] = u16(0xE09E | (x<<8))


		//ExA1 - SKNP Vx
		case "SKNP":
			if len(instr)!=2 do invalid_syntax(i, instr)
			if (instr[1])[0]!='V' || instr[2][0]!='V' do invalid_syntax(i, instr)
			x, ok1:=strconv.parse_int(instr[1][1:], 10)
			if !ok1 do invalid_syntax(i, instr)
			rom_data[i] = u16(0xE0A1 | (x<<8))


		//Raw Data
		case:
			for raw_data_byte in instr
			{
				data_byte, ok:=strconv.parse_int(raw_data_byte, 0)
				if !ok do invalid_syntax(i, instr)
				rom_data[i] = u16(data_byte)
			}
		}

	}



	if output_to_file
	{
		file, err := os.create(output_filepath)
    	if err!=nil {
    		fmt.printf("Error: Failed to open/create output file")
    		return
    	}
		defer os.close(file)

		data_bytes : []u8 = make([]u8, len(rom_data)*2)

    	for i:=0;i<len(rom_data);i+=1
    	{
    		data_bytes[i*2] = u8(0xFF00 & rom_data[i]>>8)
    		data_bytes[i*2+1] = u8(0x00FF & rom_data[i])
    	}

		os.write(file, data_bytes)
	}
	else do for i in rom_data do fmt.printf("%4X\n", i)




}
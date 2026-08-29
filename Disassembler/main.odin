package main

import "core:os"
import "core:fmt"
import "core:strings"


main :: proc()
{
	//usage-
	//1) ./disassembler <rom_path> -> prints it out to stdout
	//2) ./disassembler <rom_path> -o <output_file_path>-> writes it to a file

	if len(os.args)<=1
	{
		fmt.println("Error: Missing or Invalid ROM path.\nUsage: disassembler <path_to_rom>");
		return
	}

	rom_path : string
	output_filepath : string
	output_to_file := false
	for i:=1;i<len(os.args);i+=1
	{
		if os.args[i]=="-o"
		{
			rom_path = strings.join(os.args[1:i], " ")
			output_to_file=true
			output_filepath=strings.join(os.args[i+1:], " ")
		}
	}
	if  !output_to_file do rom_path = strings.join(os.args[1:], " ")


	rom_data, err := os.read_entire_file_from_path(rom_path, context.allocator)
	
	if err != nil
	{
		fmt.println("Error: Failed to read file")
        return
	}

	defer delete(rom_data)

	output_data : map[u16]string
	defer delete(output_data)

	visited := make([]bool, len(rom_data))
	defer delete(visited)


	labels : map[u16]int
	defer delete(labels)

	START_ADDRESS::0x200


	address : u16

	call_stack : [16]u16
	stack_ptr := -1

	address_to_visit : [32]u16//can be larger 2048 max
	address_to_visit_ptr:=-1

	address_to_visit_ptr+=1
	address_to_visit[address_to_visit_ptr]=0

	for address_to_visit_ptr!=-1
	{
		address=address_to_visit[address_to_visit_ptr]
		address_to_visit_ptr-=1
		inner_loop: for address<u16(len(rom_data)-1)
		{
			opcode := u16(rom_data[address])<<8 | u16(rom_data[address+1])

			if visited[address] do break inner_loop

			switch (opcode & 0xF000)>>12
			{

			case 0x0:

				switch opcode
				{
				//00E0 - CLS
				case 0x00E0:
					output_data[address] = fmt.tprintf("CLS")

				//00EE - RET		
				case 0x00EE:
					output_data[address] = fmt.tprintf("RET")
					visited[address]=true
					visited[address+1]=true
					address = call_stack[stack_ptr]
					stack_ptr-=1

				//0nnn - SYS addr
				case:
					if _, ok := labels[opcode & 0x0FFF]; !ok
					{
						labels[opcode & 0x0FFF]=len(labels)+1
					}
					output_data[address] = fmt.tprintf("SYS loc_%2X", labels[opcode & 0x0FFF])
					//didnt implement in the emu as well so idk
					

				}

			//1nnn JP addr
			case 0x1:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				
				output_data[address] = fmt.tprintf("JP loc_%2X", labels[opcode & 0x0FFF])
				
				visited[address]=true
				visited[address+1]=true

				//jumping to same address
				if address==((opcode & 0x0FFF)-START_ADDRESS) do break inner_loop
				else do address = (opcode & 0x0FFF)-START_ADDRESS

				continue
				
			//2nnn - CALL addr
			case 0x2:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address] = fmt.tprintf("CALL loc_%2X", labels[opcode & 0x0FFF])
				
				visited[address]=true
				visited[address+1]=true
				stack_ptr+=1
				call_stack[stack_ptr] = address//opcode & 0x0FFF
				address = (opcode & 0x0FFF)-START_ADDRESS
				continue
				

			//3xkk - SE Vx byte
			case 0x3:
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address] = fmt.tprintf("SE V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			//4xkk - SNE Vx byte
			case 0x4:
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address] = fmt.tprintf("SNE V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))
				

			//5xy0 - SE Vx Vy
			case 0x5:
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address] = fmt.tprintf("SE V%d V%d", (opcode&0x0F00)>>8, (opcode&0x00F0)>>4)
				
			//6xkk - LD Vx byte
			case 0x6:
				output_data[address] = fmt.tprintf("LD V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			//7xkk - ADD Vx byte
			case 0x7:
				output_data[address] = fmt.tprintf("ADD V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			case 0x8:
				x:=(opcode & 0x0F00)>>8
				y:=(opcode & 0x00F0)>>4

				switch opcode & 0x000F
				{

					//8xy0 - LD Vx Vy
					case 0x0:
						output_data[address] = fmt.tprintf("LD V%d V%d", x, y)

					//8xy1 - OR Vx Vy
					case 0x1:
						output_data[address] = fmt.tprintf("OR V%d V%d", x, y)

					// 8xy2 - AND Vx Vy
					case 0x2:
						output_data[address] = fmt.tprintf("AND V%d V%d", x, y)

					//8xy3 - XOR Vx Vy
					case 0x3:
						output_data[address] = fmt.tprintf("XOR V%d V%d", x, y)

					//8xy4 - ADD Vx Vy
					case 0x4:
						output_data[address] = fmt.tprintf("ADD V%d V%d", x, y)

					//8xy5 - SUB Vx Vy
					case 0x5:
						output_data[address] = fmt.tprintf("SUB V%d V%d", x, y)
						
					//8xy6 - SHR Vx { Vy}
					case 0x6:
						output_data[address] = fmt.tprintf("SHR V%d V%d", x, y)

					//8xy7 - SUBN Vx Vy
					case 0x7:
						output_data[address] = fmt.tprintf("SUBN V%d V%d", x, y)

					//8xyE - SHL Vx { Vy}
					case 0xE:
						output_data[address] = fmt.tprintf("SHL V%d V%d", x, y)

					case:
						break inner_loop
					
				}

			//9xy0 - SNE Vx Vy
			case 0x9:
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address] = fmt.tprintf("SNE V%d V%d", (opcode&0x0F00)>>8, (opcode & 0x00F0)>>4)

			//Annn - LD I addr
			case 0xA:
				addr := opcode & 0x0FFF
				if addr<START_ADDRESS
				{
					output_data[address] = fmt.tprintf("LD I 0x%3X", addr)
				}
				else
				{
					if _, ok := labels[opcode & 0x0FFF]; !ok
					{
						labels[opcode & 0x0FFF]=len(labels)+1
					}
					output_data[address] = fmt.tprintf("LD I loc_%2X", labels[opcode & 0x0FFF])
				}

			//Bnnn - JP V0 addr
			case 0xB:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address] = fmt.tprintf("JP V0 loc_%2X", labels[opcode & 0x0FFF])
				
				visited[address]=true
				visited[address+1]=true

				address = (opcode & 0x0FFF)-START_ADDRESS
				
				continue

			//Cxkk - RND Vx byte
			case 0xC:
				output_data[address] = fmt.tprintf("RND V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			//Dxyn - DRW Vx Vy nibble
			case 0xD:
				output_data[address] = fmt.tprintf("DRW V%d V%d 0x%1X", (opcode&0x0F00)>>8, (opcode & 0x00F0)>>4, (opcode & 0x000F))

			case 0xE:
				x:=(opcode & 0x0F00)>>8
				switch opcode & 0x00FF
				{
					//Ex9E - SKP Vx
					case 0x9E:
						output_data[address] = fmt.tprintf("SKP V%d", (opcode&0x0F00)>>8)

					//ExA1 - SKNP Vx
					case 0xA1:
						output_data[address] = fmt.tprintf("SKNP V%d", (opcode&0x0F00)>>8)

					case:
						break inner_loop

				}

			case 0xF:
				x:=(opcode & 0x0F00)>>8
				switch opcode & 0x00FF
				{
					//Fx07 - LD Vx DT
					case 0x07:
						output_data[address] = fmt.tprintf("LD V%d DT", (opcode&0x0F00)>>8)

					//Fx0A - LD Vx K
					case 0x0A:
						output_data[address] = fmt.tprintf("LD V%d K", (opcode&0x0F00)>>8)

					//Fx15 - LD DT Vx
					case 0x15:
						output_data[address] = fmt.tprintf("LD DT V%d", (opcode&0x0F00)>>8)

					//Fx18 - LD ST Vx
					case 0x18:
						output_data[address] = fmt.tprintf("LD ST V%d", (opcode&0x0F00)>>8)

					//Fx1E - ADD I Vx
					case 0x1E:
						output_data[address] = fmt.tprintf("ADD I V%d", (opcode&0x0F00)>>8)

					//Fx29 - LD F Vx
					case 0x29:
						output_data[address] = fmt.tprintf("LD F V%d", (opcode&0x0F00)>>8)

					//Fx33 - LD B Vx
					case 0x33:
						output_data[address] = fmt.tprintf("LD B V%d", (opcode&0x0F00)>>8)

					//Fx55 - LD [I] Vx
					case 0x55:
						output_data[address] = fmt.tprintf("LD [I] V%d", (opcode&0x0F00)>>8)
				
					//Fx65 - LD Vx [I]
					case 0x65:
						output_data[address] = fmt.tprintf("LD V%d [I]", (opcode&0x0F00)>>8)

					case:
						break inner_loop
				}		
			case:
				break inner_loop
			}
			

			//for debugging
			//fmt.printf("%3X: %s\n", address, output_data[address])
			
			
			visited[address]=true
			visited[address+1]=true
			address+=2
		}
	}

	for i in 0..<len(visited)
	{
		if !visited[i]
		{
			data_raw := u16(rom_data[i])
			output_data[u16(i)]=fmt.tprintf("DB 0x%2X", data_raw)
		}
	}

	for i in labels
	{
		output_data[(i-START_ADDRESS)]=fmt.tprintf("\nloc_%2X: \n%s", labels[i], output_data[(i-START_ADDRESS)])
	}

	output_data_buffer := make([dynamic]string, 0, len(output_data))
	for i:=0;i<len(rom_data);i+=1
	{
		if out, ok := output_data[u16(i)]; ok{
			append(&output_data_buffer, out)
		}
	}

	if output_to_file
	{
		err := os.write_entire_file(output_filepath, strings.join(output_data_buffer[:], "\n"))
		if err != nil
		{
			fmt.println("Failed to write to file")
			return
		}
	}
	else do for i in output_data_buffer do fmt.println(i)
		

}

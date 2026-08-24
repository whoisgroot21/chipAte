
package main

import "core:os"
import "core:fmt"
import "core:strings"


main :: proc()
{

	//IMPROVE address/2 is bad and can lead to errors, do something else
	
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

	//for testing
	//rom_path := "./roms/test-roms/1-chip8-logo.ch8"
	//rom_path := "./roms/custom-roms/chipAte-logo.ch8"

	rom_data, err := os.read_entire_file_from_path(rom_path, context.allocator)
	
	if err != nil
	{
		fmt.println("Error: Failed to read file")
        return
	}

	defer delete(rom_data)

	output_data := make([dynamic]string, len(rom_data)/2)
	defer delete(output_data)


	labels : map[u16]int
	defer delete(labels)

	START_ADDRESS::0x200
	//END_ADDRESS::0xFFFF//or FFF //todo replace all the magical ways to exit the loop with this


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
		for address<u16(len(rom_data))
		{
			opcode := u16(rom_data[address])<<8 | u16(rom_data[address+1])

			switch (opcode & 0xF000)>>12
			{

			case 0x0:

				switch opcode
				{
				//00E0 - CLS
				case 0x00E0:
					output_data[address/2] = fmt.tprintf("CLS")

				//00EE - RET		
				case 0x00EE:
					output_data[address/2] = fmt.tprintf("RET")
					address = call_stack[stack_ptr]-START_ADDRESS
					stack_ptr-=1

				//0nnn - SYS addr
				case:
					if _, ok := labels[opcode & 0x0FFF]; !ok
					{
						labels[opcode & 0x0FFF]=len(labels)+1
					}
					output_data[address/2] = fmt.tprintf("SYS loc_%2X", labels[opcode & 0x0FFF])
					//didnt implement in the emu as well so idk
					

				}

			//1nnn JP addr
			case 0x1:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address/2] = fmt.tprintf("JP loc_%2X", labels[opcode & 0x0FFF])
				if address==((opcode & 0x0FFF)-START_ADDRESS) do address=(0xFFFF-2)
				else do address = (opcode & 0x0FFF)-START_ADDRESS
				
			//2nnn - CALL addr
			case 0x2:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address/2] = fmt.tprintf("CALL loc_%2X", labels[opcode & 0x0FFF])
				stack_ptr+=1
				call_stack[stack_ptr]=opcode & 0x0FFF
				address = (opcode & 0x0FFF)-START_ADDRESS
				

			//3xkk - SE Vx byte
			case 0x3:
				if output_data[address/2]!=""
				{
					address=0xFFFF-2
					continue
				}
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address/2] = fmt.tprintf("SE V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			//4xkk - SNE Vx byte
			case 0x4:
				if output_data[address/2]!=""
				{
					address=0xFFFF-2
					continue
				}
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address/2] = fmt.tprintf("SNE V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))
				

			//5xy0 - SE Vx Vy
			case 0x5:
				if output_data[address/2]!=""
				{
					address=0xFFFF-2
					continue
				}
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address/2] = fmt.tprintf("SE V%d V%d", (opcode&0x0F00)>>8, (opcode&0x00F0)>>8)
				
			//6xkk - LD Vx byte
			case 0x6:
				output_data[address/2] = fmt.tprintf("LD V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			//7xkk - ADD Vx byte
			case 0x7:
				output_data[address/2] = fmt.tprintf("ADD V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			case 0x8:
				x:=(opcode & 0x0F00)>>8
				y:=(opcode & 0x00F0)>>4

				switch opcode & 0x000F
				{

					//8xy0 - LD Vx Vy
					case 0x0:
						output_data[address/2] = fmt.tprintf("LD V%d V%d", x, y)

					//8xy1 - OR Vx Vy
					case 0x1:
						output_data[address/2] = fmt.tprintf("OR V%d V%d", x, y)

					// 8xy2 - AND Vx Vy
					case 0x2:
						output_data[address/2] = fmt.tprintf("AND V%d V%d", x, y)

					//8xy3 - XOR Vx Vy
					case 0x3:
						output_data[address/2] = fmt.tprintf("XOR V%d V%d", x, y)

					//8xy4 - ADD Vx Vy
					case 0x4:
						output_data[address/2] = fmt.tprintf("ADD V%d V%d", x, y)

					//8xy5 - SUB Vx Vy
					case 0x5:
						output_data[address/2] = fmt.tprintf("SUB V%d V%d", x, y)
						
					//8xy6 - SHR Vx { Vy}
					case 0x6:
						output_data[address/2] = fmt.tprintf("SHR V%d V%d", x, y)

					//8xy7 - SUBN Vx Vy
					case 0x7:
						output_data[address/2] = fmt.tprintf("SUBN V%d V%d", x, y)

					//8xyE - SHL Vx { Vy}
					case 0xE:
						output_data[address/2] = fmt.tprintf("SHL V%d V%d", x, y)

					case:
						if _, ok := labels[opcode & 0x0FFF]; !ok
						{
							labels[opcode & 0x0FFF]=len(labels)+1
						}
						output_data[address/2] = fmt.tprintf("%X", opcode)
					
				}

			//9xy0 - SNE Vx Vy
			case 0x9:
				if output_data[address/2]!=""
				{
					address=0xFFFF-2
					continue
				}
				address_to_visit_ptr+=1
				address_to_visit[address_to_visit_ptr]=address+4
				output_data[address/2] = fmt.tprintf("SNE V%d V%d", (opcode&0x0F00)>>8, (opcode & 0x00F0)>>4)

			//Annn - LD I addr
			case 0xA:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address/2] = fmt.tprintf("LD I loc_%2X", labels[opcode & 0x0FFF])
				

			//Bnnn - JP V0 addr
			case 0xB:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address/2] = fmt.tprintf("JP V0 loc_%2X", labels[opcode & 0x0FFF])
				address = (opcode & 0x0FFF)-START_ADDRESS
				

			//Cxkk - RND Vx byte
			case 0xC:
				output_data[address/2] = fmt.tprintf("RND V%d 0x%2X", (opcode&0x0F00)>>8, (opcode & 0x00FF))

			//Dxyn - DRW Vx Vy nibble
			case 0xD:
				output_data[address/2] = fmt.tprintf("DRW V%d V%d 0x%1X", (opcode&0x0F00)>>8, (opcode & 0x00F0)>>4, (opcode & 0x000F))

			case 0xE:
				x:=(opcode & 0x0F00)>>8
				switch opcode & 0x00FF
				{
					//Ex9E - SKP Vx
					case 0x9E:
						output_data[address/2] = fmt.tprintf("SKP V%d", (opcode&0x0F00)>>8)

					//ExA1 - SKNP Vx
					case 0xA1:
						output_data[address/2] = fmt.tprintf("SKNP V%d", (opcode&0x0F00)>>8)

					case:
						if _, ok := labels[opcode & 0x0FFF]; !ok
						{
							labels[opcode & 0x0FFF]=len(labels)+1
						}
						output_data[address/2] = fmt.tprintf("%X", opcode)

				}

			case 0xF:
				x:=(opcode & 0x0F00)>>8
				switch opcode & 0x00FF
				{
					//Fx07 - LD Vx DT
					case 0x07:
						output_data[address/2] = fmt.tprintf("LD V%d DT", (opcode&0x0F00)>>8)

					//Fx0A - LD Vx K
					case 0x0A:
						output_data[address/2] = fmt.tprintf("LD V%d K", (opcode&0x0F00)>>8)

					//Fx15 - LD DT Vx
					case 0x15:
						output_data[address/2] = fmt.tprintf("LD DT V%d", (opcode&0x0F00)>>8)

					//Fx18 - LD ST Vx
					case 0x18:
						output_data[address/2] = fmt.tprintf("LD ST V%d", (opcode&0x0F00)>>8)

					//Fx1E - ADD I Vx
					case 0x1E:
						output_data[address/2] = fmt.tprintf("ADD I V%d", (opcode&0x0F00)>>8)

					//Fx29 - LD F Vx
					case 0x29:
						output_data[address/2] = fmt.tprintf("LD F V%d", (opcode&0x0F00)>>8)

					//Fx33 - LD B Vx
					case 0x33:
						output_data[address/2] = fmt.tprintf("LD B V%d", (opcode&0x0F00)>>8)

					//Fx55 - LD [I] Vx
					case 0x55:
						output_data[address/2] = fmt.tprintf("LD [I] V%d", (opcode&0x0F00)>>8)
				
					//Fx65 - LD Vx [I]
					case 0x65:
						output_data[address/2] = fmt.tprintf("LD V%d [I]", (opcode&0x0F00)>>8)

					case:
						if _, ok := labels[opcode & 0x0FFF]; !ok
						{
							labels[opcode & 0x0FFF]=len(labels)+1
						}
						output_data[address/2] = fmt.tprintf("%X", opcode)
				}		
			case:
				if _, ok := labels[opcode & 0x0FFF]; !ok
				{
					labels[opcode & 0x0FFF]=len(labels)+1
				}
				output_data[address/2] = fmt.tprintf("%X", opcode)
			}
			

			
			address+=2
		}
	}

	for i in 0..<len(output_data)
	{
		for output_data[i]==""
		{
			data_raw := u16(rom_data[i*2])<<8 | u16(rom_data[(i*2)+1])
			output_data[i]=fmt.tprintf("0x%4X", data_raw)
		}
	}

	for i in labels
	{
		output_data[(i-START_ADDRESS)/2]=fmt.tprintf("\nloc_%2X: \n%s", labels[i], output_data[(i-START_ADDRESS)/2])
		//output_data[address/2]=fmt.tprintf("loc_%2X: %s", labels[u16(address+START_ADDRESS)], output_data[address/2])
	}


	if output_to_file
	{
		err := os.write_entire_file(output_filepath, strings.join(output_data[:], "\n"))
		if err != nil
		{
			fmt.println("Failed to write to file")
			return
		}
	}
	else do for i in output_data do fmt.println(i)
		

}

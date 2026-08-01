package main

import "core:math/rand"
import "core:os"
import "core:fmt"



DISPLAY_WIDTH::64
DISPLAY_HEIGHT::32
SCALE::16


TIMER_FREQUENCY::60
EXECUTION_FREQUENCY::600


PROGRAM_MEMORY_START::0x200


FONT_SPRITES_START::0x050

//FONT_SPRITES::[16*5]{}
FONT_SPRITES : [16*5]u8 = {
	//0
	0xF0,
	0x90,
	0x90,
	0x90,
	0xF0,
	
	//1
	0x20,
	0x60,
	0x20,
	0x20,
	0x70,

	//2
	0xF0,
	0x10,
	0xF0,
	0x80,
	0xF0,

	//3
	0xF0,
	0x10,
	0xF0,
	0x10,
	0xF0,

	//4
	0x90,
	0x90,
	0xF0,
	0x10,
	0x10,

	//5
	0xF0,
	0x80,
	0xF0,
	0x10,
	0xF0,
	

	//6
	0xF0,
	0x80,
	0xF0,
	0x90,
	0xF0,

	//7
	0xF0,
	0x10,
	0x20,
	0x40,
	0x40,

	//8
	0xF0,
	0x90,
	0xF0,
	0x90,
	0xF0,

	//9
	0xF0,
	0x90,
	0xF0,
	0x10,
	0xF0,

	//A
	0xF0,
	0x90,
	0xF0,
	0x90,
	0x90,

	//B
	0xE0,
	0x90,
	0xE0,
	0x90,
	0xE0,

	//C
	0xF0,
	0x80,
	0x80,
	0x80,
	0xF0,

	//D
	0xE0,
	0x90,
	0x90,
	0x90,
	0xE0,

	//E
	0xF0,
	0x80,
	0xF0,
	0x80,
	0xF0,

	//F
	0xF0,
	0x80,
	0xF0,
	0x80,
	0x80
}


/*
keys

1 2 3 C
4 5 6 D
7 8 9 E
A 0 B F


1 2 3 4
Q W E R
A S D F
Z X C V

*/


emulator_mode::enum{
	CHIP8,
	SUPER_CHIP_LEGACY,
	SUPER_CHIP_MODERN,
	XO_CHIP,
}


Emulator::struct
{
	mode: emulator_mode,

	PC: u16,
	SP: u8,

	V: [16]u8,

	I: u16,

	framebuffer: [DISPLAY_WIDTH*DISPLAY_HEIGHT]b8,//[DISPLAY_WIDTH*DISPLAY_HEIGHT/8]u8// or [DISPLAY_WIDTH*DISPLAY_HEIGHT]b8 //or [DISPLAY_WIDTH*DISPLAY_HEIGHT]u8,

	draw_flag: bool,
	wating_for_vblank: bool,

	memory: [4096]u8,
	
	stack: [16]u16,

	
	keys: u16,//or [16]b8

	delay_timer: u8,
	sound_timer: u8,

}

emulator_init::proc(emu: ^Emulator, mode: emulator_mode)
{
	emu.mode = mode

	emu.PC=PROGRAM_MEMORY_START

	emu.SP=0

	emu.I=0

	emu.V=0

	emu.framebuffer=false
	emu.draw_flag=false

	emu.wating_for_vblank=false

	emu.memory=0
	emu.stack=0

	emu.delay_timer=0
	emu.sound_timer=0


	copy(emu.memory[FONT_SPRITES_START:], FONT_SPRITES[:])



}


emulator_load_rom::proc(emu: ^Emulator, rom_path: string) -> os.Error
{
	data, err := os.read_entire_file_from_path(rom_path, context.allocator)
	
	if err != nil
	{
		fmt.println("Failed to read file")
        return err
	}

	defer delete(data)

	copy(emu.memory[PROGRAM_MEMORY_START:], data)
	
	return nil

}


emulator_step::proc(emu: ^Emulator)
{
	if emu.wating_for_vblank do return

	//fetch
	opcode:=u16(emu.memory[emu.PC]) << 8 | u16(emu.memory[emu.PC+1])

	//step
	emu.PC+=2

	//debugging
	//fmt.printf("%X\n", opcode)

	//decode and execute
	switch (opcode & 0xF000)>>12
	{

	case 0x0:

		switch opcode
		{
		//00E0 - CLS
		case 0x00E0:
			emu.framebuffer=false
			//emu.draw_flag=true

		//00EE - RET		
		case 0x00EE:
			/*if emu.SP>=16
				return error
			*/
			emu.SP-=1
			emu.PC=emu.stack[emu.SP]
			

		//0nnn - SYS addr
		case:
			//ignored
		}

	//1nnn JP addr
	case 0x1:
		emu.PC = opcode & 0x0FFF

	//2nnn - CALL addr
	case 0x2:
		emu.stack[emu.SP]=emu.PC
		emu.SP+=1
		emu.PC = opcode & 0x0FFF
	

	//3xkk - SE Vx, byte
	case 0x3:
		x:=(opcode & 0x0F00)>>8
		if emu.V[x]==u8(opcode & 0x00FF) do emu.PC+=2

	//4xkk - SNE Vx, byte
	case 0x4:
		x:=(opcode & 0x0F00)>>8
		if emu.V[x]!=u8(opcode & 0x00FF) do emu.PC+=2

	//5xy0 - SE Vx, Vy
	case 0x5:
		x:=(opcode & 0x0F00)>>8
		y:=(opcode & 0x00F0)>>4
		if emu.V[x]==emu.V[y] do emu.PC+=2

	//6xkk - LD Vx, byte
	case 0x6:
		x:=(opcode & 0x0F00)>>8
		emu.V[x]=u8(opcode & 0x00FF)

	//7xkk - ADD Vx, byte
	case 0x7:
		x:=(opcode & 0x0F00)>>8
		emu.V[x]+=u8(opcode & 0x00FF)

	case 0x8:
		x:=(opcode & 0x0F00)>>8
		y:=(opcode & 0x00F0)>>4

		switch opcode & 0x000F
		{

			//8xy0 - LD Vx, Vy
			case 0x0:
				emu.V[x]=emu.V[y]


			//8xy1 - OR Vx, Vy
			case 0x1:
				emu.V[x]|=emu.V[y]
				if emu.mode==.CHIP8 do emu.V[0xF]=0

			// 8xy2 - AND Vx, Vy
			case 0x2:
				emu.V[x]&=emu.V[y]
				if emu.mode==.CHIP8 do emu.V[0xF]=0

			//8xy3 - XOR Vx, Vy
			case 0x3:
				emu.V[x] ~= emu.V[y]
				if emu.mode==.CHIP8 do emu.V[0xF]=0

			//8xy4 - ADD Vx, Vy
			case 0x4:
				sum:=u16(emu.V[x])+u16(emu.V[y])
				emu.V[x]=u8(sum & 0x00FF)
				emu.V[0xF] = sum>0x00FF ? 1 : 0

			//8xy5 - SUB Vx, Vy
			case 0x5:
				vf: u8 = emu.V[x]>=emu.V[y] ? 1 : 0
				emu.V[x] = emu.V[x] - emu.V[y]
				emu.V[0xF] = vf
				

			//8xy6 - SHR Vx {, Vy}
			case 0x6:
				if emu.mode==.CHIP8 do emu.V[x]=emu.V[y]
				vf: u8 = (emu.V[x] & 1)
				emu.V[x] >>= 1
				emu.V[0xF]=vf

			//8xy7 - SUBN Vx, Vy
			case 0x7:
				vf: u8 = emu.V[y]>=emu.V[x] ? 1 : 0
				emu.V[x] = emu.V[y] - emu.V[x]
				emu.V[0xF]=vf

			//8xyE - SHL Vx {, Vy}
			case 0xE:
				if emu.mode==.CHIP8 do emu.V[x]=emu.V[y]
				vf: u8 = (emu.V[x]>>7)
				emu.V[x] <<= 1
				emu.V[0xF]=vf
			
		}

	//9xy0 - SNE Vx, Vy
	case 0x9:
		x:=(opcode & 0x0F00)>>8
		y:=(opcode & 0x00F0)>>4

		if emu.V[x] != emu.V[y] do emu.PC+=2

	//Annn - LD I, addr
	case 0xA:
		emu.I = opcode & 0x0FFF

	//Bnnn - JP V0, addr
	case 0xB:
		emu.PC = u16(emu.V[0]) + (opcode & 0x0FFF)

	//Cxkk - RND Vx, byte
	case 0xC:
		x:=(opcode & 0x0F00)>>8
		emu.V[x]=u8(rand.int_max(256)) & u8(opcode & 0x00FF)

	//Dxyn - DRW Vx, Vy, nibble
	case 0xD:
		x:=(opcode & 0x0F00)>>8
		y:=(opcode & 0x00F0)>>4
		size:=int(opcode & 0x000F)

		px:=int(emu.V[x])%DISPLAY_WIDTH
		py:=int(emu.V[y])%DISPLAY_HEIGHT

        collision := false
        for i:=0;i<size;i+=1
        {
            sprite_byte:=emu.memory[int(emu.I)+i]
            
            if py+i>=DISPLAY_HEIGHT do break

            for j in uint(0)..<8
            {
            	if (sprite_byte&(128>>j))==0 do continue
				
				if px+int(j)>=DISPLAY_WIDTH do break
				idx:=((py+i)*DISPLAY_WIDTH)+(px+int(j))


        		if !collision && emu.framebuffer[idx] do collision=true

        		emu.framebuffer[idx]~=true

            }

        }

        emu.V[0xF] = u8(collision)

        emu.draw_flag=true

        if emu.mode==.CHIP8 || emu.mode==.SUPER_CHIP_LEGACY do emu.wating_for_vblank=true


	case 0xE:
		x:=(opcode & 0x0F00)>>8
		switch opcode & 0x00FF
		{
			//Ex9E - SKP Vx
			case 0x9E:
				if (emu.keys&(1<<emu.V[x]))!=0 do emu.PC+=2

			//ExA1 - SKNP Vx
			case 0xA1:
				if (emu.keys&(1<<emu.V[x]))==0 do emu.PC+=2

		}

	case 0xF:
		x:=(opcode & 0x0F00)>>8
		switch opcode & 0x00FF
		{
			//Fx07 - LD Vx, DT
			case 0x07:
				emu.V[x] = emu.delay_timer

			//Fx0A - LD Vx, K
			case 0x0A:
				if emu.keys==0 do emu.PC-=2

			//Fx15 - LD DT, Vx
			case 0x15:
				emu.delay_timer = emu.V[x]

			//Fx18 - LD ST, Vx
			case 0x18:
				emu.sound_timer = emu.V[x]

			//Fx1E - ADD I, Vx
			case 0x1E:
				emu.I += u16(emu.V[x])

			//Fx29 - LD F, Vx
			case 0x29:
				emu.I=FONT_SPRITES_START+(u16(emu.V[x])*5)

			//Fx33 - LD B, Vx
			case 0x33:
				vx:=emu.V[x]
				emu.memory[emu.I+2]=vx%10
				vx/=10
				emu.memory[emu.I+1]=vx%10
				vx/=10
				emu.memory[emu.I]=vx%10

			//Fx55 - LD [I], Vx
			case 0x55:
				for i:=0; i<=int(x); i+=1 do emu.memory[int(emu.I)+i] = emu.V[i]
				if emu.mode==.CHIP8 do emu.I+=x+1
		
			//Fx65 - LD Vx, [I]
			case 0x65:
				for i:=0; i<=int(x); i+=1 do emu.V[i] = emu.memory[int(emu.I)+i]
				if emu.mode==.CHIP8 do emu.I+=x+1

			case:
				//error invalid opcode

		}

	}


}


emulator_should_beep::proc(emu: ^Emulator) ->bool
{
	if emu.sound_timer!=0 do return true
	else do return false
}

emulator_tick_60hz_clock::proc(emu: ^Emulator)
{
	if emu.delay_timer>0 do emu.delay_timer-=1

	if emu.sound_timer>0 do emu.sound_timer-=1

	emu.wating_for_vblank=false
}


emulator_update_keys::proc(emu: ^Emulator, keys: u16)
{
	emu.keys=keys
}

emulator_get_framebuffer::proc(emu: ^Emulator) -> ^[DISPLAY_WIDTH*DISPLAY_HEIGHT]b8
{
	return &emu.framebuffer
}

emulator_test_draw_flag::proc(emu: ^Emulator) -> bool
{
	temp:=emu.draw_flag
	emu.draw_flag=false
	return temp
}
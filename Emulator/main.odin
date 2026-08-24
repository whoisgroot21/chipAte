package main

import "core:time"
import "core:os"
import "core:strings"
import "core:fmt"


import SDL "vendor:sdl2"


//CONFIG
SCALE::16
EXECUTION_FREQUENCY::600.0//OR IDK IPS?
//too lazy to implement these	
//BG_COLOR::0
//FG_COLOR::255




/*
key mapping

1 2 3 C
4 5 6 D
7 8 9 E
A 0 B F


1 2 3 4
Q W E R
A S D F
Z X C V

*/

map_key::proc(keycode: SDL.Scancode) -> u16
{
	#partial switch keycode {

	case .NUM1: return 1<<0x1
	case .NUM2: return 1<<0x2
	case .NUM3: return 1<<0x3
	case .NUM4: return 1<<0xC

	case .Q: return 1<<0x4
	case .W: return 1<<0x5
	case .E: return 1<<0x6
	case .R: return 1<<0xD

	case .A: return 1<<0x7
	case .S: return 1<<0x8
	case .D: return 1<<0x9
	case .F: return 1<<0xE

	case .Z: return 1<<0xA
	case .X: return 1<<0x0
	case .C: return 1<<0xB
	case .V: return 1<<0xF

	case: return 0
	
	}
}

beep_callback::proc "c" (userdata: rawptr, stream: [^]u8, len: i32)
{
    phase := (^u32)(userdata)
    half_period :: 50 // ~440Hz beep at 44100Hz sample rate

    for i := 0; i < int(len); i+=1
    {
        stream[i] = ((phase^ / half_period) % 2)==1 ? 140 : 116
        //phase^+=1
        phase^ = (phase^ + 1) % (half_period*2)
    }

}




App::struct
{
	emu: Emulator,

	running: bool,
	
	window: ^SDL.Window,
	renderer: ^SDL.Renderer,
	audio_dev: SDL.AudioDeviceID,
	audio_phase: u32
}


app_init::proc(app: ^App, rom_path: string) -> bool
{
	app.running=false

	//initialize the emulator
	emulator_init(&app.emu, emulator_mode.CHIP8)

	//load the rom
	emulator_load_rom(&app.emu, rom_path)


	//SDL stuff

    if SDL.Init({.VIDEO, .AUDIO}) != 0 {
        fmt.println("Error initializing SDL:", SDL.GetError())
        return false
    }



    app.window = SDL.CreateWindow(
        "ChipAte",
        SDL.WINDOWPOS_CENTERED,
        SDL.WINDOWPOS_CENTERED,
        DISPLAY_WIDTH*SCALE, DISPLAY_HEIGHT*SCALE,
        {.SHOWN},
    )

    if app.window == nil {
        fmt.println("Error creating window:", SDL.GetError())
        return false
    }

    app.renderer = SDL.CreateRenderer(app.window, -1, SDL.RENDERER_ACCELERATED)

    if app.renderer==nil{
    	fmt.println("Error creating renderer:", SDL.GetError())
        return false
    }


    spec_wanted := SDL.AudioSpec{
    	freq = 44100,
    	format = SDL.AUDIO_U8,
		channels = 1,
		samples = 512,
		callback = beep_callback,
		userdata = &app.audio_phase,
	}
    app.audio_dev = SDL.OpenAudioDevice(nil, false, &spec_wanted, nil, SDL.AudioAllowChangeFlags{})

    if app.audio_dev==0{
    	fmt.println("Error opening AudioDevice:", SDL.GetError())
        return false
    }

    SDL.PauseAudioDevice(app.audio_dev, true);

    return true

}



app_run::proc(app: ^App)
{
	app.running=true

	last_time:=time.tick_now()
	timer_time:f64=0.0
	step_time:f64=0.0

	keys: u16 = 0
	//beep: bool = false

	event: SDL.Event
	for app.running
	{
		now_time:=time.tick_now()

		delta_time := time.duration_seconds(time.tick_diff(last_time, now_time))

		timer_time += delta_time
		step_time += delta_time

		last_time=now_time

		emulator_update_keys(&app.emu, keys)
        for SDL.PollEvent(&event) {
            #partial switch event.type {

            case .QUIT:
                app.running = false

            case .KEYDOWN:
            	if event.key.keysym.scancode == .ESCAPE do app.running = false
            	key: u16 = map_key(event.key.keysym.scancode)
            	keys|=key

            case .KEYUP:
				key: u16 = map_key(event.key.keysym.scancode)
            	keys&~=key


            }
        }

        for step_time>=1/EXECUTION_FREQUENCY
        {
        	step_time -=1/EXECUTION_FREQUENCY
        	
			if(!emulator_step(&app.emu))
			{
				fmt.println("Error: Failed in Emulator Step")
				return
			}
			//OR
			/*
			err := emulator_step(&app.emu)
			if(err)
			{
				fmt.println("Error: Failed to Execute Opcode %d", err)
				return
			}
        	*/


        }
      	
        for timer_time>=1/TIMER_FREQUENCY
        {
        	timer_time -=1/TIMER_FREQUENCY
        	emulator_tick_60hz_clock(&app.emu);
        	//buzz
        	if emulator_should_beep(&app.emu) do SDL.PauseAudioDevice(app.audio_dev, false);
        	else do SDL.PauseAudioDevice(app.audio_dev, true);
        }
		
		if emulator_test_draw_flag(&app.emu)
		{
			fb:=emulator_get_framebuffer(&app.emu)

			pixels:[DISPLAY_WIDTH*DISPLAY_HEIGHT]u32
			for i in 0..<DISPLAY_HEIGHT{
				for j in 0..<DISPLAY_WIDTH{
					pixels[i*DISPLAY_WIDTH+j] = fb[i*DISPLAY_WIDTH+j] ? 0xFFFFFFFF : 0
				}
			}
			sur:=SDL.CreateRGBSurfaceWithFormatFrom(&pixels, DISPLAY_WIDTH, DISPLAY_HEIGHT, 32, DISPLAY_WIDTH*4, u32(SDL.PixelFormatEnum.RGBA8888))

			if sur==nil{
				fmt.println("Failed to create framebuffer surface: ", SDL.GetError())
				return
			}

			fb_texture := SDL.CreateTextureFromSurface(app.renderer, sur);

			SDL.FreeSurface(sur);
			
			if fb_texture==nil{
				fmt.println("Failed to create framebuffer texture from surface: ", SDL.GetError())
				return
			}


			SRect:=SDL.Rect{
				x=0,
				y=0,
				w=DISPLAY_WIDTH,
				h=DISPLAY_HEIGHT
			}
			DRect:=SDL.Rect{
				x=0,
				y=0,
				w=DISPLAY_WIDTH*SCALE,
				h=DISPLAY_HEIGHT*SCALE
			}


			SDL.RenderClear(app.renderer)

			SDL.RenderCopy(app.renderer, fb_texture, nil, &DRect)
			//SDL.RenderCopy(app.renderer, fb_texture, &SRect, &DRect)

			SDL.RenderPresent(app.renderer)

			SDL.DestroyTexture(fb_texture)

		}

	}

	
}

app_destroy::proc(app: ^App)
{

	SDL.DestroyRenderer(app.renderer)
	SDL.DestroyWindow(app.window)

    SDL.Quit()
}

main :: proc()
{
	if len(os.args)<=1
	{
		fmt.println("Error: Missing or invalid ROM path.\nUsage: emulator <path_to_rom>");
		return
	}

	rom_path := strings.join(os.args[1:], " ")
	


	test_roms:[8]string
	test_roms={
		"test-roms/1-chip8-logo.ch8",
		"test-roms/2-ibm-logo.ch8",
		"test-roms/3-corax+.ch8",
		"test-roms/4-flags.ch8",
		"test-roms/5-quirks.ch8",
		"test-roms/6-keypad.ch8",
		"test-roms/7-beep.ch8",
		"test-roms/8-scrolling.ch8",
		}
	//8th is for superchip8 only


	app: App

	if ok := app_init(&app, rom_path); !ok{
		return
	}

	app_run(&app)

	defer app_destroy(&app)

}

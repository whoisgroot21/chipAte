package main

import "core:time"
import "core:os"
import "core:strings"
import "core:fmt"


import SDL "vendor:sdl2"



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




App::struct
{
	emu: Emulator,

	running: bool,
	
	window: ^SDL.Window,
	renderer: ^SDL.Renderer,
}


app_init::proc(app: ^App, rom_path: string) -> bool
{
	app.running=false

	//initialize the emulator
	emulator_init(&app.emu)

	//load the rom
	emulator_load_rom(&app.emu, rom_path)


	//SDL stuff


    if SDL.Init({.VIDEO}) != 0 {
        fmt.println("Error initializing SDL:", SDL.GetError())
        return false
    }



    app.window = SDL.CreateWindow(
        "ChipAte",
        SDL.WINDOWPOS_CENTERED,
        SDL.WINDOWPOS_CENTERED,
        DISPLAY_WIDTH*SCALE, DISPLAY_HEIGHT*SCALE,
        {.SHOWN, .RESIZABLE},
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

        for step_time>=1/600.0
        {
        	step_time -=1/600.0
			emulator_step(&app.emu)
        }
      	

        for timer_time>=1/60.0
        {
        	timer_time -=1/60.0
        	emulator_tick_timers(&app.emu);
        	//buzz
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
	/*
	if len(os.args)<=1
	{
		fmt.println("Error: Missing or invalid ROM path.\nUsage: emulator <path_to_rom>");
		return
	}
	*/
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

	//todo
	//5-quirsk also
	//fix quirks
	//7-beep nope
	//fix beep noise
	if ok := app_init(&app, test_roms[4]); !ok{
		return
	}

	app_run(&app)

	defer app_destroy(&app)

}
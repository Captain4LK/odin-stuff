package gui

import "core:log"
import "core:fmt"
import "core:strings"
import "vendor:sdl3"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"
import "core:image/bmp"
import "core:image/netpbm"
import "core:image"
import "core:bytes"

import "../prof"

GLYPH_WIDTH :: 9
GLYPH_HEIGHT :: 16

@(private)
Context :: struct
{
   font_surface: ^sdl3.Surface,
   windows: [dynamic]^Window,
   scale: i32,
   mouse: Mouse,
   timer_event: u32,
   open_file_event: u32,
}

@(private="file")
ctx: Context

// TODO: HORIZONTAL_WRAP
Layout :: enum u8
{
   VERTICAL = 0,
   HORIZONTAL = 1,
   WRAP = 2,
}

MouseState :: enum
{
   LEFT,
   RIGHT,
   MIDDLE,
   X1,
   X2,
   DBLE_LEFT,
   DBLE_RIGHT,
}

MouseStateSet :: bit_set[MouseState]

Mouse :: struct
{
   button: MouseStateSet,
   wheel: f32,
   pos: [2]f32,
   rel: [2]f32,
   handled: bool,
}

Rect :: struct
{
   min: [2]i32,
   max: [2]i32,
}

ElementFlags :: bit_field u64
{
   layout: Layout | 2,
   style: u32 | 4,

   center_x: bool | 1,
   center_y: bool | 1,
   invisible: bool | 1,
   ignore: bool | 1,
   destroy: bool | 1,
   fill_x: bool | 1,
   fill_y: bool | 1,
   capture_mouse: bool | 1,
   no_parent: bool | 1,
   overlay: bool | 1,

   fix_x: bool | 1,
   fix_y: bool | 1,

   clip: bool | 1,

   // Layouting
}

MsgHandler :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64

Element :: struct
{
   //pad_in: [2]i32,
   //pad_out: [2]i32,
   pad: [2][2]i32,
   child_gap: i32,

   usr: u64,
   usr_ptr: rawptr,

   flags: ElementFlags,
   id: u64,
   //type_id: u32,
   parent: ^Element,
   window: ^Window,
   last_mouse: ^Element,
   children: [dynamic]^Element,

   // Timer
   timer: sdl3.TimerID,
   timer_interval: u64,

   // Layouting
   size: [2]i32,
   size_min: [2]i32,
   size_children: [2]i32,
   //child_size_required: [2]i32,

   //dimensions: [2]i32,
   //min_width: i32,
   //min_height: i32,

   bounds: Rect,
   translate: [2]i32,

   needs_redraw: bool,

   msg_base: MsgHandler,
   msg_user: MsgHandler,

   derived: any,
}

ElementType :: struct
{
   id: u32,
   name: string,
}

TextInputType :: enum
{
   CHARACTER,
   KEYCODE,
}

TextInput :: struct
{
   type: TextInputType,
   ch: u8,
   keycode: sdl3.Keycode,
}

// TODO: scale changed msg (sent through ignore)
Msg :: enum
{
   INVALID,
   NO_BLOCK_START,
   DESTROY,
   DRAW,
   //GET_SIZE,
   GET_WIDTH,
   GET_HEIGHT,
   GET_CHILD_PAD,
   NO_BLOCK_END,
   CLICK,
   CLICK_MENU,
   MOUSE,
   SLIDER_VALUE_CHANGED,
   BUTTON_DOWN,
   BUTTON_REPEAT,
   BUTTON_UP,
   TIMER,
   TEXTINPUT,
   TEXTINPUT_END,
   MOUSE_LEAVE,
   DRAGNDROP,

   OPENFILE,

   USER0,
}

Window :: struct
{
   using element: Element,

   keyboard: ^Element,
   blocking: ^Window,

   width: i32,
   height: i32,

   clip: Rect,
   translation: [2]i32,

   redraw: bool,
   //redraw: [dynamic]^Element,

   mouse_move_no_skip: bool,

   sdl_window: ^sdl3.Window,
   sdl_renderer: ^sdl3.Renderer,
   sdl_target: ^sdl3.Texture,
   sdl_overlay: ^sdl3.Texture,
   sdl_font: ^sdl3.Texture,
   sdl_icons: ^sdl3.Texture,
}

init :: proc() -> bool
{
   prof.SCOPED_EVENT(#procedure)

   res: bool = sdl3.Init({.VIDEO, .EVENTS})
   if !res
   {
      log.fatalf("Init failed: %v", sdl3.GetError())
      return false
   }

   ctx.font_surface = sdl3.CreateSurface(1024, 16, .RGBA8888)
   if ctx.font_surface == nil
   {
      log.fatalf("CreateSurface failed: %v", sdl3.GetError())
      return false
   }

   if !sdl3.LockSurface(ctx.font_surface)
   {
      log.fatalf("LockSurface failed: %v", sdl3.GetError())
      return false
   }

   font: [32 * 8]u64 = 
   {
      0x0000000000000000, 0x0000000000000000, 0xBD8181A5817E0000, 0x000000007E818199, 0xC3FFFFDBFF7E0000, 0x000000007EFFFFE7, 0x7F7F7F3600000000, 0x00000000081C3E7F,
      0x7F3E1C0800000000, 0x0000000000081C3E, 0xE7E73C3C18000000, 0x000000003C1818E7, 0xFFFF7E3C18000000, 0x000000003C18187E, 0x3C18000000000000, 0x000000000000183C,
      0xC3E7FFFFFFFFFFFF, 0xFFFFFFFFFFFFE7C3, 0x42663C0000000000, 0x00000000003C6642, 0xBD99C3FFFFFFFFFF, 0xFFFFFFFFFFC399BD, 0x331E4C5870780000, 0x000000001E333333,
      0x3C666666663C0000, 0x0000000018187E18, 0x0C0C0CFCCCFC0000, 0x00000000070F0E0C, 0xC6C6C6FEC6FE0000, 0x0000000367E7E6C6, 0xE73CDB1818000000, 0x000000001818DB3C,
      0x1F7F1F0F07030100, 0x000000000103070F, 0x7C7F7C7870604000, 0x0000000040607078, 0x1818187E3C180000, 0x0000000000183C7E, 0x6666666666660000, 0x0000000066660066,
      0xD8DEDBDBDBFE0000, 0x00000000D8D8D8D8, 0x6363361C06633E00, 0x0000003E63301C36, 0x0000000000000000, 0x000000007F7F7F7F, 0x1818187E3C180000, 0x000000007E183C7E,
      0x1818187E3C180000, 0x0000000018181818, 0x1818181818180000, 0x00000000183C7E18, 0x7F30180000000000, 0x0000000000001830, 0x7F060C0000000000, 0x0000000000000C06,
      0x0303000000000000, 0x0000000000007F03, 0xFF66240000000000, 0x0000000000002466, 0x3E1C1C0800000000, 0x00000000007F7F3E, 0x3E3E7F7F00000000, 0x0000000000081C1C,
      0x0000000000000000, 0x0000000000000000, 0x18183C3C3C180000, 0x0000000018180018, 0x0000002466666600, 0x0000000000000000, 0x36367F3636000000, 0x0000000036367F36,
      0x603E0343633E1818, 0x000018183E636160, 0x1830634300000000, 0x000000006163060C, 0x3B6E1C36361C0000, 0x000000006E333333, 0x000000060C0C0C00, 0x0000000000000000,
      0x0C0C0C0C18300000, 0x0000000030180C0C, 0x30303030180C0000, 0x000000000C183030, 0xFF3C660000000000, 0x000000000000663C, 0x7E18180000000000, 0x0000000000001818,
      0x0000000000000000, 0x0000000C18181800, 0x7F00000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000018180000, 0x1830604000000000, 0x000000000103060C,
      0xDBDBC3C3663C0000, 0x000000003C66C3C3, 0x1818181E1C180000, 0x000000007E181818, 0x0C183060633E0000, 0x000000007F630306, 0x603C6060633E0000, 0x000000003E636060,
      0x7F33363C38300000, 0x0000000078303030, 0x603F0303037F0000, 0x000000003E636060, 0x633F0303061C0000, 0x000000003E636363, 0x18306060637F0000, 0x000000000C0C0C0C,
      0x633E6363633E0000, 0x000000003E636363, 0x607E6363633E0000, 0x000000001E306060, 0x0000181800000000, 0x0000000000181800, 0x0000181800000000, 0x000000000C181800,
      0x060C183060000000, 0x000000006030180C, 0x00007E0000000000, 0x000000000000007E, 0x6030180C06000000, 0x00000000060C1830, 0x18183063633E0000, 0x0000000018180018,
      0x7B7B63633E000000, 0x000000003E033B7B, 0x7F6363361C080000, 0x0000000063636363, 0x663E6666663F0000, 0x000000003F666666, 0x03030343663C0000, 0x000000003C664303,
      0x66666666361F0000, 0x000000001F366666, 0x161E1646667F0000, 0x000000007F664606, 0x161E1646667F0000, 0x000000000F060606, 0x7B030343663C0000, 0x000000005C666363,
      0x637F636363630000, 0x0000000063636363, 0x18181818183C0000, 0x000000003C181818, 0x3030303030780000, 0x000000001E333333, 0x1E1E366666670000, 0x0000000067666636,
      0x06060606060F0000, 0x000000007F664606, 0xC3DBFFFFE7C30000, 0x00000000C3C3C3C3, 0x737B7F6F67630000, 0x0000000063636363, 0x63636363633E0000, 0x000000003E636363,
      0x063E6666663F0000, 0x000000000F060606, 0x63636363633E0000, 0x000070303E7B6B63, 0x363E6666663F0000, 0x0000000067666666, 0x301C0663633E0000, 0x000000003E636360,
      0x18181899DBFF0000, 0x000000003C181818, 0x6363636363630000, 0x000000003E636363, 0xC3C3C3C3C3C30000, 0x00000000183C66C3, 0xDBC3C3C3C3C30000, 0x000000006666FFDB,
      0x18183C66C3C30000, 0x00000000C3C3663C, 0x183C66C3C3C30000, 0x000000003C181818, 0x0C183061C3FF0000, 0x00000000FFC38306, 0x0C0C0C0C0C3C0000, 0x000000003C0C0C0C,
      0x1C0E070301000000, 0x0000000040607038, 0x30303030303C0000, 0x000000003C303030, 0x0000000063361C08, 0x0000000000000000, 0x0000000000000000, 0x0000FF0000000000,
      0x0000000000180C0C, 0x0000000000000000, 0x3E301E0000000000, 0x000000006E333333, 0x66361E0606070000, 0x000000003E666666, 0x03633E0000000000, 0x000000003E630303,
      0x33363C3030380000, 0x000000006E333333, 0x7F633E0000000000, 0x000000003E630303, 0x060F0626361C0000, 0x000000000F060606, 0x33336E0000000000, 0x001E33303E333333,
      0x666E360606070000, 0x0000000067666666, 0x18181C0018180000, 0x000000003C181818, 0x6060700060600000, 0x003C666660606060, 0x1E36660606070000, 0x000000006766361E,
      0x18181818181C0000, 0x000000003C181818, 0xDBFF670000000000, 0x00000000DBDBDBDB, 0x66663B0000000000, 0x0000000066666666, 0x63633E0000000000, 0x000000003E636363,
      0x66663B0000000000, 0x000F06063E666666, 0x33336E0000000000, 0x007830303E333333, 0x666E3B0000000000, 0x000000000F060606, 0x06633E0000000000, 0x000000003E63301C,
      0x0C0C3F0C0C080000, 0x00000000386C0C0C, 0x3333330000000000, 0x000000006E333333, 0xC3C3C30000000000, 0x00000000183C66C3, 0xC3C3C30000000000, 0x0000000066FFDBDB,
      0x3C66C30000000000, 0x00000000C3663C18, 0x6363630000000000, 0x001F30607E636363, 0x18337F0000000000, 0x000000007F63060C, 0x180E181818700000, 0x0000000070181818,
      0x1800181818180000, 0x0000000018181818, 0x18701818180E0000, 0x000000000E181818, 0x000000003B6E0000, 0x0000000000000000, 0x63361C0800000000, 0x00000000007F6363,
   }
   for c := 0; c < 128; c += 1
   {
      idx: int = c * 2
      for i := 0; i < 128; i += 1
      {
         x: int = i & 7
         y: int = i / 8
         val: int = i / 64
         bit: uint = uint(i & 63)
         set: bool = (font[idx + val] & (u64(1) << bit)) != 0

         if set
         {
            (cast([^]u32)ctx.font_surface.pixels)[y * int(ctx.font_surface.pitch / 4) + x + c * 8] = 0xffffffff
         }
         else
         {
            (cast([^]u32)ctx.font_surface.pixels)[y * int(ctx.font_surface.pitch / 4) + x + c * 8] = 0
         }
      }
   }
   sdl3.UnlockSurface(ctx.font_surface)

   set_scale(1)

   ctx.timer_event = sdl3.RegisterEvents(1)
   ctx.open_file_event = sdl3.RegisterEvents(1)

   return true
}

window_create :: proc(title: cstring, width: i32, height: i32, path_icon: string) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   window: ^Window = &element_create(Window, nil, {}, window_msg).derived.(Window)
   window.window = window
   window.width = width
   window.height = height
   window.blocking = nil

   append(&ctx.windows, window)

   res: bool = sdl3.CreateWindowAndRenderer(title, 1, 1, {.RESIZABLE}, &window.sdl_window, &window.sdl_renderer)
   if !res do log.errorf("CreateWindowAndRenderer failed: %v", sdl3.GetError())

   window.sdl_target = sdl3.CreateTexture(window.sdl_renderer, .RGBA8888, .TARGET, window.width, window.height)
   if window.sdl_target == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

   window.sdl_overlay = sdl3.CreateTexture(window.sdl_renderer, .RGBA8888, .TARGET, window.width, window.height)
   if window.sdl_overlay == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

   res = sdl3.SetTextureBlendMode(window.sdl_overlay, {.BLEND})
   if !res do log.errorf("SetTextureBlendMode failed: %v", sdl3.GetError())

   window.sdl_font = sdl3.CreateTextureFromSurface(window.sdl_renderer, ctx.font_surface)
   if window.sdl_font == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

   res = sdl3.SetWindowSize(window.sdl_window, width, height)
   if !res do log.errorf("SetWindowSize failed: %v", sdl3.GetError())

   //surface: sdl3.Surface
   //window.sdl_icons = nil
   img: ^image.Image
   err: image.Error
   img, err = image.load_from_file(path_icon)
   defer image.destroy(img)
   image.alpha_add_if_missing(img)
   if err != nil
   {
      log.errorf("failed to load image \"%v\": %v\n", path_icon, err)
   }

   data: []u8 = bytes.buffer_to_bytes(&img.pixels)
   surface: ^sdl3.Surface = sdl3.CreateSurfaceFrom(i32(img.width), i32(img.height), .RGBA32, raw_data(data), i32(img.width * 4))
   defer sdl3.DestroySurface(surface)
   window.sdl_icons = sdl3.CreateTextureFromSurface(window.sdl_renderer, surface)
   sdl3.SetTextureScaleMode(window.sdl_icons, .NEAREST)

   return window
}

quit_event :: proc()
{
   prof.SCOPED_EVENT(#procedure)

   for i := 0; i < len(ctx.windows); i += 1
   {
      element_destroy(ctx.windows[i])
   }
}

exposed_event :: proc(window_id: sdl3.WindowID) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   res: bool
   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil

   res = sdl3.SetRenderTarget(win.sdl_renderer, nil)
   if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

   res = sdl3.RenderClear(win.sdl_renderer)
   if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

   res = sdl3.RenderTexture(win.sdl_renderer, win.sdl_target, nil, nil)
   if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

   res = sdl3.RenderTexture(win.sdl_renderer, win.sdl_overlay, nil, nil)
   if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

   res = sdl3.RenderPresent(win.sdl_renderer)
   if !res do log.errorf("RenderPresent failed: %v", sdl3.GetError())

   return win
}

resized_event :: proc(window_id: sdl3.WindowID, width: i32, height: i32) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   width := width
   height := height
   res: bool
   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil

   //width: i32 = event.window.data1
   //height: i32 = event.window.data2
   sdl3.FlushEvent(.WINDOW_RESIZED)
   sdl3.FlushEvent(.WINDOW_PIXEL_SIZE_CHANGED)
   sdl3.GetWindowSizeInPixels(win.sdl_window, &width, &height)
   if win.width != width || win.height != height
   {
      win.width = width
      win.height = height

      sdl3.DestroyTexture(win.sdl_target)
      win.sdl_target = sdl3.CreateTexture(win.sdl_renderer, .RGBA8888, .TARGET, win.width, win.height)
      if win.sdl_target == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

      sdl3.DestroyTexture(win.sdl_overlay)
      win.sdl_overlay = sdl3.CreateTexture(win.sdl_renderer, .RGBA8888, .TARGET, win.width, win.height)
      if win.sdl_overlay == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

      res = sdl3.SetTextureBlendMode(win.sdl_overlay, {.BLEND})
      if !res do log.errorf("SetTextureBlendMode failed: %v", sdl3.GetError())

      res = sdl3.SetRenderTarget(win.sdl_renderer, nil)
      if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
      
      win.bounds = {{0, 0}, {win.width, win.height}}
      //fmt.printf("Layout: %v\n", win.bounds)
      element_layout(win, win.bounds)
      element_redraw(win)
   }

   return win
}

mouse_leave_event :: proc(window_id: sdl3.WindowID) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   res: bool
   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil

   ctx.mouse.pos = {-1, -1}
   ctx.mouse.rel = {0, 0}
   ctx.mouse.wheel = 0
   handle_mouse(win, ctx.mouse)

   return win
}

close_event :: proc(window_id: sdl3.WindowID) -> (quit: bool)
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return false
   
   if win == ctx.windows[0]
   {
      for i := 0; i < len(ctx.windows); i += 1
      {
         element_destroy(ctx.windows[i])
      }
      return true
   }

   for i := 0; i < len(ctx.windows); i += 1
   {
      if ctx.windows[i].blocking == win do ctx.windows[i].blocking = nil
   }

   for i := 0; i < len(ctx.windows); i += 1
   {
      if ctx.windows[i] != win do continue

      element_destroy(win)
      unordered_remove(&ctx.windows, i)
      //win = nil
      //break
   }

   return false
}

mouse_motion_event :: proc(window_id: sdl3.WindowID, xrel: f32, yrel: f32) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil

   ctx.mouse.rel[0] = xrel
   ctx.mouse.rel[1] = yrel

   // Hack to prevent flooding the event queue
   if !win.mouse_move_no_skip
   {
      flags: sdl3.MouseButtonFlags = sdl3.GetMouseState(&ctx.mouse.pos[0], &ctx.mouse.pos[1])
      sdl3.FlushEvent(.MOUSE_MOTION)
   }

   ctx.mouse.wheel = 0
   handle_mouse(win, ctx.mouse)

   return win
}

mouse_wheel_event :: proc(window_id: sdl3.WindowID, wheel: f32) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return win
   
   ctx.mouse.wheel = wheel
   handle_mouse(win, ctx.mouse)
   
   return win
}

key_down_event :: proc(window_id: sdl3.WindowID, keycode: sdl3.Keycode, 
   scancode: sdl3.Scancode, repeat: bool) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   //if event.key.down
   //{
   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil
   
   if win.keyboard != nil
   {
      input: TextInput
      input.type = .KEYCODE
      input.keycode = keycode
      element_msg(win.keyboard, .TEXTINPUT, 0, &input)
   }
   else
   {
      // TODO: pass in dp?
      if repeat
      {
         element_msg_all(win, .BUTTON_REPEAT, i64(scancode), nil)
      }
      else
      {
         element_msg_all(win, .BUTTON_DOWN, i64(scancode), nil)
      }
   }

   win = find_window(sdl3.GetWindowFromID(window_id))

   return win
   //}
}

key_up_event :: proc(window_id: sdl3.WindowID, scancode: sdl3.Scancode) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil
   
   element_msg_all(win, .BUTTON_UP, i64(scancode), nil)

   win = find_window(sdl3.GetWindowFromID(window_id))

   return win
}

drop_file_event :: proc(window_id: sdl3.WindowID, data: cstring) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil
   
   data := data
   element_msg(win, .DRAGNDROP, 0, &data)

   return win
}

button_down_event :: proc(window_id: sdl3.WindowID, x: f32, y: f32, button: u8, clicks: u8) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil

   ctx.mouse.pos[0] = x
   ctx.mouse.pos[1] = y

   switch button
   {
   case 1:
      ctx.mouse.button += {.LEFT}
      if clicks == 2 do ctx.mouse.button += {.DBLE_LEFT}
   case 3:
      ctx.mouse.button += {.RIGHT}
      if clicks == 2 do ctx.mouse.button += {.DBLE_RIGHT}
   case 2:
      ctx.mouse.button += {.MIDDLE}
   case 4:
      ctx.mouse.button += {.X1}
   case 5:
      ctx.mouse.button += {.X2}
   }

   handle_mouse(win, ctx.mouse)
   
   win = find_window(sdl3.GetWindowFromID(window_id))

   return win
}

button_up_event :: proc(window_id: sdl3.WindowID, button: u8) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return win

   switch button
   {
   case 1:
      ctx.mouse.button -= {.LEFT, .DBLE_LEFT}
   case 3:
      ctx.mouse.button -= {.RIGHT, .DBLE_RIGHT}
   case 2:
      ctx.mouse.button -= {.MIDDLE}
   case 4:
      ctx.mouse.button -= {.X1}
   case 5:
      ctx.mouse.button -= {.X2}
   }

   handle_mouse(win, ctx.mouse)

   win = find_window(sdl3.GetWindowFromID(window_id))

   return win
}

text_input_event :: proc(window_id: sdl3.WindowID, text: cstring) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = find_window(sdl3.GetWindowFromID(window_id))
   if win == nil do return nil

   for i := 0; i < len(text); i += 1
   {
      input: TextInput
      input.type = .CHARACTER
      input.ch = (transmute([^]u8)text)[i]
      element_msg(win.keyboard, .TEXTINPUT, 0, &input)
   }

   win = find_window(sdl3.GetWindowFromID(window_id))

   return win
}

// TODO: additional version for _update and _render style
// for running at a fixed framerate
msg_loop :: proc()
{
   prof.SCOPED_EVENT(#procedure)

   for
   {
      event: sdl3.Event
      res: bool = sdl3.WaitEvent(&event)
      if !res do log.errorf("WaitEvent failed: %v", sdl3.GetError())

      win: ^Window = nil

      #partial switch event.type
      {
      case .QUIT:
         quit_event()
         return
         /*
         for i := 0; i < len(ctx.windows); i += 1
         {
            element_destroy(ctx.windows[i])
         }
         return
         */
      case .WINDOW_SHOWN, .WINDOW_EXPOSED:
         win = exposed_event(event.window.windowID)
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue

         res = sdl3.SetRenderTarget(win.sdl_renderer, nil)
         if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

         res = sdl3.RenderClear(win.sdl_renderer)
         if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

         res = sdl3.RenderTexture(win.sdl_renderer, win.sdl_target, nil, nil)
         if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

         res = sdl3.RenderTexture(win.sdl_renderer, win.sdl_overlay, nil, nil)
         if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

         res = sdl3.RenderPresent(win.sdl_renderer)
         if !res do log.errorf("RenderPresent failed: %v", sdl3.GetError())
         */
      case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
      {
         win = resized_event(event.window.windowID, event.window.data1, event.window.data2)
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue

         width: i32 = event.window.data1
         height: i32 = event.window.data2
         sdl3.FlushEvent(.WINDOW_RESIZED)
         sdl3.FlushEvent(.WINDOW_PIXEL_SIZE_CHANGED)
         sdl3.GetWindowSizeInPixels(win.sdl_window, &width, &height)
         if win.width != width || win.height != height
         {
            win.width = width
            win.height = height

            sdl3.DestroyTexture(win.sdl_target)
            win.sdl_target = sdl3.CreateTexture(win.sdl_renderer, .RGBA8888, .TARGET, win.width, win.height)
            if win.sdl_target == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

            sdl3.DestroyTexture(win.sdl_overlay)
            win.sdl_overlay = sdl3.CreateTexture(win.sdl_renderer, .RGBA8888, .TARGET, win.width, win.height)
            if win.sdl_overlay == nil do log.errorf("CreateTexture failed: %v", sdl3.GetError())

            res = sdl3.SetTextureBlendMode(win.sdl_overlay, {.BLEND})
            if !res do log.errorf("SetTextureBlendMode failed: %v", sdl3.GetError())

            res = sdl3.SetRenderTarget(win.sdl_renderer, nil)
            if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
            
            win.bounds = {{0, 0}, {win.width, win.height}}
            //fmt.printf("Layout: %v\n", win.bounds)
            element_layout(win, win.bounds)
            element_redraw(win)
         }
         */
      }
      case .WINDOW_MOUSE_LEAVE:
         win = mouse_leave_event(event.window.windowID)
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue

         ctx.mouse.pos = {-1, -1}
         ctx.mouse.rel = {0, 0}
         ctx.mouse.wheel = 0
         handle_mouse(win, ctx.mouse)
         */
      case .WINDOW_CLOSE_REQUESTED:
         quit: bool = close_event(event.window.windowID)
         if quit do return
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue
         
         if win == ctx.windows[0]
         {
            for i := 0; i < len(ctx.windows); i += 1
            {
               element_destroy(ctx.windows[i])
            }
            return
         }

         for i := 0; i < len(ctx.windows); i += 1
         {
            if ctx.windows[i].blocking == win do ctx.windows[i].blocking = nil
         }

         for i := 0; i < len(ctx.windows); i += 1
         {
            if ctx.windows[i] != win do continue

            element_destroy(win)
            unordered_remove(&ctx.windows, i)
            win = nil
            break
         }
         */
      case .MOUSE_MOTION:
         win = mouse_motion_event(event.motion.windowID, event.motion.xrel, event.motion.yrel)
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue

         ctx.mouse.rel[0] = event.motion.xrel
         ctx.mouse.rel[1] = event.motion.yrel

         // Hack to prevent flooding the event queue
         if !win.mouse_move_no_skip
         {
            flags: sdl3.MouseButtonFlags = sdl3.GetMouseState(&ctx.mouse.pos[0], &ctx.mouse.pos[1])
            sdl3.FlushEvent(.MOUSE_MOTION)
         }

         ctx.mouse.wheel = 0
         handle_mouse(win, ctx.mouse)
         */
      case .MOUSE_WHEEL:
         win = mouse_wheel_event(event.wheel.windowID, event.wheel.y)
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue
         
         ctx.mouse.wheel = event.wheel.y
         handle_mouse(win, ctx.mouse)
         */
      case .KEY_DOWN:
         if event.key.down
         {
            win = key_down_event(event.key.windowID, event.key.key, event.key.scancode, event.key.repeat)
         }

         /*
         if event.key.down
         {
            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
            if win == nil do continue
            
            if win.keyboard != nil
            {
               input: TextInput
               input.type = .KEYCODE
               input.keycode = event.key.key
               element_msg(win.keyboard, .TEXTINPUT, 0, &input)
            }
            else
            {
               // TODO: pass in dp?
               if event.key.repeat
               {
                  element_msg_all(win, .BUTTON_REPEAT, int(event.key.scancode), nil)
               }
               else
               {
                  element_msg_all(win, .BUTTON_DOWN, int(event.key.scancode), nil)
               }
            }

            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         }
         */
      case .KEY_UP:
         if !event.key.down
         {
            win = key_up_event(event.key.windowID, event.key.scancode)
         }
         /*
         if !event.key.down
         {
            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
            if win == nil do continue
            
            element_msg_all(win, .BUTTON_UP, int(event.key.scancode), nil)

            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         }
         */
      case .DROP_FILE:
         win = drop_file_event(event.drop.windowID, event.drop.data)
         /*
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue
         
         element_msg(win, .DRAGNDROP, 0, &event.drop.data)
         */
      case .MOUSE_BUTTON_DOWN:
         if event.button.down
         {
            win = button_down_event(event.button.windowID, event.button.x, event.button.y, event.button.button, event.button.clicks)
         }
         /*
         if event.button.down
         {
            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
            if win == nil do continue

            ctx.mouse.pos[0] = event.button.x
            ctx.mouse.pos[1] = event.button.y

            switch event.button.button
            {
            case 1:
               ctx.mouse.button += {.LEFT}
               if event.button.clicks == 2 do ctx.mouse.button += {.DBLE_LEFT}
            case 3:
               ctx.mouse.button += {.RIGHT}
               if event.button.clicks == 2 do ctx.mouse.button += {.DBLE_RIGHT}
            case 2:
               ctx.mouse.button += {.MIDDLE}
            case 4:
               ctx.mouse.button += {.X1}
            case 5:
               ctx.mouse.button += {.X2}
            }

            handle_mouse(win, ctx.mouse)
            
            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         }
         */
      case .MOUSE_BUTTON_UP:
         if !event.button.down
         {
            win = button_up_event(event.button.windowID, event.button.button)
         }
         /*
         if !event.button.down
         {
            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
            if win == nil do continue

            switch event.button.button
            {
            case 1:
               ctx.mouse.button -= {.LEFT, .DBLE_LEFT}
            case 3:
               ctx.mouse.button -= {.RIGHT, .DBLE_RIGHT}
            case 2:
               ctx.mouse.button -= {.MIDDLE}
            case 4:
               ctx.mouse.button -= {.X1}
            case 5:
               ctx.mouse.button -= {.X2}
            }

            handle_mouse(win, ctx.mouse)

            win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         }
         */
      case .TEXT_INPUT:
         win = text_input_event(event.text.windowID, event.text.text)
         /*
         //fmt.printf("TextInputEent\n")
         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         if win == nil do continue

         for i := 0; i < len(event.text.text); i += 1
         {
            input: TextInput
            input.type = .CHARACTER
            input.ch = (transmute([^]u8)event.text.text)[i]
            element_msg(win.keyboard, .TEXTINPUT, 0, &input)
         }

         win = find_window(sdl3.GetWindowFromID(event.window.windowID))
         */
      case sdl3.EventType(ctx.timer_event):
         win = find_window(sdl3.GetWindowFromID(event.user.windowID))
         if win != nil
         {
            element_msg(cast(^Element)event.user.data1, .TIMER, 0, nil)

            // Make sure we do not flood the event queue if our update took longer
            // than the timer interval (slow frame in game)
            sdl3.FlushEvent(sdl3.EventType(ctx.timer_event))
         }

         win = find_window(sdl3.GetWindowFromID(event.user.windowID))
      case sdl3.EventType(ctx.open_file_event):
         win = find_window(sdl3.GetWindowFromID(event.user.windowID))
         if win != nil
         {
            element_msg(win, .OPENFILE, 0, event.user.data1)
         }

         // delete msg context
         msg: ^OpenFileMsg = cast(^OpenFileMsg)event.user.data1
         for file in msg.file_list
         {
            delete(file)
         }
         delete(msg.file_list)
         free(msg)

         win = find_window(sdl3.GetWindowFromID(event.user.windowID))
      }

      if win != nil && win.redraw
      {
         res: bool = sdl3.SetRenderTarget(win.sdl_renderer, win.sdl_target)
         if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

         element_redraw_msg(win)
         win.redraw = false
         /*
         for i := 0; i < len(win.redraw); i += 1
         {
            if win.redraw[i].needs_redraw
            {
               element_redraw_msg(win.redraw[i])
            }
         }
         */
         //clear(&win.redraw)

         res = sdl3.SetRenderTarget(win.sdl_renderer, nil)
         if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

         res = sdl3.RenderClear(win.sdl_renderer)
         if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

         res = sdl3.RenderTexture(win.sdl_renderer, win.sdl_target, nil, nil)
         if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

         res = sdl3.RenderTexture(win.sdl_renderer, win.sdl_overlay, nil, nil)
         if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

         res = sdl3.RenderPresent(win.sdl_renderer)
         if !res do log.errorf("RenderPresent failed: %v", sdl3.GetError())
         //}
      }
   }
}

set_scale :: proc(scale: i32)
{
   prof.SCOPED_EVENT(#procedure)

   ctx.scale = scale
}

get_scale :: proc() -> i32
{
   return ctx.scale
}

@(private="file")
handle_mouse_intern :: proc(root: ^Element, e: ^Element, m: ^Mouse)
{
   prof.SCOPED_EVENT(#procedure)

   old_trans: [2]i32 = e.window.translation
   e.window.translation += e.translate
   pt: [2]f32 = m.pos

   for i := 0; i < len(e.children); i += 1
   {
      child: ^Element = e.children[i]

      if child.flags.ignore do continue
      //if element_ignored(child) do continue

      b: Rect = child.bounds
      b.min += e.window.translation
      b.max += e.window.translation
      if pt[0] >= f32(b.min[0]) && pt[1] >= f32(b.min[1]) &&
         pt[0] <= f32(b.max[0]) && pt[1] <= f32(b.max[1])
      {
         handle_mouse_intern(root, child, m)
         //leaf: ^Element = element_by_point(child, pt)
         //if leaf != nil do return leaf
         //return child
      }
   }

   e.window.translation = old_trans

   if !m.handled
   {
      //element_msg(e, 
      capture: i64 = element_msg(e, .MOUSE, 0, m)
      if m.handled
      {
         if root.last_mouse != nil && root.last_mouse != e
         {
            element_msg(root.last_mouse, .MOUSE_LEAVE, 0, nil)
         }

         root.flags.capture_mouse = bool(capture)
         root.last_mouse = e
      }
   }
   /*
   old_trans: [2]i32 = e.window.translation
   e.window.translation += e.translate

   for i := 0; i < len(e.children); i += 1
   {
      child: ^Element = e.children[i]

      if element_ignored(child) do continue

      b: Rect = child.bounds
      b.min += e.window.translation
      b.max += e.window.translation
      if pt[0] >= f32(b.min[0]) && pt[1] >= f32(b.min[1]) &&
         pt[0] <= f32(b.max[0]) && pt[1] <= f32(b.max[1])
      {
         leaf: ^Element = element_by_point(child, pt)
         if leaf != nil do return leaf
         return child
      }
   }

   /*
   e.window.translation = old_trans
   */
   
   return nil
   */
}

handle_mouse :: proc(e: ^Element, m: Mouse)
{
   prof.SCOPED_EVENT(#procedure)

   click: ^Element

   if e.flags.capture_mouse
   {
      click = e.last_mouse
      if click != nil
      {
         m := m
         capture: i64 = element_msg(click, .MOUSE, 0, &m)
         e.flags.capture_mouse = bool(capture)
         e.last_mouse = click
      }
   }
   else
   {
      m := m
      m.handled = false
      if !element_ignored(e)
      {
         handle_mouse_intern(e, e, &m)
      }
      /*
      click = element_by_point(e, m.pos)
      if e.last_mouse != nil && e.last_mouse != click
      {
         element_msg(e.last_mouse, .MOUSE_LEAVE, 0, nil)
      }
      */
   }

   /*
   if click != nil
   {
      m := m
      capture: int = element_msg(click, .MOUSE, 0, &m)
      e.flags.capture_mouse = bool(capture)
      e.last_mouse = click
   }
   */
   /*
   click: ^Element

   if e.flags.capture_mouse
   {
      click = e.last_mouse
   }
   else
   {
      click = element_by_point(e, m.pos)
      if e.last_mouse != nil && e.last_mouse != click
      {
         element_msg(e.last_mouse, .MOUSE_LEAVE, 0, nil)
      }
   }

   if click != nil
   {
      m := m
      capture: int = element_msg(click, .MOUSE, 0, &m)
      e.flags.capture_mouse = bool(capture)
      e.last_mouse = click
   }
   */
}

window_close :: proc(win: ^Window)
{
   prof.SCOPED_EVENT(#procedure)

   event: sdl3.Event
   event.type = .WINDOW_CLOSE_REQUESTED
   event.window.windowID = sdl3.GetWindowID(win.sdl_window)
}

overlay_clear :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   target, ok := sdl3.GetRenderTarget(e.window.sdl_renderer).?
   if !ok do target = nil

   res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, e.window.sdl_overlay)
   if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

   //res = sdl3.RenderClear(e.window.sdl_renderer)
   //if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

   res = sdl3.SetRenderDrawColor(e.window.sdl_renderer, 0, 0, 0, 0)
   if !res do log.errorf("SetRenderDrawColor failed: %v", sdl3.GetError())

   res = sdl3.RenderClear(e.window.sdl_renderer)
   if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

   res = sdl3.SetRenderDrawColor(e.window.sdl_renderer, 0, 0, 0, 255)
   if !res do log.errorf("SetRenderDrawColor failed: %v", sdl3.GetError())

   res = sdl3.SetRenderTarget(e.window.sdl_renderer, target)
   if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
}

window_block :: proc(root: ^Window, blocking: ^Window)
{
   prof.SCOPED_EVENT(#procedure)

   root.blocking = blocking
}

textinput_start :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   if e == nil do return

   textinput_stop(e.window)

   e.window.keyboard = e
   res: bool = sdl3.StartTextInput(e.window.sdl_window)
   if !res do log.errorf("StartTextInput failed: %v", sdl3.GetError())
}

textinput_stop :: proc(win: ^Window)
{
   prof.SCOPED_EVENT(#procedure)

   if win == nil do return

   if win.keyboard != nil
   {
      element_msg(win.keyboard, .TEXTINPUT_END, 0, nil)
      win.keyboard = nil
      res: bool = sdl3.StopTextInput(win.sdl_window)
      if !res do log.errorf("StopTextInput failed: %v", sdl3.GetError())
   }
}

@(private="file")
window_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   win: ^Window = &e.derived.(Window)

   if msg == .GET_WIDTH
   {
      return i64(win.width)
   }
   else if msg == .GET_HEIGHT
   {
      return i64(win.height)
   }
   else if msg == .DESTROY
   {
      sdl3.DestroyTexture(win.sdl_target)
      sdl3.DestroyTexture(win.sdl_overlay)
      sdl3.DestroyTexture(win.sdl_font)
      if win.sdl_icons != nil do sdl3.DestroyTexture(win.sdl_icons)

      sdl3.DestroyRenderer(win.sdl_renderer)
      sdl3.DestroyWindow(win.sdl_window)
   }

   return 0
}

find_window :: proc(win: ^sdl3.Window) -> ^Window
{
   prof.SCOPED_EVENT(#procedure)

   if win == nil do return nil

   for i := 0; i < len(ctx.windows); i += 1
   {
      if ctx.windows[i].sdl_window == win do return ctx.windows[i]
   }

   return nil
}

rect_inside :: proc(r: Rect, p: [2]i32) -> bool
{
   prof.SCOPED_EVENT(#procedure)

   if p.x < r.min.x || p.y < r.min.y do return false
   if p.x > r.max.x || p.y > r.max.y do return false

   return true
}

@(private)
timer_callback :: proc "c" (userdata: rawptr, timer_id: sdl3.TimerID, interval: u64) -> u64
{
   e: ^Element = cast(^Element)userdata
   event: sdl3.Event
   event.type = sdl3.EventType(ctx.timer_event)
   event.user.windowID = sdl3.GetWindowID(e.window.sdl_window)
   event.user.data1 = e
   res: bool = sdl3.PushEvent(&event)

   return interval
}

@(private)
open_file_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: i32)
{
   dialog_ctx: ^DialogInternalCtx = cast(^DialogInternalCtx)userdata
   context = dialog_ctx.ctx

   filelist_len: i32 = 0
   for filelist != nil
   {
      if filelist[filelist_len] == nil do break
      filelist_len += 1
   }

   msg: ^OpenFileMsg = new(OpenFileMsg)
   msg.ident = dialog_ctx.ident
   msg.filter = filter
   msg.file_list = make([]string, filelist_len)
   for i in 0..<filelist_len
   {
      msg.file_list[i] = strings.clone_from_cstring(filelist[i])
   }

   event: sdl3.Event
   event.type = sdl3.EventType(ctx.open_file_event)
   event.user.windowID = sdl3.GetWindowID(dialog_ctx.window.sdl_window)
   event.user.data1 = msg
   res: bool = sdl3.PushEvent(&event)

   for filter in dialog_ctx.filters
   {
      delete(filter.name)
      delete(filter.pattern)
   }
   delete(dialog_ctx.filters)
   free(dialog_ctx)
}

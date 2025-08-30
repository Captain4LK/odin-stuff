package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

Separator :: struct
{
   using element: Element,
   direction: bool,
}

separator_create :: proc(parent: ^Element, flags: ElementFlags, direction: bool) -> ^Separator
{
   separator: ^Separator = &element_create(Separator, parent, flags, separator_msg).derived.(Separator)
   separator.direction = direction

   return separator
}

@(private="file")
separator_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   separator: ^Separator = &e.derived.(Separator)

   if msg == .GET_WIDTH
   {
      return int(get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return int(get_scale())
   }
   else if msg == .DRAW
   {
      draw_rectangle_fill(separator, separator.bounds, {0, 0, 0, 255})
   }

   return 0
}

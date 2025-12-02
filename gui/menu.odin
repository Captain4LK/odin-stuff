package gui

import "core:log"
import "core:strings"
import "core:fmt"
import "vendor:sdl3"

import "../prof"

MenuButton :: struct
{
   using element: Element,

   state: bool,
   text: string,
   idx: int,
}

menu_create :: proc(parent: ^Element, flags: ElementFlags, cflags: ElementFlags, labels: []string, msg_usr: MsgHandler) -> ^Group
{
   prof.SCOPED_EVENT(#procedure)

   group: ^Group = group_create(parent, flags)
   for label, idx in labels
   {
      button: ^MenuButton = &element_create(MenuButton, group, cflags, menubutton_msg).derived.(MenuButton)
      button.idx = idx
      button.msg_user = msg_usr
      button.text = strings.clone(label)
   }

   return group
}

@(private="file")
menubutton_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   //fmt.printf("MSG %v\n", msg)
   button: ^MenuButton = &e.derived.(MenuButton)

   if msg == .GET_WIDTH
   {
      return i64(len(button.text)) * i64(GLYPH_WIDTH * get_scale()) + i64(10 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(GLYPH_HEIGHT * get_scale()) + i64(8 * get_scale())
   }
   else if msg == .MOUSE_LEAVE
   {
      state_old: bool = button.state
      button.state = false
      if state_old != button.state
      {
         element_redraw(button)
      }
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp

      if button.state
      {
         mouse.handled = true
      }

      click: bool = false
      state_old: bool = button.state
      if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
      {
         button.state = true
         mouse.handled = true
      }
      else
      {
         click = button.state
         button.state = false
      }

      if click || state_old != button.state
      {
         element_redraw(button)
      }

      if click
      {
         element_msg(button, .CLICK_MENU, i64(button.idx), nil)
         button.state = false
      }
   }
   else if msg == .DRAW
   {
      menubutton_draw(button)
   }
   else if msg == .DESTROY
   {
      delete(button.text)
   }

   return 0
}

@(private="file")
menubutton_draw :: proc(button: ^MenuButton)
{
   //fmt.printf("Draw\n")
   bounds: Rect = button.bounds

   if button.state
   {
      draw_rectangle_fill(button, bounds, {50, 50, 50, 255})
   }
   else
   {
      draw_rectangle_fill(button, bounds, {90, 90, 90, 255})
   }

   draw_label(button, button.bounds, button.text, {0, 0, 0, 255}, true)
}

package gui

import "core:log"
import "core:fmt"
import "vendor:sdl3"

import "../prof"

ScrollGroup :: struct
{
   using element: Element,
}

@(private="file")
SGGroup :: struct
{
   using elment: Element,
}

@(private="file")
SGButton :: struct
{
   using element: Element,
   state: bool,
   up: bool,
   sg: ^ScrollGroup,
}

@(private="file")
SGBar :: struct
{
   using element: Element,
   sg: ^ScrollGroup,
}

scroll_group_set :: proc(sg: ^ScrollGroup, scroll: i32)
{
   prof.SCOPED_EVENT(#procedure)

   scroll_min: i32 = 0
   scroll_max: i32 = max(0, sg.size_children[1] - (sg.bounds.max[1] - sg.bounds.min[1]))

   sg.translate[1] = -min(scroll_max, max(scroll_min, -scroll))
   //fmt.printf("%v %v %v\n", sg.translate[1], scroll_max, sg.size_children[1])
         //progress: f64 = f64(-sgbar.sg.translate[1]) / f64(sgbar.sg.size_children[1] - 
                      //(sgbar.sg.bounds.max[1] - sgbar.sg.bounds.min[1]))
   element_redraw(sg)
}

scroll_group_create :: proc(parent: ^Element, flags: ElementFlags) -> ^ScrollGroup
{
   prof.SCOPED_EVENT(#procedure)

   root: ^SGGroup = sggroup_create(parent, flags)
   scroll_group: ^ScrollGroup = &element_create(ScrollGroup, root, {fill_x = true, fill_y = true, clip = true}, scroll_group_msg).derived.(ScrollGroup)
   bg: ^SGGroup = sggroup_create(root, {fill_y = true})
   b0: ^SGButton = sgbutton_create(bg, {})
   b0.up = true
   bar: ^SGBar = sgbar_create(bg, {fill_y = true, fill_x = true})
   b1: ^SGButton = sgbutton_create(bg, {})
   b1.up = false

   b0.sg = scroll_group
   b1.sg = scroll_group
   bar.sg = scroll_group

   return scroll_group
}

@(private="file")
scroll_group_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   scroll_group: ^ScrollGroup = &e.derived.(ScrollGroup)

   if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp
      if mouse.wheel != 0
      {
         mouse.handled = true
         //scroll_group.translate[1] += i32(mouse.wheel * GLYPH_HEIGHT) * get_scale()
         scroll_group_set(scroll_group, scroll_group.translate[1] + i32(mouse.wheel * GLYPH_HEIGHT) * get_scale())
      }
   }
   else if msg == .GET_WIDTH
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      return i64(scroll_group.size_min[0])
      //return int(max(space[0], scroll_group.size_min[0]))
   }
   else if msg == .GET_HEIGHT
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      //return int(max(space[0], scroll_group.size_min[1]))
      return i64(scroll_group.size_min[1])
   }
   else if msg == .DRAW
   {
      scroll_group_set(scroll_group, scroll_group.translate[1])
      scroll_group_draw(scroll_group)
   }

   return 0
}

@(private="file")
scroll_group_draw :: proc(scroll_group: ^ScrollGroup)
{
   if scroll_group.flags.style == 0
   {
      //draw_rectangle_fill(scroll_group, scroll_group.bounds, {90, 90, 90, 255})
   }
   else if scroll_group.flags.style == 1
   {
      //draw_rectangle_fill(scroll_group, scroll_group.bounds, {90, 90, 90, 255})
      //draw_rectangle(scroll_group, scroll_group.bounds, {0, 0, 0, 255})
   }
}

@(private="file")
sggroup_create :: proc(parent: ^Element, flags: ElementFlags) -> ^SGGroup
{
   prof.SCOPED_EVENT(#procedure)

   sggroup: ^SGGroup = &element_create(SGGroup, parent, flags, sggroup_msg).derived.(SGGroup)

   return sggroup
}


@(private="file")
sggroup_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   sggroup: ^SGGroup = &e.derived.(SGGroup)

   if msg == .GET_WIDTH
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      return i64(max(space[0], sggroup.size_min[0]))
   }
   else if msg == .GET_HEIGHT
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      return i64(max(space[0], sggroup.size_min[1]))
   }
   else if msg == .DRAW
   {
      ///sggroup_draw(sggroup)
      draw_rectangle_fill(sggroup, sggroup.bounds, {90, 90, 90, 255})
      draw_rectangle(sggroup, sggroup.bounds, {0, 0, 0, 255})
   }

   return 0
}

@(private="file")
sgbutton_create :: proc(parent: ^Element, flags: ElementFlags) -> ^SGButton
{
   prof.SCOPED_EVENT(#procedure)

   sgbutton: ^SGButton = &element_create(SGButton, parent, flags, sgbutton_msg).derived.(SGButton)
   //sgbutton.text = strings.clone(str)

   return sgbutton
}

@(private="file")
sgbutton_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   sgbutton: ^SGButton = &e.derived.(SGButton)

   if msg == .GET_WIDTH
   {
      return 1 * i64(GLYPH_WIDTH * get_scale()) + i64(10 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(GLYPH_HEIGHT * get_scale()) + i64(8 * get_scale())
   }
   else if msg == .MOUSE_LEAVE
   {
      state_old: bool = sgbutton.state
      sgbutton.state = false
      if state_old != sgbutton.state
      {
         element_redraw(sgbutton)
      }
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp

      click: bool = false
      state_old: bool = sgbutton.state
      if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
      {
         sgbutton.state = true
      }
      else
      {
         click = sgbutton.state
         sgbutton.state = false
      }

      if click || state_old != sgbutton.state
      {
         element_redraw(sgbutton)
      }

      if click
      {
         element_msg(sgbutton, .CLICK, 0, nil)
         sgbutton.state = false
      }
   }
   else if msg == .DRAW
   {
      sgbutton_draw(sgbutton)
   }
   else if msg == .CLICK
   {
      if sgbutton.up
      {
         scroll_group_set(sgbutton.sg, sgbutton.sg.translate[1] + 16)
         //sgbutton.sg.translate[1] += 16
      }
      else
      {
         scroll_group_set(sgbutton.sg, sgbutton.sg.translate[1] - 16)
         //sgbutton.sg.translate[1] -= 16
      }
   }

   return 0
}

@(private="file")
sgbutton_draw :: proc(sgbutton: ^SGButton)
{
   if sgbutton.flags.style == 0
   {
      bounds: Rect = sgbutton.bounds
      scale: i32 = get_scale()
      draw_rectangle_fill(sgbutton, {bounds.min + scale, bounds.max - scale}, {90, 90, 90, 255})
      draw_rectangle(sgbutton, bounds, {0, 0, 0, 255})

      if sgbutton.state
      {
         draw_rectangle_fill(sgbutton, {{bounds.min[0] + scale, bounds.min[1] + 2 * scale},
            {bounds.min[0] + 2 * scale, bounds.max[1] - 2 * scale}}, {0, 0, 0, 255})
         draw_rectangle_fill(sgbutton, {{bounds.min[0] + scale, bounds.max[1] - 2 * scale},
            {bounds.max[0] - 2 * scale, bounds.max[1] - scale}}, {0, 0, 0, 255})
         draw_rectangle_fill(sgbutton, {{bounds.max[0] - 2 * scale, bounds.min[1] + 2 * scale},
            {bounds.max[0] - scale, bounds.max[1] - 2 * scale}}, {50, 50, 50, 255})
         draw_rectangle_fill(sgbutton, {{bounds.min[0] + 2 * scale, bounds.min[1] + scale},
            {bounds.max[0] - scale, bounds.min[1] + 2 * scale}}, {50, 50, 50, 255})
      }
      else
      {
         draw_rectangle_fill(sgbutton, {{bounds.min[0] + scale, bounds.min[1] + 2 * scale},
            {bounds.min[0] + 2 * scale, bounds.max[1] - 2 * scale}}, {50, 50, 50, 255})
         draw_rectangle_fill(sgbutton, {{bounds.min[0] + scale, bounds.max[1] - 2 * scale},
            {bounds.max[0] - 2 * scale, bounds.max[1] - scale}}, {50, 50, 50, 255})
         draw_rectangle_fill(sgbutton, {{bounds.max[0] - 2 * scale, bounds.min[1] + 2 * scale},
            {bounds.max[0] - scale, bounds.max[1] - 2 * scale}}, {200, 200, 200, 255})
         draw_rectangle_fill(sgbutton, {{bounds.min[0] + 2 * scale, bounds.min[1] + scale},
            {bounds.max[0] - scale, bounds.min[1] + 2 * scale}}, {200, 200, 200, 255})
      }

      if sgbutton.up do draw_label(sgbutton, sgbutton.bounds, "\x1e", {0, 0, 0, 255}, true)
      else do draw_label(sgbutton, sgbutton.bounds, "\x1f", {0, 0, 0, 255}, true)
   }
}

@(private="file")
sgbar_create :: proc(parent: ^Element, flags: ElementFlags) -> ^SGBar
{
   prof.SCOPED_EVENT(#procedure)

   sgbar: ^SGBar = &element_create(SGBar, parent, flags, sgbar_msg).derived.(SGBar)

   return sgbar
}


@(private="file")
sgbar_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   sgbar: ^SGBar = &e.derived.(SGBar)

   if msg == .GET_WIDTH
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      return i64(max(space[0], sgbar.size_min[0]))
   }
   else if msg == .GET_HEIGHT
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      return i64(max(space[0], sgbar.size_min[1]))
   }
   else if msg == .DRAW
   {
      ///sgbar_draw(sgbar)
      //fmt.printf("%v\n", sgbar.sg.size_children)
      draw_rectangle_fill(sgbar, sgbar.bounds, {90, 90, 90, 255})
      draw_rectangle(sgbar, sgbar.bounds, {0, 0, 0, 255})

      // Bar
      if sgbar.sg.size_children[1] > 0
      {
         progress: f64 = f64(-sgbar.sg.translate[1]) / f64(sgbar.sg.size_children[1] - 
                      (sgbar.sg.bounds.max[1] - sgbar.sg.bounds.min[1]))

         //fmt.printf("%v\n", progress)
         height: i32 = sgbar.bounds.max[1] - sgbar.bounds.min[1] - 16 * get_scale()
         y: i32 = i32(progress * f64(height))
         draw_rectangle(sgbar, {{sgbar.bounds.min[0], sgbar.bounds.min[1] + y},
            {sgbar.bounds.max[0], sgbar.bounds.min[1] + y + 16 * get_scale()}}, {0, 0, 0, 255})
      }
   }
   else if msg == .MOUSE
   {
   }

   return 0
}

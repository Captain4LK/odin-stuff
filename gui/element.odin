package gui

import "core:log"
import "core:fmt"
import "vendor:sdl3"

import "../prof"

@(private="file")
id_next: u64 = 0

element_create :: proc($T: typeid, parent: ^Element, flags: ElementFlags, msg_base: MsgHandler) -> ^Element
{
   prof.SCOPED_EVENT(#procedure)

   t := new(T)
   t.derived = t^
   t.flags = flags
   t.msg_base = msg_base
   t.id = id_next
   id_next += 1

   if parent != nil
   {
      t.window = parent.window

      if !t.flags.no_parent
      {
         t.parent = parent
         append(&parent.children, t)
      }

      if parent.flags.overlay
      {
         t.flags.overlay = true
      }
   }

   return t
}

element_msg_direct :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if e == nil do return 0
   if e.flags.destroy && msg != .DESTROY do return 0

   if msg == .DRAW && e.flags.invisible do return 0
   if e.window.blocking != nil && (msg < .NO_BLOCK_START || msg > .NO_BLOCK_END) do return 0

   if e.msg_user != nil
   {
      res: i64 = e.msg_user(e, msg, di, dp)
      if res != 0 do return res
   }

   if e.msg_base != nil do return e.msg_base(e, msg, di, dp)

   return 0
}

element_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if e == nil do return 0
   if e.flags.destroy && msg != .DESTROY do return 0

   if element_ignored(e)
   {
      #partial switch msg
      {
      case .MOUSE: return 0
      case .MOUSE_LEAVE: return 0
      case .DRAW: return 0
      case .GET_WIDTH: return 0
      case .GET_HEIGHT: return 0
      case .GET_CHILD_PAD: return 0
      }
   }

   if msg == .DRAW && e.flags.invisible do return 0
   if e.window.blocking != nil && (msg < .NO_BLOCK_START || msg > .NO_BLOCK_END) do return 0

   if e.msg_user != nil
   {
      res: i64 = e.msg_user(e, msg, di, dp)
      if res != 0 do return res
   }

   if e.msg_base != nil do return e.msg_base(e, msg, di, dp)

   return 0
}

element_msg_all :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if e == nil do return 0
   if e.flags.destroy && msg != .DESTROY do return 0
   if element_ignored(e) do return 0
   if e.flags.invisible && msg == .DRAW do return 0

   for child in e.children
   {
      element_msg_all(child, msg, di, dp)
   }

   element_msg(e, msg, di, dp)

   return 0
}

element_redraw :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   if e.flags.overlay || e.flags.no_parent
   {
      element_redraw_now(e)
      return
   }

   e.window.redraw = true
   //e.needs_redraw = true
   //append(&e.window.redraw, e)
}

@(private="file")
element_redraw_now :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   if e.flags.overlay
   {
      res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, e.window.sdl_overlay)
      if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
   }
   else
   {
      res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, e.window.sdl_target)
      if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
   }

   //fmt.printf("Draw\n")
   if !element_ignored(e)
   {
      element_redraw_intern(e)
   }

   res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, nil)
   if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

   res = sdl3.RenderClear(e.window.sdl_renderer)
   if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

   res = sdl3.RenderTexture(e.window.sdl_renderer, e.window.sdl_target, nil, nil)
   if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

   res = sdl3.RenderTexture(e.window.sdl_renderer, e.window.sdl_overlay, nil, nil)
   if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

   sdl3.RenderPresent(e.window.sdl_renderer)
}

element_redraw_msg :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   e.window.clip = {{-1, -1}, {-1, -1}}
   e.window.translation = {0, 0}
   draw_disable_clip(e)

   if !element_ignored(e)
   {
      element_redraw_intern(e)
   }
}

element_by_point :: proc(e: ^Element, pt: [2]f32) -> ^Element
{
   prof.SCOPED_EVENT(#procedure)

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

   e.window.translation = old_trans
   
   return nil
}

element_set_invisible :: proc(e: ^Element, invisible: bool)
{
   prof.SCOPED_EVENT(#procedure)

   e.flags.invisible = invisible

   for i := 0; i < len(e.children); i += 1
   {
      element_set_invisible(e.children[i], invisible)
   }
}

element_ignored :: proc(e: ^Element) -> bool
{
   prof.SCOPED_EVENT(#procedure)

   if e == nil do return false
   if e.flags.ignore do return true

   current: ^Element = e.parent
   for current != nil
   {
      if current.flags.ignore do return true
      current = current.parent
   }

   return false
   //return element_ignored(e.parent)
}

element_destroy :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   for i := 0; i < len(e.children); i += 1
   {
      element_destroy(e.children[i])
   }

   element_msg(e, .DESTROY, 0, nil)
   if e.timer != 0
   {
      res: bool = sdl3.RemoveTimer(e.timer)
      if !res do log.errorf("RemoveTimer failed: %v", sdl3.GetError())
   }
   delete(e.children)
   free(e)
}

element_timer :: proc(e: ^Element, interval: u64)
{
   prof.SCOPED_EVENT(#procedure)

   if e.timer != 0
   {
      res: bool = sdl3.RemoveTimer(e.timer)
      if !res do log.errorf("RemoveTimer failed: %v", sdl3.GetError())
      e.timer = 0
   }

   e.timer_interval = interval
   e.timer = sdl3.AddTimerNS(interval, timer_callback, e)
}

@(private="file")
element_redraw_intern :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   if e.flags.invisible || e.flags.ignore do return

   element_msg(e, .DRAW, 0, nil)

   old_clip: Rect = e.window.clip
   if e.flags.clip
   {
      draw_set_clip_rect(e, e.bounds)
      e.window.clip = e.bounds
   }

   old_trans: [2]i32 = e.window.translation
   e.window.translation += e.translate

   for i := 0; i < len(e.children); i += 1
   {
      element_redraw_intern(e.children[i])
   }

   if e.flags.clip
   {
      if old_clip == {{-1, -1}, {-1, -1}}
      {
         draw_disable_clip(e)
      }
      else
      {
         draw_set_clip_rect(e, old_clip)
         e.window.clip = old_clip
      }
   }

   e.window.translation = old_trans
}


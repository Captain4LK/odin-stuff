package main

import "base:runtime"

import "../gui"
import "../prof"

import "core:log"

main :: proc()
{
   prof.init()
   defer prof.destroy()

   prof.SCOPED_EVENT(#procedure)

   context.logger = log.create_console_logger()

   res: bool = gui.init()
   gui_construct()
   
   gui_load_preset("default.json")

   gui.msg_loop()
}

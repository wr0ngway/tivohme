# HME for Ruby
#
# An implementation of TiVo's HME ("Home Media Extensions") Protocol
# for Ruby. This is based on the protocol specification, but it is
# not a port of the Java SDK, and it does things somewhat differently.
# (Starting from the spec, I did end up with a lot of similarities to
# the SDK, and I then tweaked this module to bring them closer, in
# some respects; but there are still a lot of differences.)
#
# Basic usage: import hme (or "from hme import *"); subclass the
# "Application" class; and override some of the stub functions that
# appear at the end of this file. If you want to use it with the
# included start.py, then your program should be in the form of a
# module (see the included examples). Aside from the app class, you
# may want to include TITLE and/or CLASS_NAME strings; TITLE is the
# display title, and CLASS_NAME is the name of your main app class.
# (Both will be derived from the module name if absent.)
#
# startup() is called first, before any events are handled; then the
# event loop runs until either it's out of events (i.e. the socket
# closed), or you set self.active to False. Finally, cleanup() is
# called.
#
# Items not yet implemented from the spec:
# * Event pushing other than key presses
#
# Java SDK items not in the spec and not implemented here:
# * Persistent data -- you can get the tsn and Cookie from
#   self.context.headers, if using start.py, but what you do with
#   them is outside the scope of this module
# * Numerous specific methods -- but some of these are unneeded; e.g.,
#   set_bounds() substitutes for setLocation() as well as setBounds()
module TivoHME

  # Characters for codes returned by QWERTY input
  QWERTY_MAP = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ-=[]\;\',./` '

  # Take the rawcode from a type 1 (KEY_UNKNOWN) direct text key
  # event, and return the ASCII equivalent, or "?" on error.
  def self.qwerty_map(rawcode)
    begin
      key = QWERTY_MAP[((rawcode & 0xff00) >> 8) - 0x3c]
    except
      key = '?'
    end
    return key
  end

end

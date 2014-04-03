# Unlike the hme module, this is a straight port of the version in
# TiVo's Java SDK. (I've even kept the original comments.) As such, it's
# a derivative work, released under the Common Public License.
#
# Original version credited authors: Adam Doppelt, Arthur van Hoff,
# Brigham Stevens, Jonathan Payne, Steven Samorodin
# Copyright 2004, 2005 TiVo Inc.
#
# Python version: William McBrine, 2008-2012
# Ruby Version: Matt Conway


# This sample illustrates animation in a separate thread.

class Clock < TivoHME::Application

  def startup
    root.set_color()
    @time_views = 2.times.collect {|i| TivoHME::View.new(self, xpos: 0, ypos: 100, height: 280) }

    TivoHME::Font.new(self, size: 96, style: FONT_BOLD)
    Color.new(self, 0)

    # start a separate thread to update the time
    Thread.new do
      begin
        self.update
      rescue => e
        logger.error("Failed to update clock: #{e}")
      end
    end
  end


  def handle_key_press(keynum, index)
    if [KEY_LEFT, KEY_CLEAR, KEY_PAUSE].include?(keynum)
      sound('left')
      self.active = false
    end
  end

  def update
    fade = TivoHME::Animation.new(self, 0.75)
    tm = Time.now
    n = 0

    while self.active
      # fade out the old time
      @time_views[n].set_transparency(1, animation: fade)

      # switch to the other view
      n = (n + 1) % 2

      # show the current time
      @time_views[n].set_text(Time.now.strftime("%H:%M:%S"))
      @time_views[n].set_transparency(0, animation: fade)

      # now sleep
      tm += 1
      self.sleep(tm - Time.now)
    end
  end
end
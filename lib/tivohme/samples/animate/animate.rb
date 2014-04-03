# Unlike the hme module, this is a straight port of the version in
# TiVo's Java SDK. (I've even kept the original comments.) As such, it's
# a derivative work, released under the Common Public License.
#
# Original version credited authors: Adam Doppelt, Arthur van Hoff,
# Brigham Stevens, Jonathan Payne, Steven Samorodin
# Copyright 2004, 2005 TiVo Inc.
#
# python version: William McBrine, 2008-2012
# ruby version: Matt Conway

require 'tivohme'

# A simple demonstration of how to perform animations with View classes.
# This sample shows how to use Application.send_key() to receive a
# notification when the animation request has completed.
class Animate < ::TivoHME::Application

  def handle_device_info(info)
    ver = info.fetch('version', '')
    if ['9.1', '9.3'].include?(ver[0,3]) and not ['648', '652'].include?(ver[-3,3])
        root.set_text('Sorry, this program is not compatible\n' +
                           'with this TiVo software/hardware version.')
        self.sleep(5)
        self.active = false
        return
    end

    # create a container view that will hold everything else, sized
    # to the safe action bounds.
    content = TivoHME::View.new(self,
                                xpos: SAFE_ACTION_H / 2, ypos: SAFE_ACTION_V / 2,
                                width: root.width - SAFE_ACTION_H,
                                height: root.height - SAFE_ACTION_V)

    # create the set of animated squares
    @sprites = 16.times.collect do |i|
      SpriteView.new(content, i,
                     rand(content.width),
                     rand(content.height),
                     rand(8...72),
                     rand(8...72))
    end

  end

  # Listen for our special "animation ended" event.
  def handle_key_press(keynum, index)
    if keynum == KEY_TIVO
        @sprites[index].animate()
    elsif [KEY_LEFT, KEY_CLEAR, KEY_PAUSE].include?(keynum)
        sound('left')
        self.active = false
    end
  end

  # If this ain't a screensaver, I don't know what is. -- wmcbrine
  def handle_idle(idle)
    return true
  end

end


class SpriteView < TivoHME::View

  def initialize(parent, index, x, y, width, height)
    super(parent.app, xpos: x, ypos: y, width: width, height: height, parent: parent)

    @index = index
    set_color(rand(0xffffff))

    # start animating
    animate()
  end

  # Move the sprite and send an event when we're done.
  def animate
    # Use a step of 50ms to cut down on the number of resources
    # created. -- wmcbrine
    speed = rand(5...105) * 50 / 1000.0

    dest_x = rand(parent.width)
    dest_y = rand(parent.height)
    set_bounds(xpos: dest_x, ypos: dest_y, animtime: speed)

    # send a special event
    app.send_key(KEY_TIVO, @index, animtime: speed)
  end
end

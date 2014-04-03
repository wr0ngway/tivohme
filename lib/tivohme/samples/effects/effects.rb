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

# Illustrates animation effects with ease on Views.
#
# When changing many properties of a view the change can be animated
# instead of instant, with the change happening incrementally over a
# specified period.
#
# The reciever will perform the animation with linear interpolation
# when ease is set to 0 (or no ease at all). Adjusting the ease allows
# you to animate with acceleration and deceleration.
#
# This sample shows how to use animation when changing the following
# properties of a view:
#
# bounds
# translate
# transparency
# scale
# visible
# translation
# remove from parent view

class Effects < TivoHME::Application

  def handle_device_info(info)

    ver = info.fetch('version', '')
    if ['9.1', '9.3'].include?(ver[0,3]) and not ['648', '652'].include?(ver[-3,3])
      root.set_text('Sorry, this program is not compatible\n' +
                         'with this TiVo software/hardware version.')
      self.sleep(5)
      self.active = false
      return
    end

    # Prepare our view & container
    root.set_color()

    TivoHME::Font.new(self, size: 17)

    # Container for everything inset to title-safe
    @content = TivoHME::View.new(self,
                                 xpos: SAFE_TITLE_H, ypos: SAFE_TITLE_V,
                                 width: root.width - SAFE_TITLE_H * 2,
                                 height: root.height - SAFE_TITLE_V * 2)

    # The current ease value
    @ease = 0

    # Animation time
    @anim_time = 1

    # Create the views for each demonstration -- each view is used
    # for demonstrating a different property.

    # Displays the current ease value
    @ease_text = @content.child(xpos: 300, ypos: 0, width: 190, height: 20)

    # Displays current animation animTime
    @time_text = @content.child(xpos: 300, ypos: 20, width: 190, height: 20)

    @transparency = Square.new(@content, 0, 0, 90, 90, 'Transparency')
    @visible = Square.new(@content, 100, 0, 90, 90, 'Visible')
    @bounds = Square.new(@content, 300, 100, 90, 90, 'Bounds')
    @translate = @content.child(xpos: 0, ypos: 100, width: 290, height: 90)
    Square.new(@translate, -300, 0, 600, 90, '', TivoHME::Color.new(self, 0x00ff00))
    Square.new(@translate, 0, 0, 90, 90, 'Translate')
    @scale = Square.new(@content, 0, 200, 90, 90, 'Scale')

    # Kick off the thread to update the effects animation
    Thread.new do
      begin
        update()
      rescue => e
        logger.error("Exception in update thread:: [#{e.class.name}] #{e.message}")
        logger.error(e.backtrace.join("\n")) if e.backtrace
      end
    end
  end

  # Arrow keys control the ease.  The animation resource is updated
  # with the new ease. The value of ease and animTime are updated on
  # screen, but since the settings don't take effect until the current
  # animation ends they are displayed in Red.
  def handle_key_press(code, rawcode)
    deltaD = 0
    deltaE = 0

    if code == KEY_UP
      deltaD = 0.25
    elsif code == KEY_DOWN
      deltaD = -0.25
    elsif code == KEY_RIGHT
      deltaE = 0.1
    elsif code == KEY_LEFT
      deltaE = -0.1
    elsif [KEY_CLEAR, KEY_PAUSE].include?(code)
      sound('left')
      self.active = false
    end

    if deltaD || deltaE
      @ease = [[@ease + deltaE, 1.0].min, -1.0].max
      @anim_time = [[@anim_time + deltaD, 9.75].min, 1.0].max
      show_settings(0xff0000)
    end
  end

  # Update the demo view animations and sleep until they are finished.
  # Then reverse the animations and do it again.
  def update
    parity = false
    while self.active
      parity = ! parity

      # Create the animation resource from current settings. This
      # method of creating the resource is the most efficient
      # because the receiver will use a cached resource if it has
      # one already.
      anim = TivoHME::Animation.new(self, @anim_time, ease: @ease)

      # Update the animations for each property, alternating. All
      # of these animations use the shared animation resource.
      @transparency.set_transparency((parity ? 1 : 0), animation: anim)
      @visible.set_visible(!parity, animation: anim)
      @translate.set_translation(200 * (parity ? 1 : 0), 0, animation: anim)
      if parity
        newscale = 1.5
      else
        newscale = 1
      end
      @scale.set_scale(newscale, newscale, animation: anim)

      if parity
        # add and remove this square in the future specified by
        # the animation
        Square.new(@content, 200, 0, 90, 90, 'Remove').remove(animation: anim)
        @bounds.set_bounds(xpos: 300, ypos: 150, width: 190, height: 190, animation: anim)
      else
        @bounds.set_bounds(xpos: 300, ypos: 100, width: 90, height: 90, animation: anim)
      end

      # Display the current animTime & ease in black to indicate
      # it has taken effect.
      show_settings(0)
      sleep(@anim_time)
    end
  end

  # Display the value of the ease and animTime in the given color.

  def show_settings(color)
    TivoHME::Color.new(self, color)
    @ease_text.set_text('Ease (use left/right) : %.1f' % @ease,
                        flags: RSRC_HALIGN_LEFT)
    @time_text.set_text('Time (use up/down) : %.2f' % @anim_time,
                        flags: RSRC_HALIGN_LEFT)
  end

end


# This class handles the animated squares with text.
class Square < TivoHME::View

  def initialize(parent, x, y, w, h, title='', bg=nil)
    super(parent.app, xpos: x, ypos: y, width: w, height: h, parent: parent)
    if bg.nil?
      bg = TivoHME::Color.new(self.app, 0xff00ff)  # magenta
    end
    set_resource(bg)
    @label = child()
    if title
      @label.set_text(title, color: TivoHME::Color.new(self.app))
    end
  end

end

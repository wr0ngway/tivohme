# This one is NOT ported from the Java SDK. But portions are based on my 
# Photo module for pyTivo.

require 'mini_magick'
require 'tivohme'
include TivoHME

TITLE = 'Picture Viewer'

PICTURES_PATH = File.expand_path(ENV['PICTURE_PATH'] || "~/pictures")
GOOD_EXTS = ['.jpg', '.gif', '.png', '.bmp', '.tif', '.xbm', '.xpm', 
            '.pgm', '.pbm', '.ppm', '.pcx', '.tga', '.fpx', '.ico', 
            '.pcd', '.jpeg', '.tiff']
DELAY = (ENV['DELAY'] || 5).to_f

# Simple slideshow picture viewer. Automatically uses high-def mode
# when available and appropriate, based on the TiVo's notion of the
# optimal resolution. Requires the Python Imaging Library. Loops
# forever, but any key breaks the loop (Play restarts it); Fast
# Forward and Rewind allow simple manual navigation.

class Picture < Application

  attr_accessor :files, :old, :count, :in_slideshow

  # Choose the 'optimal' resolution.
  def handle_resolution()
    return self.resolutions[0]
  end

  # Build the list of pictures, and start the slideshow.
  def handle_active()

    if ! File.directory?(PICTURES_PATH)
      self.root.set_text('Path not found: ' + PICTURES_PATH)
      self.sleep(5)
      self.active = false
      return
    end


    self.files = []
    Dir["#{PICTURES_PATH}/**/*"].each do |file|
      self.files << file if GOOD_EXTS.include?(File.extname(file))
    end

    if self.files.size == 0
      self.root.set_text('No pictures found!')
      self.sleep(5)
      self.active = false
      return
    end

    self.files.shuffle!

    self.old = nil
    self.count = -1
    self.start_slideshow()
  end

  # Handle a real keypress OR the pseudo-key that's sent five
  # seconds after the last slide.
  def handle_key_press(code, rawcode)
    if code == KEY_TIVO and self.in_slideshow
      self.next_slide()
    elsif code == KEY_PLAY
      if self.in_slideshow
        self.exit_slideshow()
      else
        self.sound('select')
        self.start_slideshow()
      end
    elsif [KEY_LEFT, KEY_CLEAR].include?(code)
      self.sound('left')
      self.active = false
    else
      if self.in_slideshow
        self.exit_slideshow()
      end
      if code == KEY_FORWARD
        self.sound('right')
        self.newpic(1)
      elsif code == KEY_REVERSE
        self.sound('left')
        self.newpic(-1)
      end
    end
  end

  def handle_idle(idle)
    if idle
      # If entering idle mode during a slideshow, ignore it;
      # if on a still frame, exit the app...
      return self.in_slideshow
    else
      # ...but we can always handle exiting idle mode.
      return true
    end
  end

  def handle_error(code, text)
    logger.error("[#{code}] #{text}")
    self.active = false
  end

  # Re-encode the picture at self.count to fit the screen
  def makepic()
    width, height, pixw, pixh = self.current_resolution
    width -= SAFE_TITLE_H
    height -= SAFE_TITLE_V

    pic = MiniMagick::Image.open(self.files[self.count])
    pic.resize("#{width}X#{height}")
    pic.format("jpg")
    return pic.to_blob
  end

  # Show the next (or previous) pic from self.files. """
  def newpic(direction)
    new = self.root.child()

    # Loop until a valid picture is found
    encoded = nil
    while true
      self.count += direction
      self.count %= self.files.size
      begin
        encoded = self.makepic()
        break
      rescue => e
        logger.error "Skipping #{self.files[self.count]}: #{e}"
      end
    end

    # Fade in the new pic
    new.set_transparency(1)
    new.set_image(data: encoded)
    new.set_transparency(0, animtime: 0.5)

    # Fade out the old
    if self.old
      self.old.set_transparency(1, animtime: 0.5)
      self.old.remove(animtime: 0.5)
      self.sleep(0.75)
      self.old.resource.remove()
    end
    self.old = new
  end

  def start_slideshow
    self.in_slideshow = true
    self.next_slide()
  end

  def next_slide
    self.newpic(1)
    self.send_key(KEY_TIVO, animtime: DELAY)
  end

  def exit_slideshow
    self.sound('slowdown1')
    self.in_slideshow = false
  end

end


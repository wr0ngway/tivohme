module TivoHME

  # Low-level stream handling
  # Take raw event data and allow various Ruby types to be
  # extracted from it.
  class EventData
    include GemLogger::LoggerSupport

    attr_accessor :index

    def initialize(data)
      logger.debug { "Received event data: [#{data.length}] #{data.unpack('H*').first}" }
      @data = data
      @index = 0
    end

    def next_char
      c = @data[@index].ord
      @index += 1
      return c
    end

    # HME boolean to bool
    def unpack_bool
      return next_char > 0
    end

    # HME variable-length integer to int
    def unpack_vint
      value = 0
      shift = 0
      while true
        c = next_char
        if (c & 0x80) != 0
          break
        end
        value += c << shift
        shift += 7
      end
      value += (c & 0x3f) << shift
      if (c & 0x40) != 0
        value = -value
      end
      return value
    end

    # HME variable-length unsigned integer to int
    def unpack_vuint
      value = 0
      shift = 0
      while true
        c = next_char
        if (c & 0x80) != 0
          break
        end
        value += c << shift
        shift += 7
      end
      value += (c & 0x7f) << shift
      return value
    end

    # HME float to float
    def unpack_float
      value = @data[@index...(@index + 4)].unpack('g')[0]
      @index += 4
      return value
    end

    # HME variable-length data to str
    def unpack_vdata
      length = unpack_vuint()
      result = @data[@index...(@index + length)]
      @index += length
      return result
    end

    # HME string to unicode
    def unpack_string
      return unpack_vdata().encode('utf-8')
    end

    # HME dict to dict (each value may be a list)
    # Note that the HME dict type is referred to, but not
    # documented, in the HME protocol specification.
    def unpack_dict
      d = {}
      while true
        key = unpack_string()
        if not key
          break
        end
        value = []
        while true
          c = next_char
          if not c
            break
          end
          if c == 1
            value.append(unpack_string())
          else
            value.append(unpack_dict())
          end
        end
        if value.length == 1
          value = value[0]
        end
        d[key] = value
      end
      return d
    end

    # Unpack a list of types, based on a format string
    def unpack(format)
      func = {
          'b' => :unpack_bool,
          'i' => :unpack_vint,
          'f' => :unpack_float,
          'v' => :unpack_vdata,
          's' => :unpack_string,
          'd' => :unpack_dict
      }
      result = format.chars.collect {|f| send(func[f]) }
      return result
    end


    class << self

      # bool to HME boolean
      def pack_bool(value)
        return value ? 1.chr : 0.chr
      end

      # int to HME variable-length integer
      def pack_vint(value)
        value = value.to_i
        result = ''
        is_neg = value < 0
        if is_neg
          value = -value
        end
        while value > 0x3f
          result += (value & 0x7f).chr
          value >>= 7
        end
        if is_neg
          value |= 0x40
        end
        result += (value | 0x80).chr
        return result
      end

      # int to HME variable-length unsigned integer
      def pack_vuint(value)
        value = value.to_i
        result = ''
        while value > 0x7f
          result += (value & 0x7f).chr
          value >>= 7
        end
        result += (value | 0x80).chr
        return result
      end

      # float to HME float
      def pack_float(value)
        return [value.to_f].pack('g')
      end

      # str to HME variable-length data
      def pack_vdata(value)
        return pack_vuint(value.size) + value
      end

      # unicode to HME string
      def pack_string(value)
        value = value.to_s
        value = value.encode('utf-8').force_encoding('ASCII-8BIT')
        return pack_vdata(value)
      end

      # dict(of lists) to HME dict
      def pack_dict(value)
        result = ''
        if ! value.is_a? Hash
          raise 'must be a hash'
        end

        # The keys must be sorted, or the TiVo ignores the transition.
        keys = value.keys()
        keys.sort()
        keys.each do |key|
          result += pack_string(key)
          items = value[key]
          items = Array(items)
          items.each do |item|
            if item.is_a? Hash
              result += 2.chr
              result += pack_dict(item)
            else
              result += 1.chr
              result += pack_string(item)
            end
          end
          result += 0.chr
        end
        result += pack_string('')
        return result
      end

      # Return the data as-is
      def pack_raw(value)
        return value
      end

      # Pack a list of types, based on a format string
      def pack(format, *values)
        func = {
            'b' => :pack_bool,
            'i' => :pack_vint,
            'f' => :pack_float,
            'v' => :pack_vdata,
            's' => :pack_string,
            'd' => :pack_dict,
            'r' => :pack_raw
        }
        result = format.chars.zip(values).collect {|f, v| send(func[f], v) }
        return result.join('')
      end

      # Read HME-style chunked event data from the input stream
      def get_chunked(stream)
        logger.debug { "Getting chunked data" }
        data = ''
        while true
          # Get the next chunk length
          begin
            length = stream.read(2).unpack('n')[0]
            logger.debug { "Read chunk length: #{length}" }
          rescue => e
            logger.debug { "Failed reading chunk length: #{e}" }
            data = nil
            break
          end

          # A zero-length chunk marks the end_ of the event
          if length.nil? || length <= 0
            break
          end

          # Otherwise, append the new chunk
          begin
            data += stream.read(length)
            logger.debug { "Read chunk [#{length}]: #{data.unpack('H*').first}" }
          rescue => e
            logger.debug { "Failed reading chunk [#{length}]: #{e}" }
            data = nil
            break
          end
        end
        logger.debug { "Completed getting chunked data" }
        return data
      end

      # Write HME-style chunked data to the output stream
      def put_chunked(stream, data)
        logger.debug { "Putting chunked data: [#{data.length}] #{data.unpack('H*').first}" }
        maxsize = 0xfffe
        size = data.length
        index = 0
        while size > 0
          blocksize = [size, maxsize].min
          begin
            packed_bs = [blocksize].pack('n')
            logger.debug { "Putting chunked blocksize: #{blocksize} -> #{packed_bs.unpack('H*').first}" }
            stream.write(packed_bs)
            packed_data = data[index ... (index + blocksize)]
            logger.debug { "Putting chunked data: #{index}...#{index + blocksize}[#{packed_data.size}] -> #{packed_data.unpack('H*').first}" }
            stream.write(packed_data)
          rescue => e
            logger.debug { "Failed writing chunk [#{blocksize}]: #{e}" }
            return
          end
          index += blocksize
          size -= blocksize
        end

        begin
          stream.write("\0\0")
        rescue => e
          logger.debug {"Failed writing chunk terminator: #{e}"}
        end

        logger.debug { "Completed putting chunked data" }
        nil
      end

    end

  end
end

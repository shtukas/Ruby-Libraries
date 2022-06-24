
# require "/Users/pascal/Galaxy/LucilleOS/Libraries/Ruby-Libraries/Mercury.rb"
=begin
    Mercury::postValue(channel, value)
    Mercury::readFirstValueOrNull(channel)
    Mercury::dequeueFirstValueOrNull(channel)
    Mercury::isEmpty(channel)
=end

require "/Users/pascal/Galaxy/LucilleOS/Libraries/Ruby-Libraries/XCache.rb"
=begin
    XCache::set(key, value)
    XCache::getOrNull(key)
    XCache::getOrDefaultValue(key, defaultValue)
    XCache::destroy(key)

    XCache::setFlag(key, flag)
    XCache::getFlag(key)

    XCache::filepath(key)
=end

require 'securerandom'
# SecureRandom.hex    #=> "eb693ec8252cd630102fd0d0fb7c3485"
# SecureRandom.hex(4) #=> "eb693123"
# SecureRandom.uuid   #=> "2d931510-d99f-494a-8c67-87feb05e1594"

class Mercury

    # Here we have a relatively inefficient implementation of a FIFO queue, but it will do 🙂

    # ------------------------------------------------------
    # Private

    # Mercury::getChannelFirstAvailableIndex(channel)
    def self.getChannelFirstAvailableIndex(channel)
        indx = 0
        loop {
            return indx if XCache::getOrNull("#{channel}:#{indx}").nil?
            indx = indx + 1
        }
    end

    # Mercury::cascadeChannelDown(channel)
    def self.cascadeChannelDown(channel)
        indx = 0
        loop {
            vx = XCache::getOrNull("#{channel}:#{indx+1}")
            if vx then
                XCache::set("#{channel}:#{indx}", vx)
            else
                XCache::destroy("#{channel}:#{indx}")
                break
            end
            indx = indx + 1
        }
    end

    # ------------------------------------------------------
    # Public Interface

    # Mercury::postValue(channel, value)
    def self.postValue(channel, value)
        indx = Mercury::getChannelFirstAvailableIndex(channel)
        XCache::set("#{channel}:#{indx}", JSON.generate([value]))
    end

    # Mercury::dequeueFirstValueOrNull(channel)
    def self.dequeueFirstValueOrNull(channel)
        value = XCache::getOrNull("#{channel}:#{0}")
        return nil if value.nil?
        Mercury::cascadeChannelDown(channel)
        JSON.parse(value)[0]
    end

    # Mercury::readFirstValueOrNull(channel)
    def self.readFirstValueOrNull(channel)
        value = XCache::getOrNull("#{channel}:#{0}")
        return nil if value.nil?
        JSON.parse(value)[0]
    end

    # Mercury::isEmpty(channel)
    def self.isEmpty(channel)
        XCache::getOrNull("#{channel}:#{0}").nil?
    end
end


# require "/Users/pascal/Galaxy/LucilleOS/Libraries/Ruby-Libraries/XCacheSets.rb"
=begin
    XCacheSets::values(setuuid: String): Array[Value]
    XCacheSets::set(setuuid: String, valueuuid: String, value)
    XCacheSets::getOrNull(setuuid: String, valueuuid: String): nil | Value
    XCacheSets::destroy(setuuid: String, valueuuid: String)
=end

# ---------------------------------------------------------------------------------------------

require 'json'

require 'digest/sha1'
# Digest::SHA1.hexdigest 'foo'
# Digest::SHA1.file(myFile).hexdigest

require 'securerandom'
# SecureRandom.hex    #=> "eb693ec8252cd630102fd0d0fb7c3485"
# SecureRandom.hex(4) #=> "1ac4eb69"
# SecureRandom.uuid   #=> "2d931510-d99f-494a-8c67-87feb05e1594"

require "/Users/pascal/Galaxy/LucilleOS/Libraries/Ruby-Libraries/XCache.rb"
=begin
    XCache::setFlagTrue(key)
    XCache::setFlagFalse(key)
    XCache::flagIsTrue(key)

    XCache::set(value)
    XCache::getOrNull(key)
    XCache::getOrDefaultValue(key, defaultValue)
    XCache::destroy(key)
=end

# ---------------------------------------------------------------------------------------------

=begin

The setuuid points at the root node located at "7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:#{root}"

nodes are 
{
    "valueuuid" 
    "value"     : value or null
    "left"      : xcache id of left or null
    "right"     : xcache id of right or null
}

=end

class XCacheSets

    # XCacheSets::values(setuuid)
    def self.values(setuuid)
        uuids = JSON.parse(XCache::getOrDefaultValue("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:uuids", "[]"))
        uuids.map{|valueuuid| XCacheSets::getOrNull(setuuid, valueuuid) }.compact
    end

    # XCacheSets::set(setuuid, valueuuid, value)
    def self.set(setuuid, valueuuid, value)
        XCache::set("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:value:#{valueuuid}", JSON.generate([value]))
        uuids = JSON.parse(XCache::getOrDefaultValue("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:uuids", "[]"))
        if !uuids.include?(valueuuid) then
            uuids << valueuuid
            XCache::set("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:uuids", JSON.generate(uuids))
        end
    end

    # XCacheSets::getOrNull(setuuid, valueuuid)
    def self.getOrNull(setuuid, valueuuid)
        packet = XCache::getOrNull("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:value:#{valueuuid}")
        packet ? JSON.parse(packet)[0] : nil
    end

    # XCacheSets::destroy(setuuid, valueuuid)
    def self.destroy(setuuid, valueuuid) 
        uuids = JSON.parse(XCache::getOrDefaultValue("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:uuids", "[]"))
        uuids.delete(valueuuid)
        XCache::set("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:uuids", JSON.generate(uuids))
        XCache::destroy("7b20d6d2-38c1-4cd7-89af-92b13907396d:#{setuuid}:value:#{valueuuid}")
    end
end

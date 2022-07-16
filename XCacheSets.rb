
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
    XCache::set(key, value)
    XCache::getOrNull(key)
    XCache::getOrDefaultValue(key, defaultValue)
    XCache::destroy(key)

    XCache::setFlag(key, flag)
    XCache::getFlag(key)

    XCache::filepath(key)
=end

# ---------------------------------------------------------------------------------------------

=begin

create table _set_ (_valueuuid_ text primary key, _value_ text);

We JSON encode the vsalues

=end

class XCacheSets

    # XCacheSets::databaseFileInXCache(setuuid)
    def self.databaseFileInXCache(setuuid)
        XCache::filepath(setuuid)
    end

    # XCacheSets::ensureDatabase(setuuid)
    def self.ensureDatabase(setuuid)
        filepath = XCacheSets::databaseFileInXCache(setuuid)
        return if File.exists?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("create table _set_ (_valueuuid_ text primary key, _value_ text);")
        db.close
    end

    # XCacheSets::values(setuuid)
    def self.values(setuuid)
        XCacheSets::ensureDatabase(setuuid)
        values = []
        db = SQLite3::Database.new(XCacheSets::databaseFileInXCache(setuuid))
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("select * from _set_", []) do |row|
            values << JSON.parse(row['_value_'])
        end
        db.close
        values
    end

    # XCacheSets::set(setuuid, valueuuid, value)
    def self.set(setuuid, valueuuid, value)
        XCacheSets::ensureDatabase(setuuid)
        db = SQLite3::Database.new(XCacheSets::databaseFileInXCache(setuuid))
        db.execute "delete from _set_ where _valueuuid_=?", [valueuuid]
        db.execute "insert into _set_ (_valueuuid_, _value_) values (?, ?)", [valueuuid, JSON.generate(value)]
        db.close
    end

    # XCacheSets::getOrNull(setuuid, valueuuid)
    def self.getOrNull(setuuid, valueuuid)
        XCacheSets::ensureDatabase(setuuid)
        value = nil
        db = SQLite3::Database.new(XCacheSets::databaseFileInXCache(setuuid))
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("select * from _set_ where _valueuuid_=?", [valueuuid]) do |row|
            value = JSON.parse(row['_value_'])
        end
        db.close
        value
    end

    # XCacheSets::destroy(setuuid, valueuuid)
    def self.destroy(setuuid, valueuuid) 
        XCacheSets::ensureDatabase(setuuid)
        db = SQLite3::Database.new(XCacheSets::databaseFileInXCache(setuuid))
        db.execute "delete from _set_ where _valueuuid_=?", [valueuuid]
        db.close
    end

    # XCacheSets::empty(setuuid)
    def self.empty(setuuid)
        XCacheSets::ensureDatabase(setuuid)
        db = SQLite3::Database.new(XCacheSets::databaseFileInXCache(setuuid))
        db.execute "delete from _set_", []
        db.close
    end
end


# require "/Users/pascal/Galaxy/LucilleOS/Libraries/Ruby-Libraries/Mercury2.rb"
=begin
    Mercury2::put(channel, value)
    Mercury2::readFirstOrNull(channel)
    Mercury2::dequeue(channel)
    Mercury2::empty?(channel)
=end

require_relative "XCache.rb"
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

class Mercury2

    # Mercury2::ensure_database(filepath)
    def self.ensure_database(filepath)
        if !File.exists?(filepath) then
            db = SQLite3::Database.new(filepath)
            db.busy_timeout = 117
            db.busy_handler { |count| true }
            db.results_as_hash = true
            db.execute "create table _data_ (_recorduuid_ text, _timestamp_ real, _object_ text);"
            db.close
        end
    end

    # Mercury2::readFirstRowOrNull(channel)
    def self.readFirstRowOrNull(channel)
        filepath = XCache::filepath(channel)
        Mercury2::ensure_database(filepath)

        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        value = nil
        db.execute("select * from _data_ order by _timestamp_ limit 1") do |row|
            value = row
        end
        db.close
        value
    end

    # ------------------------------------------------------
    # Public Interface

    # Mercury2::put(channel, value)
    def self.put(channel, value)
        filepath = XCache::filepath(channel)
        Mercury2::ensure_database(filepath)

        db = SQLite3::Database.new(filepath)
        db.execute "insert into _data_ (_recorduuid_, _timestamp_, _object_) values (?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, JSON.generate([value])]
        db.close
    end

    # Mercury2::readFirstOrNull(channel)
    def self.readFirstOrNull(channel)
        row = Mercury2::readFirstRowOrNull(channel)
        return nil if row.nil?
        JSON.parse(row['_object_'])[0]
    end

    # Mercury2::dequeue(channel)
    def self.dequeue(channel)
        row = Mercury2::readFirstRowOrNull(channel)
        return if row.nil?

        filepath = XCache::filepath(channel)
        db = SQLite3::Database.new(filepath)
        db.execute "delete from _data_ where _recorduuid_=?", [row["_recorduuid_"]]
        db.close
    end

    # Mercury2::empty?(channel)
    def self.empty?(channel)
        Mercury2::readFirstOrNull(channel).nil?
    end
end

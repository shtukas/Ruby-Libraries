# encoding: utf-8



=begin
Blades
    Blades::init(uuid)
    Blades::setAttribute(uuid, attribute_name, value)
    Blades::getAttributeOrNull(uuid, attribute_name)
    Blades::addToSet(uuid, set_id, element_id, value)
    Blades::removeFromSet(uuid, set_id, element_id)
    Blades::putDatablob(uuid, key, datablob)
    Blades::getDatablobOrNull(uuid, key)
=end


require 'fileutils'
# FileUtils.mkpath '/a/b/c'
# FileUtils.cp(src, dst)
# FileUtils.rm(path_to_image)
# FileUtils.rm_rf(dir)

require 'digest/sha1'
# Digest::SHA1.hexdigest 'foo'
# Digest::SHA1.file(myFile).hexdigest
# Digest::SHA256.hexdigest 'message'  
# Digest::SHA256.file(myFile).hexdigest

require 'json'

require 'securerandom'
# SecureRandom.hex    #=> "eb693ec8252cd630102fd0d0fb7c3485"
# SecureRandom.hex(4) #=> "eb693"
# SecureRandom.uuid   #=> "2d931510-d99f-494a-8c67-87feb05e1594"

require 'find'

# -----------------------------------------------------------------------------------

=begin

A blade is a log of events in a sqlite file.
It offers a key/value store interface and a set interface.

Each record is of the form
    (record_uuid string primary key, operation_unixtime float, operation_type string, _name_ string, _data_ blob)

Conventions:
    ----------------------------------------------------------------------------------
    | operation_name     | meaning of name                  | data conventions       |
    | "attribute"        | name of the attribute            | value is json encoded  |
    | "set-add"          | expression <set_name>/<value_id> | value is json encoded  |
    | "set-remove"       | expression <set_name>/<value_id> |                        |
    | "datablob"         | key (for instance a nhash)       | blob                   |
    ----------------------------------------------------------------------------------

reserved names:
    - uuid : unique identifier of the blade.
    - next : (optional) uuid of the next blade in the sequence

=end

class Blades

    # Blades::decide_init_location(uuid)
    def self.decide_init_location(uuid)
        # This function returns the location of a new blade (either the original blade or a next one)
        # It should be re-implemented by the code that uses this library.
        raise "Blades::decide_init_location is not implemented"
    end

    # Blades::locate_blade(uuid)
    def self.locate_blade(uuid)
        # This function takes a blade uuid and returns its location or raise an error
        # It should be re-implemented by the code that uses this library.
        raise "Blades::locate_blade"
    end

    # Blades::init(uuid)
    def self.init(uuid)
        filepath = Blades::decide_init_location(uuid)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("create table records (record_uuid string primary key, operation_unixtime float, operation_type string, _name_ string, _data_ blob)", [])
        db.close
        Blades::setAttribute(uuid, "uuid", uuid)
    end

    # Blades::setAttribute(uuid, attribute_name, value)
    def self.setAttribute(uuid, attribute_name, value)
        filepath = Blades::locate_blade(uuid)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "attribute", attribute_name, JSON.generate(value)]
        db.close
    end

    # Blades::getAttributeOrNull(uuid, attribute_name)
    def self.getAttributeOrNull(uuid, attribute_name)
        value = nil
        filepath = Blades::locate_blade(uuid)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select * from records where operation_type=? and _name_=? order by operation_unixtime", ["attribute", attribute_name]) do |row|
            value = JSON.parse(row["_data_"])
        end
        db.close
        value
    end

    # Blades::addToSet(uuid, set_id, element_id, value)
    def self.addToSet(uuid, set_id, element_id, value)
        
    end

    # Blades::removeFromSet(uuid, set_id, element_id)
    def self.removeFromSet(uuid, set_id, element_id)
        
    end

    # Blades::getSet(uuid, set_id)
    def self.getSet(uuid, set_id)

    end

    # Blades::putDatablob(uuid, key, datablob)
    def self.putDatablob(uuid, key, datablob)

    end

    # Blades::getDatablobOrNull(uuid, key)
    def self.getDatablobOrNull(uuid, key)

    end
end

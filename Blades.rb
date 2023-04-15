# encoding: utf-8

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

    # Blades::decide_init_location(blade_uuid)
    def self.decide_init_location(blade_uuid)
        # This function returns the location of a new blade (either the original blade or a next one)
        # It should be re-implemented by the code that uses this library.
        raise "Blades::decide_init_location is not implemented"
    end

    # Blades::locate_blade(blade_uuid)
    def self.locate_blade(blade_uuid)
        # This function takes a blade uuid and returns its location or raise an error
        # It should be re-implemented by the code that uses this library.
        raise "Blades::locate_blade"
    end

    # Blades::init(blade_uuid)
    def self.init(blade_uuid)
        filepath = Blades::decide_init_location(blade_uuid)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("create table records (record_uuid string primary key, operation_unixtime float, operation_type string, _name_ string, _data_ blob)", [])
        db.close
    end

    # Blades::setAttribute(blade_uuid, attribute_name, value)
    def self.setAttribute(blade_uuid, attribute_name, value)
        filepath = Blades::locate_blade(blade_uuid)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "attribute", attribute_name, JSON.generate(value)]
        db.close
    end

    # Blades::getAttributeOrNull(blade_uuid, attribute_name)
    def self.getAttributeOrNull(blade_uuid, attribute_name)
        value = nil
        filepath = Blades::locate_blade(blade_uuid)
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

    # Blades::addToSet(blade_uuid, set_id, element_id, value)
    def self.addToSet(blade_uuid, set_id, element_id, value)
        
    end

    # Blades::removeFromSet(blade_uuid, set_id, element_id)
    def self.removeFromSet(blade_uuid, set_id, element_id)
        
    end

    # Blades::getSet(blade_uuid, set_id)
    def self.getSet(blade_uuid, set_id)

    end

    # Blades::putDatablob(blade_uuid, key, datablob)
    def self.putDatablob(blade_uuid, key, datablob)

    end

    # Blades::getDatablobOrNull(blade_uuid, key)
    def self.getDatablobOrNull(blade_uuid, key)

    end
end

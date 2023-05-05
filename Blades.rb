# encoding: utf-8

=begin
Blades
    Blades::init(mikuType, uuid)
    Blades::tokenToFilepathOrNull(token)
    Blades::setAttribute(token, attribute_name, value)
    Blades::getAttributeOrNull(token, attribute_name)
    Blades::getMandatoryAttribute(token, attribute_name)
    Blades::addToSet(token, set_id, element_id, value)
    Blades::removeFromSet(token, set_id, element_id)
    Blades::putDatablob(token, key, datablob)
    Blades::getDatablobOrNull(token, key)
    Blades::destroy(token)
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
    ----------------------------------------------------------------------------------
    | "attribute"        | name of the attribute            | value is json encoded  |
    | "set-add"          | expression <set_name>/<value_id> | value is json encoded  |
    | "set-remove"       | expression <set_name>/<value_id> |                        |
    | "datablob"         | key (for instance a nhash)       | blob                   |
    ----------------------------------------------------------------------------------

reserved attributes:
    - uuid     : unique identifier of the blade.
    - mikuType : String
    - next     : (optional) uuid of the next blade in the sequence

=end

class Blades

    # ----------------------------------------------
    # Private

    # Blades::isBlade(filepath) # boolean
    def self.isBlade(filepath)
        File.basename(filepath).start_with?("blade-")
    end

    # Blades::tokenToFilepathOrNull(token) # filepath or null
    # Token is either a uuid or a filepath
    def self.tokenToFilepathOrNull(token)
        # We start by interpreting the token as a filepath
        return token if File.exist?(token)
        
        # The token can then be either
        #   - an outdated filepath
        #   - a uuid
        uuid =
            if token.include?("blade-") then
                # filepath
                return token if File.exist?(token)
                File.basename(token).gsub("blade-", "").split("@").first
            else
                uuid = token
            end

        # We have the uuid, let's try the uuid -> filepath mapping
        filepath = XCache::getOrNull("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}")
        return filepath if (filepath and File.exist?(filepath))

        # We have the uuid, but got nothing from the uuid -> filepath mapping
        # running exhaustive search.

        root = "#{ENV["HOME"]}/Galaxy/DataHub/Blades"

        Find.find(root) do |filepath|
            next if !File.file?(filepath)
            next if !Blades::isBlade(filepath)

            readUUIDFromBlade = lambda {|filepath|
                value = nil
                db = SQLite3::Database.new(filepath)
                db.busy_timeout = 117
                db.busy_handler { |count| true }
                db.results_as_hash = true
                # We go through all the values, because the one we want is the last one
                db.execute("select * from records where operation_type=? and _name_=? order by operation_unixtime", ["attribute", "uuid"]) do |row|
                    value = JSON.parse(row["_data_"])
                end
                db.close
                raise "(error: 22749e93-77e0-4907-8226-f2e620d4a372)" if value.nil?
                value
            }

            if readUUIDFromBlade.call(filepath) == uuid then
                XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}", filepath)
                return filepath
            end
        end

        nil
    end

    # Blades::rename(filepath1)
    def self.rename(filepath1)
        return filepath1 if !File.exist?(filepath1)
        dirname = File.dirname(filepath1)
        uuid = Blades::getMandatoryAttribute(filepath1, "uuid")
        hash1 = Digest::SHA1.file(filepath1).hexdigest
        filepath2 = "#{dirname}/blade-#{uuid}@#{hash1}"
        return filepath1 if filepath1 == filepath2
        FileUtils.mv(filepath1, filepath2)
        MikuTypes::registerFilepath(filepath2)
        nil
    end

    # ----------------------------------------------
    # Public

    # Blades::init(mikuType, uuid) # String : filepath
    def self.init(mikuType, uuid)
        if uuid.include?("@") then
            raise "A blade uuid cannot have the chracter: @ (use as separator in the blade filenames)"
        end
        filepath = "#{ENV["HOME"]}/Galaxy/DataHub/Blades/blade-#{uuid}@#{SecureRandom.hex}"
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("create table records (record_uuid string primary key, operation_unixtime float, operation_type string, _name_ string, _data_ blob)", [])
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "attribute", "uuid", JSON.generate(uuid)]
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "attribute", "mikuType", JSON.generate(mikuType)]
        db.close
        Blades::rename(filepath)
        nil
    end

    # Blades::setAttribute(token, attribute_name, value)
    def self.setAttribute(token, attribute_name, value)
        filepath = Blades::tokenToFilepathOrNull(token)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "attribute", attribute_name, JSON.generate(value)]
        db.close
        Blades::rename(filepath)
        nil
    end

    # Blades::getAttributeOrNull(token, attribute_name)
    def self.getAttributeOrNull(token, attribute_name)
        value = nil
        filepath = Blades::tokenToFilepathOrNull(token)
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

    # Blades::getMandatoryAttribute(token, attribute_name)
    def self.getMandatoryAttribute(token, attribute_name)
        value = nil
        filepath = Blades::tokenToFilepathOrNull(token)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select * from records where operation_type=? and _name_=? order by operation_unixtime", ["attribute", attribute_name]) do |row|
            value = JSON.parse(row["_data_"])
        end
        db.close
        raise "Failing mandatory attribute '#{attribute_name}' at blade '#{filepath}'" if value.nil?
        value
    end

    # Blades::addToSet(token, set_id, element_id, value)
    def self.addToSet(token, set_id, element_id, value)

    end

    # Blades::removeFromSet(token, set_id, element_id)
    def self.removeFromSet(token, set_id, element_id)

    end

    # Blades::getSet(token, set_id)
    def self.getSet(token, set_id)

    end

    # Blades::putDatablob(token, key, datablob)
    def self.putDatablob(token, key, datablob)

    end

    # Blades::getDatablobOrNull(token, key)
    def self.getDatablobOrNull(token, key)

    end

    # Blades::destroy(token)
    def self.destroy(token)
        filepath = Blades::tokenToFilepathOrNull(token)
        return if filepath.nil?
        FileUtils.rm(filepath)
    end
end

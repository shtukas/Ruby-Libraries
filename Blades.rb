# encoding: utf-8

=begin
Blades
    Blades::init(mikuType, uuid)
    Blades::uuidToFilepathOrNull(uuid)
    Blades::setAttribute1(filepath, attribute_name, value)
    Blades::setAttribute2(uuid, attribute_name, value)
    Blades::getAttributeOrNull1(filepath, attribute_name)
    Blades::getMandatoryAttribute1(filepath, attribute_name)
    Blades::addToSet1(filepath, set_id, element_id, value)
    Blades::removeFromSet1(filpath, set_id, element_id)
    Blades::putDatablob1(filepath, key, datablob)
    Blades::getDatablobOrNull1(filepath, key)
    Blades::destroy(uuid)
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

    # Blades::bladeRepository()
    def self.bladeRepository()
        "#{ENV["HOME"]}/Galaxy/DataHub/Blades"
    end

    # Blades::isBlade(filepath) # boolean
    def self.isBlade(filepath)
        File.basename(filepath).start_with?("blade-")
    end

    # Blades::uuidToFilepathOrNull(uuid) # filepath or null
    def self.uuidToFilepathOrNull(uuid)
        # Let's try the uuid -> filepath mapping
        filepath = XCache::getOrNull("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}")
        return filepath if (filepath and File.exist?(filepath))

        # Got nothing from the uuid -> filepath mapping
        # Running exhaustive search.

        Find.find(Blades::bladeRepository()) do |filepath|
            next if !File.file?(filepath)
            next if !Blades::isBlade(filepath)
            uuidx = Blades::getMandatoryAttribute1(filepath, "uuid")
            XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuidx}", filepath)
            return filepath if uuidx == uuid
        end

        nil
    end

    # Blades::rename(filepath1)
    def self.rename(filepath1)
        return if !File.exist?(filepath1)
        hash1 = Digest::SHA1.file(filepath1).hexdigest
        filepath2 = "#{Blades::bladeRepository()}/#{hash1[0, 2]}/blade-#{hash1}"
        return if filepath1 == filepath2
        if !File.exist?(File.dirname(filepath2)) then
            FileUtils.mkdir(File.dirname(filepath2))
        end
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
        filepath = "#{Blades::bladeRepository()}/blade-#{SecureRandom.hex}"
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

    # Blades::setAttribute1(filepath, attribute_name, value)
    def self.setAttribute1(filepath, attribute_name, value)
        raise "(error: 042f0674-5b05-469c-adc1-db0012019e12) filepath: #{filepath}, attribute_name, #{attribute_name}" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "attribute", attribute_name, JSON.generate(value)]
        db.close
        Blades::rename(filepath)
        nil
    end

    # Blades::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: cd0edf0c-c3d5-4743-852d-df9aae01632e) uuid: #{uuid}, attribute_name, #{attribute_name}" if filepath.nil?
        Blades::setAttribute1(filepath, attribute_name, value)
    end

    # Blades::getAttributeOrNull1(filepath, attribute_name)
    def self.getAttributeOrNull1(filepath, attribute_name)
        raise "(error: b1584ef9-20e9-4109-82d6-fef6d88e1265) filepath: #{filepath}, attribute_name, #{attribute_name}" if !File.exist?(filepath)
        value = nil
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

    # Blades::getMandatoryAttribute1(filepath, attribute_name)
    def self.getMandatoryAttribute1(filepath, attribute_name)
        value = Blades::getAttributeOrNull1(filepath, attribute_name)
        raise "Failing mandatory attribute '#{attribute_name}' at blade '#{filepath}'" if value.nil?
        value
    end

    # Blades::getMandatoryAttribute2(uuid, attribute_name)
    def self.getMandatoryAttribute2(uuid, attribute_name)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: 5a075c65-edab-4a36-aafb-b8aad3f6422f) uuid: #{uuid}, attribute_name, #{attribute_name}" if filepath.nil?
        Blades::getMandatoryAttribute1(filepath, attribute_name)
    end

    # Blades::getMandatoryAttribute1(filepath, attribute_name)
    def self.getMandatoryAttribute1(filepath, attribute_name)
        raise "(error: 4a99e1f9-4896-49b1-b766-05c39d5a0fa0) filepath: #{filepath}, attribute_name, #{attribute_name}" if !File.exist?(filepath)
        value = nil
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

    # Blades::addToSet1(filepath, set_id, element_id, value)
    def self.addToSet1(filepath, set_id, element_id, value)

    end

    # Blades::removeFromSet1(filpath, set_id, element_id)
    def self.removeFromSet1(filpath, set_id, element_id)

    end

    # Blades::getSet1(filepath, set_id)
    def self.getSet1(filepath, set_id)

    end

    # Blades::putDatablob1(filepath, key, datablob)
    def self.putDatablob1(filepath, key, datablob)

    end

    # Blades::getDatablobOrNull1(filepath, key)
    def self.getDatablobOrNull1(filepath, key)

    end

    # Blades::destroy(uuid)
    def self.destroy(uuid)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        return if filepath.nil?
        FileUtils.rm(filepath)
    end
end

# encoding: utf-8

=begin
Blades
    Blades::filepathsEnumerator()
    Blades::init(mikuType, uuid) # filepath
    Blades::uuidToFilepathOrNull(uuid)
    Blades::setAttribute1(filepath, attribute_name, value)
    Blades::setAttribute2(uuid, attribute_name, value)
    Blades::getAttributeOrNull1(filepath, attribute_name)
    Blades::getAttributeOrNull2(uuid, attribute_name)
    Blades::getMandatoryAttribute1(filepath, attribute_name)
    Blades::getMandatoryAttribute2(uuid, attribute_name)
    Blades::addToSet1(filepath, set_name, value_id, value)
    Blades::addToSet2(uuid, set_name, value_id, value)
    Blades::removeFromSet1(filpath, set_name, value_id)
    Blades::removeFromSet2(uuid, set_name, value_id)
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
    For specifications see DataTypes/02-blades.txt
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
        puts "Running exhaustive search to find blade filepath for uuid: #{uuid}"

        Find.find(Blades::bladeRepository()) do |filepath|
            next if !File.file?(filepath)
            next if !Blades::isBlade(filepath)
            uuidx = Blades::getMandatoryAttribute1(filepath, "uuid")
            XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuidx}", filepath)
            return filepath if uuidx == uuid
        end

        nil
    end

    # Blades::rename(filepath1) # new filepath
    def self.rename(filepath1)
        raise "(error: da2fb2ae-a50e-4359-b453-8bc4f856571a) filepath: #{filepath1}" if !File.exist?(filepath1)
        hash1 = Digest::SHA1.file(filepath1).hexdigest
        filepath2 = "#{Blades::bladeRepository()}/#{hash1[0, 2]}/blade-#{hash1}"
        return filepath1 if filepath1 == filepath2
        if !File.exist?(File.dirname(filepath2)) then
            FileUtils.mkdir(File.dirname(filepath2))
        end
        puts "renaming:".green
        puts "    old: #{filepath1}".green
        puts "    new: #{filepath2}".green
        FileUtils.mv(filepath1, filepath2)
        uuidx = Blades::getMandatoryAttribute1(filepath2, "uuid")
        XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuidx}", filepath2)
        filepath2
    end

    # ----------------------------------------------
    # Public

    # Blades::filepathsEnumerator()
    def self.filepathsEnumerator()
        Enumerator.new do |filepaths|
           begin
                Find.find(Blades::bladeRepository()) do |path|
                    next if !File.file?(path)
                    if Blades::isBlade(path) then
                        filepaths << path
                    end
                end
            rescue
            end
        end
    end

    # Blades::merge(filepath1, filepath2) # filepath
    def self.merge(filepath1, filepath2)
        puts "> Blades::merge(filepath1, filepath2) request with filepath1: #{filepath1}, filepath2: #{filepath2}".green

        if (filepath1 == filepath2) or !File.exist?(filepath1) or !File.exist?(filepath2) then
            raise "> incorrect Blades::merge(filepath1, filepath2) request with filepath1: #{filepath1}, filepath2: #{filepath2}"
        end

        db1 = SQLite3::Database.new(filepath1)
        db2 = SQLite3::Database.new(filepath2)

        # We move all the objects from db1 to db2
        # create table records (record_uuid string primary key, operation_unixtime float, operation_type string, _name_ string, _data_ blob)

        db1.busy_timeout = 117
        db1.busy_handler { |count| true }
        db1.results_as_hash = true
        db1.execute("select * from records", []) do |row|
            db2.execute "delete from records where record_uuid = ?", [row["record_uuid"]]
            db2.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [row["record_uuid"], row["operation_unixtime"], row["operation_type"], row["_name_"], row["_data_"]]
        end

        db1.close
        db2.close

        # Let's now delete the first file 
        FileUtils.rm(filepath1)

        # And rename the second one
        Blades::rename(filepath2)
    end

    # Blades::init(mikuType, uuid) # String : filepath
    def self.init(mikuType, uuid)
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
    end

    # Blades::setAttribute1(filepath, attribute_name, value)
    def self.setAttribute1(filepath, attribute_name, value)
        puts "Blades::setAttribute1(filepath: #{filepath}, attribute_name: #{attribute_name}, value: #{value})".green
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
        puts "Blades::setAttribute2(uuid: #{uuid}, attribute_name: #{attribute_name}, value: #{value})".green
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
        # We go through all the values in order, because the one we want is the last one
        db.execute("select * from records where operation_type=? and _name_=? order by operation_unixtime", ["attribute", attribute_name]) do |row|
            value = JSON.parse(row["_data_"])
        end
        db.close
        value
    end

    # Blades::getAttributeOrNull2(uuid, attribute_name)
    def self.getAttributeOrNull2(uuid, attribute_name)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: 0cda7fb0-9392-4f03-a34d-dd45fec1af2f) filepath: #{filepath}, attribute_name, #{attribute_name}" if !File.exist?(filepath)
        Blades::getAttributeOrNull1(filepath, attribute_name)
    end

    # Blades::getMandatoryAttribute1(filepath, attribute_name)
    def self.getMandatoryAttribute1(filepath, attribute_name)
        value = Blades::getAttributeOrNull1(filepath, attribute_name)
        if value.nil? then
            raise "(error: f6d8c9d9-84cb-4f14-95c2-402d2471ef93) Failing mandatory attribute '#{attribute_name}' at blade '#{filepath}'"
        end
        value
    end

    # Blades::getMandatoryAttribute2(uuid, attribute_name)
    def self.getMandatoryAttribute2(uuid, attribute_name)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: 4a99e1f9-4896-49b1-b766-05c39d5a0fa0) filepath: #{filepath}, attribute_name, #{attribute_name}" if !File.exist?(filepath)
        Blades::getMandatoryAttribute1(filepath, attribute_name)
    end

    # Blades::addToSet1(filepath, set_name, value_id, value)
    def self.addToSet1(filepath, set_name, value_id, value)
        puts "Blades::addToSet1(filepath: #{filepath}, set_name: #{set_name}, value_id: #{value_id}, value: #{value})".green
        raise "(error: ab5c468b-e672-4465-9881-6c26f987cbb0) filepath: #{filepath}, set_name: #{set_name}, value_id: #{value_id}, value: #{value}" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "set-add", "#{set_name}/#{value_id}", JSON.generate(value)]
        db.close
        Blades::rename(filepath)
        nil
    end

    # Blades::addToSet2(uuid, set_name, value_id, value)
    def self.addToSet2(uuid, set_name, value_id, value)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: 85558d55-5d95-4df7-a8ab-143c260437d5) uuid: #{uuid}, set_name: #{set_name}, value_id: #{value_id}, value: #{value}" if filepath.nil?
        Blades::addToSet1(filepath, set_name, value_id, value)
        nil
    end

    # Blades::removeFromSet1(filpath, set_name, value_id)
    def self.removeFromSet1(filpath, set_name, value_id)
        puts "Blades::removeFromSet1(filepath: #{filepath}, set_name: #{set_name}, value_id: #{value_id})".green
        raise "(error: e4675f2a-5a04-4fc0-b80d-e13db981461d) filepath: #{filepath}, set_name: #{set_name}, value_id: #{value_id}" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "set-remove", "#{set_name}/#{value_id}", nil]
        db.close
        Blades::rename(filepath)
        nil
    end

    # Blades::removeFromSet2(uuid, set_name, value_id)
    def self.removeFromSet2(uuid, set_name, value_id)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: 2aebe5d0-342a-4f65-ba55-dde43b723553) uuid: #{uuid}, set_name: #{set_name}, value_id: #{value_id}" if filepath.nil?
        Blades::removeFromSet1(filpath, set_name, value_id)
        nil
    end

    # Blades::getSet1(filepath, set_name)
    def self.getSet1(filepath, set_name)
        raise "(error: 1f4a372e-cc6f-4d8f-9d9b-ebd3e1149b93) filepath: #{filepath}, set_name: #{set_name}" if !File.exist?(filepath)
        hash_ = {} # Map[value_id, value]
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select * from records order by operation_unixtime", []) do |row|
            if row["operation_type"][0, 4] == "set-" then
                if row["_name_"].start_with?("#{set_name}/") then
                    set_name, value_id = row["_name_"].split("/")
                    if row["operation_type"] == "set-add" then
                        hash_[value_id] = JSON.parse(row["_data_"]) # we set the value, possibly overriding any previous value at that value_id
                    end
                    if row["operation_type"] == "set-remove" then
                        hash_.delete(value_id) # removing the value with the specified value_id.
                    end
                end
            end
        end
        db.close
        hash_.values
    end

    # Blades::getSet2(uuid, set_name)
    def self.getSet2(uuid, set_name)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: d4f78bfc-4daa-430d-989d-60772d3309fa) uuid: #{uuid}, set_name: #{set_name}" if filepath.nil?
        Blades::getSet1(filepath, set_name)
    end

    # Blades::putDatablob1(filepath, datablob) # nhash
    def self.putDatablob1(filepath, datablob)
        puts "Blades::putDatablob1(filepath: #{filepath}, datablob:size: #{datablob.size})".green
        raise "(error: 8e21aacf-6d08-4d51-9f65-a7a2b963ca38) filepath: #{filepath}, datablob:size: #{datablob.size}" if !File.exist?(filepath)
        nhash = "SHA256-#{Digest::SHA256.hexdigest(datablob)}"
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [SecureRandom.uuid, Time.new.to_f, "datablob", nhash, datablob]
        db.close
        Blades::rename(filepath)
        nhash
    end

    # Blades::putDatablob2(uuid, datablob) # nhash
    def self.putDatablob2(uuid, datablob)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: 41b155f5-1114-4b2d-b2b8-c1230819fd3d) uuid: #{uuid}, datablob:size: #{datablob.size}" if filepath.nil?
        if File.size(filepath) < 1024*1024*1024 then # 1Gb 
            return Blades::putDatablob1(filepath, datablob)
        end

        nextuuid = Blades::getAttributeOrNull1(filepath, "next")
        if nextuuid then
            return Blades::putDatablob2(nextuuid, datablob)
        end

        nextuuid = SecureRandom.uuid
        nextfilepath = Blades::init("NxPure", nextuuid)

        Blades::setAttribute1(nextfilepath, "previous", uuid) # marking the next blade with coordinates of the current
        Blades::setAttribute1(filepath, "next", nextuuid)     # marking the current blade with coordinates of the next

        Blades::putDatablob1(nextfilepath, datablob)
    end

    # Blades::getDatablobOrNull1(filepath, nhash)
    def self.getDatablobOrNull1(filepath, nhash)

        raise "(error: 273139ba-e4ef-4345-a4de-2594ce77c563) filepath: #{filepath}" if !File.exist?(filepath)

        datablob = nil

        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute("select * from records where operation_type=? and _name_=? order by operation_unixtime", ["datablob", nhash]) do |row|
            datablob = row["_data_"]
        end
        db.close

        return datablob if datablob

        # If we did not find a blob, it could be that the blob is at next.
        # Let's try that!

        nextuuid = Blades::getAttributeOrNull1(filepath, "next")
        return nil if nextuuid.nil?

        Blades::getDatablobOrNull2(nextuuid, nhash)
    end

    # Blades::getDatablobOrNull2(uuid, nhash)
    def self.getDatablobOrNull2(uuid, nhash)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        raise "(error: bee6247e-c798-44a9-b72b-62773f75254e) uuid: #{uuid}" if filepath.nil?
        Blades::getDatablobOrNull1(filepath, nhash)
    end

    # Blades::destroy(uuid)
    def self.destroy(uuid)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        return if filepath.nil?
        FileUtils.rm(filepath)
    end
end

class BladeElizabeth

    def initialize(uuid)
        @uuid = uuid
    end

    def putBlob(datablob) # nhash
        Blades::putDatablob2(@uuid, datablob)
    end

    def filepathToContentHash(filepath)
        "SHA256-#{Digest::SHA256.file(filepath).hexdigest}"
    end

    def getBlobOrNull(nhash)
        Blades::getDatablobOrNull2(@uuid, nhash)
    end

    def readBlobErrorIfNotFound(nhash)
        blob = getBlobOrNull(nhash)
        return blob if blob
        raise "(error: 6923aca5-2e83-4379-9d58-6c09c185d07c, nhash: #{nhash})"
    end

    def datablobCheck(nhash)
        begin
            blob = readBlobErrorIfNotFound(nhash)
            status = ("SHA256-#{Digest::SHA256.hexdigest(blob)}" == nhash)
            if !status then
                puts "(error: 63374c58-b2f3-4e79-9844-2a110c57674d) incorrect blob, exists but doesn't have the right nhash: #{nhash}"
            end
            return status
        rescue
            false
        end
    end
end

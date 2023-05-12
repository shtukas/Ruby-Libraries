# encoding: utf-8

=begin
BLxs

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

require_relative "Blades.rb"

# NxD001: {items: Array[Items], next: null or cache location}

# -----------------------------------------------------------------------------------

$SolingeninMemoryData = nil

class Solingen

    # ----------------------------------------------
    # Solingen Service Private

    # Solingen::getBladeAsItem(filepath)
    def self.getBladeAsItem(filepath)
        item = {}
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values in operation_unixtime order, because the one we want is the last one
        db.execute("select * from records where operation_type=? order by operation_unixtime", ["attribute"]) do |row|
            item[row["_name_"]] = JSON.parse(row["_data_"])
        end
        db.close
        item
    end

    # Solingen::getInMemoryData()
    def self.getInMemoryData()
        return $SolingeninMemoryData if $SolingeninMemoryData
        $SolingeninMemoryData = {} # Map[mikuType, Map[uuid, item]]

        data = XCache::getOrNull("7ea6cdc2-c1fe-4e89-89d2-6f29bad54bed")
        if data then
            data = JSON.parse(data)
            $SolingeninMemoryData = data
            return $SolingeninMemoryData
        end

        data = {}
        puts "Initialising Solingen data from blades"
        Blades::filepathsEnumerator().each{|filepath|
            puts "> Initialising Solingen data from blades: blade filepath: #{filepath}"
            uuid = Blades::getMandatoryAttribute1(filepath, "uuid")
            XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}", filepath)
            item = Solingen::getBladeAsItem(filepath)
            if data[item["mikuType"]].nil? then
                data[item["mikuType"]] = {}
            end
            data[item["mikuType"]][item["uuid"]] = item
        }

        XCache::set("7ea6cdc2-c1fe-4e89-89d2-6f29bad54bed", JSON.generate(data))
        $SolingeninMemoryData = data
        $SolingeninMemoryData
    end

    # Solingen::setInMemoryData(data)
    def self.setInMemoryData(data)
        XCache::set("7ea6cdc2-c1fe-4e89-89d2-6f29bad54bed", JSON.generate(data))
        $SolingeninMemoryData = data
    end

    # Solingen::getMikuTypesFromInMemory()
    def self.getMikuTypesFromInMemory()
        Solingen::getInMemoryData().keys
    end

    # Solingen::putItemIntoInMemoryData(item)
    def self.putItemIntoInMemoryData(item)
        data = Solingen::getInMemoryData()
        data.keys.each{|mikuType|
            data[mikuType].delete(item["uuid"])
        }
        if data[item["mikuType"]].nil? then
            data[item["mikuType"]] = {}
        end
        data[item["mikuType"]][item["uuid"]] = item
        Solingen::setInMemoryData(data)
    end

    # Solingen::getItemFromDiskByUUIDOrNull(uuid)
    def self.getItemFromDiskByUUIDOrNull(uuid)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        return nil if filepath.nil?
        Solingen::getBladeAsItem(filepath)
    end

    # Solingen::loadItemFromDiskByUUIDAndUpdateInMemoryData(uuid)
    def self.loadItemFromDiskByUUIDAndUpdateInMemoryData(uuid)
        item = Solingen::getItemFromDiskByUUIDOrNull(uuid)
        return if item.nil?
        Solingen::putItemIntoInMemoryData(item)
    end

    # Solingen::destroyInMemory(uuid)
    def self.destroyInMemory(uuid)
        mikuTypes = Solingen::getInMemoryData().keys
        data = Solingen::getInMemoryData()
        mikuTypes.each{|mikuType|
            data[mikuType].delete(uuid)
        }
        Solingen::setInMemoryData(data)
    end

    # ----------------------------------------------
    # Solingen Service Public, Blade Bridge

    # Solingen::init(mikuType, uuid) # String : filepath
    def self.init(mikuType, uuid)
        Blades::init(mikuType, uuid)
        Solingen::loadItemFromDiskByUUIDAndUpdateInMemoryData(uuid)
    end

    # Solingen::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)
        Solingen::loadItemFromDiskByUUIDAndUpdateInMemoryData(uuid)
    end

    # Solingen::getAttributeOrNull2(uuid, attribute_name)
    def self.getAttributeOrNull2(uuid, attribute_name)
        item = Solingen::getItemOrNull(uuid)
        return nil if item.nil?
        item[attribute_name]
    end

    # Solingen::getMandatoryAttribute2(uuid, attribute_name)
    def self.getMandatoryAttribute2(uuid, attribute_name)
        value = Solingen::getAttributeOrNull2(uuid, attribute_name)
        if value.nil? then
            raise "(error: 1052d5d1-6c5b-4b58-b470-22de8b68f4c8) Failing mandatory attribute '#{attribute_name}' at blade uuid: '#{uuid}'"
        end
        value
    end

    # Solingen::addToSet2(uuid, set_name, value_id, value)
    def self.addToSet2(uuid, set_name, value_id, value)
        Blades::addToSet2(uuid, set_name, value_id, value)
    end

    # Solingen::removeFromSet2(uuid, set_name, value_id)
    def self.removeFromSet2(uuid, set_name, value_id)
        Blades::removeFromSet2(uuid, set_name, value_id)
    end

    # Solingen::getSet2(uuid, set_name)
    def self.getSet2(uuid, set_name)
        Blades::getSet2(uuid, set_name)
    end

    # Solingen::putDatablob2(uuid, datablob)  # nhash
    def self.putDatablob2(uuid, datablob)
        Blades::putDatablob2(uuid, datablob)
    end

    # Solingen::getDatablobOrNull2(uuid, nhash)
    def self.getDatablobOrNull2(uuid, nhash)
        Blades::getDatablobOrNull2(uuid, nhash)
    end

    # Solingen::destroy(uuid)
    def self.destroy(uuid)
        Blades::destroy(uuid)
        Solingen::destroyInMemory(uuid)
    end

    # ----------------------------------------------
    # Solingen Service Interface, Collections

    # Solingen::mikuTypes()
    def self.mikuTypes()
        Solingen::getInMemoryData().keys
    end

    # Solingen::mikuTypeItems(mikuType)
    def self.mikuTypeItems(mikuType)
        data = Solingen::getInMemoryData()
        return [] if data[mikuType].nil?
        data[mikuType].values
    end

    # Solingen::getItemOrNull(uuid)
    def self.getItemOrNull(uuid)
        mikuTypes = Solingen::getInMemoryData().keys
        data = Solingen::getInMemoryData()
        mikuTypes.each{|mikuType|
            return data[mikuType][uuid] if data[mikuType][uuid]
        }
        nil
    end

    # Solingen::getItem(uuid)
    def self.getItem(uuid)
        mikuTypes = Solingen::getInMemoryData().keys
        data = Solingen::getInMemoryData()
        mikuTypes.each{|mikuType|
            return data[mikuType][uuid] if data[mikuType][uuid]
        }
        raise "Solingen::getItem(uuid) could not find item for uuid: #{uuid}"
    end

    # Solingen::mikuTypeCount(mikuType)
    def self.mikuTypeCount(mikuType)
        data = Solingen::getInMemoryData()
        return 0 if data[mikuType].nil?
        data[mikuType].values.size
    end
end

Thread.new {
    loop {
        sleep 300
        next if $SolingeninMemoryData.nil?
        Blades::filepathsEnumerator().each{|filepath|
            next if !File.exist?(filepath)

            uuid = Blades::getMandatoryAttribute1(filepath, "uuid")

            # First, let's compare that filepath is the recorded filepath for the uuid
            # This will enable us to detect duplicate blades and merge them
            knownFilepath = XCache::getOrNull("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}")
            if knownFilepath and File.exist?(knownFilepath) and knownFilepath != filepath then
                filepath1 = filepath
                filepath2 = knownFilepath
                filepath = Blades::merge(filepath1, filepath2)
            end

            if (unixtime = Blades::getAttributeOrNull1(filepath, "deleted")) then
                Solingen::destroyInMemory(uuid)
                # The value of the attribute is the unixtime of deletion. We keep the blades for 7 days, before permanently deleting them
                # That period was chosen because we keep the stored version of in memory data only 7 days
                if (Time.new.to_i - unixtime) > 86400*7 then
                    FileUtils.rm(filepath)
                end
                next
            end
            XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}", filepath)
            next if XCache::getFlag("d1af995a-2b1e-465e-a8d1-3c56e937ea4a:#{filepath}") # we have already seen this one
            data = Solingen::getInMemoryData()
            item = Solingen::getBladeAsItem(filepath)
            if data[item["mikuType"]].nil? then
                data[item["mikuType"]] = {}
            end
            data[item["mikuType"]][item["uuid"]] = item
            Solingen::setInMemoryData(data)
            XCache::setFlag("d1af995a-2b1e-465e-a8d1-3c56e937ea4a:#{filepath}", true)
        }
    }
}

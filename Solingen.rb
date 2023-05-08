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

class Solingen

    # Solingen::bladesFilepathsEnumerator()
    def self.bladesFilepathsEnumerator()
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

    # ----------------------------------------------
    # Data Optimization

    # Solingen::registerMikuType(mikuType)
    def self.registerMikuType(mikuType)
        mikuTypes = Solingen::mikuTypes()
        return if mikuTypes.include?(mikuType)
        mikuTypes = mikuTypes + [mikuType]
        XCache::set("mikuTypes:49132348-46f3-4814-8e27-50", JSON.generate(mikuTypes))
    end

    # Solingen::registerItem(item)
    def self.registerItem(item)
        mikuType = item["mikuType"]
        Solingen::registerMikuType(item["mikuType"])
        XCache::set("uuid(#{item["uuid"]})->item:91ea-d56a5135b895", JSON.generate(item))
        items = Solingen::mikuTypeItems(mikuType).reject{|i| i["uuid"] == item["uuid"] } + [item]
        XCache::set("mikuType(#{mikuType})->items:4f15-bb9c-1f1a7f1ad21", JSON.generate(items))
    end

    # Solingen::reloadAndRegisterItemFromDisk(uuid)
    def self.reloadAndRegisterItemFromDisk(uuid)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        item = {}
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select * from records where operation_type=? order by operation_unixtime", ["attribute"]) do |row|
            item[row["_name_"]] = JSON.parse(row["_data_"])
        end
        db.close
        puts "Solingen::reloadAndRegisterItemFromDisk(#{uuid}): #{JSON.pretty_generate(item).green}"
        Solingen::registerItem(item)
    end

    # Solingen::load()
    def self.load()
        Solingen::bladesFilepathsEnumerator().each{|filepath|
            puts "Solingen::load(): #{filepath}"
            uuid = Blades::getMandatoryAttribute1(filepath, "uuid")
            XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}", filepath)
            Solingen::reloadAndRegisterItemFromDisk(uuid)
        }
    end

    # ----------------------------------------------
    # Blade Bridge

    # Solingen::init(mikuType, uuid) # String : filepath
    def self.init(mikuType, uuid)
        Blades::init(mikuType, uuid)
        Solingen::reloadAndRegisterItemFromDisk(uuid)
    end

    # Solingen::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)
        Solingen::reloadAndRegisterItemFromDisk(uuid)
    end

    # Solingen::getAttributeOrNull2(uuid, attribute_name)
    def self.getAttributeOrNull2(uuid, attribute_name)
        item = Solingen::getItemOrNull(uuid)
        return nil if nil?
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
        Solingen::mikuTypes().each{|mikuType|
            items = Solingen::mikuTypeItems(mikuType).reject{|i| i["uuid"] == item["uuid"] }
            XCache::set("mikuType(#{mikuType})->items:4f15-bb9c-1f1a7f1ad21", JSON.generate(items))
        }
    end

    # ----------------------------------------------
    # Solingen Service

    # Solingen::mikuTypes()
    def self.mikuTypes()
        s = XCache::getOrNull("mikuTypes:49132348-46f3-4814-8e27-50")
        if s then
            return JSON.parse(s)
        else
            mikuTypes = []
            XCache::set("mikuTypes:49132348-46f3-4814-8e27-50", JSON.generate(mikuTypes))
            return mikuTypes
        end
    end

    # Solingen::mikuTypeItems(mikuType)
    def self.mikuTypeItems(mikuType)
        Solingen::registerMikuType(mikuType)
        items = XCache::getOrNull("mikuType(#{mikuType})->items:4f15-bb9c-1f1a7f1ad21")
        if items then
            return JSON.parse(items)
        else
            items = []
            XCache::set("mikuType(#{mikuType})->items:4f15-bb9c-1f1a7f1ad21", JSON.generate(items))
            return items
        end
    end

    # Solingen::getItemOrNull(uuid)
    def self.getItemOrNull(uuid)
        item = XCache::getOrNull("uuid(#{uuid})->item:91ea-d56a5135b895")
        if item then
            return JSON.parse(item)
        else
            return nil
        end
    end

    # Solingen::mikuTypeCount(mikuType)
    def self.mikuTypeCount(mikuType)
        Solingen::mikuTypeItems(mikuType).size
    end
end

unixtime = XCache::getOrNull("9beb2975-6611-4cb9-b5c6-4dbeecdf780a")
if unixtime.nil? or (Time.new.to_i - unixtime.to_i) >= 86400 then
    Solingen::load()
    XCache::set("9beb2975-6611-4cb9-b5c6-4dbeecdf780a", Time.new.to_i)
end

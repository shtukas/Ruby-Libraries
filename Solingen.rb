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

$SolingeninMemoryItems = nil

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

    # ----------------------------------------------
    # Blade Bridge

    # Solingen::init(mikuType, uuid) # String : filepath
    def self.init(mikuType, uuid)
        Blades::init(mikuType, uuid)
        Solingen::loadItemFromDiskByUUIDAndputsIntoDataFileAndInMemory(uuid)
    end

    # Solingen::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)
        Solingen::loadItemFromDiskByUUIDAndputsIntoDataFileAndInMemory(uuid)
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
        Solingen::getMikuTypesFromInMemory().each{|mikuType|
            items = Solingen::mikuTypeItems(mikuType).reject{|i| i["uuid"] == item["uuid"] }
            XCache::set("mikuType(#{mikuType})->items:4f15-bb9c-1f1a7f1ad21", JSON.generate(items))
        }
    end

    # ----------------------------------------------
    # Solingen Service Private: 

    # create table _items_ (_uuid_ string primary key, _mikuType_ string, _position_ float, _item_ string)

    # Solingen::dataFilepath()
    def self.dataFilepath()
        dbfilepath = XCache::filepath("5f490a6e-e172-436f-9a1f-f581597c3451")
        if !File.exist?(dbfilepath) then
            puts "> initialising data file"
            db = SQLite3::Database.new(dbfilepath)
            db.busy_timeout = 117
            db.busy_handler { |count| true }
            db.results_as_hash = true
            db.execute("create table _items_ (_uuid_ string primary key, _mikuType_ string, _position_ float, _item_ string)", [])

            Solingen::bladesFilepathsEnumerator().each{|bladefilepath|
                puts "> initialising data file: blade filepath: #{bladefilepath}"
                uuid = Blades::getMandatoryAttribute1(bladefilepath, "uuid")
                XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}", bladefilepath)
                item = Solingen::getBladeAsItem(bladefilepath)
                db.execute "delete from _items_ where _uuid_=?", [item["uuid"]]
                db.execute "insert into _items_ (_uuid_, _mikuType_, _position_, _item_) values (?, ?, ?, ?)", [item["uuid"], item["mikuType"], item["position"] || 0, JSON.generate(item)]
            }

            db.close
        end
        dbfilepath
    end

    # Solingen::getInMemoryItems()
    def self.getInMemoryItems()
        return $SolingeninMemoryItems if $SolingeninMemoryItems
        $SolingeninMemoryItems = {} # Map[mikuType, Map[uuid, item]

        db = SQLite3::Database.new(Solingen::dataFilepath())
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select * from _items_", []) do |row|
            item = JSON.parse(row["_item_"])
            if $SolingeninMemoryItems[item["mikuType"]].nil? then
                $SolingeninMemoryItems[item["mikuType"]] = {}
            end
            $SolingeninMemoryItems[item["mikuType"]][item["uuid"]] = item
        end
        db.close

        $SolingeninMemoryItems
    end

    # Solingen::getMikuTypesFromInMemory()
    def self.getMikuTypesFromInMemory()
        Solingen::getInMemoryItems().keys
    end

    # Solingen::putItemIntoDataFileAndInMemory(item)
    def self.putItemIntoDataFileAndInMemory(item)
        db = SQLite3::Database.new(Solingen::dataFilepath())
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "delete from _items_ where _uuid_=?", [item["uuid"]]
        db.execute "insert into _items_ (_uuid_, _mikuType_, _position_, _item_) values (?, ?, ?, ?)", [item["uuid"], item["mikuType"], item["position"] || 0, JSON.generate(item)]
        db.close

        mikuTypes = Solingen::getInMemoryItems().keys
        data = Solingen::getInMemoryItems()
        mikuTypes.each{|mikuType|
            data[mikuTypes].delete(item["uuid"])
        }
        data[item["mikuType"]][item["uuid"]] = item
        $SolingeninMemoryItems = data
    end

    # Solingen::getItemFromDiskByUUIDOrNull(uuid)
    def self.getItemFromDiskByUUIDOrNull(uuid)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        return nil if filepath.nil?
        Solingen::getBladeAsItem(filepath)
    end

    # Solingen::loadItemFromDiskByUUIDAndputsIntoDataFileAndInMemory(uuid)
    def self.loadItemFromDiskByUUIDAndputsIntoDataFileAndInMemory(uuid)
        item = Solingen::getItemFromDiskByUUIDOrNull(uuid)
        return if item.nil?
        puts "Solingen::loadItemFromDiskByUUIDAndputsIntoDataFileAndInMemory(#{uuid}): #{JSON.pretty_generate(item).green}"
        Solingen::putItemIntoDataFileAndInMemory(item)
    end

    # ----------------------------------------------
    # Solingen Service Interface

    # Solingen::mikuTypes()
    def self.mikuTypes()
        Solingen::getInMemoryItems().keys
    end

    # Solingen::mikuTypeItems(mikuType)
    def self.mikuTypeItems(mikuType)
        data = Solingen::getInMemoryItems()
        return [] if data[mikuType].nil?
        data[mikuType].values
    end

    # Solingen::getItemOrNull(uuid)
    def self.getItemOrNull(uuid)
        mikuTypes = Solingen::getInMemoryItems().keys
        data = Solingen::getInMemoryItems()
        mikuTypes.each{|mikuType|
            return data[mikuType][uuid] if data[mikuType][uuid]
        }
        nil
    end

    # Solingen::mikuTypeCount(mikuType)
    def self.mikuTypeCount(mikuType)
        data = Solingen::getInMemoryItems()
        return 0 if data[mikuType].nil?
        data[mikuType].values.size
    end
end

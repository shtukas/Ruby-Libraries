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
        Solingen::loadItemFromDiskByUUIDAndCacheIntoDateFile(uuid)
    end

    # Solingen::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)
        Solingen::loadItemFromDiskByUUIDAndCacheIntoDateFile(uuid)
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
        Solingen::getMikuTypesCached().each{|mikuType|
            items = Solingen::mikuTypeItems(mikuType).reject{|i| i["uuid"] == item["uuid"] }
            XCache::set("mikuType(#{mikuType})->items:4f15-bb9c-1f1a7f1ad21", JSON.generate(items))
        }
    end

    # ----------------------------------------------
    # Solingen Service Private

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

    # Solingen::getMikuTypesCached()
    def self.getMikuTypesCached()
        mikuTypes = []
        db = SQLite3::Database.new(Solingen::dataFilepath())
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select _mikuType_ from _items_", []) do |row|
            mikuTypes << row["_mikuType_"]
        end
        db.close
        mikuTypes.uniq
    end

    # Solingen::putItemIntoDataFile(item)
    def self.putItemIntoDataFile(item)
        db = SQLite3::Database.new(Solingen::dataFilepath())
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        db.execute "delete from _items_ where _uuid_=?", [item["uuid"]]
        db.execute "insert into _items_ (_uuid_, _mikuType_, _position_, _item_) values (?, ?, ?, ?)", [item["uuid"], item["mikuType"], item["position"] || 0, JSON.generate(item)]
        db.close
    end

    # Solingen::loadItemFromDiskByUUIDOrNull(uuid)
    def self.loadItemFromDiskByUUIDOrNull(uuid)
        filepath = Blades::uuidToFilepathOrNull(uuid)
        return nil if filepath.nil?
        Solingen::getBladeAsItem(filepath)
    end

    # Solingen::loadItemFromDiskByUUIDAndCacheIntoDateFile(uuid)
    def self.loadItemFromDiskByUUIDAndCacheIntoDateFile(uuid)
        item = Solingen::loadItemFromDiskByUUIDOrNull(uuid)
        return if item.nil?
        puts "Solingen::loadItemFromDiskByUUIDAndCacheIntoDateFile(#{uuid}): #{JSON.pretty_generate(item).green}"
        Solingen::putItemIntoDataFile(item)
    end

    # ----------------------------------------------
    # Solingen Service Interface

    # Solingen::mikuTypes()
    def self.mikuTypes()
        Solingen::getMikuTypesCached()
    end

    # Solingen::mikuTypeItems(mikuType)
    def self.mikuTypeItems(mikuType)
        items = []
        db = SQLite3::Database.new(Solingen::dataFilepath())
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select * from _items_ where _mikuType_=? order by _position_", [mikuType]) do |row|
            items << JSON.parse(row["_item_"])
        end
        db.close
        items
    end

    # Solingen::getItemOrNull(uuid)
    def self.getItemOrNull(uuid)
        item = Solingen::loadItemFromDiskByUUIDOrNull(uuid)
        return nil if item.nil?
        Solingen::putItemIntoDataFile(item)
        item
    end

    # Solingen::mikuTypeCount(mikuType)
    def self.mikuTypeCount(mikuType)
        value = nil
        db = SQLite3::Database.new(Solingen::dataFilepath())
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        # We go through all the values, because the one we want is the last one
        db.execute("select count(*) as _count_ from _items_ where _mikuType_=?", [mikuType]) do |row|
            value = row["_count_"]
        end
        db.close
        raise "(error: 51803509-3648-44c6-ac14-2ee87c4e0e51) mikuType: #{mikuType}" if value.nil?
        value
    end
end

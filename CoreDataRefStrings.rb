
# encoding: UTF-8

class CoreDataRefStrings

    # CoreDataRefStrings::coreDataReferenceTypes()
    def self.coreDataReferenceTypes()
        ["text", "url", "aion point", "open cycle", "unique string", "Dx8Unit"]
    end

    # CoreDataRefStrings::interactivelySelectCoreDataReferenceType()
    def self.interactivelySelectCoreDataReferenceType()
        types = CoreDataRefStrings::coreDataReferenceTypes()
        LucilleCore::selectEntityFromListOfEntitiesOrNull("coredata reference type", types)
    end

    # CoreDataRefStrings::locationToAionPointCoreDataReference(uuid, location)
    def self.locationToAionPointCoreDataReference(uuid, location)
        if !File.exist?(location) then
            raise "(error: c1d975c5-8d18-4f28-abde-9a32869af017) CoreDataRefStrings::locationToAionPointCoreDataReference, location: '#{location}' does not exist."
        end
        nhash = AionCore::commitLocationReturnHash(BladeElizabeth.new(uuid), location)
        "aion-point:#{nhash}"
    end

    # CoreDataRefStrings::interactivelyMakeNewReferenceStringOrNull(uuid) # payload string
    def self.interactivelyMakeNewReferenceStringOrNull(uuid)
        # This function is called during the making of a new node (or when we are issuing a new payload of an existing node)
        # It does stuff and returns a payload string or null
        referencetype = CoreDataRefStrings::interactivelySelectCoreDataReferenceType()
        if referencetype.nil? then
            return nil
        end
        if referencetype == "text" then
            text = CommonUtils::editTextSynchronously("")
            nhash = Blades::putDatablob2(uuid, text)
            return "text:#{nhash}"
        end
        if referencetype == "url" then
            url = LucilleCore::askQuestionAnswerAsString("url: ")
            nhash = Blades::putDatablob2(uuid, url)
            return "url:#{nhash}"
        end
        if referencetype == "aion point" then
            location = CommonUtils::interactivelySelectDesktopLocationOrNull()
            return nil if location.nil?
            return CoreDataRefStrings::locationToAionPointCoreDataReference(uuid, location)
        end
        if referencetype == "open cycle" then
            fname = LucilleCore::askQuestionAnswerAsString("OpenCycle directory name: ")
            if !fname.start_with?("20") then
                fname = "#{CommonUtils::today()} #{fname}"
            end
            folderpath = "#{Config::pathToGalaxy()}/OpenCycles/#{fname}"
            if !File.exist?(folderpath) then
                FileUtils.mkdir(folderpath)
            end
            return "open-cycle:#{fname}"
        end
        if referencetype == "unique string" then
            uniquestring = LucilleCore::askQuestionAnswerAsString("unique string (if needed use Nx01-#{SecureRandom.hex[0, 12]}): ")
            return "unique-string:#{uniquestring}"
        end
        if referencetype == "Dx8Unit" then
            unitId = LucilleCore::askQuestionAnswerAsString("Dx8Unit Id: ")
            return "Dx8UnitId:#{unitId}"
        end
        raise "(error: f75b2797-99e5-49d0-8d49-40b44beb538c) unsupported core data reference type: #{referencetype}"
    end

    # CoreDataRefStrings::referenceStringToSuffixString(referenceString)
    def self.referenceStringToSuffixString(referenceString)
        if referenceString.nil? then
            return ""
        end
        if referenceString == "null" then
            return ""
        end
        if referenceString.start_with?("text") then
            return " (text)"
        end
        if referenceString.start_with?("url") then
            return " (url)"
        end
        if referenceString.start_with?("aion-point") then
            return " (aion point)"
        end
        if referenceString.start_with?("open-cycle") then
            return " (open-cycle)"
        end
        if referenceString.start_with?("unique-string") then
            str = referenceString.split(":")[1]
            return " (unique string: #{str})"
        end
        if referenceString.start_with?("Dx8UnitId") then
            return " (Dx8Unit)"
        end
        raise "CoreData, I do not know how to string '#{referenceString}'"
    end

    # CoreDataRefStrings::itemToSuffixString(item)
    def self.itemToSuffixString(item)
        CoreDataRefStrings::referenceStringToSuffixString(item["field11"])
    end

    # CoreDataRefStrings::access(uuid, referenceString)
    def self.access(uuid, referenceString)
        if referenceString.nil? then
            puts "Accessing null reference string. Nothing to do."
            LucilleCore::pressEnterToContinue()
            return
        end
        if referenceString == "null" then
            puts "Accessing null reference string. Nothing to do."
            LucilleCore::pressEnterToContinue()
            return
        end
        if referenceString.start_with?("text") then
            nhash = referenceString.split(":")[1]
            text = Blades::getDatablobOrNull2(uuid, nhash)
            puts "--------------------------------------------------------------"
            puts text
            puts "--------------------------------------------------------------"
            if LucilleCore::askQuestionAnswerAsBoolean("edit ? ") then
                text = CommonUtils::editTextSynchronously(text)
                nhash = Blades::putDatablob2(uuid, text)
                refstr = "text:#{nhash}"
                BladesGI::setAttribute2(uuid, "field11", refstr)
            end
            LucilleCore::pressEnterToContinue()
            return
        end
        if referenceString.start_with?("url") then
            nhash = referenceString.split(":")[1]
            url = Blades::getDatablobOrNull2(uuid, nhash)
            if url.nil? then
                puts "(error) I could not retrieve url for reference string: #{referenceString}"
                LucilleCore::pressEnterToContinue()
                return
            end
            puts "url: #{url}"
            CommonUtils::openUrlUsingSafari(url)
            LucilleCore::pressEnterToContinue()
            return
        end
        if referenceString.start_with?("aion-point") then
            nhash = referenceString.split(":")[1]
            puts "CoreData, accessing aion point: #{nhash}"
            exportId = SecureRandom.hex(4)
            exportFoldername = "aion-point-#{exportId}"
            exportFolder = "#{ENV['HOME']}/x-space/xcache-v1-days/#{Time.new.to_s[0, 10]}/#{exportFoldername}"
            FileUtils.mkpath(exportFolder)
            AionCore::exportHashAtFolder(BladeElizabeth.new(uuid), nhash, exportFolder)
            system("open '#{exportFolder}'")
            LucilleCore::pressEnterToContinue()
            return
        end
        if referenceString.start_with?("open-cycle") then
            fname = referenceString.split(":")[1]
            directoryFilepath = "#{ENV['HOME']}/Galaxy/OpenCycles/#{fname}"
            system("open '#{directoryFilepath}'")
            return
        end
        if referenceString.start_with?("unique-string") then
            uniquestring = referenceString.split(":")[1]
            puts "CoreData, accessing unique string: #{uniquestring}"
            location = Atlas::uniqueStringToLocationOrNull(uniquestring)
            if location then
                puts "location: #{location}"
                LucilleCore::pressEnterToContinue()
            end
            return
        end
        if referenceString.start_with?("Dx8UnitId") then
            unitId = referenceString.split(":")[1]
            Dx8Units::access(unitId)
            return
        end
        raise "CoreData, I do not know how to access '#{referenceString}'"
    end

    # CoreDataRefStrings::fsck(item)
    def self.fsck(item)
        uuid = item["uuid"]
        referenceString = item["field11"]
        puts "CoreDataRefStrings::fsck(#{JSON.pretty_generate(item)})"
        if referenceString.nil? then
            return
        end
        if referenceString == "null" then
            return
        end
        if referenceString.start_with?("text") then
            nhash = referenceString.split(":")[1]
            text = BladeElizabeth.new(uuid).getBlobOrNull(nhash)
            if text.nil? then
                raise "CoreDataRefStrings::fsck: could not extract text for uuid: #{uuid}, reference string: #{referenceString}"
            end
            return
        end
        if referenceString.start_with?("url") then
            nhash = referenceString.split(":")[1]
            url = BladeElizabeth.new(uuid).getBlobOrNull(nhash)
            if url.nil? then
                raise "CoreDataRefStrings::fsck: could not extract url for uuid: #{uuid}, reference string: #{referenceString}"
            end
            return
        end
        if referenceString.start_with?("aion-point") then
            nhash = referenceString.split(":")[1]
            AionFsck::structureCheckAionHashRaiseErrorIfAny(BladeElizabeth.new(uuid), nhash)
            return
        end
        if referenceString.start_with?("open-cycle") then
            return
        end
        if referenceString.start_with?("unique-string") then
            return
        end
        if referenceString.start_with?("Dx8UnitId") then
            return
        end
        raise "CoreData, I do not know how to access '#{referenceString}'"
    end
end

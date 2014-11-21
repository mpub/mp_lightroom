--[[----------------------------------------------------------------------------

MetroPublisherExportServiceProvider.lua
Export service provider description for Lightroom MetroPublisher uploader

------------------------------------------------------------------------------]]

local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

    -- MetroPublisher plug-in
require 'MetroPublisherAPI'
require 'MetroPublisherUploadExportDialog'

local exportServiceProvider = {}

exportServiceProvider.exportPresetFields = {
    { key = 'api_key', default = "" },
    { key = 'secret', default = "" },
    { key = 'instance_id', default = "" },
    { key = 'add_article', default = false },
    { key = 'article_title', default = "" },
    { key = 'urlname', default = "" },
    { key = 'relevance', default = "" },
    { key = 'display', default = "" },
    { key = 'publish', default = true },
    { key = 'open_in_browser', default = true },
    { key = 'section_uuid', default = "" },
    { key = 'content', default = "" },
    { key = 'description', default = "" },
    { key = 'section_list', default = {{ title = "No Section", value = "" }} },
}

exportServiceProvider.hideSections = { 'exportLocation', 'video' }
exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = nil

exportServiceProvider.startDialog = MetroPublisherUploadExportDialog.startDialog
exportServiceProvider.sectionsForTopOfDialog = MetroPublisherUploadExportDialog.sectionsForTopOfDialog


function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
    
    local exportSession = exportContext.exportSession

    -- Make a local reference to the export parameters.
    
    local exportSettings = assert( exportContext.propertyTable )
        
    -- Get the # of photos.
    
    local nPhotos = exportSession:countRenditions()
    
    -- Set progress title.
    
    local progressScope = exportContext:configureProgress {
                        title = nPhotos > 1
                                    and LOC( "$$$/MetroPublisher/Publish/Progress=Publishing ^1 photos to MetroPublisher", nPhotos )
                                    or LOC "$$$/MetroPublisher/Publish/Progress/One=Publishing one photo to MetroPublisher",
                    }

    -- Iterate through photo renditions.
    
    local failures = {}
    local photos_added = {}
    local article_uuid

    -- get Authorization Token
    MetroPublisherAPI.getAuthToken()
    
    if exportSettings.add_article then
        article_uuid, slot_uuid = MetroPublisherAPI.addArticle()
    end

    for _, rendition in exportContext:renditions{ stopIfCanceled = true } do
    
        -- Wait for next photo to render.

        local success, pathOrMessage = rendition:waitForRender()
        
        -- Check for cancellation again after photo has been rendered.
        
        if progressScope:isCanceled() then break end
        
        if success then

            local filename = LrPathUtils.leafName( pathOrMessage )
            local filetype = exportContext.propertyTable.LR_format
            local title = rendition.photo:getFormattedMetadata( 'title' )
            local headline = rendition.photo:getFormattedMetadata( 'headline' )
            if not title or title == '' then
                title = headline
            end
            local description = rendition.photo:getFormattedMetadata( 'caption' )
            local copyright = rendition.photo:getFormattedMetadata( 'copyright' )

            local photo = MetroPublisherAPI.uploadPhoto( filename, filetype, title, description, copyright, pathOrMessage )
            table.insert(photos_added, photo)
                    
            -- When done with photo, delete temp file. There is a cleanup step that happens later,
            -- but this will help manage space in the event of a large upload.
            
            LrFileUtils.delete( pathOrMessage )
                    
        end
        
    end

    if exportSettings.add_article then
        MetroPublisherAPI.addMedia( article_uuid, slot_uuid, photos_added )
        LrDialogs.message(LOC "$$$/MetroPublisher/ExportDialog/ArticleSuccess=Article successfully created.")
        if exportSettings.open_in_browser then
            MetroPublisherAPI.showArticle( article_uuid )
        end
    end

end

--------------------------------------------------------------------------------

return exportServiceProvider

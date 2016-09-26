--[[----------------------------------------------------------------------------

MetroPublisherUploadExportDialog
Export dialog customization for Lightroom MetroPublisher uploader

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import "LrBinding"

    -- MetroPublisher plug-in
require 'MetroPublisherAPI'

--============================================================================--

MetroPublisherUploadExportDialog = {}

-------------------------------------------------------------------------------

local function updateExportStatus( propertyTable )
    
    local message = nil
    
    repeat
        -- Use a repeat loop to allow easy way to "break" out.
        -- (It only goes through once.)
        
        if propertyTable.api_key == "" or propertyTable.api_key == nil or propertyTable.secret == "" or propertyTable.secret == nil 
         or propertyTable.instance_id == "" or propertyTable.instance_id == nil then
            message = LOC "$$$/MetroPublisher/ExportDialog/Messages/EnterKeySecret=Enter API Key and secret"
            break
        end

    until true
    
    if message then
        propertyTable.message = message
        propertyTable.hasError = true
        propertyTable.hasNoError = false
        propertyTable.LR_cantExportBecause = message
    else
        propertyTable.message = nil
        propertyTable.hasError = false
        propertyTable.hasNoError = true
        propertyTable.LR_cantExportBecause = nil
    end
    
end

-------------------------------------------------------------------------------

function MetroPublisherUploadExportDialog.startDialog( propertyTable )
    -- reset Article Data
    propertyTable.add_article = false
    propertyTable.article_title = ''
    propertyTable.urlname = ''
    propertyTable.relevance = 'inline'
    propertyTable.display = 'carousel'
    propertyTable.publish = true
    propertyTable.open_in_browser = true
    propertyTable.section_uuid  = ''
    propertyTable.content = ''
    propertyTable.description = ''
    
    
    -- not sure if it's a good idea to force this every time the dialog opens
    propertyTable.LR_size_doConstrain = true
    propertyTable.LR_size_doNotEnlarge = false
    propertyTable.LR_size_resizeType = 'longEdge'
    propertyTable.LR_size_maxWidth = 1280
    propertyTable.LR_size_units = 'pixels'
    propertyTable.LR_size_resolution = 72
    propertyTable.LR_size_resolutionUnits = 'inch'
    propertyTable.LR_jpeg_useLimitSize = true
    propertyTable.LR_jpeg_limitSize = 749
    
    propertyTable:addObserver( 'items', updateExportStatus )
    propertyTable:addObserver( 'api_key', updateExportStatus )
    propertyTable:addObserver( 'secret', updateExportStatus )
    propertyTable:addObserver( 'instance_id', updateExportStatus )
    propertyTable:addObserver( 'section_uuid', updateExportStatus )
    
    updateExportStatus( propertyTable )
    
end

-------------------------------------------------------------------------------

function MetroPublisherUploadExportDialog.sectionsForTopOfDialog( _, propertyTable )

    local f = LrView.osFactory()
    local bind = LrView.bind
    local share = LrView.share

    local section_popup = f:popup_menu {
            value = bind 'section_uuid',
            enabled = bind 'add_article',
            items = bind 'section_list',
    }


    local result = {
    
        {
            title = LOC "$$$/MetroPublisher/ExportDialog/MetroPublisherSettings=MetroPublisher",
            
            synopsis = bind { key = 'api_key', object = propertyTable },
            
            f:row {
                f:column {
                    f:picture {
                        value = _PLUGIN:resourceId('mp-logo.png'),
                    },
                },
                f:column {
                    f:row {
                        f:static_text {
                            title = LOC "$$$/MetroPublisher/ExportDialog/MPTitle=Metro Publisher Lightroom Plugin V 1.4",
                            font = '<system/bold>',
                            alignment = 'right',
                        },
                    },
                    f:row {
                        f:static_text {
                            title = LOC "$$$/MetroPublisher/ExportDialog/MPText=Packed with great features and at a price that no other CMS can beat, Metro Publisher is built to help media companies, regardless of their size, succeed online. Free yourself from the responsibilities and headaches of technology problems so you can focus on your core competencies of growing audience, increasing revenue and building your brand online.",
                            wrap = true,
                            alignment = 'left',
                            width_in_chars = 40,
                            height_in_lines = 6
                        },
                    },
                },
            },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/APIKey=API Key:",
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:edit_field {
                    value = bind 'api_key',
                    width_in_chars = 45
                },    
            },

            synopsis = bind { key = 'secret', object = propertyTable },
            
            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/Secret=Secret:",
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:password_field {
                    value = bind 'secret',
                    width_in_chars = 45
                },    
            },

            synopsis = bind { key = 'instance_id', object = propertyTable },
            
            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/InstanceID=Instance ID:",
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:edit_field {
                    value = bind 'instance_id',
                },    
            },

            synopsis = bind { key = 'add_article', object = propertyTable },

            f:row {
                    f:checkbox {
                        title = LOC "$$$/MetroPublisher/ExportDialog/AddArticle=Add Article for images",
                        value = bind 'add_article',
                    },
            },

            synopsis = bind { key = 'article_title', object = propertyTable },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/ArticleTitle=Article Title:",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:edit_field {
                    value = bind 'article_title',
                    enabled = bind 'add_article',
                },    
            },

            synopsis = bind { key = 'urlname', object = propertyTable },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/ArticleURLName=Article URL Name:",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:edit_field {
                    value = bind 'urlname',
                    enabled = bind 'add_article',
                },    
            },

            synopsis = bind { key = 'publish', object = propertyTable },
            synopsis = bind { key = 'open_in_browser', object = propertyTable },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/PublishArticle=Publish Article",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:checkbox {
                    value = bind 'publish',
                    enabled = bind 'add_article',
                },

                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/OpenInBrowser=Open in Browser after adding",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:checkbox {
                    value = bind 'open_in_browser',
                    enabled = bind 'add_article',
                },
            },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/Position=Position",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:radio_button {
                    enabled = bind 'add_article',
                    title = "Full Width",
                    value = bind 'relevance', 
                    checked_value = 'inline',
                }, 
                f:radio_button {
                    enabled = bind 'add_article',
                    title = "Aside",
                    value = bind 'relevance',
                    checked_value = 'aside',
                },
            },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/Display=Display",
                    enabled = bind {
                        keys = { 'add_article', 'relevance' },
                        operation = function( binder, values, fromTable )
                            if fromTable then
                                return (values.add_article and values.relevance == 'inline')
                            end
                            return LrBinding.kUnsupportedDirection
                        end 
                    },
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:radio_button {
                    enabled = bind {
                        keys = { 'add_article', 'relevance' },
                        operation = function( binder, values, fromTable )
                            if fromTable then
                                return (values.add_article and values.relevance == 'inline')
                            end
                            return LrBinding.kUnsupportedDirection
                        end 
                    },
                    title = "Carousel",
                    value = bind 'display', 
                    checked_value = 'carousel',
                }, 
                f:radio_button {
                    enabled = bind {
                        keys = { 'add_article', 'relevance' },
                        operation = function( binder, values, fromTable )
                            if fromTable then
                                return (values.add_article and values.relevance == 'inline')
                            end
                            return LrBinding.kUnsupportedDirection
                        end 
                    },
                    title = "Gallery",
                    value = bind 'display',
                    checked_value = 'gallery',
                },
            },

            synopsis = bind { key = 'section_uuid', object = propertyTable },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/ArticleSection=Article Section:",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                section_popup,
                f:push_button {
                    title = "Update Sections",
                    enabled = bind 'add_article',
                    action = function()
                        LrFunctionContext.postAsyncTaskWithContext("get mp sections",
                            function(context)
                                section_popup.items =  MetroPublisherAPI.getSections()
                            end )
                        LrDialogs.message('Sections updated')
                    end
                },
            },
            
            synopsis = bind { key = 'description', object = propertyTable },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/ArticleDescription=Article Description:",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:edit_field {
                    value = bind 'description',
                    enabled = bind 'add_article',
                    width_in_chars = 40,
                    height_in_lines = 6,
                },    
            },

            synopsis = bind { key = 'content', object = propertyTable },

            f:row {
                f:static_text {
                    title = LOC "$$$/MetroPublisher/ExportDialog/ArticleContent=Article Content:",
                    enabled = bind 'add_article',
                    alignment = 'right',
                    width = share 'labelWidth'
                },
                f:edit_field {
                    value = bind 'content',
                    enabled = bind 'add_article',
                    width_in_chars = 40,
                    height_in_lines = 10,
                },    
            },

            
        },
    }

    propertyTable:addObserver( 'article_title', function( properties, key, newValue )
        local new_urlname = string.lower(newValue)
        new_urlname = string.gsub(new_urlname, " ", "-")
        -- new_urlname = title_value.toLowerCase().replace(/\s+$/, "").replace(/\//, "").replace(/ /g, '-');
        propertyTable.urlname = new_urlname
    end )

    propertyTable:addObserver( 'publish', function( properties, key, newValue )
        propertyTable.open_in_browser = newValue
    end )
        
    propertyTable:addObserver( 'open_in_browser', function( properties, key, newValue )
        if newValue == true then
            propertyTable.publish = true
        end
    end )
        
    return result
    
end


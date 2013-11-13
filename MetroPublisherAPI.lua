--[[----------------------------------------------------------------------------

MetroPublisherAPI.lua
Code to initiate MetroPublisher API requests

------------------------------------------------------------------------------]]

json = require 'dkjson'

-- Lightroom SDK
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import 'LrHttp'
local LrFileUtils = import 'LrFileUtils'
local LrDate = import 'LrDate'
local lrUuid = import 'LrUUID'
local LrErrors = import 'LrErrors'

local prefs = import 'LrPrefs'.prefsForPlugin()

local bind = LrView.bind
local share = LrView.share

local logger = import 'LrLogger'( 'MetroPublisherAPI' )
logger:enable('print')

MetroPublisherAPI = {}

--------------------------------------------------------------------------------
function MetroPublisherAPI.getIssuedDate()
    -- append Z to indicate that we are sending utc datetime
    local date = LrDate.currentTime()
    local w3c_date = LrDate.timeToW3CDate( date )
    local utc_date = string.format('%sZ', w3c_date)
    return utc_date
end

function MetroPublisherAPI.getAuthToken()
    -- gets a new Authorisation Token from MetroPublisher and save it in the preferences
    local api_key, secret = prefs.api_key, prefs.secret
    local url = 'https://go.vanguardistas.net/oauth/token'
    local data = string.format( 'grant_type=client_credentials&api_key=%s&api_secret=%s', assert( api_key,  secret) )

    logger:info( 'getting MetroPublisher Auth Token:', url )
   
    local response, hdrs = LrHttp.post( url, data, {{
            field = 'Content-Type',
            value = 'application/x-www-form-urlencoded',
        }
    })
    
    logger:info( 'MetroPublisher response:', response)
    local json_resp = json.decode(response)
    prefs.access_token = json_resp.access_token
    return json_resp
end

--------------------------------------------------------------------------------

function MetroPublisherAPI.makeAuthHeader( ctype )
    -- Create header table to be send with a request to MetroPublisher

    -- default to form urlencoded
    ctype = ctype or 'application/x-www-form-urlencoded'

    -- Automatically get Auth Token key.
    if not prefs.access_token then
        MetroPublisherAPI.getAuthToken()
    end

    local auth = string.format( 'Bearer %s', prefs.access_token)
    logger:info( 'call MetroPublisher makeAuthHeader:', auth )
    local headers = {
         { field = 'Authorization', value = auth },
         { field = 'Content-Type', value = ctype },
    }
    return headers
     
end
--------------------------------------------------------------------------------

function MetroPublisherAPI.checkMetroPublisherResponse( json_resp )
    -- check the response we got from MetroPublisher and raise an error if something went wrong
    if json_resp.error ~= nil then
        local error_info = ''
        if json_resp.error_info ~= nil then
            if type(json_resp.error_info) == 'table' then
                for key,value in pairs(json_resp.error_info) do
                    error_info = tostring(key) .. ': ' .. tostring(value) .. ' '
                end
            end
            if type(json_resp.error_info) == 'string' then
                local error_info = json_resp.error_info
            end
        end
        LrErrors.throwUserError( LOC( "$$$/Flickr/Error/API/Upload=MetroPublisher API returned an error message (Message: ^1. ^2)",
                            tostring( json_resp.error_description ), error_info ) )
    end
    
end


--------------------------------------------------------------------------------

function MetroPublisherAPI.uploadPhoto( filename, filetype, title, description, copyright, path )
    -- upload an Image to MetroPublisher
    logger:info( 'call MetroPublisher uploadPhoto:', file )

    -- generate new image uuid
    local uuid = lrUuid.generateUUID()
    
    -- first we add the file with some metadata
    local url = string.format('https://api.metropublisher.com/%s/files/%s', prefs.instance_id, uuid)
    local headers = MetroPublisherAPI.makeAuthHeader('application/json')
    
    local metadata_table = {}
    metadata_table.filename = tostring(filename)
    if title and title ~= '' then
        metadata_table.title = tostring(title)
    else
        metadata_table.title = tostring(filename)
    end
    if description and description ~= '' then
        metadata_table.description = tostring(description)
    end
    if copyright and copyright ~= '' then
        metadata_table.credits = tostring(copyright)
    end
    
    local data = json.encode(metadata_table)
    local response, hdrs = LrHttp.post( url, data, headers, 'PUT')
    local json_resp = json.decode(response)
    MetroPublisherAPI.checkMetroPublisherResponse(json_resp)
    
    
    -- then update the filedata
    local ctype = string.format('image/%s', string.lower(filetype))
    local file = LrFileUtils.readFile( path )
    headers = MetroPublisherAPI.makeAuthHeader(ctype)
    local postBody = file
    local response, hdrs = LrHttp.post( url, postBody, headers )
        
    -- Parse MetroPublisher response for photo ID.
    
    local json_resp = json.decode(response)
    MetroPublisherAPI.checkMetroPublisherResponse(json_resp)
    local resp_table = {}
    resp_table.uuid = json_resp.uuid
    resp_table.title = title
    resp_table.filename = filename
    resp_table.description = description
    return resp_table
    
end

--------------------------------------------------------------------------------

function MetroPublisherAPI.addArticle()
    -- add Article in MetroPublisher to be used to add the Images to
    logger:info( 'call MetroPublisher addArticle:' )

    -- generate new article uuid
    local uuid = lrUuid.generateUUID()
    
    -- first we add the article with some metadata
    local url = string.format('https://api.metropublisher.com/%s/content/%s', prefs.instance_id, uuid)
    local headers = MetroPublisherAPI.makeAuthHeader('application/json')
    
    local metadata_table = {}
    metadata_table.urlname = prefs.urlname
    if prefs.section_uuid and prefs.section_uuid ~= '' then
        metadata_table.section_uuid = prefs.section_uuid
    end

    metadata_table.title = prefs.article_title
    metadata_table.content_type = 'article'

    if prefs.description and prefs.description ~= '' then
        metadata_table.description = prefs.description
    end

    if prefs.content and prefs.content ~= '' then
        metadata_table.content = '<p>' .. prefs.content .. '</p>'
    end

    if prefs.publish then
        metadata_table.state = 'published'
        metadata_table.issued = MetroPublisherAPI.getIssuedDate()
    end

    local data = json.encode(metadata_table)
    
    local response, hdrs = LrHttp.post( url, data, headers, 'PUT')

    -- Parse MetroPublisher response to see if the article was added correctly.    
    local json_resp = json.decode(response)
    MetroPublisherAPI.checkMetroPublisherResponse(json_resp)
    return uuid
end

--------------------------------------------------------------------------------

function MetroPublisherAPI.addMedia( article_uuid, photos_added )
    -- attach the images we have added before to the article we have added before
    local image_data_table = {}
    local images = {}

    for i, v in ipairs(photos_added) do
        local image = {}
        image.type = 'file'
        if v.title and v.title ~= '' then
            image.title = v.title
        else
            image.title = v.filename
        end
        if v.description and v.description ~= '' then
            image.content = '<p>' .. v.description .. '</p>'            
        end
        image.image_uuid = v.uuid
        table.insert( images, image )
    end
    image_data_table.items = images
    local images_data = json.encode(image_data_table)

    local url = string.format('https://api.metropublisher.com/%s/content/%s/media', prefs.instance_id, article_uuid)
    local headers = MetroPublisherAPI.makeAuthHeader('application/json')
    local response, hdrs = LrHttp.post( url, images_data, headers, 'PUT' )    
    
    local json_resp = json.decode(response)
    MetroPublisherAPI.checkMetroPublisherResponse(json_resp)
end

--------------------------------------------------------------------------------

function MetroPublisherAPI.formatSections(section_data)
    -- add the parent section titles to subsection titles and sort them again
    local section_by_id = {}
    for i, v in ipairs(section_data) do
        section_by_id[v.uuid] = v
    end
    
    local sections = {}
    for i, v in ipairs(section_data) do
        title = v.title
        if v.parentid then
            parent = section_by_id[v.parentid]
            while true do
                title = string.format('%s - %s', parent.title, title)
                if parent.parentid then
                    parent = section_by_id[parent.parentid]
                else
                    break
                end
            end
        end
        table.insert(sections, { title = title, value = v.uuid })
    end
    table.sort(sections, function(a,b) return a.title < b.title end)
    table.insert(sections, 1, { title = "No Section", value = "" })
    return sections
end

--------------------------------------------------------------------------------

function MetroPublisherAPI.getSections()
    -- load the sections from MetroPublisher to show them in the Article Dialog

    -- get Authorization Token
    -- not very nice to get a new token on every section update but we can't be sure to be authenticated at this point
    MetroPublisherAPI.getAuthToken()
    local next_page_exists = true
    local section_data = {}
    local headers = MetroPublisherAPI.makeAuthHeader()
    local data = string.format( 'fields=title-uuid-parentid' )
    local url = string.format('https://api.metropublisher.com/%s/sections?%s', prefs.instance_id, data)

    while next_page_exists do
        local response, hdrs = LrHttp.get( url, headers)
    
        -- Parse MetroPublisher response to get the sections.    
        local json_resp = json.decode(response)
        MetroPublisherAPI.checkMetroPublisherResponse(json_resp)
        for i, v in ipairs(json_resp.items) do
            table.insert(section_data, { title = v[1], uuid = v[2], parentid = v[3] })
        end
        if json_resp.next then
            url = string.format('https://api.metropublisher.com/%s/sections?%s', prefs.instance_id, json_resp.next)
        else
            next_page_exists = false
        end
    end
    local sections = MetroPublisherAPI.formatSections(section_data)
    return sections
end

--------------------------------------------------------------------------------

function MetroPublisherAPI.showArticle( article_uuid )
    -- get the public URL for the new Article and open it in a Browser
    -- get public Article URL
    local headers = MetroPublisherAPI.makeAuthHeader()
    local url = string.format('https://api.metropublisher.com/%s/content/%s/info', prefs.instance_id, article_uuid)
    local response, hdrs = LrHttp.get( url, headers)
    local json_resp = json.decode(response)
    MetroPublisherAPI.checkMetroPublisherResponse(json_resp)
    local public_url = json_resp.public_url
    LrHttp.openUrlInBrowser( public_url )
end

